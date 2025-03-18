// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/dex/MyDEX.sol";
import "@uniswapv2-solc0.8/contracts/UniswapV2Factory.sol";
import "@uniswapv2-solc0.8/contracts/UniswapV2Router.sol";
import "@uniswapv2-solc0.8/contracts/test/WETH9.sol";
import "@uniswapv2-solc0.8/contracts/test/ERC20.sol";

contract MyDEXTest is Test {
    MyDEX dex;
    UniswapV2Factory factory;
    WETH9 weth;
    UniswapV2Router router;
    ERC20 tokenA;
    ERC20 tokenB;

    //    address user = address(0x1234);
    address user = makeAddr("user1");

    function setUp() public {
        // 部署基础合约
        factory = new UniswapV2Factory(address(this));
        weth = new WETH9();
        router = new UniswapV2Router(address(factory), address(weth));
        dex = new MyDEX(address(factory), payable(address(weth)), payable(address(router)));
        // 部署测试代币（初始代币在 address(this)）
        tokenA = new ERC20(1e10 * 1e18);
        tokenB = new ERC20(1e10 * 1e18);

        // 给用户分配 ETH 和代币
        vm.deal(user, 100 ether);
        tokenA.transfer(user, 500 ether);
        tokenB.transfer(user, 500 ether);
    }

    function testCreatePair() public {
        vm.prank(user);
        dex.createPair(address(tokenA), address(tokenB));
        address pair = dex._factory().getPair(address(tokenA), address(tokenB));
        assertTrue(pair != address(0), "Pair creation failed");
    }

    function testAddLiquidity() public {
        vm.startPrank(user);
        dex.createPair(address(tokenA), address(tokenB));

        // 用户授权 MyDEX
        tokenA.approve(address(dex), 100 ether);
        tokenB.approve(address(dex), 100 ether);

        // 查看pair是否存在
        address checkPair = dex._factory().getPair(address(tokenA), address(tokenB));
        assertTrue(checkPair != address(0), "Pair not created before adding liquidity");

        // 添加流动性
        dex.addLiquidity(address(tokenA), address(tokenB), 100 ether, 100 ether, 0, 0, user, block.timestamp + 300);

        address pair = dex._factory().getPair(address(tokenA), address(tokenB));
        assertTrue(UniswapV2ERC20(pair).balanceOf(user) > 0, "Liquidity not added");
        vm.stopPrank();
    }

    function testSwapExactETHForTokens() public {
        vm.startPrank(user);
        dex.createPair(address(dex._weth()), address(tokenA));

        // 添加流动性
        dex._weth().deposit{value: 10 ether}();
        dex._weth().approve(address(dex), 100 ether);
        tokenA.approve(address(dex), 100 ether);

        dex.addLiquidity(
            address(dex._weth()), address(tokenA), 10 ether, 100 ether, 9 ether, 90 ether, user, block.timestamp + 300
        );

        // 构造 path
        address[] memory path = new address[](2);
        path[0] = address(dex._weth());
        path[1] = address(tokenA);

        // 执行 ETH -> TokenA 兑换
        // ETH -> WETH -> TokenA
        uint256 balanceBefore = tokenA.balanceOf(user);
        dex.swapExactETHForTokens{value: 1 ether}(0, path, user, block.timestamp + 300);
        uint256 balanceAfter = tokenA.balanceOf(user);
        assertTrue(balanceAfter > balanceBefore, "Swap ETH for tokens failed");
        vm.stopPrank();
    }

    function testSwapExactTokensForETH() public {
        vm.startPrank(user);
        dex.createPair(address(tokenA), address(dex._weth()));

        // 添加流动性
        dex._weth().deposit{value: 10 ether}();
        dex._weth().approve(address(dex), 100 ether);
        tokenA.approve(address(dex), 100 ether);
        dex.addLiquidity(
            address(tokenA), address(dex._weth()), 100 ether, 10 ether, 90 ether, 9 ether, user, block.timestamp + 300
        );

        // 授权并兑换
        tokenA.approve(address(dex), 10 ether);
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(dex._weth());

        uint256 ethBefore = user.balance;
        dex.swapExactTokensForETH(10 ether, 0, path, user, block.timestamp + 300);
        uint256 ethAfter = user.balance;
        assertTrue(ethAfter > ethBefore, "Swap tokens for ETH failed");
        vm.stopPrank();
    }

    function testSwapExactTokensForTokens() public {
        vm.startPrank(user);
        dex.createPair(address(tokenA), address(tokenB));

        // 添加流动性
        tokenA.approve(address(dex), 100 ether);
        tokenB.approve(address(dex), 100 ether);
        dex.addLiquidity(
            address(tokenA), address(tokenB), 100 ether, 100 ether, 90 ether, 90 ether, user, block.timestamp + 300
        );

        // 授权并兑换
        tokenA.approve(address(dex), 10 ether);
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);

        uint256 balanceBefore = tokenB.balanceOf(user);
        dex.swapExactTokensForTokens(10 ether, 0, path, user, block.timestamp + 300);
        uint256 balanceAfter = tokenB.balanceOf(user);
        console.log("before: ", balanceBefore);
        console.log("after: ", balanceAfter);
        assertTrue(balanceAfter > balanceBefore, "Swap tokens for tokens failed");
        vm.stopPrank();
    }
}
