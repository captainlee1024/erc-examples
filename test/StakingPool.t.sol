// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import "forge-std/Vm.sol";

import "../src/staking/KKToken.sol";
import "../src/staking/StakingPool.sol";

contract StakingPoolTest is Test {
    KKToken kkToken;
    StakingPool stakingPool;

    address owner = address(this);
    address user = address(0x1234);
    address user2 = makeAddr("user2");
    address user3 = makeAddr("user3");

    function setUp() public {
        vm.startPrank(owner);
        // 部署 KKToken
        kkToken = new KKToken("KK Token", "KK");
        // 部署 StakingPool
        stakingPool = new StakingPool(address(kkToken));
        vm.stopPrank();

        // 给用户分配 ETH
        vm.deal(user, 100 ether);
        vm.deal(user2, 100 ether);
        vm.deal(user3, 100 ether);

        // 初始状态：owner 拥有所有 KKToken（1e10 * 1e18）
        // 转移一些 KKToken 给 StakingPool 以便 mint 奖励
        kkToken.transfer(address(stakingPool), 1e10 * 1e18); // 转移 10亿个 KKToken
    }

    function testStake() public {
        vm.startPrank(user);

        // 用户质押 1 ETH
        uint256 stakeAmount = 1 ether;
        stakingPool.stake{value: stakeAmount}();

        // 验证总质押量
        assertEq(stakingPool.totalStaked(), stakeAmount, "Total staked should increase");
        // 验证用户质押量
        assertEq(stakingPool.balanceOf(user), stakeAmount, "User balance should increase");
        // 验证 lastUpdateBlock 更新
        assertEq(stakingPool._lastUpdateBlock(), block.number, "Last update block should be current block");

        vm.stopPrank();
    }

    function testReceive() public {
        vm.startPrank(user);

        // 直接发送 1 ETH
        uint256 sendAmount = 1 ether;
        (bool success,) = address(stakingPool).call{value: sendAmount}("");
        require(success, "ETH send failed");

        // 验证总质押量
        assertEq(stakingPool.totalStaked(), sendAmount, "Total staked should increase via receive");
        assertEq(stakingPool.balanceOf(user), 1 ether, "User balance should not increase via receive");

        vm.stopPrank();
    }

    function testUnstake() public {
        vm.startPrank(user);

        // 质押 1 ETH
        uint256 stakeAmount = 2 ether;
        stakingPool.stake{value: stakeAmount}();

        // 前进几个区块以累积奖励
        vm.roll(block.number + 10);

        // 赎回 0.5 ETH
        uint256 unstakeAmount = 1 ether;
        uint256 balanceBefore = user.balance;
        stakingPool.unstake(unstakeAmount);

        // 验证用户质押量减少
        assertEq(stakingPool.balanceOf(user), stakeAmount - unstakeAmount, "User balance should decrease");
        // 验证总质押量减少
        assertEq(stakingPool.totalStaked(), stakeAmount - unstakeAmount, "Total staked should decrease");
        // 验证 ETH 返回
        assertEq(user.balance, balanceBefore + unstakeAmount, "ETH should be returned to user");

        vm.stopPrank();
    }

    function testClaim() public {
        vm.startPrank(user);

        // 质押 1 ETH
        uint256 stakeAmount = 1 ether;
        stakingPool.stake{value: stakeAmount}();

        // 前进 10 个区块
        vm.roll(block.number + 10);

        // 领取奖励
        uint256 balanceBefore = kkToken.balanceOf(user);
        stakingPool.claim();
        uint256 balanceAfter = kkToken.balanceOf(user);

        // 验证奖励发放
        assertGt(balanceAfter, balanceBefore, "KKToken balance should increase after claim");
        // 验证用户质押量未变
        assertEq(stakingPool.balanceOf(user), stakeAmount, "Stake amount should not change after claim");

        vm.stopPrank();
    }

    function testClaimWithMoreUserStake() public {
        vm.roll(block.number + 10);

        vm.startPrank(user);
        // uer 质押 1 ETH
        uint256 user1StakeAmount = 1 ether;
        stakingPool.stake{value: user1StakeAmount}();

        // 前进 10 个区块
        vm.roll(block.number + 10);
        vm.stopPrank();

        vm.startPrank(user2);
        // uer2 质押 1 ETH
        uint256 user2StakeAmount = 1 ether;
        stakingPool.stake{value: user2StakeAmount}();

        // 前进 10 个区块
        vm.roll(block.number + 10);
        vm.stopPrank();

        vm.startPrank(user3);
        // user3 质押 2 ETH
        uint256 user3StakeAmount = 2 ether;
        stakingPool.stake{value: user3StakeAmount}();

        // 前进 10 个区块
        vm.roll(block.number + 10);
        vm.stopPrank();

        // 查看此时的奖励
        vm.prank(user);
        assertEq(kkToken.balanceOf(user), 0);
        vm.prank(user);
        // 是设置时间不是设置区块用的
        //        vm.warp(41);
        stakingPool.claim();

        vm.prank(user2);
        assertEq(kkToken.balanceOf(user2), 0);
        vm.prank(user2);
        // 是设置时间不是设置区块用的
        //        vm.warp(41);
        stakingPool.claim();

        vm.prank(user3);
        assertEq(kkToken.balanceOf(user3), 0);
        vm.prank(user3);
        // 是设置时间不是设置区块用的
        //        vm.warp(41);
        stakingPool.claim();

        // user1 reward = 1 * (10 * 10 * 1 + 10 * 10 * 1/2 + 10 * 10 * 1/4)
        assertEq(kkToken.balanceOf(user), 1e18 * (10 * 10 * 0 + 10 * 10 * 1 + 10 * 10 * 1 / 2 + 10 * 10 * 1 / 4));
        // user2 reward = 1 * (10 * 10 * 1/2 + 10 * 10 * 1/4)
        assertEq(kkToken.balanceOf(user2), 1e18 * (10 * 10 * 1 / 2 + 10 * 10 * 1 / 4));
        // user3 reward = 2 * (10 * 10 * 1/4)
        assertEq(kkToken.balanceOf(user3), 2e18 * (10 * 10 * 1 / 4));

        //        // 领取奖励
        //        uint256 balanceBefore2 = kkToken.balanceOf(user);
        //        stakingPool.claim();
        //        uint256 balanceAfter2 = kkToken.balanceOf(user);
        //
        //        // 验证奖励发放
        //        assertGt(balanceAfter2, balanceBefore2, "KKToken balance should increase after claim");
        //        // 验证用户质押量未变
        //        assertEq(stakingPool.balanceOf(user), stakeAmount + stakeAmount2, "Stake amount should not change after claim");
    }

    function testClaimWithMultiStakeOneUser() public {
        vm.startPrank(user);

        // 质押 1 ETH
        uint256 stakeAmount = 1 ether;
        stakingPool.stake{value: stakeAmount}();

        // 前进 10 个区块
        vm.roll(block.number + 10);

        // 再质押 1 ETH
        stakingPool.stake{value: stakeAmount}();

        // 再前进 10 个块
        vm.roll(block.number + 10);

        // 领取奖励
        uint256 balanceBefore = kkToken.balanceOf(user);
        assertEq(balanceBefore, 10 * 10 * 1e18, "KKToken balance should be 10 * 10 * 1e18 before claim");

        stakingPool.claim();
        uint256 balanceAfter = kkToken.balanceOf(user);

        assertEq(balanceAfter, 2 * 10 * 10 * 1e18, "KKToken balance should be 10 * 10 * 1e18 before claim");

        assertGt(balanceAfter, balanceBefore, "KKToken balance should increase after claim");
        // 验证用户质押量未变
        assertEq(stakingPool.balanceOf(user), stakeAmount * 2, "Stake amount should not change after claim");

        vm.stopPrank();
    }

    function testEarned() public {
        vm.startPrank(user);

        // 质押 1 ETH
        uint256 stakeAmount = 1 ether;
        stakingPool.stake{value: stakeAmount}();

        // 前进 10 个区块
        vm.roll(block.number + 10);

        // 计算预期奖励
        uint256 blocksPassed = 10;
        uint256 expectedReward = (blocksPassed * stakingPool._preBlockReward()) / stakeAmount * stakeAmount;
        uint256 earned = stakingPool.earned(user);

        // 验证待领取奖励
        assertEq(earned, expectedReward, "Earned reward calculation incorrect");

        vm.stopPrank();
    }

    function testBalanceOf() public {
        vm.startPrank(user);

        // 质押 1 ETH
        uint256 stakeAmount = 1 ether;
        stakingPool.stake{value: stakeAmount}();

        // 验证余额
        assertEq(stakingPool.balanceOf(user), stakeAmount, "BalanceOf should return staked amount");

        vm.stopPrank();
    }

    function testRevertStakeZero() public {
        vm.prank(user);
        // 尝试质押 0 ETH，应失败
        vm.expectRevert("stake amount must be greater than 1 ether");
        stakingPool.stake{value: 0}();
    }

    function test_Revert_When_UnstakeZero() public {
        vm.startPrank(user);
        stakingPool.stake{value: 1 ether}();
        vm.expectRevert("unstake amount must be greater than 0");
        stakingPool.unstake(0);
        vm.stopPrank();
    }

    function test_Revert_When_UnstakeMoreThanStaked() public {
        vm.startPrank(user);
        stakingPool.stake{value: 1 ether}();
        vm.expectRevert("unstake amount must be less than staked amount");
        stakingPool.unstake(2 ether);
        vm.stopPrank();
    }
}
