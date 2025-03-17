// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {TokenBankForChainLink} from "../src/BankForChainLink.sol";
import {TToken} from "../src/TerryToken.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "forge-std/Vm.sol";

contract BankForChainLinkTest is Test {
    TokenBankForChainLink _bankForChainLink;
    TToken _erc20A;
    TToken _erc20B;
    TToken _erc20C;
    TToken _erc20D;
    TToken _erc20E;
    Vm.Wallet private ownerWallet = vm.createWallet("owner");
    Vm.Wallet private userWallet = vm.createWallet("user");

    function setUp() public {
        vm.startPrank(ownerWallet.addr);
        _bankForChainLink = new TokenBankForChainLink();
        vm.stopPrank();

        vm.startPrank(userWallet.addr);
        _erc20A = new TToken("TTokenA", "TTKA");
        _erc20B = new TToken("TTokenB", "TTKB");
        _erc20C = new TToken("TTokenC", "TTKC");
        _erc20D = new TToken("TTokenD", "TTKD");
        _erc20E = new TToken("TTokenE", "TTKE");
        vm.stopPrank();

        _bankForChainLink.addSupportToken(address(_erc20A));
        _bankForChainLink.addSupportToken(address(_erc20B));
        _bankForChainLink.addSupportToken(address(_erc20C));
        _bankForChainLink.addSupportToken(address(_erc20D));
        _bankForChainLink.addSupportToken(address(_erc20E));
    }

    function testCheckUpKeep_success() public {
        vm.startPrank(userWallet.addr);
        _erc20A.approve(address(_bankForChainLink), 100 * 1e18);
        _bankForChainLink.deposit(address(_erc20A), 100 * 1e18);
        _erc20B.approve(address(_bankForChainLink), 100 * 1e18);
        _bankForChainLink.deposit(address(_erc20B), 100 * 1e18);
        _erc20C.approve(address(_bankForChainLink), 100 * 1e18);
        _bankForChainLink.deposit(address(_erc20C), 100 * 1e18);
        _erc20D.approve(address(_bankForChainLink), 100 * 1e18);
        _bankForChainLink.deposit(address(_erc20D), 100 * 1e18);
        _erc20E.approve(address(_bankForChainLink), 80 * 1e18);
        _bankForChainLink.deposit(address(_erc20E), 80 * 1e18);
        vm.stopPrank();

        vm.startPrank(ownerWallet.addr);
        (bool upkeepNeeded, bytes memory performData) = _bankForChainLink.checkUpkeep(new bytes(0));
        assertEq(upkeepNeeded, true);
        _bankForChainLink.performUpkeep(performData);
        vm.stopPrank();

        // assert
        assertEq(_erc20A.balanceOf(ownerWallet.addr), 50 * 1e18);
        assertEq(_erc20A.balanceOf(address(_bankForChainLink)), 50 * 1e18);
        assertEq(_erc20B.balanceOf(ownerWallet.addr), 50 * 1e18);
        assertEq(_erc20B.balanceOf(address(_bankForChainLink)), 50 * 1e18);
        assertEq(_erc20C.balanceOf(ownerWallet.addr), 50 * 1e18);
        assertEq(_erc20C.balanceOf(address(_bankForChainLink)), 50 * 1e18);
        assertEq(_erc20D.balanceOf(ownerWallet.addr), 50 * 1e18);
        assertEq(_erc20D.balanceOf(address(_bankForChainLink)), 50 * 1e18);
        assertEq(_erc20E.balanceOf(ownerWallet.addr), 0);
        assertEq(_erc20E.balanceOf(address(_bankForChainLink)), 80 * 1e18);
    }
}
