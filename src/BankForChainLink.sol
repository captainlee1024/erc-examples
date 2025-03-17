// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {AutomationCompatible} from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "./TerryToken.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract TokenBankForChainLink is AutomationCompatible, Ownable {
    mapping(address => mapping(address => uint256)) public Balance;
    mapping(address => bool) public _supportTokens;
    address[] public _supportTokenList;
    uint256 public constant _checkPoint = 100 * 1e18;

    modifier onlySupportToken(address targetToken_) {
        require(_supportTokens[targetToken_], "unSupport token");
        _;
    }

    constructor() Ownable(msg.sender) {}

    function isSupportToken(address token) public view returns (bool) {
        return _supportTokens[token];
    }

    function deposit(address token, uint256 amount) public onlySupportToken(token) {
        bool result = ERC20Permit(token).transferFrom(msg.sender, address(this), amount);
        require(result, "deposit failed, ERC20Permit.transferFrom return false");
        Balance[token][msg.sender] += amount;
    }

    function withdraw(address token, uint256 amount) public onlySupportToken(token) {
        require(Balance[token][msg.sender] >= amount, "Insufficient balance");
        bool result = ERC20Permit(token).transfer(msg.sender, amount);
        require(result, "withdraw failed, ERC20Permit.transfer return false");
        Balance[token][msg.sender] -= amount;
    }

    function depositWithPermit(
        address token,
        address owner,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {
        ERC20Permit(token).permit(owner, address(this), amount, deadline, v, r, s);
        bool result = ERC20Permit(token).transferFrom(owner, address(this), amount);
        require(result, "deposit failed, ERC20Permit.transferFrom return false");
        Balance[token][msg.sender] += amount;
    }

    function addSupportToken(address newToken_) external {
        _supportTokens[newToken_] = true;
        _supportTokenList.push(newToken_);
    }

    function checkUpkeep(bytes calldata checkData)
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        // TODO: 每个代币的精度不同，需要优化
        // 每个块都检查一下
        // 检查所有代币
        // FIXME: 注意，数组足够长时是否会影响call调用? (call 调用是否受gas limit影响)
        uint256 len = _supportTokenList.length;
        uint256 tmpBalance;
        uint256 count;
        // 第一次遍历 统计符合条件的token数量
        for (uint256 i = 0; i < len; i++) {
            tmpBalance = ERC20Permit(_supportTokenList[i]).balanceOf(address(this));
            if (tmpBalance >= _checkPoint) {
                count++; // 记录符合条件的地址数量
            }
        }

        if (count == 0) {
            return (false, new bytes(0));
        }

        // 第二次遍历 复制符合条件的地址
        address[] memory performUpkeepAddress = new address[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < len; i++) {
            tmpBalance = ERC20Permit(_supportTokenList[i]).balanceOf(address(this));
            if (tmpBalance >= _checkPoint) {
                performUpkeepAddress[index] = _supportTokenList[i]; // 手动管理索引
                index++;
            }
        }

        performData = abi.encode(performUpkeepAddress);

        return (true, performData);
    }

    function performUpkeep(bytes calldata performData) external override {
        address[] memory targetTokens = abi.decode(performData, (address[]));
        uint256 len = targetTokens.length;
        bool result;
        for (uint256 i = 0; i < len; i++) {
            result = ERC20Permit(targetTokens[i]).transfer(owner(), _checkPoint / 2);
            require(result, "performUpkeep failed, ERC20Permit.transfer return false");
        }
    }
}
