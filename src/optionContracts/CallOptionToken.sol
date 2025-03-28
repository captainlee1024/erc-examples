// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract CallOptionToken is ERC20, Ownable {
    // 行权日期
    uint256 public _expiryDate;
    // 行权价格
    uint256 public _strikePrice;
    // 期权发行着
    address public _issuer;
    // 标的资产数额
    uint256 public _underlyingAmount;
    uint256 public constant TOKENS_PER_ETH = 100;

    event SETP(uint256 setp);

    // 用于购买标的资产的token
    // 这里指定 U
    IERC20 _USDC;

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 strikePrice_,
        uint256 expiryDate_,
        address expiryToken_,
        address issuer_,
        uint256 underlyingAmount_
    ) ERC20(name_, symbol_) Ownable(msg.sender) {
        _expiryDate = expiryDate_;
        _strikePrice = strikePrice_;
        _issuer = issuer_;
        _underlyingAmount = underlyingAmount_;
        _USDC = IERC20(expiryToken_);

        // NOTE: 发行比例 1:1000
        _mint(_issuer, _underlyingAmount * TOKENS_PER_ETH);
    }

    // burn 等其他方法也用到了，不能重写该方法
    // /// 重写_update方法，添加转账检查，行权日期前的期权才可以交易
    // function _update(address from, address to, uint256 value) internal override {
    //     require(_expiryDate > block.timestamp, "CallOptionToken has exceeded the trading time");
    //     // 当前转移期权数量 amount: value
    //     // 当前期权发行方，即标的归属人 Issure
    //     super._update(from, to, value);
    // }

    function transferFrom(address from, address to, uint256 value) public override returns (bool) {
        require(_expiryDate > block.timestamp, "CallOptionToken has exceeded the trading time");
        address spender = _msgSender();
        _spendAllowance(from, spender, value);
        _transfer(from, to, value);
        return true;
    }

    function transfer(address to, uint256 value) public override returns (bool) {
        require(_expiryDate > block.timestamp, "CallOptionToken has exceeded the trading time");
        address owner = _msgSender();
        _transfer(owner, to, value);
        return true;
    }

    // 行权
    // 这里需要先approve 对应的USDC给期权合约
    function exercise() public payable {
        emit SETP(10);
        require(_expiryDate < block.timestamp, "Option has expired");
        // 价格波动对期权影响较大，当天必须成交
        // require(_expiryDate > block.timestamp - 1 days, "not expiryDate");

        emit SETP(1);
        // 可购买的总ETH数量, 用户可获得的ETH
        uint256 exercisableAmount = balanceOf(msg.sender) / TOKENS_PER_ETH;
        require(_underlyingAmount >= exercisableAmount, "Insufficient underlying asset");

        emit SETP(2);
        // 购买所需价格
        uint256 exercisePayment = exercisableAmount * _strikePrice;
        // require(msg.value >= exercisePayment, "Insufficient payment");
        require(_USDC.balanceOf(msg.sender) >= exercisePayment, "Insufficient payment");
        emit SETP(exercisePayment);

        emit SETP(3);
        // 更新标的资产信息
        // 有可能期权被卖出一部分，剩余的还可以销毁期权回收标的
        _underlyingAmount -= exercisableAmount;
        // 销毁当前Token
        _burn(msg.sender, balanceOf(msg.sender));

        emit SETP(4);
        // 将用户行权的钱发送给Issuer
        // (bool sentToIssuer,) = _issuer.call{value: exercisePayment}("");
        // require(sentToIssuer, "Failed to send strike price to issuer");
        // 创建期权是可以指定行权使用什么Token，这里是U
        bool result = _USDC.transferFrom(msg.sender, _issuer, exercisePayment);
        require(result, "Failed to exercise, USDC transferFrom error");

        emit SETP(5);
        // 发送标的资产给用户
        (bool sent,) = msg.sender.call{value: exercisableAmount}("");
        require(sent, "Failed to send ETH");
        emit SETP(6);
    }

    // 发行者过期赎回期权
    // 就是发行的期权没有被行权，最终在谁手里谁就可以赎回
    function expireAndRedeem() public {
        require(_expiryDate < block.timestamp, "The option has not yet expired");
        require(balanceOf(msg.sender) > 0, "Holding options: 0");

        uint256 remainingUnderlying = _underlyingAmount;
        // 更新标的资产信息
        _underlyingAmount = 0;

        // 销毁token
        require(balanceOf(_issuer) == (remainingUnderlying * TOKENS_PER_ETH), "Option Error");
        _burn(_issuer, balanceOf(_issuer));

        // 发送标的资产给发行者
        if (remainingUnderlying > 0) {
            (bool sent,) = _issuer.call{value: remainingUnderlying}("");
            require(sent, "Failed to send ETH");
        }
    }

    // 查询期权详情
    // 返回用户持有期权Token数量，行权时间，行权价格
    function getOptionInfo(address user) public view returns (uint256, uint256, uint256) {
        return (balanceOf(user), _expiryDate, _strikePrice);
    }

    receive() external payable {}
}
