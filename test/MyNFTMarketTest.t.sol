// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {NFTMarket} from "../src/MyNFTMarket.sol";
import {BaseERC20} from "../src/MyERC20.sol";
import {MyNFT} from "../src/MyNFT.sol";

contract NFTMarketTest is Test {
    NFTMarket public market;
    BaseERC20 public erc20;
    MyNFT public nft;

    function setUp() public {
        console.logAddress(msg.sender);
        erc20 = new BaseERC20();
        console.logAddress(address(erc20));
        nft = new MyNFT("TerryNFT", "TNFT");
        console.logAddress(address(nft));
        market = new NFTMarket(erc20, nft);
        console.logAddress(address(market));
        console.logAddress(address(vm));
        console.logAddress(address(this));
    }

    // 以test_list_should_works为例，理解foundry作弊码实现原理
    // 运行forge test --mt test_list_should_works -vvv发生一次call调用
    // sender和origin 是默认账户0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38
    function test_list_should_works() public {
        address alice = makeAddr("alice");
        // 发生第二次call调用, 调用nft合约
        // sender是NFTMarketTest
        nft.mint(alice, "tokenURI");
        // 发生第三次call调用，调用vm合约作弊码函数
        // 虚拟机在执行该call时会在
        vm.prank(alice);
        vm.expectEmit(true, true, false, true);
        emit NFTMarket.List(alice, 1, 100);
        market.list(1, 100);
        (address owner, uint256 price) = market._listings(1);
        assertEq(owner, alice);
        assertEq(price, 100);
        // contract addr, mapping的slot, 和要查询的值的index

        vm.startMappingRecording();
        erc20.transfer(alice, 100);
        erc20.transfer(address(market), 100);
        bytes32 mappingSlot = bytes32(uint256(4));
        bytes32 dataSlot1 = vm.getMappingSlotAt(address(erc20), mappingSlot, 0);
        bytes32 dataSlot2 = vm.getMappingSlotAt(address(erc20), mappingSlot, 1);
        bytes32 dataSlot3 = vm.getMappingSlotAt(address(erc20), mappingSlot, 2);

        console.logUint(uint256(vm.terryGetStorageAt(address(erc20), dataSlot1)));
        console.logString("Set new value: 999");
        vm.terrySetStorageAt(address(erc20), dataSlot1, bytes32(uint256(999)));

        console.logUint(uint256(vm.load(address(erc20), dataSlot1)));
        console.logUint(uint256(vm.load(address(erc20), dataSlot2)));
        console.logUint(uint256(vm.load(address(erc20), dataSlot3)));

        vm.setArbitraryStorage(address(0));
    }

    function test_list_failed() public {
        // failed with not owner
        address alice = makeAddr("alice");
        nft.mint(alice, "tokenURI");
        vm.expectRevert("Not the owner of the NFT");
        market.list(1, 100);

        // failed with invalid price
        vm.expectRevert("Invalid price");
        market.list(1, 0);
        // failed with invalid token ID
        vm.expectRevert("Invalid token ID");
        market.list(0, 100);

        // failed with NFT already listed
        vm.startPrank(alice);
        market.list(1, 100);
        vm.expectRevert("NFT already listed");
        market.list(1, 100);
        vm.stopPrank();
    }

    function test_buy_should_works() public {
        address alice = makeAddr("alice");
        address bob = makeAddr("bob");
        erc20.transfer(bob, 1000);

        // mint approve and lis
        nft.mint(alice, "tokenURI");
        nft.mint(alice, "tokenURI");
        vm.startPrank(alice);
        nft.approve(address(market), 1);
        nft.approve(address(market), 2);
        market.list(1, 100);
        market.list(2, 200);
        vm.stopPrank();

        // approve
        vm.startPrank(bob);
        erc20.approve(address(market), 200);
        // 使用 buy 直接购买
        market.buy(1, 200);

        // buy by erc20 transferAndCall
        erc20.transferAndCall(address(market), 300, abi.encode(uint256(2)));

        vm.stopPrank();

        // check owner
        (address nft_1_owner, uint256 nft_1_price) = market._listings(1);
        assertEq(nft_1_owner, address(0));
        assertEq(nft_1_price, 0);
        assertEq(nft.ownerOf(1), bob);

        (address nft_2_owner, uint256 nft_2_price) = market._listings(2);
        assertEq(nft_2_owner, address(0));
        assertEq(nft_2_price, 0);
        assertEq(nft.ownerOf(2), bob);

        // check ERC20 Balance
        // 检查高出的部分是否退回给买家
        assertEq(erc20.balanceOf(bob), 700);
        assertEq(erc20.balanceOf(address(market)), 0);
        assertEq(erc20.balanceOf(alice), 300);
    }

    function testFuzz_market(address buyer, uint256 price) public {
        assumeNotZeroAddress(buyer);
        price = bound(price, 1 * 10 ** (erc20.decimals() - 2), 1000 * 10 ** erc20.decimals());
        address alice = makeAddr("alice");

        // mint and list use fuzzy price
        nft.mint(alice, "tokenURI");
        vm.startPrank(alice);
        nft.approve(address(market), 1);
        market.list(1, price);
        vm.stopPrank();

        // transfer amount to buyer, amount >= price
        erc20.transfer(buyer, price);
        vm.prank(buyer);
        erc20.transferAndCall(address(market), price, abi.encode(uint256(1)));

        // check owner
        assertEq(nft.ownerOf(1), buyer);
    }

    function invariant_market_balance() public {
        assertEq(erc20.balanceOf(address(market)), 0);
    }
}
