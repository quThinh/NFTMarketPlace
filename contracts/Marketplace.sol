// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./NFT.sol";
import "./INFT.sol";
import "./MockERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "hardhat/console.sol";

contract MarketPlace is ReentrancyGuard {
    using Address for address payable;
    using NFT for ERC721Token;
    struct Ask {
        bool exist;
        address seller;
        address to;
        uint256 price;
    }
    struct Bid {
        address buyer;
        uint256 price;
    }
    struct Sell {
        address seller;
        uint256 price;
    }
    mapping(address => mapping(uint256 => Ask)) public asks;
    mapping(address => mapping(uint256 => Bid)) public bids;
    mapping(address => mapping(uint256 => Sell)) public sells;
    mapping(address => mapping(uint256 => address)) public bidOwner;
    mapping(address => mapping(uint256 => address)) public sellOwner;
    mapping(address => uint256) public treasury;
    address public admin;

    constructor() {
        admin = msg.sender;
    }

    function createAsk(
        ERC721Token nft,
        uint256 tokenId,
        address to,
        uint256 price
    ) external {
        address nftAddress = address(nft);
        require(
            nft.quantityOf(msg.sender, tokenId) == 1,
            "NFT quantity must be at least 1"
        );
        require(nft.getApproved(tokenId) == address(this), "Not approved yet");
        asks[nftAddress][tokenId] = Ask({
            exist: true,
            seller: msg.sender,
            to: to,
            price: price
        });
    }

    function acceptAsk(
        ERC721Token nft,
        uint256 tokenId
    ) external payable nonReentrant {
        address nftAddress = address(nft);
        Ask memory ask = asks[nftAddress][tokenId];
        require(ask.exist, "Ask does not exist");
        require(ask.seller != msg.sender, "Can not accept own ask");
        require(ask.to == msg.sender, "Ask not exist");
        require(msg.value >= ask.price, "Not enough value");

        treasury[ask.seller] += ask.price;
        if (bidOwner[nftAddress][tokenId] != address(0)) {
            treasury[bids[nftAddress][tokenId].buyer] += bids[nftAddress][
                tokenId
            ].price;
            delete bids[nftAddress][tokenId];
        }
        bool success = nft.safeTransferFrom_(
            ask.seller,
            ask.to,
            tokenId,
            new bytes(0)
        );
        require(success, "NFT transfer failed");
        delete asks[nftAddress][tokenId];
    }

    function createBid(
        ERC721Token nft,
        uint256 tokenId,
        uint256 price
    ) external payable nonReentrant {
        address nftAddress = address(nft);
        require(
            bidOwner[nftAddress][tokenId] != address(0),
            "Owner have not listed this NFT yet"
        );
        require(
            msg.value > bids[nftAddress][tokenId].price,
            "Value must bigger than previous bid"
        );
        require(msg.value == price, "Value must be equal to what was bid");
        bids[nftAddress][tokenId].buyer = msg.sender;
        bids[nftAddress][tokenId].price = msg.value;
        treasury[bids[nftAddress][tokenId].buyer] += price;
    }

    function acceptBid(ERC721Token nft, uint256 tokenId) external {
        address nftAddress = address(nft);
        require(
            bidOwner[nftAddress][tokenId] != address(0),
            "You have not listed this NFT yet"
        );
        require(nft.quantityOf(msg.sender, tokenId) == 1, "NFT is not yours");
        require(
            bids[nftAddress][tokenId].buyer != address(0),
            "No one bid yet"
        );

        bool success = nft.safeTransferFrom_(
            msg.sender,
            bids[nftAddress][tokenId].buyer,
            tokenId,
            new bytes(0)
        );
        treasury[bids[nftAddress][tokenId].buyer] -= bids[nftAddress][tokenId]
            .price;
        treasury[msg.sender] += bids[nftAddress][tokenId].price;
        require(success, "NFT transfer failed");
        delete asks[nftAddress][tokenId];
        delete bids[nftAddress][tokenId];
    }

    function cancelBid(ERC721Token nft, uint256 tokenId) external {
        address nftAddress = address(nft);
        require(bids[nftAddress][tokenId].buyer == msg.sender, "Bid not yours");
        require(
            bidOwner[nftAddress][tokenId] != address(0),
            "You have not listed this NFT yet"
        );
        treasury[msg.sender] += bids[nftAddress][tokenId].price;
        delete bids[nftAddress][tokenId];
    }

    function cancelAsk(ERC721Token nft, uint256 tokenId) external {
        address nftAddress = address(nft);
        require(asks[nftAddress][tokenId].exist, "Bid does not exist");
        require(
            asks[nftAddress][tokenId].seller == msg.sender,
            "Bid not yours"
        );
        delete asks[nftAddress][tokenId];
    }

    function listToBid(
        ERC721Token nft,
        uint256 tokenId,
        uint256 firstPrice
    ) external {
        address nftAddress = address(nft);
        require(
            sellOwner[nftAddress][tokenId] == address(0),
            "Unlisted sell this NFT first"
        );
        require(
            bidOwner[nftAddress][tokenId] == address(0),
            "You have listed bid this NFT"
        );
        bids[nftAddress][tokenId] = Bid({buyer: address(0), price: firstPrice});
        bidOwner[nftAddress][tokenId] = msg.sender;
    }

    function unListBid(ERC721Token nft, uint256 tokenId) external {
        address nftAddress = address(nft);
        require(bidOwner[nftAddress][tokenId] == msg.sender, "Not bid owner");
        bool success = nft.safeTransferFrom_(
            address(this),
            msg.sender,
            tokenId,
            new bytes(0)
        );
        require(success, "NFT transfer failed");
        delete bids[nftAddress][tokenId];
        bidOwner[nftAddress][tokenId] = address(0);
    }

    function listSell(
        ERC721Token nft,
        uint256 tokenId,
        uint256 price
    ) external {
        address nftAddress = address(nft);
        require(
            nft.getApproved(tokenId) == address(this),
            "Approved NFT first"
        );
        require(
            bidOwner[nftAddress][tokenId] == address(0),
            "Unlisted bid this NFT first"
        );
        require(
            sellOwner[nftAddress][tokenId] == address(0),
            "You have listed sell this NFT"
        );
        sellOwner[nftAddress][tokenId] = msg.sender;
        sells[nftAddress][tokenId] = Sell({seller: msg.sender, price: price});
    }

    function unListSell(ERC721Token nft, uint256 tokenId) external {
        address nftAddress = address(nft);
        require(sellOwner[nftAddress][tokenId] == msg.sender, "Not bid owner");
        bool success = nft.safeTransferFrom_(
            address(this),
            msg.sender,
            tokenId,
            new bytes(0)
        );
        require(success, "NFT transfer failed");
        delete sells[nftAddress][tokenId];
        bidOwner[nftAddress][tokenId] = address(0);
    }

    function promptBuy(
        ERC721Token nft,
        uint256 tokenId
    ) external payable nonReentrant {
        address nftAddress = address(nft);
        require(
            sellOwner[nftAddress][tokenId] != address(0),
            "No one listed sell this NFT yet"
        );
        Sell memory sell = sells[nftAddress][tokenId];
        require(
            msg.value >= sell.price,
            "Value must be equal to or bigger than the price"
        );
        bool success = nft.safeTransferFrom_(
            sell.seller,
            msg.sender,
            tokenId,
            new bytes(0)
        );
        require(success, "NFT transfer failed");
        treasury[sellOwner[nftAddress][tokenId]] += sell.price;
        delete sells[nftAddress][tokenId];
        delete bids[nftAddress][tokenId];
        sellOwner[nftAddress][tokenId] = address(0);
        bidOwner[nftAddress][tokenId] = address(0);
    }

    function withdraw() external {
        require(treasury[msg.sender] != 0, "Nothing to withdraw");
        payable(address(this)).sendValue(treasury[msg.sender]);
    }
}
