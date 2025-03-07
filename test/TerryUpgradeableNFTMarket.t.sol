// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {TerryUpgradeableNFTMarket} from "../src/TerryUpgradeableNFTMarket.sol";
import {TerryUpgradeableNFTMarketV2} from "../src/TerryUpgradeableNFTMarketV2.sol";
import {TTokenUpgradeable} from "../src/TerryUpgradeableToken.sol";
import {TNFTUpgradeable} from "../src/TerryUpgradeableNFT.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "forge-std/Vm.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract NFTMarketTest is Test {
    TTokenUpgradeable payToken;
    TNFTUpgradeable nft;
    TerryUpgradeableNFTMarket marketV1;
    TerryUpgradeableNFTMarketV2 marketV2;
    ERC1967Proxy proxyToken;
    ERC1967Proxy proxyNft;
    ERC1967Proxy proxyMarket;
    address owner;
    Vm.Wallet ownerWallet;
    address newOwner;

    function setUp() public {
        ownerWallet = vm.createWallet("owner");
        owner = ownerWallet.addr;
        newOwner = makeAddr("newOwner");
        // token v1 impl
        payToken = new TTokenUpgradeable();
        // proxy
        bytes memory erc20InitCallData =
            abi.encodeWithSignature("initialize(string,string,address)", "TUToken", "TUTK", owner);
        proxyToken = new ERC1967Proxy(address(payToken), erc20InitCallData);
        // nft v1 impl
        nft = new TNFTUpgradeable();
        // proxy
        bytes memory nftInitCallData =
            abi.encodeWithSelector(TNFTUpgradeable.initialize.selector, "TerryUNFT", "TUNFT", owner);
        proxyNft = new ERC1967Proxy(address(nft), nftInitCallData);
        // nft market v1
        marketV1 = new TerryUpgradeableNFTMarket();
        // proxy
        //        "initialize(string memory marketName_, address paymentToken_, address nft_, address owner)"
        bytes memory marketInitCallData = abi.encodeWithSelector(
            TerryUpgradeableNFTMarket.initialize.selector, "TUMarket", address(payToken), address(nft), owner
        );
        proxyMarket = new ERC1967Proxy(address(marketV1), marketInitCallData);
    }

    function testUpgradeMarket() public {
        vm.startPrank(owner);
        // nft market v2
        marketV2 = new TerryUpgradeableNFTMarketV2();
        console.log(TerryUpgradeableNFTMarket(address(proxyMarket)).version());

        //        initialize(string memory marketName_, address paymentToken_, address nft_, address owner)
        //        bytes memory marketV2InitCallData = abi.encodeWithSelector( TerryUpgradeableNFTMarketV2.initialize.selector,
        //            "TUMarketV2", address(payToken), address(nft), owner);
        bytes memory marketV2UpgradeCallData =
            abi.encodeWithSelector(TerryUpgradeableNFTMarketV2.upgradeVersion.selector, 2);
        UUPSUpgradeable market = UUPSUpgradeable(address(proxyMarket));
        market.upgradeToAndCall(address(marketV2), marketV2UpgradeCallData);
        console.log(TerryUpgradeableNFTMarketV2(address(proxyMarket)).version());
        vm.stopPrank();
    }

    function testCannotInitializeTwice() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        TerryUpgradeableNFTMarket(address(proxyMarket)).initialize("name", address(payToken), address(nft), owner);
    }
}
