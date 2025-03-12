// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract MyWallet {
    string public name;
    mapping(address => bool) private approved;
    address public owner;

    modifier auth() {
        //        require(msg.sender == owner, "Not authorized");
        address loadedOwner;
        assembly {
            loadedOwner := sload(2)
        }
        require(msg.sender == loadedOwner, "Not authorized");
        _;
    }

    constructor(string memory _name) {
        name = _name;
        owner = msg.sender;
    }

    function transferOwernship(address _addr) public auth {
        require(_addr != address(0), "New owner is the zero address");
        //        require(owner != _addr, "New owner is the same as the old owner");
        address loadedOwner;
        assembly {
            loadedOwner := sload(2)
        }
        require(loadedOwner != _addr, "New owner is the same as the old owner");
        //        owner = _addr;
        assembly {
            sstore(2, _addr)
        }
    }
}
