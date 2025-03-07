// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "./Inscription.sol";

contract InscriptionCloneFactory is Ownable {
    //    using Clones for address;
    address _impl;
    address _implOwner;
    mapping(address => address) _proxyOwners;

    constructor(address impl_) Ownable(msg.sender) {
        _impl = impl_;
        _implOwner = msg.sender;
    }

    function deployInscription(
        string memory name,
        string memory symbol,
        uint256 totalSupply,
        uint256 perMint,
        uint256 price
    ) external returns (address) {
        address cloneProxyInstance = Clones.clone(_impl);

        // 将代理地址转换为 Inscription 类型
        Inscription inscription = Inscription(cloneProxyInstance);

        // 初始化代理
        inscription.initialize(name, symbol, totalSupply, perMint, price);

        _proxyOwners[cloneProxyInstance] = msg.sender;

        return cloneProxyInstance;
    }

    function mintInscription(address tokenAddr) external payable {
        Inscription inscription = Inscription(tokenAddr);
        _splitEther(tokenAddr, inscription);
        inscription.mintInscription(msg.sender);
    }

    function _splitEther(address tokenAddr, Inscription inscription) private {
        require(msg.value > 0, "Must send some ETH");
        uint256 mintFee = inscription.perMint() * inscription.price();
        require(msg.value >= mintFee, "Insufficient mint costs");
        uint256 refundFees = msg.value - mintFee;

        // 计算分配金额（一半一半）
        uint256 totalAmount = mintFee;
        uint256 amount1 = totalAmount / 2; // 第一部分
        uint256 amount2 = totalAmount - amount1; // 第二部分（处理奇数情况）

        // 转账给 impl
        (bool success1,) = _implOwner.call{value: amount1}("");
        require(success1, "Transfer to Inscription impl failed");

        // 转账给 token
        address proxyOwner = _proxyOwners[tokenAddr];
        require(proxyOwner != address(0), "proxy owner not found");
        (bool success2,) = proxyOwner.call{value: amount2}("");
        require(success2, "Transfer to tokenAddr failed");

        // 退回多余的费用
        if (refundFees > 0) {
            (bool success3,) = msg.sender.call{value: refundFees}("");
            require(success3, "Refund of fees failed");
        }
    }

    receive() external payable {}

    function sendEther(address payable recipient, uint256 amount) external payable onlyOwner {
        require(address(this).balance >= amount, "Insufficient balance");
        (bool success,) = recipient.call{value: amount}("");
        require(success, "Call failed");
    }
}
