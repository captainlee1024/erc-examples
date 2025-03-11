// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// 开启预售: 支持对给定的任意ERC20开启预售，设定预售价格，募集ETH目标，超募上限，预售时长。
// 任意用户可支付ETH参与预售；
// 预售结束后，如果没有达到募集目标，则用户可领会退款；
// 预售成功，用户可领取 Token，且项目方可提现募集的ETH；

contract IDO {
    IERC20 private _erc20;
    // 1 eth 购买 token量
    uint256 private _tokenPreEth; // 1 token / price eth
    // 预期最低筹集金额
    uint256 private _minFundAmount; // eth
    // 预期最高筹集金额
    uint256 private _maxFundAmount; // eth
    // token释放总量
    uint256 private _preTotalSupply; // token
    // 当前筹集到的金额
    uint256 _totalFundEthAmount; // eth
    // 当前状态
    Status private _currentStatus;
    uint256 private _deadline; // 截止日期
    enum Status { Idle, Active, Success, Failed }
    // 用户投资eth金额
    mapping(address => uint256) _userEthAmount;
    address _tokenTeam; // IDO发起方账户，用于接收筹集的eth

    constructor() {}

    function startIDO(
        address erc20_,
        uint256 tokenPreEth_,
        uint256 minFundAmount_,
        uint256 maxFundAmount_,
        uint256 deadline_
    ) external onlyIdle {
        uint256 preTotalSupply = minFundAmount_ * tokenPreEth_;
//        require(IERC20(erc20_).allowance(msg.sender, address(this)) == preTotalSupply, "Not enough authorized tokens");
        require(IERC20(erc20_).balanceOf(address(this)) == preTotalSupply, "Not enough authorized tokens");

        _erc20 = IERC20(erc20_);
        _tokenPreEth = tokenPreEth_;
        _minFundAmount = minFundAmount_;
        _maxFundAmount = maxFundAmount_;
        _currentStatus = Status.Active;
        _deadline = deadline_;
        _preTotalSupply = preTotalSupply;
        _tokenTeam = msg.sender;
    }

    // 预售
    function presale() external payable onlyActive {
        // 单笔最小筹集金额
        require(msg.value >= 0.1 ether, "PreSale failed, A minimum of 0.1 eth is required");
        // 不超过筹集金额上限
        require((msg.value + _totalFundEthAmount) <= _maxFundAmount, "Pre sale failed. The maximum fundraising limit has been exceeded.");

        _userEthAmount[msg.sender] += msg.value;
        _totalFundEthAmount += msg.value;
    }

    // 预售成功，用户领取token
    function claim() external onlySuccess {
        uint256 toUser = _preTotalSupply * _userEthAmount[msg.sender] / _totalFundEthAmount;
        _userEthAmount[msg.sender] = 0;
        bool result = _erc20.transfer(msg.sender, toUser);
        require(result, "claim failed");
    }

    // 集资成功，按IDO规则分账, 这里全部给项目方
    function withdraw() external onlySuccess {
        uint256 toTeam = _totalFundEthAmount;
        _totalFundEthAmount = 0;
        (bool result, ) = _tokenTeam.call{value: toTeam}("");
        require(result, "withdraw failed");
    }

    // 集资失败，用户领取退款
    function refund() external onlyFailed {
        require(_userEthAmount[msg.sender] > 0, "no founds deposited");
        uint256 toUser = _userEthAmount[msg.sender];
        _userEthAmount[msg.sender] = 0;
        (bool result, ) = msg.sender.call{value: toUser}("");
        require(result, "refund failed");
    }

    function refundTokenToTeam() external onlyFailed {
        uint256 preTotalSupply = _minFundAmount * _tokenPreEth;
        bool result = _erc20.transfer(_tokenTeam, preTotalSupply);
        require(result, "refundTokenToTeam failed");
    }

    receive() payable external {}

    modifier onlySuccess() {
        _advanceState();
        require(_currentStatus == Status.Success, "Operation allowed only in Success state");
        _;
    }

    modifier onlyFailed(){
        _advanceState();
        require(_currentStatus == Status.Failed, "Operation allowed only in Failed state");
        _;
    }

    modifier onlyActive() {
        _advanceState();
        require(_currentStatus == Status.Active, "Operation allowed only in Active state");
        _;
    }

    modifier onlyIdle() {
        _advanceState();
        require(_currentStatus == Status.Idle, "Operation allowed only in Idle state");
        _;
    }

    function _advanceState() private {
        if (_currentStatus == Status.Active) {
            if (block.timestamp >= _deadline) {
                if (_totalFundEthAmount >= _minFundAmount) {
                    _currentStatus = Status.Success;
                } else {
                    _currentStatus = Status.Failed;
                }
            }
        }
    }
}