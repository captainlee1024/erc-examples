// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Bank} from "../src/BankForTest.sol";

contract BankTest is Test {
    Bank public bank;

    function setUp() public {
        bank = new Bank();
    }

    function test_Deposit() public {
        bank.depositETH{value: 1000}();
        assertEq(bank.balanceOf(address(this)), 1000);
    }

    function testFuzz_ExpectEmittedDepositEvent_topic1(address x) public {
        // start prank
        vm.deal(x, 1000000);
        vm.prank(x);
        vm.expectEmit(true, false, false, false);
        // expected event
        emit Bank.Deposit(x, 2);
        bank.depositETH{value: 1000000}();
        // end prank

        vm.deal(address(this), 1000000);
        vm.expectEmit(true, false, false, false);
        // expected event
        emit Bank.Deposit(address(this), 2);
        bank.depositETH{value: 1000000}();
    }

    function test_ExpectEmittedDepositEvent_data() public {
        vm.expectEmit(false, false, false, true);
        // expected event
        emit Bank.Deposit(address(0), 2);
        bank.depositETH{value: 2}();
    }

    function test_BalanceOf() public {
        bank.depositETH{value: 1000}();
        assertEq(bank.balanceOf(address(this)), 1000);
    }

    function testFuzz_BalanceOf(uint256 x) public {
        x = bound(x, 10, type(uint256).max);
        vm.deal(address(this), x);
        bank.depositETH{value: x/2}();
        assertEq(bank.balanceOf(address(this)), x/2);
    }


}