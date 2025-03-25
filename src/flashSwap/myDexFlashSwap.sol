// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IUniswapV2Callee} from "@uniswapv2-solc0.8/contracts/interfaces/IUniswapV2Callee.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IUniswapV2Factory} from "@uniswapv2-solc0.8/contracts/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Pair} from "@uniswapv2-solc0.8/contracts/interfaces/IUniswapV2Pair.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MyDEX} from "../dex/MyDEX.sol";

// 假定场景
// 两个UniswapV2的DEX: dexA和dexB, 他们分别有一个TokenA/TokenB的池子
//  - pairA : pair: tokenA: 1e10 , tokenB: 1e10
//  - pairB : pair: tokenA: 1e10 , tokenB: 1e4
//
// flashSwap逻辑:
// 从pairB借出tokenA 数量1e8, 用tokenA买pairA的tokenB, 用tokenB还给pairB TokenB
// 剩余的Token是这次闪电贷的利润
contract MyDexFlashSwap is IUniswapV2Callee, Ownable {
    address public _owner;

    constructor() Ownable(msg.sender) {}

    // 假定场景
    // B 池子比例失衡
    function flashSwap(
        address pairA,
        address pairB,
        address tokenA,
        uint256 amountAOut,
        address tokenB,
        uint256 amountBOut
    ) external onlyOwner {
        // 1. 从pairB借出tokenA
        // 借出 999000 TokenA 剩余 1000 TokenA
        // 保持K不变需要还 amountBIn的 TokenB需要使用uint256 amountOut, uint256 reserveIn, uint256 reserveOut, bool tokenOutIs1计算
        //        bytes memory hookCallData = abi.encode(tokenA, tokenB, pairA);
        //        IUniswapV2Pair(pairB).swap(amountAOut, amountBOut, address(this), hookCallData);
        // 2. 去pairA买tokenB在Hook uniswapV2Call中
        // 3. 用tokenB还pairB的tokenA, 归还必须在Hook uniswapV2Call中, uniswapV2Call执行完毕, swap退出前会检查K值

        // fixed
        // 因为 token0 token1 是根据地址字典序比较后动态分配的，并不是crate pair时候传入的
        // 所以这里也动态调整一下
        bytes memory hookCallData = abi.encode(pairA);
        address token0 = IUniswapV2Pair(pairB).token0();
        address token1 = IUniswapV2Pair(pairB).token1();

        // 动态分配 amount0Out 和 amount1Out
        // 如果 顺序和传入token顺序一致则 amountAOut就是token0 对应的amount0Out
        // 否则，顺序不一致 token0是tokenB, amountBOut时token0对应的amount0Out
        // tokenA是token0的话
        // tokenA 和 amountAOut放第一组
        uint256 amount0Out = (tokenA == token0) ? amountAOut : (tokenB == token0 ? amountBOut : 0);
        //        uint256 amount0Out = (tokenA == token0) ? amountAOut : 0;

        // 同上
        uint256 amount1Out = (tokenA == token1) ? amountAOut : (tokenB == token1 ? amountBOut : 0);
        //        uint256 amount1Out = (tokenA == token0) ? 0 : amountAOut;
        //        uint256 amount1Out = (tokenB == token0) ? amountAOut : 0;
        IUniswapV2Pair(pairB).swap(amount0Out, amount1Out, address(this), hookCallData);
    }

    // sender flashSwap合约地址
    function uniswapV2Call(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external override {
        require(sender == address(this), "Invalid sender");
        // 解析参数
        address pairA = abi.decode(data, (address));
        address pairB = msg.sender; // PoolB 调用此函数

        // TODO: 这里传递过来的数据有 amount0Out, amount1Out, 对应的时token0, 和 token1
        // 假设都是uniswap pair, 那么 token0 和 token1顺序一致
        // 暂不考虑：假设不是uniswap pair, 那么 token0 和 token1 顺序无法确定
        address token0 = IUniswapV2Pair(pairA).token0();
        address token1 = IUniswapV2Pair(pairA).token1();

        // 计算借入的量
        uint256 amountBorrowed = amount0 > 0 ? amount0 : amount1;
        //        // 确认是借的哪个token
        //        // 只有一个 > 0
        //        // 如果 > 0, amountBorrowed 为 token0, tokenA
        //        address tokenA = amount0 > 0 ? token0 : token1;
        //        // tokenB is token 1
        //        // 如果 > 0 amountBorrowed 为 token1， tokenA
        //        address tokenB = amount1 > 0 ? token0 : token1;
        //
        // // 2. 去pairA换tokenB
        // 在 pairA 用 tokenA 换 tokenB
        // 使用全部借入的 tokenA
        address borrowedToken;
        address unBorrowedToken;
        {
            // 只使用amount0 amount1有一个为0的情况
            if (amount0 > amount1) {
                // 如果amount0
                borrowedToken = token0;
                unBorrowedToken = token1;
            } else {
                borrowedToken = token1;
                unBorrowedToken = token0;
            }
            // 刚借到钱时余额
            // 999999000000000000000000000000 [9.999e29]
            IERC20(borrowedToken).balanceOf(address(this));
            // 0
            IERC20(unBorrowedToken).balanceOf(address(this));
            // 从 poolB 借出来 tokenAAmount
            //            uint256 amountToSwap = amountBorrowed;
            // 在PoolA中全部兑换成 tokenB
            IERC20(borrowedToken).transfer(pairA, amountBorrowed);

            (uint112 reserve0A, uint112 reserve1A,) = IUniswapV2Pair(pairA).getReserves();
            bool tokenAIs0 = borrowedToken == IUniswapV2Pair(pairA).token0();
            // 如果 borrowed 是token0, 第一个参数是token0 的储备
            uint256 reserve0In = tokenAIs0 ? reserve0A : reserve1A;
            // 如果 borrowed 是 token0, 第二个参数是 token1 的储备
            uint256 reserve1In = tokenAIs0 ? reserve1A : reserve0A;
            uint256 amountOut = getAmountOut(amountBorrowed, reserve0In, reserve1In);

            // 如果 borrowed是 token0, amount0Out就为0
            uint256 amount0Out = borrowedToken == IUniswapV2Pair(pairA).token0() ? 0 : amountOut;
            // 如果 borrowed是 token1, amount1Out就为0
            uint256 amount1Out = borrowedToken == IUniswapV2Pair(pairA).token1() ? 0 : amountOut;
            IUniswapV2Pair(pairA).swap(amount0Out, amount1Out, address(this), new bytes(0));

            // 借到的钱全部兑换后的余额
            // 0
            IERC20(borrowedToken).balanceOf(address(this));
            // 999998996990975936837584 [9.999e23]
            IERC20(unBorrowedToken).balanceOf(address(this));
        }

        // 计算归还 pairB 的 tokenB 数量
        {
            // 借tokenA还tokenB
            (uint112 reserve0B, uint112 reserve1B,) = IUniswapV2Pair(pairB).getReserves();
            bool tokenIs0 = borrowedToken == IUniswapV2Pair(pairB).token0();
            // 如果时borrowedToken, 则第一个放token1
            uint256 reserve0In = tokenIs0 ? reserve0B : reserve1B;
            // 如果是borrowedToken, 则第二个放token0
            uint256 reserve1In = tokenIs0 ? reserve1B : reserve0B;
            // borrowed = 1e8
            uint256 amountIn = getAmountIn(amountBorrowed, reserve0In, reserve1In);

            require(IERC20(unBorrowedToken).balanceOf(address(this)) >= amountIn, "Insufficient profit");
            // FIXME: 999998996990975936837584 [9.999e23]
            // 为什么不够还
            // already fixed
            IERC20(unBorrowedToken).transfer(pairB, amountIn);
        }

        // 最后剩余
        // 借到的钱全部兑换后的余额
        // 0
        IERC20(borrowedToken).balanceOf(address(this));
        // 999998996990975936837584 [9.999e23]
        IERC20(unBorrowedToken).balanceOf(address(this));
        require(IERC20(unBorrowedToken).balanceOf(address(this)) != 0, "!!!!");

        // 利润：剩余的 tokenB
        uint256 profit = IERC20(unBorrowedToken).balanceOf(address(this));
        if (profit > 0) {
            IERC20(unBorrowedToken).transfer(owner(), profit);
        }
    }

    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    /*
    公式推导
    还款为token0, 借款为token1

    (reserve0In * 1000 + amountIn * 997) * (reserve1In - amountOut) = reserve0In * reserve1In * 1000
    (reserve1In - amountOut) = (reserve0In * reserve1In * 1000) / (reserve0In * 1000 + amountIn * 997)
    reserve1In - (reserve0In * reserve1In * 1000) / (reserve0In * 1000 + amountIn * 997) = amountOut
    amountOut = [reserve1In * (reserve0In * 1000 + amountIn * 997) - (reserve0In * reserve1In * 1000)] / (reserve0In * 1000 + amountIn * 997)
    amountOut = (reserve1In * amountIn * 997) / (reserve0In * 1000 + amountIn * 997)
    */
    function getAmountOut(uint256 amountIn, uint256 reserve0In, uint256 reserve1In)
        internal
        pure
        returns (uint256 amountOut)
    {
        require(amountIn > 0, "UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT");
        require(reserve0In > 0 && reserve1In > 0, "UniswapV2Library: INSUFFICIENT_LIQUIDITY");
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserve1In;
        uint256 denominator = reserve0In * 1000 + amountInWithFee;
        amountOut = numerator / denominator;
    }

    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    /*
    公式推导：
    amountOut为token0, 还款时只还token1

    (reserve0In - amountOut) * (reserve1In + amountIn) = reserve0In * reserve1In
    (reserve1In + amountIn) = (reserve0In * reserve1In) / (reserve0In - amountOut)
    amountIn = (reserve0In * reserve1In) / (reserve0In - amountOut) - reserve1In
    amountIn = [(reserve0In * reserve1In) - (reserve0In - amountOut) * reserve1In] /  (reserve0In - amountOut)
    amountIn = (reserve1In * amountOut) / (reserve0In - amount)

    此时 amountIn 为扣除千三手续费之后的amountIn, 实际支付应为 amountIn * 1000 / 997
    即：amountIn = (reserve1In * amountOut * 1000) / (reserve0In - amount) * 997
    支付时应 + 1， 防止精度确实，验证不通过
    */
    function getAmountIn(uint256 amountOut, uint256 reserve0In, uint256 reserve1In)
        internal
        pure
        returns (uint256 amountIn)
    {
        require(amountOut > 0, "UniswapV2Library: INSUFFICIENT_OUTPUT_AMOUNT");
        require(reserve0In > 0 && reserve1In > 0, "UniswapV2Library: INSUFFICIENT_LIQUIDITY");
        //        uint256 numerator = reserve0In * amountOut * 1000;
        uint256 numerator = reserve1In * amountOut * 1000;

        //        uint256 denominator = (reserve1In - amountOut) * 997;
        uint256 denominator = (reserve0In - amountOut) * 997;
        amountIn = numerator / denominator + 1;
    }

    // 提取合约中的资金
    function withdraw(address token) external onlyOwner {
        uint256 balance = IERC20(token).balanceOf(address(this));
        IERC20(token).transfer(owner(), balance);
    }

    receive() external payable {}
}
