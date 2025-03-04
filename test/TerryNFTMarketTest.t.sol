// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test, console} from "forge-std/Test.sol";
import {NFTMarket} from "../src/TerryNFTMarket.sol";
import {TToken} from "../src/TerryToken.sol";
import {MyNFT} from "../src/TerryNFT.sol";
//import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "forge-std/Vm.sol";



contract NFTMarketTest is Test {
    NFTMarket public market;
    TToken public erc20;
    MyNFT public nft;
    Vm.Wallet private aliceWallet = vm.createWallet("alice");
    address private alice;
    address private bob;

    function setUp() public {
        erc20 = new TToken("TerryToken", "TTK");
        nft = new MyNFT();
        market = new NFTMarket("TNFTMarket", address(nft), address(erc20));
        aliceWallet = vm.createWallet("alice");
        alice = aliceWallet.addr;
        bob = makeAddr("bob");
    }

    function test_permit_buy() public {
        // 初始化bob token
        erc20.transfer(bob, 1000);
        console.logString("Before");
        uint256 bobBalance = erc20.balanceOf(bob);
        uint256 aliceBalance = erc20.balanceOf(alice);
        console.log("bob addr:", bob, " balance: ", bobBalance);
        console.log("alice addr:", alice, " balance: ", aliceBalance);

        // mint nft
        nft.mintNFT(alice, "tokenURI");
        console.log("nft 1 owner: ", nft.ownerOf(1));

        // prove and list
        vm.startPrank(alice);
        nft.approve(address(market), 1);
        NFTMarket.Policy  policy = NFTMarket.Policy.permitWhitelist;
        market.listNFTWithPolicy(1, 100, policy);

        // sign EIP712 typed data
        // domain
        bytes32 hashdName = keccak256(bytes("TNFTMarket"));
        bytes32 hashdVersion = keccak256(bytes("1"));
        bytes32 EIP712TypeHash = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
        bytes32 domainSeparator = keccak256(abi.encode(EIP712TypeHash, hashdName, hashdVersion, block.chainid, address(market)));

        // permitBuy
        bytes32 PERMIT_TYPEHASH = keccak256("permitBuy(address owner, uint256 tokenId, address authorizedBuyer)");
        bytes32 structHash = keccak256(abi.encode(PERMIT_TYPEHASH, alice, 1, bob));

        bytes32 hash = ECDSA.toTypedDataHash(domainSeparator, structHash);

        // sign
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(aliceWallet, hash);
        vm.stopPrank();

        // approve and permit buy
        vm.startPrank(bob);
        erc20.approve(address(market), 100);
        market.permitBuy(1, v, r, s);
        vm.stopPrank();

        console.logString("After");
        console.log("bob addr:", bob, " balance: ", erc20.balanceOf(bob));
        console.log("alice addr:", alice, " balance: ", erc20.balanceOf(alice));
        console.log("nft 1 owner: ", nft.ownerOf(1));

    }
}
