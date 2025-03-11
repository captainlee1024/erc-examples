// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {TToken} from "./TerryToken.sol";

// 用户随时可以质押项目方代币 RNT(自定义的ERC20) ，开始赚取项目方Token(esRNT)；
// 可随时解押提取已质押的 RNT；
// 可随时领取esRNT奖励，每质押1个RNT每天可奖励 1 esRNT;
// esRNT 是锁仓性的 RNT， 1 esRNT 在 30 天后可兑换 1 RNT，
//  随时间线性释放，支持提前将 esRNT 兑换成 RNT，但锁定部分将被 burn 燃烧掉。

contract StakePool is Ownable {
    IERC20 _RNT; // 项目方指定Token
    IERC20 _esRNT; // 质押凭证
    uint256 vestingDuration = 30 days; // esRNT解锁时间
    //    uint256 rewardPerSecond = 1e18 / 1 days; // 每秒钟收益
    uint256 rewardPerDay = 1; // 每天的收益
    mapping(address => StakeInfo) userStakeInfo; // 质押信息记录
    address burnedAddr = address(0x000000000000000000000000000000000000dEaD);

    struct StakeInfo {
        uint256 staked; //质押金额，可持续追加
        uint256 unClaimed; // 截止当前block.timestamp可领取esToken 领取还要根据领取时间进行转换
        uint256 lastUpdateTime;
    }

    mapping(address => mapping(uint256 => ESRNTLockedInfo)) userLockedESRNTInfo; //

    struct ESRNTLockedInfo {
        uint256 amount;
        uint256 startLockingTime;
    }

    mapping(address => uint256) userESRNTLockCounter;

    function incrementUserESRNTLockCounter(address user) internal {
        userESRNTLockCounter[user] += 1;
    }

    function currentUserESRNTLockCounter(address user) public view returns (uint256) {
        return userESRNTLockCounter[user];
    }

    constructor(address RNT_, address esRNT_) Ownable(msg.sender) {
        _RNT = IERC20(RNT_);
        _esRNT = IERC20(esRNT_);
        //        _esRNT = new TToken("esRNToken", "esRNT");
    }

    function stake(uint256 amount_) public {
        require(amount_ >= 1e18, "Stake failed, stake at least 1 token (1e18)");
        StakeInfo memory stakeInfo = userStakeInfo[msg.sender];
        bool result = _RNT.transferFrom(msg.sender, address(this), amount_);
        require(result, "transferFrom failed");
        if (stakeInfo.lastUpdateTime == 0) {
            // 首次stake
            stakeInfo = StakeInfo(amount_, 0, block.timestamp);
        } else {
            // 领取之前的累积奖励
            uint256 rewardsSinceLastUpdate =
                stakeInfo.staked * (block.timestamp - stakeInfo.lastUpdateTime) / 86400 * rewardPerDay;
            stakeInfo.staked += amount_;
            stakeInfo.unClaimed += rewardsSinceLastUpdate;
            stakeInfo.lastUpdateTime = block.timestamp;

            uint256 toUser = stakeInfo.unClaimed;
            // 累计奖励清零
            stakeInfo.unClaimed = 0;
            bool result = _esRNT.transfer(msg.sender, toUser);
            require(result, "transfer esRNT failed");
            result = _RNT.transferFrom(msg.sender, address(this), amount_);
            require(result, "transferFrom failed");
        }

        userStakeInfo[msg.sender] = stakeInfo;
    }

    function unStake() public {
        // 领取所有累计奖励
        claim();
        // 清除记录，提取质押token
        StakeInfo memory stakeInfo = userStakeInfo[msg.sender];
        uint256 toUser = stakeInfo.staked;
        stakeInfo.staked = 0;
        stakeInfo.lastUpdateTime = 0;
        stakeInfo.unClaimed = 0;
        userStakeInfo[msg.sender] = stakeInfo;
        bool result = _RNT.transfer(msg.sender, toUser);
        require(result, "unStake failed, withdraw RNT failed");
    }

    // 领取esRNT, 并加入待解锁中
    function claim() public {
        require(userStakeInfo[msg.sender].lastUpdateTime > 0, "Claim failed, no staked tokens");
        StakeInfo memory stakeInfo = userStakeInfo[msg.sender];
        // 领取当前时间之前的所有奖励
        uint256 rewardsSinceLastUpdate =
            stakeInfo.staked * (block.timestamp - stakeInfo.lastUpdateTime) / 86400 * rewardPerDay;
        stakeInfo.unClaimed += rewardsSinceLastUpdate;
        stakeInfo.lastUpdateTime = block.timestamp;

        // 领取金额
        uint256 toUser = stakeInfo.unClaimed;
        // 累计奖励归零
        stakeInfo.unClaimed = 0;
        bool result = _esRNT.transfer(msg.sender, toUser);
        require(result, "transfer failed");
    }

    function activeESRNT(address user) public view returns (uint256) {
        return _esRNT.balanceOf(user);
    }

    // 将本次领取的esRNT开启30天锁定, 返回本次锁定对应的Id
    function lockESRNT(uint256 amount) public returns (uint256) {
        incrementUserESRNTLockCounter(msg.sender);
        uint256 lockId = currentUserESRNTLockCounter(msg.sender);
        require(
            userLockedESRNTInfo[msg.sender][lockId].startLockingTime == 0,
            "LockESRNT failed, lockId has already been used"
        );

        // lock the esRNT and return lockId
        bool result = _esRNT.transferFrom(msg.sender, address(this), amount);
        require(result, "transfer failed");
        userLockedESRNTInfo[msg.sender][lockId] = ESRNTLockedInfo(amount, block.timestamp);

        return lockId;
    }

    // 解锁并兑换成RNT, 如果时间不够，部分兑换的RNT将被burn
    function unlockESRNT(uint256 esRNTLockedId_) public {
        ESRNTLockedInfo memory lockInfo = userLockedESRNTInfo[msg.sender][esRNTLockedId_];
        require(lockInfo.startLockingTime != 0, "unlock esRNT failed, locked esRNT not found by lockedId");

        userLockedESRNTInfo[msg.sender][esRNTLockedId_] = ESRNTLockedInfo(0, 0);

        // 判断是否超过30天
        if (block.timestamp - lockInfo.startLockingTime >= vestingDuration) {
            // 超过30天等额兑换
            bool result = _RNT.transfer(msg.sender, lockInfo.amount);
            require(result, "transfer failed");

            //            _esRNT.transferFrom(msg.sender, address(this), lockInfo.amount);
        } else {
            // 未达到30天，线性比例兑换
            uint256 toBurn =
                lockInfo.amount * (vestingDuration - (block.timestamp - lockInfo.startLockingTime)) / vestingDuration;
            uint256 toUser = lockInfo.amount - toBurn;
            bool result = _RNT.transfer(burnedAddr, toBurn);
            require(result, "transfer failed");
            result = _RNT.transfer(msg.sender, toUser);
            require(result, "transfer failed");
            //            _esRNT.transferFrom(msg.sender, address(this), lockInfo.amount);
        }
    }
}
