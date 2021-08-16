pragma solidity ^0.5.16;

import "./PhxDoubleFarmStorage.sol";
import "./proxy/ZiplinProxy.sol";

contract PhxDoubleFarmProxy is Proxy,PhxDoubleFarmV1Storage {

    event Upgraded(address indexed implementation);

    constructor(address _implAddress,address _rewardToken,address _multiSignature)
        multiSignatureClient(_multiSignature)
        public
    {
        rewardToken = _rewardToken;
        _setImplementation(_implAddress);
    }


    /**
     * @dev Storage slot with the address of the current implementation.
     * This is the keccak-256 hash of "org.zeppelinos.proxy.implementation", and is
     * validated in the constructor.
     */
    bytes32 internal constant IMPLEMENTATION_SLOT = keccak256("org.Phoenix.implementation.unlocksc");

    function proxyType() public pure returns (uint256){
        return 2;
    }

    function implementation() public view returns (address) {
        return _implementation();
    }
    /**
     * @dev Returns the current implementation.
     * @return Address of the current implementation
     */
    function _implementation() internal view returns (address impl) {
        bytes32 slot = IMPLEMENTATION_SLOT;
        assembly {
            impl := sload(slot)
        }
    }

    /**
     * @dev Upgrades the proxy to a new implementation.
     * @param newImplementation Address of the new implementation.
     */
    function _upgradeTo(address newImplementation)  public onlyOperator(0) validCall{
        _setImplementation(newImplementation);
        emit Upgraded(newImplementation);
    }

    /**
     * @dev Sets the implementation address of the proxy.
     * @param newImplementation Address of the new implementation.
     */
    function _setImplementation(address newImplementation) internal {
        require(ZOSLibAddress.isContract(newImplementation), "Cannot set a proxy implementation to a non-contract address");

        bytes32 slot = IMPLEMENTATION_SLOT;

        assembly {
            sstore(slot, newImplementation)
        }
    }
}
