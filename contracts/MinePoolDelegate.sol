pragma solidity ^0.5.16;

import "./Math.sol";
import "./SafeMath.sol";
import "./IERC20.sol";
import "./LPTokenWrapper.sol";
import "./Halt.sol";


contract MinePoolDelegate is LPTokenWrapper {

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event HisReward(address indexed user, uint256 indexed reward,uint256 indexed idx);

    modifier updateReward(address account) {
        require(now >= startTime,"not reach start time");
        
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;     
        }
        _;
    }

    function update() onlyOwner public{
        //for the future use
    }

    function setPoolMineAddress(address _liquidpool,address _fnxaddress) public onlyOwner{
        require(_liquidpool != address(0));
        require(_fnxaddress != address(0));
        
        lp  = _liquidpool;
        fnx = _fnxaddress;
    }
    
    function setMineRate(uint256 _reward,uint256 _duration) public onlyOwner updateReward(address(0)){
        require(_reward>0);
        require(_duration>0);

        //token number per seconds
        rewardRate = _reward.div(_duration);
        require(rewardRate > 0);

        rewardPerduration = _reward;
        duration = _duration;
    }   
    
    function setPeriodFinish(uint256 startime,uint256 endtime)public onlyOwner updateReward(address(0)) {
        //the setting time must pass timebeing
        require(startime >=now);
        require(endtime > startTime);
        
        //set new finish time
        lastUpdateTime = startime;
        periodFinish = endtime;
        startTime = startime;
    }  
    
    /**
     * @dev getting back the left mine token
     * @param reciever the reciever for getting back mine token
     */
    function getbackLeftMiningToken(address reciever)  public onlyOwner {
        uint256 bal =  IERC20(fnx).balanceOf(address(this));
        IERC20(fnx).transfer(reciever,bal);
    }  
        
//////////////////////////public function/////////////////////////////////    

    function lastTimeRewardApplicable() public view returns(uint256) {
         uint256 timestamp = Math.max(block.timestamp,startTime);
         return Math.min(timestamp,periodFinish);
     }

    function rewardPerToken() public view returns(uint256) {
        if (totalSupply() == 0 || now < startTime) {
            return rewardPerTokenStored;
        }
        
        return rewardPerTokenStored.add(
            lastTimeRewardApplicable().sub(lastUpdateTime).mul(rewardRate).mul(1e18).div(totalSupply())
        );
    }

    function earned(address account) internal view returns(uint256) {
        return balanceOf(account).mul(rewardPerToken().sub(userRewardPerTokenPaid[account])).div(1e18).add(rewards[account]);
     }

    //keep same name with old version
    function totalRewards(address account) public view returns(uint256) {
        return earned(account);
     }

    function stake(uint256 amount,bytes memory data) public updateReward(msg.sender) notHalted nonReentrant {
        require(amount > 0, "Cannot stake 0");
        require(now < periodFinish,"over finish time");//do not allow to stake after finish
        
        super.stake(amount);
        emit Staked(msg.sender, amount);
    }

    function unstake(uint256 amount,bytes memory data) public updateReward(msg.sender) notHalted nonReentrant {
        require(amount > 0, "Cannot withdraw 0");

        
        super.unstake(amount);
        emit Withdrawn(msg.sender, amount);
    }

    function exit() public notHalted nonReentrant {
        super.unstake(balanceOf(msg.sender));
        getReward();
    }

    function getReward() public updateReward(msg.sender) notHalted nonReentrant {
        uint256 reward = earned(msg.sender);
        if (reward > 0) {
            rewards[msg.sender] = 0;
            IERC20(fnx).transfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }
    
    /**
     * @return Total number of distribution tokens balance.
     */
    function distributionBalance() public view returns (uint256) {
        return IERC20(fnx).balanceOf(address(this));
    }    

    /**
     * @param addr The user to look up staking information for.
     * @return The number of staking tokens deposited for addr.
     */
    function totalStakedFor(address addr) public view returns (uint256) {
        return super.balanceOf(addr);
    }
    
    /**
     * @dev all stake token.
     * @return The number of staking tokens
     */
    function totalStaked() public view returns (uint256) {
        return super.totalSupply();
    }
    

    function getMineInfo() public view returns (uint256,uint256,uint256,uint256) {
        return (rewardPerduration,duration,startTime,periodFinish);
    }
    
    function getVersion() public view returns (uint256) {
        return 1;
    }    

}
