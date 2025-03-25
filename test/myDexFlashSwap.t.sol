// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Vm.sol";
import {Test, console} from "forge-std/Test.sol";
import {MyDexFlashSwap} from "../src/flashSwap/MyDexFlashSwap.sol";
import {MyDEX} from "../src/dex/MyDEX.sol";
import "@uniswapv2-solc0.8/contracts/UniswapV2Factory.sol";
import "@uniswapv2-solc0.8/contracts/UniswapV2Router.sol";
import "@uniswapv2-solc0.8/contracts/test/WETH9.sol";
import "@uniswapv2-solc0.8/contracts/test/ERC20.sol";
import {TokenA, TokenB} from "./flashSwapToken.sol";

contract MyDexFlashSwapTest is Test {
    MyDEX public dexA;
    UniswapV2Factory public dexAFactory;
    UniswapV2Router public dexARouter;
    address public pairA;
    Vm.Wallet public dexAOwner;

    MyDEX public dexB;
    UniswapV2Factory public dexBFactory;
    UniswapV2Router public dexBRouter;
    address public pairB;
    Vm.Wallet public dexBOwner;

    TokenA public tokenA;
    Vm.Wallet public tokenAOwner;

    TokenB public tokenB;
    Vm.Wallet public tokenBOwner;

    WETH9 public weth;
    Vm.Wallet public wethOwner;

    MyDexFlashSwap public flashSwap;
    Vm.Wallet public flashSwapOwner;

    function setUp() public {
        wethOwner = vm.createWallet("wethOwner");
        vm.prank(wethOwner.addr);
        weth = new WETH9();

        {
            // 初始化 交易所A
            dexAOwner = vm.createWallet("dexAOwner");
            vm.startPrank(dexAOwner.addr);
            dexAFactory = new UniswapV2Factory(dexAOwner.addr);
            dexARouter = new UniswapV2Router(address(dexAFactory), address(weth));
            dexA = new MyDEX(address(dexAFactory), payable(address(weth)), payable(address(dexARouter)));
            vm.stopPrank();

            // 初始化交易所B
            dexBOwner = vm.createWallet("dexBOwner");
            vm.startPrank(dexBOwner.addr);
            dexBFactory = new UniswapV2Factory(dexBOwner.addr);
            dexBRouter = new UniswapV2Router(address(dexBFactory), address(weth));
            dexB = new MyDEX(address(dexBFactory), payable(address(weth)), payable(address(dexBRouter)));
            vm.stopPrank();

            // 初始化TokenA
            tokenAOwner = vm.createWallet("tokenAOwner");
            tokenBOwner = vm.createWallet("tokenBOwner");

            vm.startPrank(tokenAOwner.addr);
            tokenA = new TokenA(2e14 * 1e18);
            tokenA.transfer(tokenBOwner.addr, 1e14 * 1e18);
            vm.stopPrank();

            // 初始化TokenB
            vm.startPrank(tokenBOwner.addr);
            tokenB = new TokenB(2e14 * 1e18);
            tokenB.transfer(tokenAOwner.addr, 1e14 * 1e18);
            vm.stopPrank();

            // 初始化闪电贷合约
            flashSwapOwner = vm.createWallet("flashSwapOwner");
            vm.prank(flashSwapOwner.addr);
            flashSwap = new MyDexFlashSwap();
        }

        {
            // 初始化dexA的PairA池子
            vm.startPrank(tokenAOwner.addr);
            dexA.createPair(address(tokenA), address(tokenB));

            // 用户授权 MyDEX
            tokenA.approve(address(dexA), 1e10);
            tokenB.approve(address(dexA), 1e10);

            // 查看pair是否存在
            address checkPair_a = dexA._factory().getPair(address(tokenA), address(tokenB));
            assertTrue(checkPair_a != address(0), "Pair not created before adding liquidity");
            pairA = checkPair_a;

            // 添加流动性
            dexA.addLiquidity(
                address(tokenA), address(tokenB), 1e10, 1e10, 0, 0, tokenAOwner.addr, block.timestamp + 300
            );

            address pair_a = dexA._factory().getPair(address(tokenA), address(tokenB));
            assertTrue(UniswapV2ERC20(pair_a).balanceOf(tokenAOwner.addr) > 0, "Liquidity not added");
            vm.stopPrank();
        }

        // 初始化dexB的PariB池子
        {
            vm.startPrank(tokenBOwner.addr);
            dexB.createPair(address(tokenA), address(tokenB));

            // 用户授权 MyDEX
            tokenA.approve(address(dexB), 1e10);
            tokenB.approve(address(dexB), 1e4);

            // 查看pair是否存在
            address checkPair_b = dexB._factory().getPair(address(tokenA), address(tokenB));
            assertTrue(checkPair_b != address(0), "Pair not created before adding liquidity");
            pairB = checkPair_b;

            // 添加流动性
            dexB.addLiquidity(
                address(tokenA), address(tokenB), 1e10, 1e4, 0, 0, tokenBOwner.addr, block.timestamp + 300
            );

            address pair_b = dexB._factory().getPair(address(tokenA), address(tokenB));
            assertTrue(UniswapV2ERC20(pair_b).balanceOf(tokenBOwner.addr) > 0, "Liquidity not added");
            vm.stopPrank();
        }
    }

    function testFlashSwap() public {
        // 记录初始余额：
        // 发起闪电贷套利的user的余额
        // 这里都为0
        console.log("====================");
        console.log("user before tokenA: ", tokenA.balanceOf(address(flashSwapOwner.addr)));
        console.log("user before tokenB:", tokenB.balanceOf(address(flashSwapOwner.addr)));

        // PoolA初始余额
        console.log("PoolA before tokenA: ", tokenA.balanceOf(address(pairA)));
        console.log("PoolA before tokenB: ", tokenB.balanceOf(address(pairA)));

        // PoolB 初始余额
        console.log("PoolB before tokenA: ", tokenA.balanceOf(address(pairB)));
        console.log("PoolB before tokenB: ", tokenB.balanceOf(address(pairB)));
        uint256 totalTokenABefore = tokenA.balanceOf(address(flashSwapOwner.addr)) + tokenA.balanceOf(address(pairA))
            + tokenA.balanceOf(address(pairB));
        uint256 totalTokenBBefore = tokenB.balanceOf(address(flashSwapOwner.addr)) + tokenB.balanceOf(address(pairA))
            + tokenB.balanceOf(address(pairB));
        console.log("total tokenA:", totalTokenABefore);
        console.log("total tokenB:", totalTokenBBefore);

        vm.startPrank(flashSwapOwner.addr);
        // 执行闪电贷
        flashSwap.flashSwap(
            pairA,
            pairB,
            address(tokenA),
            1e8, // 从 pariB 借 999,000 tokenA
            address(tokenB),
            0
        );

        // 记录闪电贷之后的个方余额
        console.log("====================");

        // user ：
        // PoolB借出 1e8 tokenA
        // 去PoolA全部兑换成TokenB
        // 归还一定数量的TokenB会PoolB
        // 最终TokenA 为0， TokenB 的余额为本次收益
        console.log("user after tokenA: ", tokenA.balanceOf(address(flashSwapOwner.addr)));
        console.log("user after tokenA: ", tokenB.balanceOf(address(flashSwapOwner.addr)));

        // PoolA的余额
        console.log("PoolA after tokenA: ", tokenA.balanceOf(address(pairA)));
        console.log("PoolA after tokenA: ", tokenB.balanceOf(address(pairA)));

        // PoolB的余额
        console.log("PoolB after tokenA: ", tokenA.balanceOf(address(pairB)));
        console.log("PoolB after tokenA: ", tokenB.balanceOf(address(pairB)));
        uint256 totalTokenAAfter = tokenA.balanceOf(address(flashSwapOwner.addr)) + tokenA.balanceOf(address(pairA))
            + tokenA.balanceOf(address(pairB));
        uint256 totalTokenBAfter = tokenB.balanceOf(address(flashSwapOwner.addr)) + tokenB.balanceOf(address(pairA))
            + tokenB.balanceOf(address(pairB));
        console.log("total tokenA:", totalTokenAAfter);
        console.log("total tokenB:", totalTokenBAfter);

        // 最终套利前和套利后的 套利用户和两个池子的代币总量也应该保持一致
        // 套利过程中的手续费在池子中，总量不变
        assertEq(totalTokenAAfter, totalTokenABefore);
        assertEq(totalTokenBAfter, totalTokenBBefore);
        vm.stopPrank();
    }
}
