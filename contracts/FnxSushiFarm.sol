pragma solidity 0.5.16;
pragma experimental ABIEncoderV2;

import "./openzeppelin/contracts/ownership/Ownable.sol";
import "./openzeppelin/contracts/math/SafeMath.sol";
import "./openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "./openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./FnxSushiFarmStorage.sol";
import "./FnxSushiFarmInterface.sol";
import "./UniFarm.sol";

interface ISushiChef {
    function deposit(uint256 _pid, uint256 _amount) external;
    function emergencyWithdraw(uint256 _pid) external;
    function getMultiplier(uint256 _from, uint256 _to) external view returns (uint256);
    function pendingSushi(uint256 _pid, address _user)  external view returns (uint256);
    function sushi() external view returns (address);
    function sushiPerBlock() external view returns (uint256);
    function poolInfo(uint256) external  view returns ( address lpToken, uint256 allocPoint, uint256 lastRewardBlock, uint256 accsushiPerShare);
    function poolLength() external view returns (uint256);
    function totalAllocPoint() external view returns (uint256);
    function userInfo(uint256, address) external view returns (uint256 amount, uint256 rewardDebt);
    function withdraw(uint256 _pid, uint256 _amount) external;
}

contract FnxSushiFarm is FnxSushiFarmV1Storage, FnxSushiFarmInterface{
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IERC20 public fnxToken = IERC20(0xeF9Cd7882c067686691B6fF49e650b43AFBBCC6B);

    event QuitFnx(address to, uint256 amount);
    event QuitExtReward(address extFarmAddr, address rewardToken, address to, uint256 amount);
    event UpdatePoolInfo(uint256 pid, uint256 bonusEndBlock, uint256 fnxPerBlock);
    event WithdrawFnx(address to, uint256 amount);
    event DoubleFarmingEnable(uint256 pid, bool flag);
    event SetExtFarm(uint256 pid, address extFarmAddr, uint256 extPid );
    event EmergencyWithdraw(uint256 indexed pid);


    constructor() public {
        admin = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == admin, "Ownable: caller is not the owner");
        _;
    }

    function _poolInfo(uint256 _pid) external view returns (
        address lpToken,         // Address of LP token contract.
        uint256 currentSupply,    //
        uint256 bonusStartBlock,  //
        uint256 newStartBlock,    //
        uint256 bonusEndBlock,    // Block number when bonus fnx period ends.

        uint256 lastRewardBlock,  // Last block number that fnxs distribution occurs.
        uint256 accFnxPerShare,// Accumulated fnxs per share, times 1e12. See below.
        uint256 fnxPerBlock,   // fnx tokens created per block.
        uint256 totalDebtReward){

            require(_pid < poolInfo.length,"pid >= poolInfo.length");
            PoolInfo storage pool = poolInfo[_pid]; 

            return (
                address(pool.lpToken),
                pool.currentSupply,
                pool.bonusStartBlock,
                pool.newStartBlock,
                pool.bonusEndBlock,

                pool.lastRewardBlock,
                pool.accFnxPerShare,
                pool.fnxPerBlock,
                pool.totalDebtReward
                );
        }
    
    function _extFarmInfo(uint256 _pid) external view returns (
		address extFarmAddr,  
        bool extEnableDeposit,
        uint256 extPid,
        uint256 extRewardPerShare,
        uint256 extTotalDebtReward,  //
        bool extEnableClaim){

            require(_pid < poolInfo.length,"pid >= poolInfo.length");
            PoolInfo storage pool = poolInfo[_pid]; 

            return (
                pool.extFarmInfo.extFarmAddr,
                pool.extFarmInfo.extEnableDeposit,
                pool.extFarmInfo.extPid,
                pool.extFarmInfo.extRewardPerShare,
                pool.extFarmInfo.extTotalDebtReward,
                pool.extFarmInfo.extEnableClaim);
        }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(address _lpToken,
                 uint256 _bonusStartBlock,
                 uint256 _bonusEndBlock,
                 uint256 _fnxPerBlock,
                 uint256 _totalMineFnx,
                 uint256 _duration
                 ) public onlyOwner {
        require(block.number < _bonusEndBlock, "block.number >= bonusEndBlock");
        require(_bonusStartBlock < _bonusEndBlock, "_bonusStartBlock >= _bonusEndBlock");
        require(address(_lpToken) != address(0), "_lpToken == 0");
        uint256 lastRewardBlock = block.number > _bonusStartBlock ? block.number : _bonusStartBlock;

        ExtFarmInfo memory extFarmInfo = ExtFarmInfo({
                extFarmAddr:address(0x0),
                extEnableDeposit:false,
                extPid: 0,
                extRewardPerShare: 0,
                extTotalDebtReward:0,
                extEnableClaim:false
                });


        poolInfo.push(PoolInfo({
            lpToken: IERC20(_lpToken),
            currentSupply: 0,
            bonusStartBlock: _bonusStartBlock,
            newStartBlock: _bonusStartBlock,
            bonusEndBlock: _bonusEndBlock,
            lastRewardBlock: lastRewardBlock,
            accFnxPerShare: 0,
            fnxPerBlock: _fnxPerBlock,
            totalDebtReward: 0,
            extFarmInfo:extFarmInfo
        }));

        PoolMineInfo memory pmi = PoolMineInfo({
            totalMineFnx:_totalMineFnx,
            duration:_duration
        });

        poolMineInfo[poolInfo.length-1] = pmi;
    }

    function updatePoolInfo(uint256 _pid, uint256 _bonusEndBlock, uint256 _fnxPerBlock,uint256 _totalMineFnx,uint256 _duration) public onlyOwner {
        require(_pid < poolInfo.length,"pid >= poolInfo.length");
        require(_bonusEndBlock > block.number, "_bonusEndBlock <= block.number");
        updatePool(_pid);
        PoolInfo storage pool = poolInfo[_pid];
        if(pool.bonusEndBlock <= block.number){
            pool.newStartBlock = block.number;
        }

        pool.bonusEndBlock = _bonusEndBlock;
        pool.fnxPerBlock = _fnxPerBlock;
        //keep it to later show
        poolMineInfo[_pid].totalMineFnx=_totalMineFnx;
        poolMineInfo[_pid].duration=_duration;

        emit UpdatePoolInfo(_pid, _bonusEndBlock, _fnxPerBlock);
    }

    function getMultiplier(uint256 _pid) internal view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        if(block.number <= pool.bonusStartBlock){
            return 0;// no begin
        }

        if(pool.lastRewardBlock >= pool.bonusEndBlock){
            return 0;// ended
        }

        if(block.number >= pool.bonusEndBlock){
            // ended, but no update, lastRewardBlock < bonusEndBlock
            return pool.bonusEndBlock.sub(pool.lastRewardBlock);
        }

        return block.number.sub(pool.lastRewardBlock);
    }

    // View function to see pending fnxs on frontend.
    function pendingFnx(uint256 _pid, address _user) public view returns (uint256,uint256) {
        require(_pid < poolInfo.length,"pid >= poolInfo.length");
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accFnxPerShare = pool.accFnxPerShare;
        if (block.number > pool.lastRewardBlock && pool.currentSupply != 0) {
            uint256 multiplier = getMultiplier(_pid);
            uint256 fnxReward = multiplier.mul(pool.fnxPerBlock);
            accFnxPerShare = accFnxPerShare.add(fnxReward.mul(1e12).div(pool.currentSupply));
        }
        return (user.amount, user.amount.mul(accFnxPerShare).div(1e12).sub(user.rewardDebt));
    }

    /////////////////////////////////////////////////////////////////////////////////////////
    function totalUnclaimedExtFarmReward(address extFarmAddr) public view returns(uint256){
        
        uint256 allTotalUnclaimed = 0; 
        
        for (uint256 index = 0; index < poolInfo.length; index++) {
            PoolInfo storage pool = poolInfo[index];

            if(pool.extFarmInfo.extFarmAddr == address(0x0) || pool.extFarmInfo.extFarmAddr != extFarmAddr) continue;

            allTotalUnclaimed = pool.currentSupply.mul(pool.extFarmInfo.extRewardPerShare).div(1e12).sub(pool.extFarmInfo.extTotalDebtReward).add(allTotalUnclaimed);
            
        }

        return allTotalUnclaimed;
    }

    function distributeFinalExtReward(uint256 _pid, uint256 _amount) public onlyOwner{

        require(_pid < poolInfo.length,"pid >= poolInfo.length");
        PoolInfo storage pool = poolInfo[_pid];
        require(pool.extFarmInfo.extFarmAddr != address(0x0),"pool not supports double farming");

        uint256 allUnClaimedExtReward = totalUnclaimedExtFarmReward(pool.extFarmInfo.extFarmAddr);

        uint256 extRewardCurrentBalance = IERC20(ISushiChef(pool.extFarmInfo.extFarmAddr).sushi()).balanceOf(address(this));

        uint256 maxDistribute = extRewardCurrentBalance.sub(allUnClaimedExtReward);

        require(_amount <= maxDistribute,"distibute too much external rewards");

        pool.extFarmInfo.extRewardPerShare = _amount.mul(1e12).div(pool.currentSupply).add(pool.extFarmInfo.extRewardPerShare);
    }

    function getExtFarmRewardRate(ISushiChef sushiChef,IERC20 lpToken, uint256 extPid) internal view returns(uint256 rate){

        uint256 multiplier = sushiChef.getMultiplier(block.number-1, block.number);
        uint256 sushiPerBlock = sushiChef.sushiPerBlock();
        (,uint256 allocPoint,,) = sushiChef.poolInfo(extPid);
        uint256 totalAllocPoint = sushiChef.totalAllocPoint();
        uint256 totalSupply = lpToken.balanceOf(address(sushiChef));

        rate = multiplier.mul(sushiPerBlock).mul(allocPoint).mul(1e12).div(totalAllocPoint).div(totalSupply);
    }

    function extRewardPerBlock(uint256 _pid) public view returns(uint256){
        require(_pid < poolInfo.length,"pid >= poolInfo.length");
        PoolInfo storage pool = poolInfo[_pid];

        if(!pool.extFarmInfo.extEnableDeposit) return 0;

        ISushiChef sushiChef = ISushiChef(pool.extFarmInfo.extFarmAddr);
        uint256 rate = getExtFarmRewardRate(sushiChef, pool.lpToken,pool.extFarmInfo.extPid);
        (uint256 amount,) = sushiChef.userInfo(_pid,address(this));
        uint256 extReward = rate.mul(amount).div(1e12);

        return extReward;
    }
    
    function allPendingReward(uint256 _pid,address _user) public view returns(uint256,uint256,uint256){
        uint256 depositAmount;
        uint256 fnxReward;
        uint256 sushiReward;
        
        (depositAmount,fnxReward) = pendingFnx(_pid,_user);
        sushiReward = pendingExtReward(_pid,_user);
        
        return (depositAmount,fnxReward,sushiReward);
    }

    function enableDoubleFarming(uint256 _pid, bool enable)public onlyOwner{
        require(_pid < poolInfo.length,"pid >= poolInfo.length");
        PoolInfo storage pool = poolInfo[_pid];

        require(pool.extFarmInfo.extFarmAddr != address(0x0),"pool not supports double farming yet");
        if(pool.extFarmInfo.extEnableDeposit != enable){

            uint256 oldSuShiRewarad = IERC20(ISushiChef(pool.extFarmInfo.extFarmAddr).sushi()).balanceOf(address(this));

            if(enable){
                pool.lpToken.approve(pool.extFarmInfo.extFarmAddr,0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
                if(pool.currentSupply > 0) {
                    ISushiChef(pool.extFarmInfo.extFarmAddr).deposit(pool.extFarmInfo.extPid,pool.currentSupply);
                }

                pool.extFarmInfo.extEnableClaim = true;

            }else{
                pool.lpToken.approve(pool.extFarmInfo.extFarmAddr,0);
                (uint256 amount,) = ISushiChef(pool.extFarmInfo.extFarmAddr).userInfo(pool.extFarmInfo.extPid,address(this));
                if(amount > 0){
                    ISushiChef(pool.extFarmInfo.extFarmAddr).withdraw(pool.extFarmInfo.extPid,amount);
                }
            }

            if(pool.currentSupply > 0){
                uint256 deltaSuShiReward = IERC20(ISushiChef(pool.extFarmInfo.extFarmAddr).sushi()).balanceOf(address(this)).sub(oldSuShiRewarad);

                pool.extFarmInfo.extRewardPerShare = deltaSuShiReward.mul(1e12).div(pool.currentSupply).add(pool.extFarmInfo.extRewardPerShare);
            }

            pool.extFarmInfo.extEnableDeposit = enable;

            emit DoubleFarmingEnable(_pid,enable);
        }

    }

    function setDoubleFarming(uint256 _pid,address extFarmAddr,uint256 _extPid) public onlyOwner{
        require(_pid < poolInfo.length,"pid >= poolInfo.length");
        require(extFarmAddr != address(0x0),"extFarmAddr == 0x0");
        PoolInfo storage pool = poolInfo[_pid];

        require(pool.extFarmInfo.extFarmAddr == address(0x0),"cannot set extFramAddr again");

        uint256 extPoolLength = ISushiChef(extFarmAddr).poolLength();
        require(_extPid < extPoolLength,"bad _extPid");

        (address lpToken,,,) = ISushiChef(extFarmAddr).poolInfo(_extPid);
        require(lpToken == address(pool.lpToken),"pool mismatch between FnxFarm and extFarm");

        pool.extFarmInfo.extFarmAddr = extFarmAddr;
        pool.extFarmInfo.extPid = _extPid;

        emit SetExtFarm(_pid, extFarmAddr, _extPid);

    }

    function disableExtEnableClaim(uint256 _pid)public onlyOwner{
        require(_pid < poolInfo.length,"pid >= poolInfo.length");
        PoolInfo storage pool = poolInfo[_pid];

        require(pool.extFarmInfo.extEnableDeposit == false, "can only disable extEnableClaim when extEnableDeposit is disabled");

        pool.extFarmInfo.extEnableClaim = false;
    }

    function pendingExtReward(uint256 _pid, address _user) public view returns(uint256){
        require(_pid < poolInfo.length,"pid >= poolInfo.length");

        PoolInfo storage pool = poolInfo[_pid];
        if(pool.extFarmInfo.extFarmAddr == address(0x0)){
            return 0;
        }

        if(pool.currentSupply <= 0) return 0;

        UserInfo storage user = userInfo[_pid][_user];
        if(user.amount <= 0) return 0;
        
        uint256 extRewardPerShare = pool.extFarmInfo.extRewardPerShare;

        if(pool.extFarmInfo.extEnableDeposit){
            uint256 totalPendingSushi = ISushiChef(pool.extFarmInfo.extFarmAddr).pendingSushi(pool.extFarmInfo.extPid,address(this));
            extRewardPerShare = totalPendingSushi.mul(1e12).div(pool.currentSupply).add(extRewardPerShare);
        }

        uint256 userPendingSuShi = user.amount.mul(extRewardPerShare).div(1e12).sub(user.extRewardDebt);

        return userPendingSuShi;
    }

    function depositLPToSuShiChef(uint256 _pid,uint256 _amount) internal {
        require(_pid < poolInfo.length,"pid >= poolInfo.length");
        PoolInfo storage pool = poolInfo[_pid];

        if(pool.extFarmInfo.extFarmAddr == address(0x0)) return;
        
        UserInfo storage user =  userInfo[_pid][msg.sender];

        if(pool.extFarmInfo.extEnableDeposit){
            
            uint256 oldSuShiRewarad = IERC20(ISushiChef(pool.extFarmInfo.extFarmAddr).sushi()).balanceOf(address(this));
            uint256 oldTotalDeposit = pool.currentSupply.sub(_amount);
            
            ISushiChef(pool.extFarmInfo.extFarmAddr).deposit(pool.extFarmInfo.extPid, _amount);

            uint256 deltaSuShiReward = IERC20(ISushiChef(pool.extFarmInfo.extFarmAddr).sushi()).balanceOf(address(this));
            deltaSuShiReward = deltaSuShiReward.sub(oldSuShiRewarad);

            if(oldTotalDeposit > 0 && deltaSuShiReward > 0){
                pool.extFarmInfo.extRewardPerShare = deltaSuShiReward.mul(1e12).div(oldTotalDeposit).add(pool.extFarmInfo.extRewardPerShare);
            }

        }

        if(pool.extFarmInfo.extEnableClaim) {
            uint256 transferSuShiAmount = user.amount.sub(_amount).mul(pool.extFarmInfo.extRewardPerShare).div(1e12).sub(user.extRewardDebt);
            
            if(transferSuShiAmount > 0){
                address sushiToken = ISushiChef(pool.extFarmInfo.extFarmAddr).sushi();
                IERC20(sushiToken).safeTransfer(msg.sender,transferSuShiAmount);
            }
        }

        pool.extFarmInfo.extTotalDebtReward = pool.extFarmInfo.extTotalDebtReward.sub(user.extRewardDebt);
        user.extRewardDebt = user.amount.mul(pool.extFarmInfo.extRewardPerShare).div(1e12);
        pool.extFarmInfo.extTotalDebtReward = pool.extFarmInfo.extTotalDebtReward.add(user.extRewardDebt);
        
    }

    function withDrawLPFromSuShi(uint256 _pid,uint256 _amount) internal{
        require(_pid < poolInfo.length,"pid >= poolInfo.length");
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user =  userInfo[_pid][msg.sender];

        if(pool.extFarmInfo.extFarmAddr == address(0x0)) return;

        if(pool.extFarmInfo.extEnableDeposit){
            
            require(user.amount >= _amount,"withdraw too much lpToken");

            uint256 oldSuShiRewarad = IERC20(ISushiChef(pool.extFarmInfo.extFarmAddr).sushi()).balanceOf(address(this));
            uint256 oldTotalDeposit = pool.currentSupply;
            
            ISushiChef(pool.extFarmInfo.extFarmAddr).withdraw(pool.extFarmInfo.extPid, _amount);

            uint256 deltaSuShiReward = IERC20(ISushiChef(pool.extFarmInfo.extFarmAddr).sushi()).balanceOf(address(this)).sub(oldSuShiRewarad);
            if(oldTotalDeposit > 0 && deltaSuShiReward > 0) pool.extFarmInfo.extRewardPerShare = deltaSuShiReward.mul(1e12).div(oldTotalDeposit).add(pool.extFarmInfo.extRewardPerShare);
            
        }

        if(pool.extFarmInfo.extEnableClaim) {
            uint256 transferSuShiAmount = user.amount.mul(pool.extFarmInfo.extRewardPerShare).div(1e12).sub(user.extRewardDebt);

            if(transferSuShiAmount > 0){
                address sushiToken = ISushiChef(pool.extFarmInfo.extFarmAddr).sushi();
                IERC20(sushiToken).safeTransfer(msg.sender,transferSuShiAmount);
            }
        }
        
        pool.extFarmInfo.extTotalDebtReward = pool.extFarmInfo.extTotalDebtReward.sub(user.extRewardDebt);
        user.extRewardDebt = user.amount.sub(_amount).mul(pool.extFarmInfo.extRewardPerShare).div(1e12);
        pool.extFarmInfo.extTotalDebtReward = pool.extFarmInfo.extTotalDebtReward.add(user.extRewardDebt);
    }

    //////////////////////////////////////////////////////////////////////////////////////////////

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) internal {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        if (pool.currentSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }

        uint256 multiplier = getMultiplier(_pid);
        uint256 fnxReward = multiplier.mul(pool.fnxPerBlock);
        pool.accFnxPerShare = pool.accFnxPerShare.add(fnxReward.mul(1e12).div(pool.currentSupply));
        pool.lastRewardBlock = block.number;

    }

    // Deposit LP tokens to MasterChef for Fnx allocation.
    function deposit(uint256 _pid, uint256 _amount) public  notHalted nonReentrant {
        require(_pid < poolInfo.length, "pid >= poolInfo.length");

        PoolInfo storage pool = poolInfo[_pid];
        updatePool(_pid);

        UserInfo storage user = userInfo[_pid][msg.sender];
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accFnxPerShare).div(1e12).sub(user.rewardDebt);
            if(pending > 0) {
                fnxToken.transfer(msg.sender, pending);
            }
        }

        if(_amount > 0) {
            pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            user.amount = user.amount.add(_amount);
            pool.currentSupply = pool.currentSupply.add(_amount);
        }
        
        // must excute after lpToken has beem transfered from user to this contract and the amount of user depoisted is updated.
        depositLPToSuShiChef(_pid,_amount); 
            
        pool.totalDebtReward = pool.totalDebtReward.sub(user.rewardDebt);
        user.rewardDebt = user.amount.mul(pool.accFnxPerShare).div(1e12);
        pool.totalDebtReward = pool.totalDebtReward.add(user.rewardDebt);

        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) public notHalted nonReentrant {
        require(_pid < poolInfo.length, "pid >= poolInfo.length");
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");

        withDrawLPFromSuShi(_pid,_amount);

        updatePool(_pid);

        uint256 pending = user.amount.mul(pool.accFnxPerShare).div(1e12).sub(user.rewardDebt);
        if(pending > 0) {
            fnxToken.transfer(msg.sender, pending);
        }

        if(_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.currentSupply = pool.currentSupply.sub(_amount);
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
        }

        pool.totalDebtReward = pool.totalDebtReward.sub(user.rewardDebt);
        user.rewardDebt = user.amount.mul(pool.accFnxPerShare).div(1e12);
        pool.totalDebtReward = pool.totalDebtReward.add(user.rewardDebt);

        emit Withdraw(msg.sender, _pid, _amount);
    }


    function emergencyWithdraw(uint256 _pid) public onlyOwner {
        require(_pid < poolInfo.length, "pid >= poolInfo.length");
        PoolInfo storage pool = poolInfo[_pid];

        if(pool.extFarmInfo.extFarmAddr == address(0x0)) return;

        ISushiChef(pool.extFarmInfo.extFarmAddr).emergencyWithdraw(pool.extFarmInfo.extPid);

        pool.extFarmInfo.extEnableDeposit = false;            

        emit EmergencyWithdraw(_pid);
    }

    // Safe Fnx transfer function, just in case if rounding error causes pool to not have enough fnx.
    function safeFnxTransfer(address _to, uint256 _amount) internal {
        uint256 fnxBal = fnxToken.balanceOf(address(this));
        if (_amount > fnxBal) {
            fnxToken.transfer(_to, fnxBal);
        } else {
            fnxToken.transfer(_to, _amount);
        }
    }

    function quitFnx(address _to) public onlyOwner {
        require(_to != address(0), "_to == 0");
        uint256 fnxBal = fnxToken.balanceOf(address(this));
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            PoolInfo storage pool = poolInfo[pid];
            require(block.number > pool.bonusEndBlock, "quitFnx block.number <= pid.bonusEndBlock");
            updatePool(pid);
            uint256 fnxReward = pool.currentSupply.mul(pool.accFnxPerShare).div(1e12).sub(pool.totalDebtReward);
            fnxBal = fnxBal.sub(fnxReward);
        }
        safeFnxTransfer(_to, fnxBal);
        emit QuitFnx(_to, fnxBal);
    }

    function quitExtFarm(address extFarmAddr, address _to) public onlyOwner{
        require(_to != address(0), "_to == 0");
        require(extFarmAddr != address(0), "extFarmAddr == 0");

        IERC20 sushiToken = IERC20(ISushiChef(extFarmAddr).sushi());

        uint256 sushiBalance = sushiToken.balanceOf(address(this));

        uint256 totalUnclaimedReward = totalUnclaimedExtFarmReward(extFarmAddr);

        require(totalUnclaimedReward <= sushiBalance, "extreward shortage");

        uint256 quitBalance = sushiBalance.sub(totalUnclaimedReward);

        sushiToken.safeTransfer(_to, quitBalance);
        emit QuitExtReward(extFarmAddr,address(sushiToken),_to, quitBalance);
    }

    function _become(address payable uniFarm) public {
        require(msg.sender == UniFarm(uniFarm).admin(), "only uniFarm admin can change brains");
        require(UniFarm(uniFarm)._acceptImplementation() == 0, "change not authorized");
    }

    function setRewardToken(address _tokenAddr) public onlyOwner {
        fnxToken = IERC20(_tokenAddr);
    }

    function totalStaked(uint256 _pid) public view returns (uint256){
        require(_pid < poolInfo.length,"pid >= poolInfo.length");

        PoolInfo storage pool = poolInfo[_pid];
        return pool.currentSupply;
    }


    function getMineInfo(uint256 _pid) public view returns (uint256,uint256,uint256,uint256) {
        return (poolMineInfo[_pid].totalMineFnx,poolMineInfo[_pid].duration,poolInfo[_pid].bonusStartBlock,poolInfo[_pid].bonusEndBlock);
    }

 }