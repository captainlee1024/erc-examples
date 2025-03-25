// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TokenA is ERC20 {
    constructor(uint256 _totalSupply) ERC20("TokenB", "TKB") {
        _mint(msg.sender, _totalSupply);
    }
}

contract TokenB is ERC20 {
    constructor(uint256 _totalSupply) ERC20("TokenB", "TKB") {
        _mint(msg.sender, _totalSupply);
    }
}
