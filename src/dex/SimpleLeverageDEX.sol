// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// 极简的杠杆 DEX 实现
contract SimpleLeverageDEX {
    uint256 public vK; // 100000
    uint256 public vETHAmount;
    uint256 public vUSDCAmount;

    IERC20 public USDC; // 自己创建一个币来模拟 USDC

    /// 用户持仓信息
    struct PositionInfo {
        uint256 margin; // 保证金    // 真实的资金， 如 USDC
        uint256 borrowed; // 借入的资金
        // 持仓, 即我们持有多少个eth
        // 无论是做空还是做多持仓都是eth
        // 对应的放入eth和买入eth，这个数量都是持仓
        uint256 position; // 虚拟 eth 持仓
        // 表示做多还是做空
        bool isLong;
    }

    mapping(address => PositionInfo) public positions;

    event GetAmountOut(uint256 indexed out);

    constructor(uint256 vEth, uint256 vUSDC, address USDC_) {
        // 10
        vETHAmount = vEth;

        // 10000
        vUSDCAmount = vUSDC;

        // k = 1_00_000
        vK = vEth * vUSDC;

        USDC = IERC20(USDC_);
    }

    /// 开启杠杆头寸
    /// _margin: 保证金, 本金
    /// level: 杠杆倍数
    /// long: 做空 or 做多
    function openPosition(uint256 _margin, uint256 level, bool long) external {
        require(positions[msg.sender].position == 0, "Position already open");

        PositionInfo storage pos = positions[msg.sender];

        // 转入本金
        bool result = USDC.transferFrom(msg.sender, address(this), _margin); // 用户提供保证金
        require(result, "open position failed, transferFrom failed");

        //
        uint256 amount = _margin * level;
        // 借款
        uint256 borrowAmount = amount - _margin;

        // 保证金
        pos.margin = _margin;
        // 借款
        pos.borrowed = borrowAmount;

        if (long) {
            // 做多ETH, 那么就是看涨, 放入u 提 eth
            // 放入 amount的u, swap到对应的eth
            // 持仓数据就是这个eth
            pos.position = swapByIn(amount, false);
            pos.isLong = true;
        } else {
            // 做空eth, 看跌eth, 就放入eth, 提前换u
            // 也可以看作是, 做多u, 放入eth, 提u
            //
            // NOTE: 此时我们只有U, 没有eth
            // 此时的计算方式是，按照我们有eth来看，那么此时我们的u就是放入eth之后取出的u
            // 按照这种方式模拟我们放入了多少eth兑换了这么多u
            // 这个eth就是我们的做空持仓
            //
            // 此时的场景是：
            // 借 eth, 卖出，获得到amount的U
            //
            // 平仓：
            // 平仓时要把卖出的Eth都买回来
            //  - 此时我们从Pool中获取持仓数量的ETH，ethOut确定，计算出amountIn
            //    如果amountIn > 我们开仓时的_margin * level, 则我们是亏损的
            //    如果 amountIn - _margin*level = _margin, 则我们的本金刚好亏损完
            //    - 盈利时：
            //      此时，我们开仓时的_margin*level > amountIn, 我们可以提走 _margin + (_margin*level - amountIn)
            //    - 亏损时：我们平仓时_margin*level < amountIn, 并且 _margin*level + _margin < amountIn,
            //      此时我们需要把开仓时卖eth获取的 _margin*level 打进池子，并且再打入(amountIn - _margin*level)的本金
            //      剩余的_margin - (amountIn - _margin*level) 即 margin*(level + 1) - amountIn就是用户亏损后的余额
            //      清算逻辑同平仓逻辑，多一步检查，是否达到清算阈值
            //
            //
            // 清算：
            // 如果没有任何人介入，本金亏损完之后，接下来亏损的就是杠杆合约项目方的钱
            // 所以一般会在保证金亏损一部分之后, 比如保证金亏损50%时，便支持任何人来清算
            // 清算可以获得剩余还未亏损的保证金
            // 提U 放eth
            // pos.position = swapByOut(amount, true);
            pos.position = swapByOut(amount, false);
            pos.isLong = false;
        }
    }

    function swapByIn(uint256 amountIn, bool isEth) internal returns (uint256) {
        require(amountIn > 0, "invalid amountIn");
        uint256 reserve0;
        uint256 reserve1;

        if (isEth) {
            reserve0 = vETHAmount;
            reserve1 = vUSDCAmount;
        } else {
            reserve0 = vUSDCAmount;
            reserve1 = vETHAmount;
        }

        uint256 amountOut = getAmountOut(amountIn, reserve0, reserve1);
        emit GetAmountOut(amountOut);

        if (isEth) {
            vETHAmount += amountIn;
            vUSDCAmount -= amountOut;
        } else {
            vUSDCAmount += amountIn;
            vETHAmount -= amountOut;
        }

        return amountOut;
    }

    function getAmountOut(uint256 amountIn, uint256 reserve0, uint256 reserve1) internal view returns (uint256) {
        uint256 reserve0Out = reserve0 + amountIn;
        uint256 reserve1Out = vK / reserve0Out;

        uint256 out = reserve1 - reserve1Out;
        return out;
    }

    function swapByOut(uint256 amountOut, bool isEth) internal returns (uint256) {
        require(amountOut > 0, "invalid AmountOut");

        uint256 reserve0;
        uint256 reserve1;

        if (isEth) {
            reserve0 = vETHAmount;
            reserve1 = vUSDCAmount;
        } else {
            reserve0 = vUSDCAmount;
            reserve1 = vETHAmount;
        }

        uint256 amountIn = getAmountIn(amountOut, reserve0, reserve1);

        // 更新reserve
        if (isEth) {
            vETHAmount -= amountOut;
            vUSDCAmount += amountIn;
        } else {
            vETHAmount += amountIn;
            vUSDCAmount -= amountOut;
        }

        // 开仓时：如果是做空，这里就是返回的持仓eth数量
        return amountIn;
    }

    function getAmountIn(uint256 amountOut, uint256 reserve0, uint256 reserve1) internal view returns (uint256) {
        uint256 reserve0Out = reserve0 - amountOut;
        uint256 reserve1Out = vK / reserve0Out;

        return reserve1Out - reserve1;
    }

    // 关闭头寸并结算, 不考虑协议亏损
    // 此时的场景是做空：
    // 借 eth, 卖出，获得到amount的U
    //
    // 平仓：
    // 平仓时要把卖出的Eth都买回来
    //  - 此时我们从Pool中获取持仓数量的ETH，ethOut确定，计算出amountIn
    //    如果amountIn > 我们开仓时的_margin * level, 则我们是亏损的
    //    如果 amountIn - _margin*level = _margin, 则我们的本金刚好亏损完
    //    - 盈利时：
    //      此时，我们开仓时的_margin*level > amountIn, 我们可以提走 _margin + (_margin*level - amountIn)
    //    - 亏损时：我们平仓时_margin*level < amountIn, 并且 _margin*level + _margin < amountIn,
    //      此时我们需要把开仓时卖eth获取的 _margin*level 打进池子，并且再打入(amountIn - _margin*level)的本金
    //      剩余的_margin - (amountIn - _margin*level) 即 margin*(level + 1) - amountIn就是用户亏损后的余额
    //      清算逻辑同平仓逻辑，多一步检查，是否达到清算阈值
    //
    function closePosition() external {
        require(positions[msg.sender].position != 0, "Position already close");
        USDC.balanceOf(address(this));
        emit GetAmountOut(vETHAmount);
        emit GetAmountOut(vUSDCAmount);
        _closePosition(msg.sender, msg.sender);
    }

    function _closePosition(address _positionUser, address _refundTo) internal {
        PositionInfo memory pos = positions[_positionUser];

        if (pos.isLong) {
            // 做多
            // 需要把平仓时买的eth都卖出
            // 卖出的钱如果不足以换borrowed说明本金都赔光了，还陪了项目方的钱
            uint256 selled = getAmountOut(pos.position, vETHAmount, vUSDCAmount);
            require(selled >= pos.borrowed, "Insufficient funds to close the position");
            emit GetAmountOut(selled);
            // 更新池子
            vETHAmount += pos.position;
            vUSDCAmount -= selled;
            // 清空用户仓位信息
            delete positions[_positionUser];
            // 如果selled == pos.borrowed, 本金亏光了
            // 如果 selled > pos.borrowed + pos.margin, 则 selled - pos.borrowed - pos.margin 就是本次盈利金额
            USDC.transfer(_refundTo, selled - pos.borrowed);
        } else {
            // 做空
            // 需要把持仓的eth都买回来
            // 判断买回持仓的eth需要多少钱
            uint256 payAmount = getAmountIn(pos.position, vETHAmount, vUSDCAmount);
            // FIXME: 如果没人清算，项目方会一直赔钱
            // 这里的实现暂时是该仓位永远不能关闭，除非盈利回来，足以收回项目方的贷款
            // 需要优化
            require(payAmount <= pos.borrowed + pos.margin + pos.margin, "Insufficient funds to close the position");
            uint256 profitWithMargin = pos.borrowed + pos.margin + pos.margin - payAmount;
            // 更新池子
            vETHAmount -= pos.position;
            vUSDCAmount += payAmount;
            // 清空用户仓位信息
            delete positions[_positionUser];
            //转账给用户
            USDC.transfer(_refundTo, profitWithMargin);
        }
    }

    // 清算头寸， 清算的逻辑和关闭头寸类似，不过利润由清算用户获取
    // 注意： 清算人不能是自己，同时设置一个清算条件，例如亏损大于保证金的 80%
    function liquidatePosition(address _user) external {
        PositionInfo memory position = positions[_user];
        require(position.position != 0, "No open position");
        int256 pnl = calculatePnL(_user);

        require(-pnl > int256(position.margin / 2), "PNL has not reached the liquidation threshold");
        // 开始清算
        _closePosition(_user, msg.sender);

        // delete positions[_user];
    }

    // 计算盈亏： 对比当前的仓位和借的 vUSDC
    function calculatePnL(address user) public returns (int256) {
        require(positions[user].position != 0, "Position not found");
        PositionInfo memory pos = positions[user];

        if (pos.isLong) {
            // 做多
            // 需要把平仓时买的eth都卖出
            // 卖出的钱如果不足以换borrowed说明本金都赔光了，还陪了项目方的钱
            uint256 selled = getAmountOut(pos.position, vETHAmount, vUSDCAmount);
            emit GetAmountOut(selled);
            // 如果selled == pos.borrowed, 本金亏光了
            // 如果 selled > pos.borrowed + pos.margin, 则 selled - pos.borrowed - pos.margin 就是本次盈利金额
            return int256(selled) - int256(pos.borrowed) - int256(pos.margin);
        } else {
            // 做空
            // 需要把持仓的eth都买回来
            // 判断买回持仓的eth需要多少钱
            uint256 payAmount = getAmountIn(pos.position, vETHAmount, vUSDCAmount);
            int256 profitWithOutMargin = int256(pos.borrowed) + int256(pos.margin) - int256(payAmount);
            return profitWithOutMargin;
        }
    }
}
