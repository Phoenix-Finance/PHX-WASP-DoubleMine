pragma solidity =0.5.16;

import "./SafeMath.sol";
import "./MinePoolData.sol";
import "./IERC20.sol";

contract LPTokenWrapper is MinePoolData {
    
    using SafeMath for uint256;

    function totalSupply() public view returns(uint256) {
        return totalsupply;
    }

    function balanceOf(address account) public view returns(uint256) {
        return balances[account];
    }

    function stake(uint256 amount) public {
        totalsupply = totalsupply.add(amount);
        balances[msg.sender] = balances[msg.sender].add(amount);
        IERC20(lp).transferFrom(msg.sender,address(this), amount);
    }

    function unstake (uint256 amount) public {
        totalsupply = totalsupply.sub(amount);
        balances[msg.sender] = balances[msg.sender].sub(amount);
        IERC20(lp).transfer(msg.sender, amount);
    }
    
}