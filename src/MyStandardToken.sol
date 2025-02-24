// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MyToken is ERC20, Ownable {
    constructor() ERC20("MyToken", "MTK") Ownable(msg.sender) {
        // 在部署时给部署者 mint 一些初始代币（可选）
        _mint(msg.sender, 1000 * 10 ** decimals());
    }

    // 只有 owner 可以铸造新代币
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    // 允许任何持币者销毁自己的代币
    function burn(uint256 amount) public {
        _burn(msg.sender, amount);
    }
}
