// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";


contract NFTMarket is Ownable, EIP712 {
    string public marketName;

    /**
     * @dev Mismatched signature.
     */
    error ERC2612InvalidSigner(address signer, address owner);

    bytes32 private constant PERMIT_TYPEHASH = keccak256("permitBuy(address owner, uint256 tokenId, address authorizedBuyer)");

    // 上架ID 自增
    uint256 private _listingIds;
    function currentListingId() public view returns(uint256) {
        return _listingIds;
    }

    function incrementListingId() internal {
        _listingIds++;
    }

    IERC20 public paymentToken; // 用于购买的 ERC-20 代币
    IERC721 public nftContract; // NFT 合约

    struct Listing {
        uint256 listingId; // 唯一标识
        uint256 tokenId;   // NFT 的 tokenId
        address seller;    // 卖家地址
        uint256 price;     // 价格（以 ERC-20 代币计）
        bool active;       // 是否仍在出售
        Policy policy;      // 是否需要通过离线白名单接口购买
    }

    enum Policy { normal, permitWhitelist }

    mapping(uint256 => Listing) public listings; // listingId 到 Listing 的映射

    event NFTListed(uint256 indexed listingId, uint256 indexed tokenId, address seller, uint256 price);
    event NFTPurchased(uint256 indexed listingId, uint256 indexed tokenId, address buyer, uint256 price);
    event ListingCancelled(uint256 indexed listingId);

    constructor(string memory _marketName, address _nftContract, address _paymentToken) Ownable() EIP712(_marketName, "1") {
        marketName = _marketName;
        nftContract = IERC721(_nftContract);
        paymentToken = IERC20(_paymentToken);
    }

    // 列出 NFT 出售
    function listNFTWithPolicy(uint256 tokenId, uint256 price, Policy policy) external {
        require(price > 0, "Price must be greater than zero");
        require(nftContract.ownerOf(tokenId) == msg.sender, "You must own the NFT");
        require(nftContract.isApprovedForAll(msg.sender, address(this)) ||
        nftContract.getApproved(tokenId) == address(this),
            "Market must be approved to transfer NFT");

        incrementListingId();
        uint256 listingId = currentListingId();

        listings[listingId] = Listing({
            listingId: listingId,
            tokenId: tokenId,
            seller: msg.sender,
            price: price,
            active: true,
            policy: policy
        });

        emit NFTListed(listingId, tokenId, msg.sender, price);
    }

    // 购买 NFT
    function buyNFT(uint256 listingId) external {
        Listing storage listing = listings[listingId];
        require(listing.policy == Policy.normal, "Offchain signature authorization is required");
        require(listing.active, "Listing is not active");
        require(paymentToken.balanceOf(msg.sender) >= listing.price, "Insufficient ERC-20 balance");
        require(paymentToken.allowance(msg.sender, address(this)) >= listing.price,
            "Market must be approved to spend ERC-20 tokens");

        // 转移 ERC-20 代币给卖家
        require(paymentToken.transferFrom(msg.sender, listing.seller, listing.price),
            "ERC-20 transfer failed");

        // 转移 NFT 给买家
        nftContract.safeTransferFrom(listing.seller, msg.sender, listing.tokenId);

        // 标记为已售
        listing.active = false;

        emit NFTPurchased(listingId, listing.tokenId, msg.sender, listing.price);
    }

    // 取消列出
    function cancelListing(uint256 listingId) external {
        Listing storage listing = listings[listingId];
        require(listing.active, "Listing is not active");
        require(listing.seller == msg.sender, "Only seller can cancel");

        listing.active = false;
        emit ListingCancelled(listingId);
    }

    // 查看当前 listingId
    function getCurrentListingId() external view returns (uint256) {
        return currentListingId();
    }

    // 查看指定 listing 的详情
    function getListing(uint256 listingId) external view returns (Listing memory) {
        return listings[listingId];
    }

    function permitBuy(uint256 listingId, uint8 v, bytes32 r, bytes32 s) external {
        Listing storage listing = listings[listingId];
        require(listing.policy == Policy.permitWhitelist, "Offchain signature authorization is not required");
        require(listing.active, "Listing is not active");
        require(paymentToken.balanceOf(msg.sender) >= listing.price, "Insufficient ERC-20 balance");
        require(paymentToken.allowance(msg.sender, address(this)) >= listing.price,
            "Market must be approved to spend ERC-20 tokens");

        // 根据标准获取Hash
        bytes32 structHash = keccak256(abi.encode(PERMIT_TYPEHASH, listing.seller, listing.tokenId, msg.sender));
        bytes32 hash = _hashTypedDataV4(structHash);

        address signer = ECDSA.recover(hash, v, r, s);
        if (signer != listing.seller) {
            revert ERC2612InvalidSigner(signer, listing.seller);
        }

        // 转移 ERC-20 代币给卖家
        require(paymentToken.transferFrom(msg.sender, listing.seller, listing.price),
            "ERC-20 transfer failed");

        // 转移 NFT 给买家
        nftContract.safeTransferFrom(listing.seller, msg.sender, listing.tokenId);

        // 标记为已售
        listing.active = false;

        emit NFTPurchased(listingId, listing.tokenId, msg.sender, listing.price);
    }
}