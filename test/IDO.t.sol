// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {TToken} from "../src/TerryToken.sol";
import "forge-std/Vm.sol";
import {IDO} from "../src/IDO.sol";

contract IDOTest is Test {
    IDO _ido;
    TToken _erc20;
    address tokenTeam;
    address user1;
    address user2;
    address user3;
    address user4;
    address user5;
    uint256 deadline;

    uint256 tokenPreEth;
    uint256 minFundAmount;
    uint256 maxFundAmount;

    function setUp() public {
        tokenTeam = makeAddr("tokenTeam");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");
        user4 = makeAddr("user4");
        user5 = makeAddr("user5");

        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
        vm.deal(user3, 100 ether);
        vm.deal(user4, 100 ether);
        vm.deal(user5, 100 ether);

        tokenPreEth = 100;
        minFundAmount = 100 ether;
        maxFundAmount = 200 ether;

        _ido = new IDO();
        vm.startPrank(tokenTeam);
        // 1e10 * 10**18
        _erc20 = new TToken("TerryToken", "TTK");
        vm.stopPrank();
    }

    function test_fund_success() public {
        // 发起IDO
        vm.startPrank(tokenTeam);
        // 授权拍卖的token量
//        _erc20.approve(address(_ido), tokenPreEth * minFundAmount);
        _erc20.transfer(address(_ido), tokenPreEth * minFundAmount);
        deadline = block.timestamp + 30 days;
        _ido.startIDO(
            address(_erc20),
            tokenPreEth,
            minFundAmount,
            maxFundAmount,
            deadline
        );
        vm.stopPrank();

        // 用户购买
        vm.prank(user1);
        _ido.presale{value: 10 ether}();

        vm.prank(user2);
        _ido.presale{value: 20 ether}();

        vm.prank(user3);
        _ido.presale{value: 20 ether}();

        vm.prank(user4);
        _ido.presale{value: 50 ether}();

        vm.prank(user5);
        _ido.presale{value: 100 ether}();

        // 还没有到期，调用claim报错
        vm.prank(user1);
        vm.expectRevert("Operation allowed only in Success state");
        _ido.claim();

        vm.warp(deadline + 1);
        vm.prank(user1);
        _ido.claim();

        vm.prank(user2);
        _ido.claim();

        vm.prank(user3);
        _ido.claim();

        vm.prank(user4);
        _ido.claim();

        vm.prank(user5);
        _ido.claim();

        vm.prank(tokenTeam);
        _ido.withdraw();

        // 5个用户分得的token
        // total fund = 10 + 20 + 20 + 50 + 100 = 200
        uint256 totalFund = 200 ether;
        // token 总拍卖量
        uint256 totalPreSale = tokenPreEth * minFundAmount;
        // user1 得到token量
        assertEq(_erc20.balanceOf(user1), totalPreSale * 10 ether/totalFund);
        // user2 得到token量
        assertEq(_erc20.balanceOf(user2), totalPreSale * 20 ether/totalFund);
        // user3 得到token量
        assertEq(_erc20.balanceOf(user3), totalPreSale * 20 ether/totalFund);
        // user4 得到token量
        assertEq(_erc20.balanceOf(user4), totalPreSale * 50 ether/totalFund);
        // user5 得到token量
        assertEq(_erc20.balanceOf(user5), totalPreSale * 100 ether/totalFund);
        // 项目方筹集到的金额
        assertEq(tokenTeam.balance, 200 ether);
    }

    function test_fund_failed() public {
        // 发起IDO
        vm.startPrank(tokenTeam);
        // 授权拍卖的token量
//        _erc20.approve(address(_ido), tokenPreEth * minFundAmount);
        _erc20.transfer(address(_ido), tokenPreEth * minFundAmount);
        deadline = block.timestamp + 30 days;
        _ido.startIDO(
            address(_erc20),
            tokenPreEth,
            minFundAmount,
            maxFundAmount,
            deadline
        );
        vm.stopPrank();

        // 用户购买
        vm.prank(user1);
        _ido.presale{value: 10 ether}();

        vm.prank(user2);
        _ido.presale{value: 10 ether}();

        vm.prank(user3);
        _ido.presale{value: 10 ether}();

        vm.prank(user4);
        _ido.presale{value: 10 ether}();

        vm.prank(user5);
        _ido.presale{value: 10 ether}();

        // 还没有到期，调用claim报错
        vm.prank(user1);
        vm.expectRevert("Operation allowed only in Success state");
        _ido.claim();

        vm.warp(deadline + 1);
        vm.prank(user1);
        vm.expectRevert("Operation allowed only in Success state");
        _ido.claim();

        vm.prank(user1);
        _ido.refund();

        vm.prank(user2);
        _ido.refund();

        vm.prank(user3);
        _ido.refund();

        vm.prank(user4);
        _ido.refund();

        vm.prank(user5);
        _ido.refund();

        vm.prank(tokenTeam);
        _ido.refundTokenToTeam();

        // 5个用户分得的token
        // user1 得到token量
        assertEq(_erc20.balanceOf(user1), 0);
        // user1 eth 余额
        assertEq(user1.balance, 100 ether);
        // user2 得到token量
        assertEq(_erc20.balanceOf(user2), 0);
        // user2 eth 余额
        assertEq(user2.balance, 100 ether);
        // user3 得到token量
        assertEq(_erc20.balanceOf(user3), 0);
        // user3 eth 余额
        assertEq(user3.balance, 100 ether);
        // user4 得到token量
        assertEq(_erc20.balanceOf(user4), 0);
        // user4 eth 余额
        assertEq(user4.balance, 100 ether);
        // user5 得到token量
        assertEq(_erc20.balanceOf(user5), 0);
        // user5 eth 余额
        assertEq(user5.balance, 100 ether);

        // 代币数量还是等于mint时的发行量
        assertEq(_erc20.balanceOf(tokenTeam), 1e10 * 1e18);
        // 项目方筹集到的金额
        assertEq(tokenTeam.balance, 0);
    }
}