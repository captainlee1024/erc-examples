// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Permit2 } from "lib/permit2/src/Permit2.sol";
import {Test, console} from "forge-std/Test.sol";
import {Permit2TTokenBank} from "../src/TerryPermit2TokenBank.sol";
import {TToken} from "../src/TerryToken.sol";
import {IAllowanceTransfer} from "lib/permit2/src/interfaces/IAllowanceTransfer.sol";
import {ISignatureTransfer} from "lib/permit2/src/interfaces/ISignatureTransfer.sol";
import {PermitSignature} from "lib/permit2/test/utils/PermitSignature.sol";
import "forge-std/Vm.sol";

contract Permit2Test is Test {
    // permit2erc20 代币合约实例
    TToken permitERC20;
    // permit2 合约实例
    Permit2 permit2;
    // 支持 permit2合约进行存款的 erc20 bank实例
    Permit2TTokenBank permit2TTokenBank;

    Vm.Wallet private aliceWallet = vm.createWallet("alice");
    address alice;
    uint256 amount = 10;
    uint256 deadline;
    bytes32 public constant TOKEN_PERMISSIONS_TYPEHASH = keccak256("TokenPermissions(address token,uint256 amount)");

    bytes32 public constant PERMIT_TRANSFER_FROM_TYPEHASH = keccak256(
        "PermitTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)"
    );

    function setUp() public {
        // create permit2
        permit2 = new Permit2();
        // create permiterc20
        permitERC20 = new TToken("TerryToken", "TTK");
        // create bank
        permit2TTokenBank = new Permit2TTokenBank(permitERC20, permit2);
        alice = aliceWallet.addr;
    }

    function testTerrySignatureTransfer() public {
        // init alice's erc20 balance
        permitERC20.transfer(alice, 1000);

        // approve
        vm.startPrank(alice);
        permitERC20.approve(address(permit2),  type(uint160).max);
        vm.stopPrank();

        uint256 deadline = uint256(block.timestamp + 100000);

        // sign
        uint256 nonce = permitERC20.nonces(alice);
        // sign transfer
        ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({
                token: address(permitERC20),
                amount: amount
            }),
            nonce: nonce,
            deadline: deadline
        });
        bytes32 tokenPermissions = keccak256(abi.encode(TOKEN_PERMISSIONS_TYPEHASH, permit.permitted));
        bytes32 msgHash = keccak256(
            abi.encodePacked(
                "\x19\x01",
                permit2.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        PERMIT_TRANSFER_FROM_TYPEHASH, tokenPermissions, address(permit2TTokenBank), permit.nonce, permit.deadline
                    )
                )
            )
        );

//        bytes32 tokenPermissionsHash = _hashTokenPermissions(permit.permitted);
//        bytes32 hash = keccak256(
//        abi.encode(PERMIT_TRANSFER_FROM_TYPEHASH, tokenPermissionsHash, address(permit2TTokenBank), permit.nonce, permit.deadline)
//        );
//
////        keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR(), permit.hash()));
//        bytes32 msgHash = keccak256(abi.encodePacked("\x19\x01", permit2.DOMAIN_SEPARATOR(), hash));
//
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(aliceWallet.privateKey, msgHash);
        bytes memory sig =  bytes.concat(r, s, bytes1(v));
        // sign details
//        ISignatureTransfer.SignatureTransferDetails memory transferDetails = ISignatureTransfer.SignatureTransferDetails({
//            to: address(permit2TTokenBank),
//            requestedAmount: amount
//        });

        // deposit with permit2
        permit2TTokenBank.depositWithPermit2(alice, amount, deadline, sig);

        // assert
        assert(permitERC20.balanceOf(address(permit2TTokenBank)) == amount);
        assert(permitERC20.balanceOf(address(alice)) == (1000 - amount));
    }
}