// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MyNFT is ERC721URIStorage, Ownable {
    uint256 private _tokenId;

    function currentTokenId() internal view returns (uint256) {
        return _tokenId;
    }

    function incrementTokenId() internal {
        _tokenId += 1;
    }

    constructor() ERC721("TerryNFT", "TNFT") Ownable(msg.sender) {}

    // 铸造新的 NFT
    function mintNFT(address recipient, string memory tokenURI) public onlyOwner returns (uint256) {
        incrementTokenId();
        uint256 newTokenId = currentTokenId();

        _mint(recipient, newTokenId);
        _setTokenURI(newTokenId, tokenURI);

        return newTokenId;
    }

    // 获取当前 tokenId
    function getCurrentTokenId() public view returns (uint256) {
        return _tokenId;
    }
}
