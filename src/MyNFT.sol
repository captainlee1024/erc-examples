// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./MyERC721.sol";
import {IERC4906} from "@openzeppelin/contracts/interfaces/IERC4906.sol";

contract MyNFT is IERC4906, BaseERC721 {
    uint256 private _tokenCounter;

    mapping(uint256 tokenId => string) private _tokenURIs;

    constructor(string memory name, string memory symbol) BaseERC721(name, symbol) {
        _tokenCounter = 0;
    }

    // Interface ID as defined in ERC-4906. This does not correspond to a traditional interface ID as ERC-4906 only
    // defines events and does not include any external function.
    bytes4 private constant ERC4906_INTERFACE_ID = bytes4(0x49064906);

    /**
     * @dev See {IERC165-supportsInterface}
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(BaseERC721, IERC165) returns (bool) {
        return interfaceId == ERC4906_INTERFACE_ID || super.supportsInterface(interfaceId);
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        _requireOwned(tokenId);

        string memory _tokenURI = _tokenURIs[tokenId];
        string memory base = _baseURI();

        // If there is no base URI, return the token URI.
        if (bytes(base).length == 0) {
            return _tokenURI;
        }
        // If both are set, concatenate the baseURI and tokenURI (via string.concat).
        if (bytes(_tokenURI).length > 0) {
            return string.concat(base, _tokenURI);
        }

        return super.tokenURI(tokenId);
    }

    /**
     * @dev Sets `_tokenURI` as the tokenURI of `tokenId`.
     *
     * Emits {MetadataUpdate}.
     */
    function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal virtual {
        _tokenURIs[tokenId] = _tokenURI;
        emit MetadataUpdate(tokenId);
    }

    string private _baseTokenURI;

    function _baseURI() internal view virtual override returns (string memory) {
        //    function _baseURI() internal view virtual returns (string memory) {

        return _baseTokenURI;
    }

    function setBaseURI(string calldata newBaseTokenURI) public {
        _baseTokenURI = newBaseTokenURI;
    }

    function mint(address to, string memory _tokenURI) public returns (uint256) {
        _tokenCounter += 1;
        uint256 tokenId = _tokenCounter;
        super._mint(to, tokenId);
        _setTokenURI(tokenId, _tokenURI);
        return tokenId;
    }
}
