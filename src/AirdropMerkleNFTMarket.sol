// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract AirdropMerkleNFTMarket {
    IERC20 public token;
    IERC721 public nft;
    bytes32 public merkleRoot;

    struct Listing {
        address seller;
        uint256 tokenId;
        uint256 price; // 以 Token 计价, 白名单半价
    }

    mapping(uint256 => Listing) public listings;

    event Listed(address indexed seller, uint256 indexed tokenId, uint256 price);
    event Purchased(address indexed buyer, uint256 indexed tokenId, uint256 price);

    constructor(address _token, address _nft, bytes32 _merkleRoot) {
        token = IERC20(_token);
        nft = IERC721(_nft);
        merkleRoot = _merkleRoot;
    }

    // 上架 NFT
    function list(uint256 tokenId, uint256 price) external {
        require(nft.ownerOf(tokenId) == msg.sender, "Not owner");
        require(nft.getApproved(tokenId) == address(this), "Not approved");
        listings[tokenId] = Listing(msg.sender, tokenId, price);
        emit Listed(msg.sender, tokenId, price);
    }

    // permit 授权预支付
    function permitPrePay(address owner, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external {
        IERC20Permit(address(token)).permit(owner, address(this), value, deadline, v, r, s);
    }

    // 领取 NFT（需通过 Merkle 验证）
    function claimNFT(uint256 tokenId, bytes32[] calldata merkleProof) external {
        Listing memory listing = listings[tokenId];
        require(listing.seller != address(0), "Not listed");

        uint256 price = listing.price;
        // 检查白名单并应用 50% 折扣
        if (verifyWhitelist(msg.sender, merkleProof)) {
            price = price / 2;
        }

        // 转移 Token 和 NFT
        require(token.transferFrom(msg.sender, listing.seller, price), "Token transfer failed");
        nft.transferFrom(listing.seller, msg.sender, tokenId);

        delete listings[tokenId];
        emit Purchased(msg.sender, tokenId, price);
    }

    // Multicall 集成
    struct Call {
        bytes callData; // 只需 calldata，因为 target 是当前合约
    }

    function multicall(Call[] calldata calls) external returns (bytes[] memory results) {
        results = new bytes[](calls.length);
        for (uint256 i = 0; i < calls.length; i++) {
            (bool success, bytes memory result) = address(this).delegatecall(calls[i].callData);
            require(success, "Multicall: call failed");
            results[i] = result;
        }
    }

    // 验证白名单
    function verifyWhitelist(address user, bytes32[] calldata proof) internal view returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(user));
        return MerkleProof.verify(proof, merkleRoot, leaf);
    }
}
