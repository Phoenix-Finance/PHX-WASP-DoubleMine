pragma solidity 0.5.16;
import { IERC20 } from "./openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Halt.sol";
import "./ReentrancyGuard.sol";

//pragma experimental ABIEncoderV2;
contract FnxSushiFarmErrorReporter {
    enum Error {
        NO_ERROR,
        UNAUTHORIZED
    }

    enum FailureInfo {
        ACCEPT_ADMIN_PENDING_ADMIN_CHECK,
        ACCEPT_PENDING_IMPLEMENTATION_ADDRESS_CHECK,
        SET_PENDING_ADMIN_OWNER_CHECK,
        SET_PENDING_IMPLEMENTATION_OWNER_CHECK
    }

    /**
      * @dev `error` corresponds to enum Error; `info` corresponds to enum FailureInfo, and `detail` is an arbitrary
      * contract-specific code that enables us to report opaque error codes from upgradeable contracts.
      **/
    event Failure(uint error, uint info, uint detail);

    /**
      * @dev use this when reporting a known error from the money market or a non-upgradeable collaborator
      */
    function fail(Error err, FailureInfo info) internal returns (uint) {
        emit Failure(uint(err), uint(info), 0);

        return uint(err);
    }

    /**
      * @dev use this when reporting an opaque error from an upgradeable collaborator contract
      */
    function failOpaque(Error err, FailureInfo info, uint opaqueError) internal returns (uint) {
        emit Failure(uint(err), uint(info), opaqueError);

        return uint(err);
    }
}

contract FnxSushiFarmV1Storage is Halt, ReentrancyGuard{
    // Info of each user.
    struct UserInfo {
        uint256 amount;     // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        uint256 extRewardDebt; 
    }

    struct ExtFarmInfo{
        address extFarmAddr;  
        bool extEnableDeposit;
        uint256 extPid;
        uint256 extRewardPerShare;
        uint256 extTotalDebtReward;  //
        bool extEnableClaim;
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20  lpToken;          // Address of LP token contract. 0
        uint256 currentSupply;    //1
        uint256 bonusStartBlock;  //2
        uint256 newStartBlock;    //3
        uint256 bonusEndBlock;    // Block number when bonus fnx period ends.4
        uint256 lastRewardBlock;  // Last block number that fnxs distribution occurs.5
        uint256 accFnxPerShare;// Accumulated Fnx per share, times 1e12. See below.6
        uint256 fnxPerBlock;   // fnx tokens created per block.7
        uint256 totalDebtReward;  //8
        ExtFarmInfo extFarmInfo;
    }

    struct PoolMineInfo {
        uint256 totalMineFnx;
        uint256 duration;
    }

    IERC20 public fnxToken = IERC20(0xeF9Cd7882c067686691B6fF49e650b43AFBBCC6B);

    PoolInfo[] poolInfo;   // Info of each pool.
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;// Info of each user that stakes LP tokens.
    mapping (uint256=>PoolMineInfo) public poolmineinfo;
}