// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "./TerryToken.sol";

contract TTokanBank {
    ERC20Permit public tToken;
    mapping(address => uint256) public Balance;

    constructor(ERC20Permit _tToken) {
        tToken = _tToken;
    }

    function deposit(uint256 amount) public {
        tToken.transferFrom(msg.sender, address(this), amount);
        Balance[msg.sender] += amount;
    }

    function withdraw(uint256 amount) public {
        require(Balance[msg.sender] >= amount, "Insufficient balance");
        tToken.transfer(msg.sender, amount);
        Balance[msg.sender] -= amount;
    }

    function depositWithPermit(address owner, uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s) public {
        tToken.permit(owner, address(this), amount, deadline, v, r, s);
        tToken.transferFrom(owner, address(this), amount);
        Balance[msg.sender] += amount;
    }
}
