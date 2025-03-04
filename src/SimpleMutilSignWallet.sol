// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MultiSigWallet is Ownable {
    // 代币合约接口
    IERC20 public token;

    // 签名者列表
    mapping(address => bool) public isSigner;
    address[] public signers;

    // 存储交易
    struct Transaction {
        address to;
        uint256 value;
        uint256 signatures;
        bool executed;
    }

    Transaction[] public transactions;

    // 必须的签名数
    uint256 public requiredSignatures;

    // 事件
    event TransactionSubmitted(uint256 transactionId, address indexed to, uint256 value);
    event TransactionSigned(uint256 transactionId, address indexed signer);
    event TransactionExecuted(uint256 transactionId);

    constructor(address _token, uint256 _requiredSignatures) Ownable() {
        token = IERC20(_token);
        requiredSignatures = _requiredSignatures;
    }

    modifier onlySigner() {
        require(isSigner[msg.sender], "Not a signer");
        _;
    }

    modifier transactionExists(uint256 transactionId) {
        require(transactionId < transactions.length, "Transaction does not exist");
        _;
    }

    modifier notExecuted(uint256 transactionId) {
        require(!transactions[transactionId].executed, "Transaction already executed");
        _;
    }

    modifier notSigned(uint256 transactionId) {
        require(!hasSigned(transactionId, msg.sender), "Signer already signed");
        _;
    }

    // 检查签名者是否已经签署
    function hasSigned(uint256 transactionId, address signer) public view returns (bool) {
        for (uint256 i = 0; i < transactions[transactionId].signatures; i++) {
            if (signers[i] == signer) {
                return true;
            }
        }
        return false;
    }

    // 添加签名者
    function addSigner(address signer) public onlyOwner {
        require(!isSigner[signer], "Already a signer");
        isSigner[signer] = true;
        signers.push(signer);
    }

    // 删除签名者
    function removeSigner(address signer) public onlyOwner {
        require(isSigner[signer], "Not a signer");
        isSigner[signer] = false;

        for (uint256 i = 0; i < signers.length; i++) {
            if (signers[i] == signer) {
                signers[i] = signers[signers.length - 1];
                signers.pop();
                break;
            }
        }
    }

    // 提交交易（ERC-20 转账）
    function submitTransaction(address to, uint256 value) public onlySigner {
        uint256 transactionId = transactions.length;
        transactions.push(Transaction({
            to: to,
            value: value,
            signatures: 0,
            executed: false
        }));

        emit TransactionSubmitted(transactionId, to, value);
    }

    // 签署交易
    function signTransaction(uint256 transactionId) public onlySigner transactionExists(transactionId) notExecuted(transactionId) notSigned(transactionId) {
        transactions[transactionId].signatures++;

        emit TransactionSigned(transactionId, msg.sender);

        // 当签名数达到要求时，执行交易
        if (transactions[transactionId].signatures >= requiredSignatures) {
            executeTransaction(transactionId);
        }
    }

    // 执行交易
    function executeTransaction(uint256 transactionId) public transactionExists(transactionId) notExecuted(transactionId) {
        require(transactions[transactionId].signatures >= requiredSignatures, "Not enough signatures");

        transactions[transactionId].executed = true;
        bool success = token.transfer(transactions[transactionId].to, transactions[transactionId].value);
        require(success, "Token transfer failed");

        emit TransactionExecuted(transactionId);
    }

    // 获取签名者地址
    function getSigners() public view returns (address[] memory) {
        return signers;
    }

    // 获取已提交交易数
    function getTransactionCount() public view returns (uint256) {
        return transactions.length;
    }
}
