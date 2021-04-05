pragma solidity =0.5.16;
import "./FNXCoin.sol";

contract FnxToken is FNXCoin {

    constructor () public{
        name = "FnxToken";
        symbol = "FnxToken";
        decimals = 6;
    }
}
