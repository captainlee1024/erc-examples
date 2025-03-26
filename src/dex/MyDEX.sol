// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {UniswapV2ERC20} from "@uniswapv2-solc0.8/contracts/UniswapV2ERC20.sol";
import {UniswapV2Factory} from "@uniswapv2-solc0.8/contracts/UniswapV2Factory.sol";
import {UniswapV2Router} from "@uniswapv2-solc0.8/contracts/UniswapV2Router.sol";
import {WETH9} from "@uniswapv2-solc0.8/contracts/test/WETH9.sol";

contract MyDEX {
    UniswapV2Factory public _factory;
    WETH9 public _weth;
    UniswapV2Router public _router;

    constructor(address factory_, address payable weth_, address payable router_) {
        _factory = UniswapV2Factory(factory_);
        _weth = WETH9(weth_);
        _router = UniswapV2Router(router_);
    }

    function createPair(address tokenA, address tokenB) external {
        address pair = _factory.createPair(tokenA, tokenB);
        require(pair != address(0), "MyDEX: PAIR_CREATION_FAILED");
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external {
        // 用户approve后，这里先transfer到DEX
        UniswapV2ERC20(tokenA).transferFrom(msg.sender, address(this), amountADesired);
        UniswapV2ERC20(tokenB).transferFrom(msg.sender, address(this), amountBDesired);

        UniswapV2ERC20(tokenA).approve(address(_router), amountADesired);
        UniswapV2ERC20(tokenB).approve(address(_router), amountBDesired);
        _router.addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin, to, deadline);
    }

    function swapExactETHForTokens(uint256 amountOutMin, address[] calldata path, address to, uint256 deadline)
        external
        payable
    {
        // 确保路径以 WETH 开始
        require(path[0] == address(_weth), "MyDEX: INVALID_PATH");
        _router.swapExactETHForTokens{value: msg.value}(amountOutMin, path, to, deadline);
    }

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external {
        // TODO: path 这里默认是 token -> WETH 只有一个
        UniswapV2ERC20(path[0]).transferFrom(msg.sender, address(this), amountIn);
        UniswapV2ERC20(path[0]).approve(address(_router), amountIn);
        _router.swapExactTokensForETH(amountIn, amountOutMin, path, to, deadline);
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external {
        // TODO: 这里目前之有一个 token -> token 的路径，只有一个池子
        UniswapV2ERC20(path[0]).transferFrom(msg.sender, address(this), amountIn);
        UniswapV2ERC20(path[0]).approve(address(_router), amountIn);
        _router.swapExactTokensForTokens(amountIn, amountOutMin, path, to, deadline);
    }
}
