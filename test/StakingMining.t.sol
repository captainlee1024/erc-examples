// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {StakePool} from "../src/StakingMining.sol";
import "forge-std/Test.sol";
import {TToken} from "../src/TerryToken.sol";

contract StakingMiningTest is Test {
    StakePool stakePool;
    TToken ESRNT;
    address stakeOwner;

    TToken RNT;
    address rntOwner;

    address user1;
    address user2;
    uint256 initialAmount;
    uint256 stakePoolInitialTokenHoldings;

    function setUp() public {
        rntOwner = makeAddr("rntOwner");
        vm.prank(rntOwner);
        RNT = new TToken("RNToken", "RNT");

        stakeOwner = makeAddr("stakeOwner");
        vm.prank(stakeOwner);
        ESRNT = new TToken("ESRNTOKEN", "ESRNT");

        vm.prank(stakeOwner);
        stakePool = new StakePool(address(RNT), address(ESRNT));

        vm.prank(stakeOwner);
        ESRNT.transfer(address(stakePool), 1e10 * 1e18);

        vm.prank(rntOwner);
        stakePoolInitialTokenHoldings = 1e5 * 1e18;
        RNT.transfer(address(stakePool), stakePoolInitialTokenHoldings);

        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        initialAmount = 10 * 1e18; //10 token

        // 初始化 RNT 金额
        vm.startPrank(rntOwner);
        RNT.transfer(user1, initialAmount);
        RNT.transfer(user2, initialAmount);
        vm.stopPrank();
    }

    // esRNT 锁定30天以上，成功解锁并兑换为预期数量RNT 测试
    function testUnlockESRNT_SuccessAfter30Days() public {
        uint256 stakeTimestamp = block.timestamp;
        // staking
        vm.startPrank(user1);
        RNT.approve(address(stakePool), 10 * 1e18);

        vm.warp(stakeTimestamp);
        stakePool.stake(10 * 1e18);

        vm.stopPrank();

        assertEq(RNT.balanceOf(address(stakePool)), stakePoolInitialTokenHoldings + 10 * 1e18);
        assertEq(RNT.balanceOf(user1), 0);

        uint256 afterStakeOneDay = stakeTimestamp + 1 days;
        // unStake and claim after 1 day
        vm.startPrank(user1);

        vm.warp(afterStakeOneDay);
        stakePool.unStake();

        vm.stopPrank();

        assertEq(RNT.balanceOf(address(stakePool)), stakePoolInitialTokenHoldings);
        assertEq(RNT.balanceOf(user1), 10 * 1e18);
        // 一天后 unStake
        // 获取的收益等价于stake的 10 * 1e18
        assertEq(stakePool.activeESRNT(user1), 10 * 1e18);

        // lockESRNT
        vm.startPrank(user1);
        ESRNT.approve(address(stakePool), 10 * 1e18);
        uint256 lockingTimestamp = block.timestamp;
        vm.warp(lockingTimestamp);
        uint256 lockedId = stakePool.lockESRNT(10 * 1e18);
        assertEq(stakePool.activeESRNT(user1), 0);

        // 30天后 解锁兑换为RNT 一比一兑换
        uint256 afterLockingThirtyDays = lockingTimestamp + 30 days;
        vm.warp(afterLockingThirtyDays);
        // unlockESRNT after after 30day
        stakePool.unlockESRNT(lockedId);
        vm.stopPrank();
        // 获取到了一倍收益
        assertEq(RNT.balanceOf(user1), 10 * 1e18 * 2);
    }

    // esRNT 锁定30天以上，成功解锁并兑换为预期数量RNT 测试
    function testUnlockESRNT_SuccessBefore30Days() public {
        uint256 stakeTimestamp = block.timestamp;
        // staking
        vm.startPrank(user1);
        RNT.approve(address(stakePool), 10 * 1e18);

        vm.warp(stakeTimestamp);
        stakePool.stake(10 * 1e18);

        vm.stopPrank();

        assertEq(RNT.balanceOf(address(stakePool)), stakePoolInitialTokenHoldings + 10 * 1e18);
        assertEq(RNT.balanceOf(user1), 0);

        uint256 afterStakeOneDay = stakeTimestamp + 1 days;
        // unStake and claim after 1 day
        vm.startPrank(user1);

        vm.warp(afterStakeOneDay);
        stakePool.unStake();

        vm.stopPrank();

        assertEq(RNT.balanceOf(address(stakePool)), stakePoolInitialTokenHoldings);
        assertEq(RNT.balanceOf(user1), 10 * 1e18);
        // 一天后 unStake
        // 获取的收益等价于stake的 10 * 1e18
        assertEq(stakePool.activeESRNT(user1), 10 * 1e18);

        // lockESRNT
        vm.startPrank(user1);
        ESRNT.approve(address(stakePool), 10 * 1e18);
        uint256 lockingTimestamp = block.timestamp;
        vm.warp(lockingTimestamp);
        uint256 lockedId = stakePool.lockESRNT(10 * 1e18);
        assertEq(stakePool.activeESRNT(user1), 0);

        // 15天后 解锁兑换为RNT 收益线形释放，释放一般的预期收益 及 10 / 2 * 1e18的收益
        uint256 afterLockingThirtyDays = lockingTimestamp + 15 days;
        vm.warp(afterLockingThirtyDays);
        // unlockESRNT after after 30day
        stakePool.unlockESRNT(lockedId);
        vm.stopPrank();
        // 获取到了一半的收益
        assertEq(RNT.balanceOf(user1), 10 * 1e18 + 5 * 1e18);
    }
}
