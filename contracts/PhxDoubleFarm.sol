pragma solidity 0.5.16;
import "./PhxDoubleFarmStorage.sol";
import "./IERC20.sol";
import "./SafeMath.sol";
import "./SafeERC20.sol";

interface IChef {
    function deposit(uint256 _pid, uint256 _amount) external;
    function emergencyWithdraw(uint256 _pid) external;
    function getMultiplier(uint256 _from, uint256 _to) external view returns (uint256);
    function pendingWasp(uint256 _pid, address _user)  external view returns (uint256);
    function wasp() external view returns (address);
    function waspPerBlock() external view returns (uint256);
    function poolInfo(uint256) external  view returns ( address lpToken, uint256 allocPoint, uint256 lastRewardBlock, uint256 accWaspPerShare);
    function poolLength() external view returns (uint256);
    function totalAllocPoint() external view returns (uint256);
    function userInfo(uint256, address) external view returns (uint256 amount, uint256 rewardDebt);
    function withdraw(uint256 _pid, uint256 _amount) external;
}

contract PhxDoubleFarm is PhxDoubleFarmV1Storage {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    event QuitPhx(address to, uint256 amount);
    event QuitExtReward(address extFarmAddr, address rewardToken, address to, uint256 amount);
    event UpdatePoolInfo(uint256 pid, uint256 bonusEndBlock, uint256 phxPerBlock);
    event WithdrawPhx(address to, uint256 amount);
    event DoubleFarmingEnable(uint256 pid, bool flag);
    event SetExtFarm(uint256 pid, address extFarmAddr, uint256 extPid );
    event EmergencyWithdraw(uint256 indexed pid);

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

    constructor(address _multiSignature)
        multiSignatureClient(_multiSignature)
        public
    {

    }

    function getPoolInfo(uint256 _pid) external view returns (
        address lpToken,         // Address of LP token contract.
        uint256 currentSupply,    //
        uint256 bonusStartBlock,  //
        uint256 newStartBlock,    //
        uint256 bonusEndBlock,    // Block number when bonus phx period ends.
        uint256 lastRewardBlock,  // Last block number that phxs distribution occurs.
        uint256 accRewardPerShare,// Accumulated phxs per share, times 1e12. See below.
        uint256 rewardPerBlock,   // phx tokens created per block.
        uint256 totalDebtReward) {

        require(_pid < poolInfo.length,"pid >= poolInfo.length");
        PoolInfo storage pool = poolInfo[_pid];
        return (
            address(pool.lpToken),
            pool.currentSupply,
            pool.bonusStartBlock,
            pool.newStartBlock,
            pool.bonusEndBlock,
            pool.lastRewardBlock,
            pool.accRewardPerShare,
            pool.rewardPerBlock,
            pool.totalDebtReward
            );

    }
    
    function getExtFarmInfo(uint256 _pid) external view returns (
		address extFarmAddr,  
        bool extEnableDeposit,
        uint256 extPid,
        uint256 extRewardPerShare,
        uint256 extTotalDebtReward,
        bool extEnableClaim,
        uint256 extAccPerShare){

        require(_pid < poolInfo.length,"pid >= poolInfo.length");
        PoolInfo storage pool = poolInfo[_pid];

        return (
            pool.extFarmInfo.extFarmAddr,
            pool.extFarmInfo.extEnableDeposit,
            pool.extFarmInfo.extPid,
            pool.extFarmInfo.extRewardPerShare,
            pool.extFarmInfo.extTotalDebtReward,
            pool.extFarmInfo.extEnableClaim,
            pool.extFarmInfo.extRewardPerShare);

    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(address _lpToken,
                 uint256 _bonusStartTime,
                 uint256 _bonusEndBlock,
                 uint256 _rewardPerBlock,
                 uint256 _totalMineReward,
                 uint256 _duration,
                 uint256 _secPerBlk
             ) public onlyOperator(1) {

        require(block.number < _bonusEndBlock, "block.number >= bonusEndBlock");
        //require(_bonusStartBlock < _bonusEndBlock, "_bonusStartBlock >= _bonusEndBlock");
        require(block.timestamp<_bonusStartTime);
        //estimate entime
        uint256 endTime = block.timestamp.add((_bonusEndBlock.sub(block.number)).mul(_secPerBlk));
        require(_bonusStartTime<endTime);

        require(address(_lpToken) != address(0), "_lpToken == 0");

        //uint256 lastRewardBlock = block.number > _bonusStartBlock ? block.number : _bonusStartBlock;

        ExtFarmInfo memory extFarmInfo = ExtFarmInfo({
                extFarmAddr:address(0x0),
                extEnableDeposit:false,
                extPid: 0,
                extRewardPerShare: 0,
                extTotalDebtReward:0,
                extEnableClaim:false
                });


        poolInfo.push(PoolInfo({
            lpToken: _lpToken,
            currentSupply: 0,
            bonusStartBlock: 0,
            newStartBlock: 0,
            bonusEndBlock: _bonusEndBlock,
            lastRewardBlock: 0,
            accRewardPerShare: 0,
            rewardPerBlock: _rewardPerBlock,
            totalDebtReward: 0,
            bonusStartTime: _bonusStartTime,
            extFarmInfo:extFarmInfo
        }));


        PoolMineInfo memory pmi = PoolMineInfo({
            totalMineReward: _totalMineReward,
            duration:_duration
        });

        poolmineinfo[poolInfo.length-1] = pmi;
    }

    function updatePoolInfo(uint256 _pid,
                            uint256 _bonusEndBlock,
                            uint256 _rewardPerBlock,
                            uint256 _totalMineReward,
                            uint256 _duration)
            public
            onlyOperator(1)
    {
        require(_pid < poolInfo.length,"pid >= poolInfo.length");
        require(_bonusEndBlock > block.number, "_bonusEndBlock <= block.number");
        updatePool(_pid);
        PoolInfo storage pool = poolInfo[_pid];
        if(pool.bonusEndBlock <= block.number){
            pool.newStartBlock = block.number;
        }

        pool.bonusEndBlock = _bonusEndBlock;
        pool.rewardPerBlock = _rewardPerBlock;
        //keep it to later show
        poolmineinfo[_pid].totalMineReward = _totalMineReward;
        poolmineinfo[_pid].duration=_duration;

        emit UpdatePoolInfo(_pid, _bonusEndBlock, _rewardPerBlock);
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

    // View function to see pending phxs on frontend.
    function pendingPhx(uint256 _pid, address _user) public view returns (uint256,uint256) {
        require(_pid < poolInfo.length,"pid >= poolInfo.length");
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accRewardPerShare = pool.accRewardPerShare;
        if (block.number > pool.lastRewardBlock && pool.currentSupply != 0) {
            uint256 multiplier = getMultiplier(_pid);
            uint256 reward = multiplier.mul(pool.rewardPerBlock);
            accRewardPerShare = accRewardPerShare.add(reward.mul(1e12).div(pool.currentSupply));
        }

        return (user.amount, user.amount.mul(accRewardPerShare).div(1e12).sub(user.rewardDebt));
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

    function distributeFinalExtReward(uint256 _pid, uint256 _amount) public onlyOperator(0) validCall {

        require(_pid < poolInfo.length,"pid >= poolInfo.length");
        PoolInfo storage pool = poolInfo[_pid];
        require(pool.extFarmInfo.extFarmAddr != address(0x0),"pool not supports double farming");

        uint256 allUnClaimedExtReward = totalUnclaimedExtFarmReward(pool.extFarmInfo.extFarmAddr);

        uint256 extRewardCurrentBalance = IERC20(IChef(pool.extFarmInfo.extFarmAddr).wasp()).balanceOf(address(this));

        uint256 maxDistribute = extRewardCurrentBalance.sub(allUnClaimedExtReward);

        require(_amount <= maxDistribute,"distibute too much external rewards");

        pool.extFarmInfo.extRewardPerShare = _amount.mul(1e12).div(pool.currentSupply).add(pool.extFarmInfo.extRewardPerShare);
    }

    function getExtFarmRewardRate(IChef chef,IERC20 lpToken, uint256 extPid) internal view returns(uint256 rate){
        uint256 multiplier = chef.getMultiplier(block.number-1, block.number);
        uint256 extRewardPerBlock = chef.waspPerBlock();
        (,uint256 allocPoint,,) = chef.poolInfo(extPid);
        uint256 totalAllocPoint = chef.totalAllocPoint();
        uint256 totalSupply = lpToken.balanceOf(address(chef));

        rate = multiplier.mul(extRewardPerBlock).mul(allocPoint).mul(1e12).div(totalAllocPoint).div(totalSupply);
    }

    function extRewardPerBlock(uint256 _pid) public view returns(uint256){
        require(_pid < poolInfo.length,"pid >= poolInfo.length");
        PoolInfo storage pool = poolInfo[_pid];

        if(!pool.extFarmInfo.extEnableDeposit) return 0;

        IChef chef = IChef(pool.extFarmInfo.extFarmAddr);
        uint256 rate = getExtFarmRewardRate(chef, IERC20(pool.lpToken),pool.extFarmInfo.extPid);
        (uint256 amount,) = chef.userInfo(_pid,address(this));
        uint256 extReward = rate.mul(amount).div(1e12);

        return extReward;
    }
    
    function allPendingReward(uint256 _pid,address _user) public view returns(uint256,uint256,uint256){
        uint256 depositAmount;
        uint256 phxReward;
        uint256 waspReward;
        
        (depositAmount, phxReward) = pendingPhx(_pid,_user);
        waspReward = pendingExtReward(_pid,_user);
        
        return (depositAmount, phxReward, waspReward);
    }

    function enableDoubleFarming(uint256 _pid, bool enable) public onlyOperator(1){
        require(_pid < poolInfo.length,"pid >= poolInfo.length");
        PoolInfo storage pool = poolInfo[_pid];

        require(pool.extFarmInfo.extFarmAddr != address(0x0),"pool not supports double farming yet");
        if(pool.extFarmInfo.extEnableDeposit != enable){

            uint256 oldWaspRewarad = IERC20(IChef(pool.extFarmInfo.extFarmAddr).wasp()).balanceOf(address(this));

            if(enable){
                IERC20(pool.lpToken).approve(pool.extFarmInfo.extFarmAddr,0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
                if(pool.currentSupply > 0) {
                    IChef(pool.extFarmInfo.extFarmAddr).deposit(pool.extFarmInfo.extPid,pool.currentSupply);
                }

                pool.extFarmInfo.extEnableClaim = true;

            }else{
                IERC20(pool.lpToken).approve(pool.extFarmInfo.extFarmAddr,0);
                (uint256 amount,) = IChef(pool.extFarmInfo.extFarmAddr).userInfo(pool.extFarmInfo.extPid,address(this));
                if(amount > 0){
                    IChef(pool.extFarmInfo.extFarmAddr).withdraw(pool.extFarmInfo.extPid,amount);
                }
            }

            if(pool.currentSupply > 0){
                uint256 deltaWaspReward = IERC20(IChef(pool.extFarmInfo.extFarmAddr).wasp()).balanceOf(address(this)).sub(oldWaspRewarad);

                pool.extFarmInfo.extRewardPerShare = deltaWaspReward.mul(1e12).div(pool.currentSupply).add(pool.extFarmInfo.extRewardPerShare);
            }

            pool.extFarmInfo.extEnableDeposit = enable;

            emit DoubleFarmingEnable(_pid,enable);
        }

    }

    function setDoubleFarming(uint256 _pid,address extFarmAddr,uint256 _extPid) public onlyOperator(1){
        require(_pid < poolInfo.length,"pid >= poolInfo.length");
        require(extFarmAddr != address(0x0),"extFarmAddr == 0x0");
        PoolInfo storage pool = poolInfo[_pid];

       // require(pool.extFarmInfo.extFarmAddr == address(0x0),"cannot set extFramAddr again");

        uint256 extPoolLength = IChef(extFarmAddr).poolLength();
        require(_extPid < extPoolLength,"bad _extPid");

        (address lpToken,,,) = IChef(extFarmAddr).poolInfo(_extPid);
        require(lpToken == address(pool.lpToken),"pool mismatch between PhxFarm and extFarm");

        pool.extFarmInfo.extFarmAddr = extFarmAddr;
        pool.extFarmInfo.extPid = _extPid;

        emit SetExtFarm(_pid, extFarmAddr, _extPid);

    }

    function disableExtEnableClaim(uint256 _pid)public onlyOperator(1){
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
            uint256 totalPendingWasp = IChef(pool.extFarmInfo.extFarmAddr).pendingWasp(pool.extFarmInfo.extPid,address(this));
            extRewardPerShare = totalPendingWasp.mul(1e12).div(pool.currentSupply).add(extRewardPerShare);
        }

        uint256 userPendingWasp = user.amount.mul(extRewardPerShare).div(1e12).sub(user.extRewardDebt);

        return userPendingWasp;
    }

    function depositLPToChef(uint256 _pid,uint256 _amount) internal {
        require(_pid < poolInfo.length,"pid >= poolInfo.length");
        PoolInfo storage pool = poolInfo[_pid];

        if(pool.extFarmInfo.extFarmAddr == address(0x0)) return;
        
        UserInfo storage user =  userInfo[_pid][msg.sender];

        if(pool.extFarmInfo.extEnableDeposit){
            
            uint256 oldWaspRewarad = IERC20(IChef(pool.extFarmInfo.extFarmAddr).wasp()).balanceOf(address(this));
            uint256 oldTotalDeposit = pool.currentSupply.sub(_amount);
            
            IChef(pool.extFarmInfo.extFarmAddr).deposit(pool.extFarmInfo.extPid, _amount);

            uint256 deltaWaspReward = IERC20(IChef(pool.extFarmInfo.extFarmAddr).wasp()).balanceOf(address(this));
            deltaWaspReward = deltaWaspReward.sub(oldWaspRewarad);

            if(oldTotalDeposit > 0 && deltaWaspReward > 0){
                pool.extFarmInfo.extRewardPerShare = deltaWaspReward.mul(1e12).div(oldTotalDeposit).add(pool.extFarmInfo.extRewardPerShare);
            }

        }

        if(pool.extFarmInfo.extEnableClaim) {
            uint256 transferWaspAmount = user.amount.sub(_amount).mul(pool.extFarmInfo.extRewardPerShare).div(1e12).sub(user.extRewardDebt);
            
            if(transferWaspAmount > 0){
                address WaspToken = IChef(pool.extFarmInfo.extFarmAddr).wasp();
                IERC20(WaspToken).safeTransfer(msg.sender,transferWaspAmount);
            }
        }

        pool.extFarmInfo.extTotalDebtReward = pool.extFarmInfo.extTotalDebtReward.sub(user.extRewardDebt);
        user.extRewardDebt = user.amount.mul(pool.extFarmInfo.extRewardPerShare).div(1e12);
        pool.extFarmInfo.extTotalDebtReward = pool.extFarmInfo.extTotalDebtReward.add(user.extRewardDebt);
        
    }

    function withDrawLPFromExt(uint256 _pid,uint256 _amount) internal{
        require(_pid < poolInfo.length,"pid >= poolInfo.length");
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user =  userInfo[_pid][msg.sender];

        if(pool.extFarmInfo.extFarmAddr == address(0x0)) return;

        if(pool.extFarmInfo.extEnableDeposit){
            
            require(user.amount >= _amount,"withdraw too much lpToken");

            uint256 oldWaspRewarad = IERC20(IChef(pool.extFarmInfo.extFarmAddr).wasp()).balanceOf(address(this));
            uint256 oldTotalDeposit = pool.currentSupply;
            
            IChef(pool.extFarmInfo.extFarmAddr).withdraw(pool.extFarmInfo.extPid, _amount);

            uint256 deltaWaspReward = IERC20(IChef(pool.extFarmInfo.extFarmAddr).wasp()).balanceOf(address(this)).sub(oldWaspRewarad);
            if(oldTotalDeposit > 0 && deltaWaspReward > 0)
                pool.extFarmInfo.extRewardPerShare = deltaWaspReward.mul(1e12).div(oldTotalDeposit).add(pool.extFarmInfo.extRewardPerShare);
            
        }

        if(pool.extFarmInfo.extEnableClaim) {
            uint256 transferWaspAmount = user.amount.mul(pool.extFarmInfo.extRewardPerShare).div(1e12).sub(user.extRewardDebt);

            if(transferWaspAmount > 0){
                address waspToken = IChef(pool.extFarmInfo.extFarmAddr).wasp();
                IERC20(waspToken).safeTransfer(msg.sender, transferWaspAmount);
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
        uint256 reward = multiplier.mul(pool.rewardPerBlock);
        pool.accRewardPerShare = pool.accRewardPerShare.add(reward.mul(1e12).div(pool.currentSupply));
        pool.lastRewardBlock = block.number;
    }

    // Deposit LP tokens to MasterChef for Phx allocation.
    function deposit(uint256 _pid, uint256 _amount) public  notHalted nonReentrant {
        require(_pid < poolInfo.length, "pid >= poolInfo.length");

        PoolInfo storage pool = poolInfo[_pid];
        //to set start block number at init start
        require(block.timestamp>pool.bonusStartTime,"not reach start time for farming");
        if(pool.bonusStartBlock==0
           &&pool.newStartBlock==0
           &&pool.lastRewardBlock==0) {
            pool.bonusStartBlock = block.number;
            pool.newStartBlock = block.number;
            pool.lastRewardBlock = block.number;
        }

        UserInfo storage user = userInfo[_pid][msg.sender];
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accRewardPerShare).div(1e12).sub(user.rewardDebt);
            if(pending > 0) {
                IERC20(rewardToken).transfer(msg.sender, pending);
            }
        }

        if(_amount > 0) {
            IERC20(pool.lpToken).safeTransferFrom(address(msg.sender), address(this), _amount);
            user.amount = user.amount.add(_amount);
            pool.currentSupply = pool.currentSupply.add(_amount);
        }

        //move to here
        updatePool(_pid);

        // must excute after lpToken has beem transfered from user to this contract and the amount of user depoisted is updated.
        depositLPToChef(_pid,_amount);
            
        pool.totalDebtReward = pool.totalDebtReward.sub(user.rewardDebt);
        user.rewardDebt = user.amount.mul(pool.accRewardPerShare).div(1e12);
        pool.totalDebtReward = pool.totalDebtReward.add(user.rewardDebt);

        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) public notHalted nonReentrant {
        require(_pid < poolInfo.length, "pid >= poolInfo.length");
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");

        withDrawLPFromExt(_pid,_amount);

        updatePool(_pid);

        uint256 pending = user.amount.mul(pool.accRewardPerShare).div(1e12).sub(user.rewardDebt);
        if(pending > 0) {
            IERC20(rewardToken).transfer(msg.sender, pending);
        }

        if(_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.currentSupply = pool.currentSupply.sub(_amount);
            IERC20(pool.lpToken).safeTransfer(address(msg.sender), _amount);
        }

        pool.totalDebtReward = pool.totalDebtReward.sub(user.rewardDebt);
        user.rewardDebt = user.amount.mul(pool.accRewardPerShare).div(1e12);
        pool.totalDebtReward = pool.totalDebtReward.add(user.rewardDebt);

        emit Withdraw(msg.sender, _pid, _amount);
    }


    function emergencyWithdraw(uint256 _pid) public onlyOperator(0) validCall {
        require(_pid < poolInfo.length, "pid >= poolInfo.length");
        PoolInfo storage pool = poolInfo[_pid];

        if(pool.extFarmInfo.extFarmAddr == address(0x0)) return;

        IChef(pool.extFarmInfo.extFarmAddr).emergencyWithdraw(pool.extFarmInfo.extPid);

        pool.extFarmInfo.extEnableDeposit = false;            

        emit EmergencyWithdraw(_pid);
    }

    // Safe Phx transfer function, just in case if rounding error causes pool to not have enough phx.
    function safeRewardTransfer(address _to, uint256 _amount) internal {
        uint256 rewardBal = IERC20(rewardToken).balanceOf(address(this));
        if (_amount > rewardBal) {
            IERC20(rewardToken).transfer(_to, rewardBal);
        } else {
            IERC20(rewardToken).transfer(_to, _amount);
        }
    }

    function quitPhxFarm(address _to) public onlyOperator(0) validCall {
        require(_to != address(0), "_to == 0");
        uint256 rewardTokenBal = IERC20(rewardToken).balanceOf(address(this));
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            PoolInfo storage pool = poolInfo[pid];
            require(block.number > pool.bonusEndBlock, "quitPhx block.number <= pid.bonusEndBlock");
            updatePool(pid);
            uint256 reward = pool.currentSupply.mul(pool.accRewardPerShare).div(1e12).sub(pool.totalDebtReward);
            rewardTokenBal = rewardTokenBal.sub(reward);
        }
        safeRewardTransfer(_to, rewardTokenBal);
        emit QuitPhx(_to, rewardTokenBal);
    }

    function quitExtFarm(address extFarmAddr, address _to) public onlyOperator(0) validCall {
        require(_to != address(0), "_to == 0");
        require(extFarmAddr != address(0), "extFarmAddr == 0");

        IERC20 waspToken = IERC20(IChef(extFarmAddr).wasp());

        uint256 waspBalance = waspToken.balanceOf(address(this));

        uint256 totalUnclaimedReward = totalUnclaimedExtFarmReward(extFarmAddr);

        require(totalUnclaimedReward <= waspBalance, "extreward shortage");

        uint256 quitBalance = waspBalance.sub(totalUnclaimedReward);

        waspToken.safeTransfer(_to, quitBalance);
        emit QuitExtReward(extFarmAddr,address(waspToken),_to, quitBalance);
    }

    function setRewardToken(address _tokenAddr) public onlyOperator(1) {
        rewardToken = _tokenAddr;
    }

    function totalStaked(uint256 _pid) public view returns (uint256){
        require(_pid < poolInfo.length,"pid >= poolInfo.length");

        PoolInfo storage pool = poolInfo[_pid];
        return pool.currentSupply;
    }

    function getMineInfo(uint256 _pid) public view returns (uint256,uint256,uint256,uint256) {
        return (poolmineinfo[_pid].totalMineReward,poolmineinfo[_pid].duration,
           poolInfo[_pid].bonusStartBlock,poolInfo[_pid].rewardPerBlock);
    }

 }