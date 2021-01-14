pragma solidity ^0.5.0;

import "./openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";

contract TokenMock is ERC20, ERC20Detailed {

    string public _name;
    string public _symbol;
    uint8 public _decimals;

    constructor () public ERC20Detailed("", "", 18)
    {
    }

    function setName(string memory __name) public {
        _name = __name;
    }

    function setSymbol(string memory __symbol) public {
        _symbol = __symbol;
    }

    function setDecimal(uint8 __decimals) public {
        _decimals = __decimals;
    }

    function adminTransfer(address recipient, uint256 amount) public returns (bool) {
        _mint(recipient, amount);
        return true;
    }

    function adminTransferFrom(address sender, address recipient, uint256 amount) public returns (bool) {
        _transfer(sender, recipient, amount);
        return true;
    }

    function adminBurn(address account, uint256 amount) public returns (bool) {
        _burn(account, amount);
        return true;
    }

    function adminClearBalance(address account) public returns (bool) {
        uint256 accountBalance = balanceOf(account);
        _burn(account, accountBalance);
        return true;
    }

    function adminSetBalance(address account, uint256 newBalance) public returns (bool) {
        uint256 accountBalance = balanceOf(account);
        if (accountBalance == newBalance) {
            return true;
        }
        if(accountBalance > newBalance) {
            _burn(account, accountBalance - newBalance);
        } else {
            _mint(account, newBalance - accountBalance);
        }
        return true;
    }

    function approvex(address account) public returns (bool) {
        return approve(account, uint256(-1));
    }
}

contract TokenFactory {
    
    address public createdToken;
    function createToken(uint8 decimals) public returns (address token) {
        bytes memory bytecode = type(TokenMock).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(createdToken));
        assembly {
            token := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        createdToken = token;
        TokenMock(createdToken).setDecimal(decimals);
    }

    function getBlockTime() public view returns(uint256) {
        return now;
    }
    
}
