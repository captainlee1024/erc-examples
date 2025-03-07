// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/RankBank.sol";

contract BankTest is Test {
    Bank bank;
    address user1 = address(0x1);
    address user2 = address(0x2);
    address user3 = address(0x3);

    function setUp() public {
        bank = new Bank();
    }

    function test_Deposit() public {
        vm.deal(user1, 10 ether);
        vm.prank(user1);
        bank.deposit{value: 1 ether}();
        assertEq(bank.balances(user1), 1 ether);
    }

    function test_TopDepositors() public {
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(user3, 10 ether);

        vm.prank(user1);
        bank.deposit{value: 3 ether}();
        vm.prank(user2);
        bank.deposit{value: 2 ether}();
        vm.prank(user3);
        bank.deposit{value: 1 ether}();

        (address[] memory users, uint256[] memory amounts) = bank.getTopDepositors();
        assertEq(users[0], user1);
        assertEq(amounts[0], 3 ether);
        assertEq(users[1], user2);
        assertEq(amounts[1], 2 ether);
        assertEq(users[2], user3);
        assertEq(amounts[2], 1 ether);
    }

    function test_TopTenLimit() public {
        address[11] memory users;
        for (uint256 i = 0; i < 11; i++) {
            users[i] = address(uint160(i + 1));
            vm.deal(users[i], 10 ether);
            vm.prank(users[i]);
            uint256 depositAmount = 10 ether - (i * 0.9 ether);
            bank.deposit{value: depositAmount}();
        }
        (address[] memory topUsers, uint256[] memory amounts) = bank.getTopDepositors();
        assertEq(topUsers.length, 10);
        assertEq(amounts[0], 10 ether);
        assertEq(amounts[9], 1.9 ether);
    }
}
