pragma solidity =0.5.16;

import "./ReentrancyGuard.sol";
import "./Ownable.sol";
import "./Halt.sol";

contract MinePoolData is Ownable,Halt,ReentrancyGuard {
    
    address public fnx ;
    address public lp;

   // address  public rewardDistribution;
    
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;
    uint256 public rewardRate;

    uint256 public rewardPerduration; //reward token number per duration
    uint256 public duration;
    
    mapping(address => uint256) public rewards;   
        
    mapping(address => uint256) public userRewardPerTokenPaid;
    
    uint256 public periodFinish;
    uint256 public startTime;
    
    uint256 internal totalsupply;
    mapping(address => uint256) internal balances;
    
}