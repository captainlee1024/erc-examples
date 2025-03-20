// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IStaking, IToken} from "./IStakingPool.sol";
import {KKToken} from "./KKToken.sol";

/// 质押池资金发生变动的区块
/// 每个ETH从质押池启动至今的收益

contract StakingPool is IStaking {
    /// 挖矿激励代币 KK Token
    IToken public _KKToken;
    /// 每个区块奖励
    uint256 public _preBlockReward = 10e18;
    /// 总质押的ETH数量
    uint256 private _totalStaked;

    function totalStaked() external view returns (uint256) {
        return _totalStaked * 1e18;
    }
    /// 质押池资金发生变动的最新区块, 初始为合约部署区块

    uint256 public _lastUpdateBlock = block.number;
    /// 合约启动阶段空矿池阶段的收益
    RewardRateChangeRecords public _initRewardRateInfo = RewardRateChangeRecords(0, 0);
    /// 每个ChangePoint对应的uint256Info记录
    mapping(uint256 => RewardRateChangeRecords) public _totalRewardChangeRecords;

    struct RewardRateChangeRecords {
        // 已经结算过总PreEthReward block区间
        uint256 settlementBlockStageRewardPreEth;
        // 当前时间段的PreEthReward的block，当下次totalStaked变动时，结算当前价格的block区间并添加至settlementBlockStageRewardPreEth
        uint256 newRewardPreEthOneBlock;
    }
    /// 用户质押信息

    struct UserStakeInfo {
        /// 质押的ETH数量
        uint256 amount;
        /// 当前amount数量产生收益的起始区块
        uint256 startRewardBlock;
    }
    /// 用户质押信息

    mapping(address => UserStakeInfo) public _userStakeInfo;

    constructor(address KKTokenAddress) {
        _KKToken = IToken(KKTokenAddress);
        _totalRewardChangeRecords[_lastUpdateBlock] = _initRewardRateInfo;
    }

    /**
     * @dev 质押 ETH 到合约
     */
    function stake() external payable {
        require(msg.value >= 1 ether, "stake amount must be greater than 1 ether");
        // 领取累计奖励
        _claim(msg.sender);
        uint256 ethAmount = msg.value / 1e18;
        _totalStaked += ethAmount;
        _updateUserInfo(_userStakeInfo[msg.sender].amount + ethAmount);
        _updateRewardInfo();
    }

    function _updateRewardInfo() internal {
        uint256 currentBlock = block.number;

        RewardRateChangeRecords memory rewardRateRecords = _totalRewardChangeRecords[_lastUpdateBlock];

        // 结算上一个时间段的totalRewardPreEth
        // 1 -> 11- 1 * 0
        // 2 -> 21 - 11 * 10个token每个eth每个block
        // 3 -> 31 - 21 * 5个token每个eth每个block
        uint256 settlementLastRateStage = (block.number - _lastUpdateBlock) * rewardRateRecords.newRewardPreEthOneBlock;
        // 追加到之前的 settlementBlockStageRewardPreEth中
        // 1 -> 0
        // 2 -> 0 + (21 - 11 * 10个token每个eth每个block)
        // 3 -> 0 + (21 - 11 * 10个token每个eth每个block) + (31 - 21 * 5个token每个eth每个block)
        rewardRateRecords.settlementBlockStageRewardPreEth += settlementLastRateStage;

        // 从当前block开启新Rate
        // 1 -> block 11 , 10 / 1 = 10个token每个eth每个block
        // 2 -> block 21, 10 / 2 = 5个token每个eth每个block
        // 3 -> block 31, 10 / 4 = 2.5个token每个eth每个block
        uint256 newRewardPreEthOneBlock = _preBlockReward / _totalStaked;
        rewardRateRecords.newRewardPreEthOneBlock = newRewardPreEthOneBlock;

        // 1 -> 存入 block 11 -> 11, 10个token每个eth每个block
        // 2 -> 存入block 21 -> 21, 5个token每个eth每个block
        _totalRewardChangeRecords[currentBlock] = rewardRateRecords;

        // 1 -> 11
        // 11 -> 21
        _lastUpdateBlock = currentBlock;
    }

    /**
     * @dev 赎回质押的 ETH
     * @param amount_ 赎回数量
     */
    function unstake(uint256 amount_) external {
        require(amount_ >= 1 ether, "unstake amount must be greater than 0");
        uint256 ethAmount = amount_ / 1e18;
        require(_userStakeInfo[msg.sender].amount >= ethAmount, "unstake amount must be less than staked amount");
        // 领取累计奖励
        _claim(msg.sender);

        // 更新用户质押信息: newAmount, startRewardBlock
        _updateUserInfo(_userStakeInfo[msg.sender].amount - ethAmount);

        // 更新池子总质押数量
        _totalStaked -= ethAmount;

        // 更新收益信息
        _updateRewardInfo();

        // 转账ETH
        payable(msg.sender).transfer(ethAmount * 1e18);
    }

    function _claim(address user) internal {
        uint256 rewards = _earned(user);
        // 更新用户质押信息: startRewardBlock = currentBlock
        //        UserStakeInfo userinfo = _userStakeInfo[user];
        //        userinfo.startRewardBlock = block.number;
        //        _userStakeInfo[user] = userinfo;
        //        _KKToken.mint(user, rewards);
        _KKToken.transfer(user, rewards);
    }

    // 更新用户质押信息: newAmount, startRewardBlock = currentBlock
    function _updateUserInfo(uint256 newAmount) internal {
        _userStakeInfo[msg.sender].amount = newAmount;
        _userStakeInfo[msg.sender].startRewardBlock = block.number;
    }

    /**
     * @dev 领取 KK Token 收益
     */
    function claim() external {
        _claim(msg.sender);
        _updateUserInfo(_userStakeInfo[msg.sender].amount);
    }

    /**
     * @dev 获取质押的 ETH 数量
     * @param account 质押账户
     * @return 质押的 ETH 数量
     */
    function balanceOf(address account) external view returns (uint256) {
        return _userStakeInfo[account].amount * 1e18;
    }

    /**
     * @dev 获取待领取的 KK Token 收益
     * @param account 质押账户
     * @return 待领取的 KK Token 收益
     */
    function earned(address account) external view returns (uint256) {
        return _earned(account);
    }

    function _earned(address account) internal view returns (uint256) {
        UserStakeInfo memory userStakeInfo = _userStakeInfo[account];
        uint256 startPoint = userStakeInfo.startRewardBlock;
        uint256 endPoint = block.number;

        // === 模拟结算当前时间段的totalRewardPreEth ===
        // 但不存入_totalRewardChangeRecords
        RewardRateChangeRecords memory rewardRateRecords = _totalRewardChangeRecords[_lastUpdateBlock];

        // 模拟结算上一个时间段的totalRewardPreEth (31 - 21)
        uint256 settlementLastRateStage = (block.number - _lastUpdateBlock) * rewardRateRecords.newRewardPreEthOneBlock;
        // 追加到之前的 settlementBlockStageRewardPreEth中
        rewardRateRecords.settlementBlockStageRewardPreEth += settlementLastRateStage;

        // 开始进行计算
        return (
            rewardRateRecords.settlementBlockStageRewardPreEth
                - _totalRewardChangeRecords[startPoint].settlementBlockStageRewardPreEth
        ) * userStakeInfo.amount;
    }

    receive() external payable {
        require(msg.value >= 1 ether, "stake amount must be greater than 1 ether");
        uint256 ethAmount = msg.value / 1e18;
        _totalStaked += ethAmount;
        _updateUserInfo(_userStakeInfo[msg.sender].amount + ethAmount);
        _updateRewardInfo();
    }
}
