// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import "./MyERC20.sol";
import "./MyNFT.sol";

contract NFTMarket {
    BaseERC20 public _supportedToken;

    MyNFT public _nft;
    // supported all nft
    constructor(BaseERC20 _erc20, MyNFT _erc721) {
        _supportedToken = _erc20;
        _nft = _erc721;
    }

    struct Listing {
        address owner;
        uint256 price;
    }

    mapping(uint256 => Listing) public _listings;

    event List(address indexed user, uint256 indexed tokenId, uint amount);

    function list(uint256 tokenId, uint256 price) public {
        require(tokenId > 0, "Invalid token ID");
        require(price > 0, "Invalid price");
        require(_nft.ownerOf(tokenId) == msg.sender, "Not the owner of the NFT");
        require(_listings[tokenId].owner == address(0), "NFT already listed");

        _listings[tokenId] = Listing(msg.sender, price);
        emit List(_nft.ownerOf(tokenId), tokenId, price);
    }

    function buy(uint256 tokenId, uint256 bid) public {
        require(bid >= _listings[tokenId].price, "Insufficient payment");
        require(_listings[tokenId].owner != address(0), "NFT not listed");

        // Transfer the NFT from the owner to the buyer
        // Assuming you have a function to transfer the NFT
        _transferNFT(_listings[tokenId].owner, msg.sender, tokenId);

        // Transfer the payment to the owner, use myERC20
        // _payment(_listings[tokenId].owner, _listings[tokenId].price, msg.sender, bid);
        _supportedToken.transferFrom(msg.sender, _listings[tokenId].owner, _listings[tokenId].price);

        // Remove the listing
        delete _listings[tokenId];
        // _buy(msg.sender, bid, tokenId);
    }

    function _transferNFT(address from, address to, uint256 tokenId) public {
        _nft.transferFrom(from, to, tokenId);
    }

    function _payment(address nftSeller, uint256 price, address buyer, uint256 bid) public {
        _supportedToken.transfer(nftSeller, price);
        if (bid > price) {
            _supportedToken.transfer(buyer, (bid - price));
        }
    }

    function onErc20Received(address operator, address from, uint256 bid, bytes memory data) public returns (bool success) {
        uint256 tokenId = abi.decode(data, (uint256));
        // uint256 tokenId = 1;

        require(tokenId > 0, "Invalid token ID");

        // Listing memory listing = _listings[tokenId];
        // require(listing.price > 0, "NFT is not listed for sale");
        // require(tokenId == uint256(1), "token Id not one");
        require(_listings[tokenId].price > 0, "NFT is not listed for sale");

        _buy(operator, bid, tokenId);
        return true;
    }
    function _buy(address buyer, uint256 bid, uint256 tokenId) private{
        require(bid >= _listings[tokenId].price, "Insufficient payment");
        require(_listings[tokenId].owner != address(0), "NFT not listed");

        // Transfer the NFT from the owner to the buyer
        // Assuming you have a function to transfer the NFT
        _transferNFT(_listings[tokenId].owner, buyer, tokenId);

        // Transfer the payment to the owner, use myERC20
        _payment(_listings[tokenId].owner, _listings[tokenId].price, buyer, bid);

        // Remove the listing
        delete _listings[tokenId];
    }
}