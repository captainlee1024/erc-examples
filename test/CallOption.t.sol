// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Vm.sol";
import {Test, console} from "forge-std/Test.sol";
import {MyDexFlashSwap} from "../src/flashswap/MyDexFlashSwap.sol";
import {CallOptionFactory} from "../src/optionContracts/OptionFactory.sol";
import {CallOptionToken} from "../src/optionContracts/OptionFactory.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {TToken} from "../src/TerryToken.sol";

contract CallOptionTest is Test {
    Vm.Wallet _optionFactoryOwner;
    CallOptionFactory _factory;

    CallOptionToken _optionToken;

    Vm.Wallet _usdcOwner;
    address _USDC;

    Vm.Wallet _user1;
    Vm.Wallet _user2;
    uint256 _user2InitUSDC = 100000 * 1e18;
    Vm.Wallet _user3;
    uint256 _user3InitUSDC = 100000 * 1e18;

    function setUp() public {
        _user1 = vm.createWallet("_user1");
        _user2 = vm.createWallet("_user2");
        _user3 = vm.createWallet("_user3");

        vm.deal(_user1.addr, 10 ether);

        _optionFactoryOwner = vm.createWallet("_optionFactoryOwner");

        vm.startPrank(_optionFactoryOwner.addr);
        _factory = new CallOptionFactory();
        vm.stopPrank();

        _usdcOwner = vm.createWallet("_usdcOwner");
        vm.startPrank(_usdcOwner.addr);
        _USDC = address(new TToken("USDCToken", "USDC"));
        IERC20(_USDC).transfer(_user2.addr, _user2InitUSDC);
        IERC20(_USDC).transfer(_user3.addr, _user3InitUSDC);
        vm.stopPrank();
    }

    function test_createOption_success() public {
        vm.startPrank(_user1.addr);
        uint256 optionId = _factory.createOption{value: 10 ether}(
            3000 * 1e18, block.timestamp + 1000, _USDC, "CallETHOptionToken", "CEOToken"
        );
        vm.stopPrank();
        CallOptionFactory.OptionInfo memory optioninfo = _factory.getOptionInfo(optionId);
        assertEq(_user1.addr, optioninfo.issuer);
        assertEq(3000 * 1e18, optioninfo.strikePrice);
        assertEq(block.timestamp + 1000, optioninfo.expiryDate);
        assertEq(10 ether, optioninfo.totalUnderlying);
    }

    function test_exerciseAndexpireAndRedeem_success() public {
        // user1 创建期权
        // 标的 ETH, 行权价格是 3000U
        vm.startPrank(_user1.addr);
        // uint256 optionId = _factory.createOption{value: 10 ether}(
        //     3000 * 1e18, block.timestamp + 1000, _USDC, "CallETHOptionToken", "CEOToken"
        // );
        uint256 optionId = _factory.createOption{value: 10 ether}(
            3000, block.timestamp + 1000, _USDC, "CallETHOptionToken", "CEOToken"
        );
        vm.stopPrank();
        CallOptionFactory.OptionInfo memory optioninfo = _factory.getOptionInfo(optionId);
        _optionToken = CallOptionToken(payable(optioninfo.tokenAddress));

        // 用户1 买 1ETH对应的期权
        // 1个eth的期权售价 1000U
        vm.prank(_user2.addr);
        IERC20(_USDC).transfer(_user1.addr, 100 * 1e18);
        assertEq(IERC20(_USDC).balanceOf(_user1.addr), 100 * 1e18);
        assertEq(IERC20(_USDC).balanceOf(_user2.addr), _user2InitUSDC - 100 * 1e18);

        // 收到钱转移期权
        vm.prank(_user1.addr);
        bool result1 = _optionToken.transfer(_user2.addr, 100 * 1e18);
        assertEq(true, result1);

        // 用户2买 4ETH对应的期权
        // 4个eth的期权售价 4000U
        vm.prank(_user3.addr);
        IERC20(_USDC).transfer(_user1.addr, 4 * 100 * 1e18);
        assertEq(IERC20(_USDC).balanceOf(_user1.addr), 500 * 1e18);
        assertEq(IERC20(_USDC).balanceOf(_user3.addr), _user3InitUSDC - 400 * 1e18);

        // 收到钱转移期权
        vm.prank(_user1.addr);
        bool result2 = _optionToken.transfer(_user3.addr, 4 * 100 * 1e18);
        assertEq(true, result2);

        vm.warp(block.timestamp + 10001);

        // 行权
        // approve 购买期权标的 1 ETH的U, 按照行权价格 3000
        vm.startPrank(_user2.addr);
        IERC20(_USDC).approve(address(_optionToken), 3000 * 1e18);
        _optionToken.balanceOf(_user2.addr);
        _optionToken.exercise();

        assertEq(IERC20(_USDC).balanceOf(_user1.addr), 3500 * 1e18);
        assertEq(IERC20(_USDC).balanceOf(_user2.addr), _user3InitUSDC - 3100 * 1e18);
        assertEq(_user2.addr.balance, 1 * 1e18);
        vm.stopPrank();

        vm.startPrank(_user3.addr);
        // 行权
        // approve 购买期权标的 1 ETH的U, 按照行权价格 3000
        // IERC20(_USDC).balanceOf(_user3.addr);
        IERC20(_USDC).approve(address(_optionToken), 4 * 3000 * 1e18);
        _optionToken.exercise();

        assertEq(IERC20(_USDC).balanceOf(_user1.addr), 15500 * 1e18);
        assertEq(IERC20(_USDC).balanceOf(_user3.addr), _user3InitUSDC - (4 * 3000 * 1e18 + 400 * 1e18));
        assertEq(_user3.addr.balance, 4 * 1e18);
        vm.stopPrank();

        // 剩余 5 eth 可以过期回收
        vm.startPrank(_user1.addr);
        _optionToken.balanceOf(_user1.addr);
        _optionToken._underlyingAmount();
        _optionToken.expireAndRedeem();

        assertEq(IERC20(_USDC).balanceOf(_user1.addr), 15500 * 1e18);
        assertEq(_user1.addr.balance, 5 ether);
        vm.stopPrank();
    }
}
