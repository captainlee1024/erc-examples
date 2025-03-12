// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {MyWallet} from "../src/MyWalletForTest.sol";

contract MyWalletTest is Test {
    MyWallet _myWallet;
    address walletOwner;
    address newWalletOwner;
    address notOwner;

    function setUp() public {
        walletOwner = makeAddr("walletOwner");
        newWalletOwner = makeAddr("newWalletOwner");
        notOwner = makeAddr("notOwner");

        vm.prank(walletOwner);
        _myWallet = new MyWallet("my_wallet");
    }

    function testTransferOwernship_success() public {
        vm.prank(walletOwner);
        _myWallet.transferOwernship(newWalletOwner);
        assertEq(_myWallet.owner(), newWalletOwner);
    }

    function testTransferOwernship_failed() public {
        vm.expectRevert("Not authorized");
        vm.prank(notOwner);
        _myWallet.transferOwernship(notOwner);
    }
}
