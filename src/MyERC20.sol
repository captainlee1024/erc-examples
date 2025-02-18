// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {NFTMarket} from "./MyNFTMarket.sol";

contract BaseERC20 {
    string public name;
    string public symbol;
    uint8 public decimals;

    uint256 public totalSupply;

    mapping(address => uint256) balances;

    mapping(address => mapping(address => uint256)) allowances;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    error ERC20OnCheckeceived();

    constructor() {
        name = "BaseERC20";
        symbol = "BERC20";
        decimals = 18;
        totalSupply = 100000000000000000000000000;
        balances[msg.sender] = totalSupply;
    }

    function balanceOf(address _owner) public view returns (uint256 balance) {
        return balances[_owner];
    }

    // transfer(address,uint256)
    function transfer(address _to, uint256 _value) public returns (bool success) {
        require(balances[msg.sender] >= _value, "ERC20: transfer amount exceeds balance");

        bool _success = transferFrom(msg.sender, _to, _value);
        require(_success);

        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    function transferAndCall(address _to, uint256 _value, bytes calldata _data) public virtual returns (bool) {
        if (!transfer(_to, _value)) {
            revert();
        }
        _checkOnErc20Received(msg.sender, msg.sender, _to, _value, _data);
        return true;
    }

    function _checkOnErc20Received(
        address _msgSender,
        address _from,
        address _to,
        uint256 _amount,
        bytes memory _data
    ) private {
        // onErc20Received(address operator, address from, uint256 bid, bytes memory data)
        // bytes memory payload =
        //     abi.encodeWithSignature("onErc20Received(address,address,uint256,bytes)", _msgSender, _from, _amount, _data);
        // (bool success, bytes memory resultBytes) = _to.call(payload);

        bool success = NFTMarket(_to).onErc20Received(_msgSender, _from, _amount, _data);
        require(success, "ERC20 check received failed");
        //abi.decode(result, (bool))
        // bool result = abi.decode(resultBytes, (bool));
        // require(result, "onErc20Received: execution failed");
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        // if ((msg.sender != _from) && (allowances[_from][msg.sender] >= 0)) {
        if (msg.sender != _from) {
            require(allowances[_from][msg.sender] >= _value, "ERC20: transfer amount exceeds allowance");
            allowances[_from][msg.sender] -= _value;
        }

        // require(balances[_from] >= _value, "ERC20: transfer amount exceeds balance");

        balances[_from] -= _value;
        balances[_to] += _value;

        emit Transfer(_from, _to, _value);
        return true;
    }

    function approve(address _spender, uint256 _value) public returns (bool success) {
        // require(balances[msg.sender] >= (allowances[msg.sender][_spender] + _value), "ERC20: approve amount exceeds balance");
        allowances[msg.sender][_spender] += _value;

        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender) public view returns (uint256 remaining) {
        return allowances[_owner][_spender];
    }

    receive() external payable {}
}
