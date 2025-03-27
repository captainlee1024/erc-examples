// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "../src/dex/SimpleLeverageDEX.sol";
import {TToken} from "../src/TerryToken.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SimpleLeverageDEXTest is Test {
    Vm.Wallet _usdcOwner;
    IERC20 _usdc;
    Vm.Wallet _dexOwner;
    SimpleLeverageDEX _simpleLeverageDex;

    Vm.Wallet _user1;
    Vm.Wallet _user2;
    Vm.Wallet _user3;

    function setUp() public {
        _user1 = vm.createWallet("user1");
        _user2 = vm.createWallet("user2");
        _user3 = vm.createWallet("user3");

        _usdcOwner = vm.createWallet("usdcOwner");
        _dexOwner = vm.createWallet("dexOwner");

        vm.startPrank(_usdcOwner.addr);
        _usdc = IERC20(new TToken("USECToken", "USDC"));
        _usdc.transfer(_user1.addr, 100);
        _usdc.transfer(_user2.addr, 10000);
        _usdc.transfer(_user3.addr, 1000000);
        vm.stopPrank();

        vm.startPrank(_dexOwner.addr);
        // eth: 10
        // usdc: 10000
        // k: 100_000
        _simpleLeverageDex = new SimpleLeverageDEX(100, 1000, address(_usdc));
        vm.stopPrank();
    }

    function test_openPosition_success() public {
        vm.startPrank(_user1.addr);
        _usdc.approve(address(_simpleLeverageDex), 10);
        _simpleLeverageDex.openPosition(10, 10, true);
        (uint256 margin, uint256 borrowed, uint256 position, bool isLong) = _simpleLeverageDex.positions(_user1.addr);
        assertEq(margin, 10);
        assertEq(borrowed, 90);
        // position = 100 - (10000 / (1000 + 100) = 100 - (10000 / 1100) = 110000 - 10000 / 1100 = 10000 / 1100 = 100/11
        // position = 100 -
        // assertEq(position, uint256(100 / 11));
        assertEq(isLong, true);

        console.log("user margin: ", margin);
        console.log("user borrowed: ", borrowed);
        console.log("user position: ", position);
        console.log("user isLong: ", isLong);
        vm.stopPrank();
    }

    function test_closePosition_success() public {
        vm.startPrank(_user1.addr);
        _usdc.approve(address(_simpleLeverageDex), 10);
        _simpleLeverageDex.openPosition(10, 2, true);
        (uint256 margin, uint256 borrowed, uint256 position, bool isLong) = _simpleLeverageDex.positions(_user1.addr);
        assertEq(margin, 10);
        assertEq(borrowed, 10);
        // position = 100 - (10000 / (1000 + 100) = 100 - (10000 / 1100) = 110000 - 10000 / 1100 = 10000 / 1100 = 100/11
        // position = 100 -
        // assertEq(position, uint256(100 / 11));
        assertEq(isLong, true);

        console.log("user1 margin: ", margin);
        console.log("user1 borrowed: ", borrowed);
        console.log("user1 position: ", position);
        console.log("user1 isLong: ", isLong);
        vm.stopPrank();

        vm.startPrank(_user2.addr);
        _usdc.approve(address(_simpleLeverageDex), 100);
        _simpleLeverageDex.openPosition(10, 10, true);
        (uint256 marginUser2, uint256 borrowedUser2, uint256 positionUser2, bool isLongUser2) =
            _simpleLeverageDex.positions(_user2.addr);
        console.log("user2 margin: ", marginUser2);
        console.log("user2 borrowed: ", borrowedUser2);
        console.log("user2 position: ", positionUser2);
        console.log("user2 isLong: ", isLongUser2);
        vm.stopPrank();

        vm.startPrank(_user1.addr);
        int256 user1Pnl = _simpleLeverageDex.calculatePnL(_user1.addr);
        console.log("user 1 Pnl: ", user1Pnl);
        _simpleLeverageDex.closePosition();
        uint256 user1Balance = _usdc.balanceOf(_user1.addr);
        console.log("user 1 balance: ", user1Balance);
        assertEq(user1Pnl, int256(user1Balance - 100));
        vm.stopPrank();
    }

    function test_liquidatePosition_success() public {
        vm.startPrank(_user1.addr);
        _usdc.approve(address(_simpleLeverageDex), 10);
        _simpleLeverageDex.openPosition(10, 10, true);
        (uint256 margin, uint256 borrowed, uint256 position, bool isLong) = _simpleLeverageDex.positions(_user1.addr);
        assertEq(margin, 10);
        assertEq(borrowed, 90);
        // position = 100 - (10000 / (1000 + 100) = 100 - (10000 / 1100) = 110000 - 10000 / 1100 = 10000 / 1100 = 100/11
        // position = 100 -
        // assertEq(position, uint256(100 / 11));
        assertEq(isLong, true);

        console.log("user1 margin: ", margin);
        console.log("user1 borrowed: ", borrowed);
        console.log("user1 position: ", position);
        console.log("user1 isLong: ", isLong);
        vm.stopPrank();

        vm.startPrank(_user2.addr);
        _usdc.approve(address(_simpleLeverageDex), 100);
        // 做空 10 10倍杠杆
        // eth已经被做多拉上去了，此时同样的本金，同样的杠杆去做空就会盈利，前一个做多就会有损失
        _simpleLeverageDex.openPosition(10, 10, false);
        (uint256 marginUser2, uint256 borrowedUser2, uint256 positionUser2, bool isLongUser2) =
            _simpleLeverageDex.positions(_user2.addr);
        console.log("user2 margin: ", marginUser2);
        console.log("user2 borrowed: ", borrowedUser2);
        console.log("user2 position: ", positionUser2);
        console.log("user2 isLong: ", isLongUser2);
        vm.stopPrank();

        vm.startPrank(_user3.addr);
        int256 user1Pnl = _simpleLeverageDex.calculatePnL(_user1.addr);
        console.log("user 1 Pnl: ", user1Pnl);
        _simpleLeverageDex.liquidatePosition(_user1.addr);
        uint256 user3Balance = _usdc.balanceOf(_user3.addr);
        // 10 是user1的本金
        int256 user3Pnl = 10 + user1Pnl;
        console.log("user 3 Pnl: ", user3Pnl);
        console.log("user 3 balance: ", user3Balance);
        assertEq(user3Pnl, int256(user3Balance - 1000000));
        vm.stopPrank();
    }
}
