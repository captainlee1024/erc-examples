// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IToken} from "./IStakingPool.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract KKToken is ERC20Permit, IToken, Ownable {
    constructor(string memory name_, string memory symbol_)
        ERC20(name_, symbol_)
        ERC20Permit(name_)
        Ownable(msg.sender)
    {
        _mint(msg.sender, 1e10 * 1e18);
    }

    function mint(address to, uint256 amount) external override onlyOwner {
        _mint(to, amount);
    }

    function burn(uint256 amount) public {
        _burn(msg.sender, amount);
    }
}
