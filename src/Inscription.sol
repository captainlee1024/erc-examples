// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract Inscription is ERC20Permit, Ownable{
    // 单次发行量
    uint256 private _perMint;
    // 单个代币铸造费用
    uint256 private _price;
    uint256 private _currentSupply;
    string private _name;
    string private _symbol;      // 自定义符号
    uint256 private _totalSupply; // 自定义最大供应量
    constructor(string memory name_, string memory symbol_)
        ERC20(name_, symbol_)
        ERC20Permit(name_)
        Ownable(msg.sender)
    {}

    function  sendEther(address payable recipient) external payable onlyOwner {
        require(address(this).balance >= msg.value, "Insufficient balance");
        (bool success, ) = recipient.call{value: msg.value}("");
        require(success, "Call failed");
    }

    // symbol_ 铭文名称
    function initialize(string memory name_, string memory symbol_, uint256 totalSupply_, uint256 perMint_, uint256 price_) public {
        _name = name_;
        _symbol = symbol_;
        _totalSupply = totalSupply_;
        _perMint = perMint_;
        _price = price_;
    }

    function mintInscription(address receiver) public payable {
        require((_currentSupply + _perMint) <= _totalSupply, "Exceeds total supply");
       _mint(receiver, _perMint) ;
        _currentSupply += _perMint;
    }

    // 重写 symbol() 以支持动态更新
    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view override virtual returns (uint256) {
        return _totalSupply;
    }

    /**
    * @dev Returns the name of the token.
     */
    function name() public view override virtual returns (string memory) {
        return _name;
    }

    function circulatingSupply() public view returns(uint256){
        return _currentSupply;
    }

    function price() public view returns (uint256) {
        return _price;
    }

    function perMint() public view returns (uint256) {
        return _perMint;
    }
}
