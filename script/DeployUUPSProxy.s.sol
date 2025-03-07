// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Test, console} from "forge-std/Test.sol";
import {TerryUpgradeableNFTMarket} from "../src/TerryUpgradeableNFTMarket.sol";
import {TerryUpgradeableNFTMarketV2} from "../src/TerryUpgradeableNFTMarketV2.sol";
import {TTokenUpgradeable} from "../src/TerryUpgradeableToken.sol";
import {TNFTUpgradeable} from "../src/TerryUpgradeableNFT.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "forge-std/Vm.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/// forge script ./script/DeployUUPSProxy.s.sol --account 2f9ada67-5e0d-4ae5-8f5b-cb3e1e6e23a5 --rpc-url https://eth-sepolia.public.blastapi.io --sig "run()" --broadcast
contract UUPSDeployScript is Script {
    TTokenUpgradeable payToken;
    TNFTUpgradeable nft;
    TerryUpgradeableNFTMarket marketV1;
    ERC1967Proxy proxyToken;
    ERC1967Proxy proxyNft;
    ERC1967Proxy proxyMarket;
    address owner;

    function run() public {
        // my account
        owner = address(0xc213d510fe60552A27F29842729bD28393CBFEe7);
        vm.startBroadcast(owner);

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
        vm.stopBroadcast();
        console.log("erc20: ", address(payToken));
        console.log("erc20 proxy: ", address(proxyToken));
        console.log("nft: ", address(nft));
        console.log("nft proxy: ", address(proxyNft));
        console.log("market: ", address(marketV1));
        console.log("market proxy: ", address(proxyMarket));
    }
}
