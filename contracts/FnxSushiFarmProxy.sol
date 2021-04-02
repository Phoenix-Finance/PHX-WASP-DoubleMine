pragma solidity =0.5.16;
import "./baseProxy.sol";
import "./FnxSushiFarmStorage.sol";
/**
 * @title  Erc20Delegator Contract

 */
contract FnxSushiFarmProxy is FnxSushiFarmErrorReporter,baseProxy{

    constructor(address _implementation) baseProxy(_implementation) public {

    }

    function add(  address,// _lpToken,
                   uint256,//_bonusStartBlock,
                   uint256,// _bonusEndBlock,
                   uint256,// _fnxPerBlock,
                   uint256,// _totalMineFnx,
                   uint256// _duration
                )
     public
     {

        delegateAndReturn();
     }
    function setDoubleFarming(  uint256,// _pid,
                                address,// extFarmAddr,
                                uint256// _extPid
                             )
    public
    {
        delegateAndReturn();
    }

    function enableDoubleFarming(uint256 /*_pid*/, bool /*enable*/)public {
        delegateAndReturn();
    }

    function updatePoolInfo(uint256,// _pid,
                            uint256,// _bonusEndBlock,
                            uint256,// _fnxPerBlock,
                            uint256,// _totalMineFnx,
                            uint256// _duration
                            )
    public
    {
       delegateAndReturn();
    }


    function getMineInfo(uint256 /*_pid*/) public view returns (uint256,uint256,uint256,uint256)
    {
        delegateToViewAndReturn();
    }

    function totalStaked(uint256 /*_pid*/) public view returns (uint256)
    {
        delegateToViewAndReturn();
    }

    function allPendingReward(uint256 /*_pid*/,address /*_user*/) public view returns(uint256,uint256,uint256)
    {
        delegateToViewAndReturn();
    }

    function deposit(uint256 /*_pid*/, uint256 /*_amount*/) public {
        delegateAndReturn();
    }

    function withdraw(uint256 /*_pid*/, uint256 /*_amount*/) public
    {
        delegateAndReturn();
    }

}
