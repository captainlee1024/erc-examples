// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import {Permit2} from "lib/permit2/src/Permit2.sol";
import "./TerryToken.sol";
import {ISignatureTransfer} from "lib/permit2/src/interfaces/ISignatureTransfer.sol";

contract Permit2TTokenBank {
    ERC20Permit public tToken;
    Permit2 public tokenBankPermit2;
    mapping(address => uint256) public Balance;

    bytes32 public constant TOKEN_PERMISSIONS_TYPEHASH = keccak256("TokenPermissions(address token,uint256 amount)");

    bytes32 public constant PERMIT_TRANSFER_FROM_TYPEHASH = keccak256(
        "PermitTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)"
    );

    constructor(ERC20Permit _tToken, Permit2 _tbPermit2) {
        tToken = _tToken;
        tokenBankPermit2 = _tbPermit2;
    }

    function deposit(uint256 amount) public {
        tToken.transferFrom(msg.sender, address(this), amount);
        Balance[msg.sender] += amount;
    }

    function withdraw(uint256 amount) public {
        require(Balance[msg.sender] >= amount, "Insufficient balance");
        tToken.transfer(msg.sender, amount);
        Balance[msg.sender] -= amount;
    }

    function depositWithPermit(address owner, uint256 amount, uint256 deadline, uint8 v, bytes32 r, bytes32 s) public {
        tToken.permit(owner, address(this), amount, deadline, v, r, s);
        tToken.transferFrom(owner, address(this), amount);
        Balance[msg.sender] += amount;
    }

    function depositWithPermit2(address owner, uint256 amount, uint256 deadline, bytes calldata signature) public {
        //uint48 expiration = uint48(block.timestamp + 100);
        uint256 nonce = tToken.nonces(owner);
        // sign transfer
        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({
            token: address(tToken),
            amount: amount
        }),
            nonce: nonce,
            deadline: deadline
        });
//        bytes32 tokenPermissions = keccak256(abi.encode(TOKEN_PERMISSIONS_TYPEHASH, permit.permitted));
//        bytes32 msgHash = keccak256(
//            abi.encodePacked(
//                "\x19\x01",
//                tokenBankPermit2.DOMAIN_SEPARATOR(),
//                keccak256(
//                    abi.encode(
//                        PERMIT_TRANSFER_FROM_TYPEHASH, tokenPermissions, address(this), permit.nonce, permit.deadline
//                    )
//                )
//            )
//        );

        // sign details
        ISignatureTransfer.SignatureTransferDetails memory transferDetails = ISignatureTransfer.SignatureTransferDetails({
            to: address(this),
            requestedAmount: amount
        });

        tokenBankPermit2.permitTransferFrom(permit, transferDetails, owner, signature);
    }
}