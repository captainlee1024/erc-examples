// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {CallOptionToken} from "./CallOptionToken.sol";

contract CallOptionFactory is Ownable {
    address public constant UNDERLYING_ASSET = address(0); // ETH

    struct OptionInfo {
        address issuer;
        uint256 strikePrice;
        uint256 expiryDate;
        uint256 totalUnderlying;
        address tokenAddress;
    }

    mapping(uint256 => OptionInfo) public options;
    uint256 public optionCount;

    event OptionCreated(
        uint256 indexed optionId,
        address indexed issuer,
        address tokenAddress,
        uint256 strikePrice,
        uint256 expiryDate,
        uint256 underlyingAmount
    );
    event OptionExercised(
        uint256 indexed optionId, address indexed user, uint256 tokenAmount, uint256 underlyingReceived
    );
    event OptionExpired(uint256 indexed optionId, uint256 remainingUnderlying);

    constructor() Ownable(msg.sender) {}

    function createOption(
        uint256 _strikePrice,
        uint256 _expiryDate,
        address _expiryToken,
        string memory _name,
        string memory _symbol
    ) external payable returns (uint256) {
        require(msg.value > 0, "Must provide ETH as underlying asset");
        require(_strikePrice > 0, "Invalid strike price");
        require(_expiryDate > block.timestamp, "Expiry date must be in the future");

        CallOptionToken newOption =
            new CallOptionToken(_name, _symbol, _strikePrice, _expiryDate, _expiryToken, msg.sender, msg.value);

        optionCount++;
        options[optionCount] = OptionInfo({
            issuer: msg.sender,
            strikePrice: _strikePrice,
            expiryDate: _expiryDate,
            totalUnderlying: msg.value,
            tokenAddress: address(newOption)
        });

        (bool sent,) = address(newOption).call{value: msg.value}("");
        require(sent, "Failed to send ETH to option contract");

        emit OptionCreated(optionCount, msg.sender, address(newOption), _strikePrice, _expiryDate, msg.value);
        return optionCount;
    }

    function getOptionInfo(uint256 optionId) external view returns (OptionInfo memory) {
        require(optionId <= optionCount && optionId > 0, "Invalid option ID");
        return options[optionId];
    }
}
