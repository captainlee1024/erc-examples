// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/// @custom:oz-upgrades-from TNFTUpgradeable
contract TNFTUpgradeable is Initializable, ERC721URIStorageUpgradeable, OwnableUpgradeable, UUPSUpgradeable {
    uint256 private _tokenId;

    function incrementTokenId() internal {
        _tokenId++;
    }

    function currentTokenId() internal returns (uint256) {
        return _tokenId;
    }

    constructor() {
        _disableInitializers();
    }

    function initialize(string memory name_, string memory symbol_, address owner_) public initializer {
        __ERC721URIStorage_init();
        __ERC721_init(name_, symbol_);
        __Ownable_init(owner_);
        __UUPSUpgradeable_init();
    }

    function mintNFT(address recipient, string memory tokenURI) public onlyOwner returns (uint256) {
        incrementTokenId();
        uint256 newTokenId = currentTokenId();

        _mint(recipient, newTokenId);
        _setTokenURI(newTokenId, tokenURI);

        return newTokenId;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
