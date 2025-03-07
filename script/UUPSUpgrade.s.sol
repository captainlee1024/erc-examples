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

/// forge script ./script/UUPSUpgrade.s.sol --account 2f9ada67-5e0d-4ae5-8f5b-cb3e1e6e23a5 --rpc-url https://eth-sepolia.public.blastapi.io --sig "run(address)" 0x1D540c2ee7A8a65e01895D8Edc273762306DbB4a --broadcast
contract UUPSDeployScript is Script {
    TerryUpgradeableNFTMarketV2 marketV2;
    address proxyMarket;
    address owner;

    function run(address proxyMarket_) public {
        proxyMarket = proxyMarket_;
        owner = address(0xc213d510fe60552A27F29842729bD28393CBFEe7);
        vm.startBroadcast(owner);

        // nft market v2
        marketV2 = new TerryUpgradeableNFTMarketV2();
        console.log(TerryUpgradeableNFTMarket(proxyMarket).version());

        bytes memory marketV2UpgradeCallData =
            abi.encodeWithSelector(TerryUpgradeableNFTMarketV2.upgradeVersion.selector, 2);
        UUPSUpgradeable market = UUPSUpgradeable(proxyMarket);
        market.upgradeToAndCall(address(marketV2), marketV2UpgradeCallData);
        console.log(TerryUpgradeableNFTMarket(proxyMarket).version());
        vm.stopBroadcast();

        console.log("marketV2 impl addr: ", address(marketV2));
        console.log("market proxy: ", proxyMarket);
    }
}
