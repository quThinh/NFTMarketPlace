// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./NFT.sol";
import "./INFT.sol";
import "./MockERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "hardhat/console.sol";

contract MarketPlace is ReentrancyGuard {
    using Counters for Counters.Counter;
    using Address for address payable;
    using NFT for ERC721Token;
    using SafeERC20 for IERC20;
    struct Ask {
        bool exist;
        address seller;
        address to;
        uint256 price;
        address tokenPayment;
        address nftAddress;
        uint256 tokenId;
    }

    struct Auction {
        uint256 id;
        bool exist;
        address seller;
        uint256 price;
        address tokenPayment;
        address nftAddress;
        uint256 tokenId;
    }

    struct Bid {
        uint256 id;
        uint256 price;
        address buyer;
        address tokenPayment;
        address nftAddress;
        uint256 tokenId;
        uint256 auctionId;
    }

    struct Sell {
        uint256 id;
        bool exist;
        address seller;
        uint256 price;
        address nftAddress;
        uint256 tokenId;
        address tokenPayment;
    }
    mapping(address => mapping(uint256 => Ask)) public asks;

    //mapping id to auction
    mapping(uint256 => Auction) public idToAuction;

    //mapping nft to auctionId
    mapping(address => mapping(uint256 => uint256)) public nftToAuctionId;

    //mapping bidId to auctionId
    mapping(uint256 => uint256) public bidIdToAuctionId;

    //mapping bidId to auctionId
    mapping(uint256 => Bid) public idToBid;

    //mapping nft to sellId
    mapping(address => mapping(uint256 => uint256)) public nftToSellId;

    //mapping id to Sell
    mapping(uint256 => Sell) public idToSell;

    mapping(address => mapping(uint256 => Sell)) public sells;
    mapping(address => mapping(uint256 => address)) public sellOwner;
    mapping(address => mapping(address => uint256)) public treasury;
    address public admin;
    Counters.Counter public auctionId;
    Counters.Counter public bidId;
    Counters.Counter public sellId;

    constructor() {
        admin = msg.sender;
    }

    function createAsk(
        ERC721Token nft,
        uint256 tokenId,
        address to,
        uint256 price,
        address tokenPayment
    ) external {
        address nftAddress = address(nft);
        require(
            nft.quantityOf(msg.sender, tokenId) == 1,
            "NFT quantity must be at least 1"
        );
        asks[nftAddress][tokenId] = Ask({
            exist: true,
            seller: msg.sender,
            to: to,
            price: price,
            tokenPayment: tokenPayment,
            nftAddress: nftAddress,
            tokenId: tokenId
        });
    }

    function acceptAsk(
        ERC721Token nft,
        uint256 tokenId
    ) external payable nonReentrant {
        address nftAddress = address(nft);
        Ask memory ask = asks[nftAddress][tokenId];
        require(ask.exist, "Ask not exist");
        require(ask.to == msg.sender, "Ask not exist");
        require(ask.seller != msg.sender, "Can not accept own ask");
        if (ask.tokenPayment == address(0)) {
            require(msg.value >= ask.price, "Not enough value");
        } else {
            IERC20(ask.tokenPayment).safeTransfer(address(this), ask.price);
        }
        treasury[ask.seller][ask.tokenPayment] += ask.price;
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
        uint256 price,
        address tokenPayment
    ) external payable nonReentrant {
        address nftAddress = address(nft);
        uint256 id = nftToAuctionId[nftAddress][tokenId];
        Auction memory auction = idToAuction[id];
        require(
            auction.exist == true,
            "Owner have not created auction for this NFT yet"
        );
        require(auction.seller == msg.sender, "Can not bid your own auction");
        if (auction.tokenPayment == address(0)) {
            require(msg.value == price, "Value must be equal to what was bid");
        } else {
            IERC20(auction.tokenPayment).safeTransfer(
                address(this),
                price
            );
        }
        idToBid[id] = Bid({
            id: bidId.current(),
            price: price,
            buyer: msg.sender,
            tokenPayment: tokenPayment,
            nftAddress: nftAddress,
            tokenId: tokenId,
            auctionId: id
        });

        bidId.increment();
        treasury[msg.sender][tokenPayment] += price;
    }

    function acceptBid(
        ERC721Token nft_,
        uint256 tokenId_,
        uint256 bidId_
    ) external {
        address nftAddress = address(nft_);
        uint256 auctionid = nftToAuctionId[nftAddress][tokenId_];
        require(bidIdToAuctionId[bidId_] == auctionid, "Bid not exist");

        Auction memory auction = idToAuction[auctionid];
        require(auction.exist, "Auction not exist");
        require(auction.seller == msg.sender, "Bid not yours");

        Bid memory bid = idToBid[bidId_];

        bool success = nft_.safeTransferFrom_(
            msg.sender,
            bid.buyer,
            tokenId_,
            new bytes(0)
        );
        require(success, "NFT transfer failed");
        treasury[msg.sender][bid.tokenPayment] += bid.price;
        delete idToBid[bidId_];
        delete nftToAuctionId[nftAddress][tokenId_];
        delete idToAuction[auctionid];
    }

    function cancelBid(
        ERC721Token nft_,
        uint256 tokenId_,
        uint256 bidId_
    ) external {
        address nftAddress = address(nft_);
        uint256 auctionid = nftToAuctionId[nftAddress][tokenId_];
        require(bidIdToAuctionId[bidId_] == auctionid, "Bid not exist");

        Auction memory auction = idToAuction[auctionid];
        require(auction.seller == msg.sender, "Bid not yours");
        Bid memory bid = idToBid[bidId_];

        treasury[msg.sender][bid.tokenPayment] += bid.price;

        delete idToBid[bidId_];
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

    function createAuction(
        ERC721Token nft,
        uint256 tokenId,
        uint256 firstPrice,
        address tokenPayment
    ) external {
        address nftAddress = address(nft);
        uint256 id = nftToAuctionId[nftAddress][tokenId];
        Auction memory auction = idToAuction[id];
        require(auction.exist == true, "You have created auction for this NFT");
        uint256 currentId = auctionId.current();
        idToAuction[currentId] = Auction({
            id: currentId,
            exist: true,
            seller: msg.sender,
            price: firstPrice,
            tokenPayment: tokenPayment,
            nftAddress: nftAddress,
            tokenId: tokenId
        });
        auctionId.increment();
    }

    function deleteAuction(ERC721Token nft, uint256 tokenId) external {
        address nftAddress = address(nft);
        uint256 id = nftToAuctionId[nftAddress][tokenId];
        Auction memory auction = idToAuction[id];
        require(auction.exist == true, "Auction not exist");
        require(auction.seller == msg.sender, "Not auction owner");

        delete nftToAuctionId[nftAddress][tokenId];
        delete idToAuction[id];
    }

    function listSell(
        ERC721Token nft_,
        uint256 tokenId_,
        uint256 price_,
        address tokenPayment_
    ) external {
        address nftAddress = address(nft_);
        uint256 id = nftToSellId[nftAddress][tokenId_];
        Sell memory sell = idToSell[id];
        require(sell.exist == false, "You have listed sell this NFT");
        nftToSellId[nftAddress][tokenId_] = sellId.current();
        idToSell[sellId.current()] = Sell({
            id: sellId.current(),
            exist: true,
            seller: msg.sender,
            price: price_,
            tokenId: tokenId_,
            nftAddress: nftAddress,
            tokenPayment: tokenPayment_
        });
        sellId.increment();
    }

    function unListSell(uint256 id) external {
        Sell memory sell = idToSell[id];
        require(sell.exist == true, "Sell not exist");
        require(sell.seller == msg.sender, "Not sell owner");
        bool success = ERC721Token(sell.nftAddress).safeTransferFrom_(
            address(this),
            msg.sender,
            sell.tokenId,
            new bytes(0)
        );
        require(success, "NFT transfer failed");
        delete idToSell[id];
        delete nftToSellId[sell.nftAddress][sell.tokenId];
    }

    function promptBuy(uint256 sellId_) external payable nonReentrant {
        Sell memory sell = idToSell[sellId_];
        require(sell.exist == true, "Sell not exist");
        require(sell.seller == msg.sender, "Can not buy your own sell");

        if (sell.tokenPayment == address(0)) {
            require(
                msg.value >= sell.price,
                "Value must be equal to or bigger than the price"
            );
        } else {
            IERC20(sell.tokenPayment).safeTransfer(address(this), sell.price);
        }

        bool success = ERC721Token(sell.nftAddress).safeTransferFrom_(
            sell.seller,
            msg.sender,
            sell.tokenId,
            new bytes(0)
        );
        require(success, "NFT transfer failed");

        treasury[sell.seller][sell.tokenPayment] += sell.price;

        delete idToSell[sellId_];
        delete nftToSellId[sell.nftAddress][sell.tokenId];
    }

    function withdraw(address token) external {
        uint256 balance = treasury[msg.sender][token];
        require(balance != 0, "Nothing to withdraw");
        if (token == address(0)) {
            payable(address(this)).sendValue(balance);
        } else {
            IERC20(token).safeTransfer(msg.sender, balance);
        }
        treasury[msg.sender][token] = 0;
    }
}
