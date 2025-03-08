// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/TerryToken.sol";
import "../src/TerryNFT.sol";
import "../src/AirdropMerkleNFTMarket.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract AirdropMerkleNFTMarketTest is Test {
    TToken token;
    MyNFT nft;
    AirdropMerkleNFTMarket market;
    //    Multicall multicall;
    bytes32 merkleRoot = 0x01f100cfab9a9f2730aeac33b864a59d5af722989b09dec7c76b9b1a2cc62e3d; // 从脚本生成
        // 三个白名单用户
    //"0x0fF93eDfa7FB7Ad5E962E4C0EdB9207C03a0fe02",
    //"0x3a7e663c871351BbE7B6dD006cB4A46d75cCe61D",
    //"0x696BA93ef4254Da47ff05b6CAa88190dB335F1C3",

    //Merkle Root: 0x01f100cfab9a9f2730aeac33b864a59d5af722989b09dec7c76b9b1a2cc62e3d
    //Address: 0x0fF93eDfa7FB7Ad5E962E4C0EdB9207C03a0fe02, Proof: [
    //'0x2d38b9a5083145958e41e8dc4a04a3d9fdb5b30aef77424a93e10c4b954b1a3e',
    //'0x1cf4086a8cf15d83df4f50d7fabbaec5f4ea3163eb951ca727ea88e556c3f5b4'
    //]
    //Address: 0x3a7e663c871351BbE7B6dD006cB4A46d75cCe61D, Proof: [
    //'0x10a7d32dcea667e33744f2e12dea3a857c0798fbc0abc6d097d3ed82f8a52d63',
    //'0x1cf4086a8cf15d83df4f50d7fabbaec5f4ea3163eb951ca727ea88e556c3f5b4'
    //]
    //Address: 0x696BA93ef4254Da47ff05b6CAa88190dB335F1C3, Proof: [
    //'0xf475e748a5d4a881b93d5afe69395ada163c4433474348c8d47e23df8692ef27'
    //]
    //Leaf:  0x10a7d32dcea667e33744f2e12dea3a857c0798fbc0abc6d097d3ed82f8a52d63
    //Verified:  true
    //
    Vm.Wallet sellerWallet;
    address seller;

    Vm.Wallet buyerWallet;
    address buyer; // 白名单用户

    Vm.Wallet buyer2Wallet;
    address buyer2; // 白名单用户2

    Vm.Wallet buyer3Wallet;
    address buyer3; // 白名单用户3

    address nonWhitelisted = address(0x78910);
    bytes32 private constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    uint256 tokenId;
    uint256 deadline;
    uint256 sellPrice = 10 * 10 ** 18; // 白名单特价 5折

    function setUp() public {
        // init seller wallet
        sellerWallet = vm.createWallet("seller");
        seller = sellerWallet.addr;

        buyerWallet = vm.createWallet("buyer");
        buyer = buyerWallet.addr;

        buyer2Wallet = vm.createWallet("buyer2");
        buyer2 = buyer2Wallet.addr;

        buyer3Wallet = vm.createWallet("buyer3");
        buyer3 = buyer3Wallet.addr;

        console.log("seller addr: ", seller);
        console.log("buyer addr: ", buyer);
        console.log("buyer2 addr: ", buyer2);
        console.log("buyer3 addr: ", buyer3);
        // init token, nft, market, multicall
        token = new TToken("TerryToken", "TTK");
        nft = new MyNFT();
        market = new AirdropMerkleNFTMarket(address(token), address(nft), merkleRoot);
        //        multicall = new Multicall();

        // init balance
        vm.deal(seller, 10 ether);
        vm.deal(buyer, 10 ether);
        vm.deal(nonWhitelisted, 10 ether);

        // init erc20 balance
        token.transfer(buyer, 1000 * 10 ** 18);
        token.transfer(nonWhitelisted, 1000 * 10 ** 18);

        // mint nft
        tokenId = nft.mintNFT(seller, "tokenURI");

        // approve nft
        vm.prank(seller);
        nft.approve(address(market), tokenId);

        // list nft
        vm.prank(seller);
        market.list(tokenId, sellPrice); // 价格 10 Token
    }

    function test_ListAndBuyWithPermit() public {
        bytes32[] memory proof = new bytes32[](2);
        proof[0] = 0x2d38b9a5083145958e41e8dc4a04a3d9fdb5b30aef77424a93e10c4b954b1a3e;
        proof[1] = 0x1cf4086a8cf15d83df4f50d7fabbaec5f4ea3163eb951ca727ea88e556c3f5b4;

        uint256 currentNonce = token.nonces(buyer);

        // 生成 permit 数据
        deadline = block.timestamp + 24000 hours;
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                token.DOMAIN_SEPARATOR(),
                keccak256(abi.encode(PERMIT_TYPEHASH, buyer, address(market), sellPrice, currentNonce, deadline))
            )
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(buyerWallet.privateKey, digest); // 假设 buyer 的私钥对应 vm.sign 的 key 1

        //        market.permitPrePay(buyer, 50 * 10**18, deadline, v, r, s);
        // 构造 multicall 数据
        AirdropMerkleNFTMarket.Call[] memory calls = new AirdropMerkleNFTMarket.Call[](2);
        calls[0] = AirdropMerkleNFTMarket.Call(
            abi.encodeWithSignature(
                "permitPrePay(address,uint256,uint256,uint8,bytes32,bytes32)", buyer, sellPrice, deadline, v, r, s
            )
        );
        calls[1] =
            AirdropMerkleNFTMarket.Call(abi.encodeWithSignature("claimNFT(uint256,bytes32[])", tokenId, proof, buyer));

        console.log("market addr: ", address(market));
        vm.prank(buyer);
        market.multicall(calls);

        assertEq(nft.ownerOf(1), buyer);
        assertEq(token.balanceOf(seller), sellPrice / 2);
        assertEq(token.balanceOf(buyer), 1000 * 10 ** 18 - sellPrice / 2);
    }

    function test_NonWhitelistedBuy() public {
        vm.prank(nonWhitelisted);
        token.approve(address(market), 100 * 10 ** 18);
        vm.prank(nonWhitelisted);
        market.claimNFT(1, new bytes32[](0));

        assertEq(nft.ownerOf(1), nonWhitelisted);
        assertEq(token.balanceOf(seller), sellPrice);
    }
}
