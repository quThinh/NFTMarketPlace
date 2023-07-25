import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { ethers } from "hardhat";

import {
    MarketPlace__factory,
    MarketPlace,
    ERC721Token__factory,
    ERC721Token,
    INFT__factory,
    INFT,
    ERC20Token,
    ERC20Token__factory,
} from "../typechain-types";
import { BigNumber, Signer } from "ethers";

describe("MarketPlace", () => {
    let account1: SignerWithAddress;
    let account2: SignerWithAddress;
    let mockERC20: ERC20Token;
    let mockToken: ERC721Token;
    let marketPlace: MarketPlace;
    let address0 = "0x0000000000000000000000000000000000000000";
    const higherBidPrice = ethers.utils.parseEther("3");
    beforeEach(async () => {
        const accounts: SignerWithAddress[] = await ethers.getSigners();
        account1 = accounts[0];
        account2 = accounts[1];
        // const MockTokenFactory: ERC20Token__factory = <ERC20Token__factory>(
        const MockTokenFactory: ERC721Token__factory = <ERC721Token__factory>(
            await ethers.getContractFactory("ERC721Token")
        );
        const MockERC20Factory: ERC20Token__factory = <ERC20Token__factory>(
            await ethers.getContractFactory("ERC20Token")
        );
        mockToken = <ERC721Token>await MockTokenFactory.deploy("BaseURI");
        mockERC20 = <ERC20Token>await MockERC20Factory.deploy();
        const marketPlaceFactory: MarketPlace__factory =
            await ethers.getContractFactory("MarketPlace");
        marketPlace = await marketPlaceFactory.deploy();
        await mockToken.safeMint(account1.address, "");
        await mockToken.safeMint(account2.address, "");
        await mockERC20.mint(account2.address, ethers.utils.parseEther("3"));
    });

    describe("Deployment", () => {
        it("Should deploy successfully", async () => {
            expect(await marketPlace.admin()).to.equal(account1.address);
        });
    });
    describe("Should ask successfully", () => {
        it("Should create ask successfully", async () => {
            await mockToken.approve(marketPlace.address, 1);
            const tx = await marketPlace
                .connect(account1)
                .createAsk(mockToken.address, 1, account2.address, 2, address0);
            const asks = await marketPlace.asks(mockToken.address, 1);
            expect(asks.exist).to.equal(true);
            expect(asks.seller).to.equal(account1.address);
            expect(asks.to).to.equal(account2.address);
            expect(asks.price).to.equal(2);
            expect(asks.tokenPayment).to.equal(address0);
            expect(asks.nftAddress).to.equal(mockToken.address);
            expect(asks.tokenId).to.equal(1);
        });
        it("Should accept ask successfully", async () => {
            const tx1 = await mockToken.approve(marketPlace.address, 1);
            tx1.wait();
            await marketPlace
                .connect(account1)
                .createAsk(mockToken.address, 1, account2.address, 2, address0);
            const ask = await marketPlace.asks(mockToken.address, 1);
            const treasury = await marketPlace.treasury(ask.seller, address0);
            const tx = await marketPlace
                .connect(account2)
                .acceptAsk(mockToken.address, 1, { value: 2 });
            const owner = await mockToken.ownerOf(1);
            const treasuryAfter = await marketPlace.treasury(ask.seller, address0);
            expect(tx).to.changeEtherBalance([account1, marketPlace], [-2, 2]);
            expect(treasuryAfter).to.equal(treasury.add(2));
            expect(owner).to.equal(account2.address);
        });
    });

    describe("Should bid successfully", () => {
        it("Should create auction successfully", async () => {
            await mockToken.approve(marketPlace.address, 1);
            const tx = await marketPlace
                .connect(account1)
                .createAuction(mockToken.address, 1, 2, mockERC20.address);
            const auctionId = await marketPlace.nftToAuctionId(mockToken.address, 1);
            const auction = await marketPlace.idToAuction(auctionId);
            expect(auction.id).to.equal(auctionId);
            expect(auction.exist).to.equal(true);
            expect(auction.seller).to.equal(account1.address);
            expect(auction.price).to.equal(2);
            expect(auction.tokenPayment).to.equal(mockERC20.address);
            expect(auction.nftAddress).to.equal(mockToken.address);
            expect(auction.tokenId).to.equal(1);
            expect(await marketPlace.auctionId()).to.equal(ethers.BigNumber.from(1))
        });
        it("Should delete auction successfully", async () => {
            await mockToken.approve(marketPlace.address, 1);
            await marketPlace
                .connect(account1)
                .createAuction(mockToken.address, 1, 2, mockERC20.address);
            const tx = await marketPlace
                .connect(account1)
                .deleteAuction(1);
            const auctionId = await marketPlace.nftToAuctionId(mockToken.address, 1);
            const auction = await marketPlace.idToAuction(auctionId);
            expect(auction.id).to.equal(0);
            expect(auction.exist).to.equal(false);
            expect(auction.seller).to.equal(address0);
            expect(auction.price).to.equal(0);
            expect(auction.tokenPayment).to.equal(address0);
            expect(auction.nftAddress).to.equal(address0);
            expect(auction.tokenId).to.equal(0);
            expect(await marketPlace.auctionId()).to.equal(ethers.BigNumber.from(1))
        });
        it("Should create bid successfully", async () => {
            await mockToken.approve(marketPlace.address, 1);
            await marketPlace
                .connect(account1)
                .createAuction(mockToken.address, 1, 2, mockERC20.address);
            const treasuryBefore = await marketPlace.treasury(account2.address, mockERC20.address);

            await mockERC20.connect(account2).approve(marketPlace.address, 444);
            const tx = await marketPlace
                .connect(account2)
                .createBid(mockToken.address, 1, 2, mockERC20.address);
            const bid = await marketPlace.idToBid(1);
            const treasury = await marketPlace.treasury(bid.buyer, mockERC20.address);
            expect(bid.id).to.equal(ethers.BigNumber.from(1));
            expect(bid.price).to.equal(2);
            expect(bid.buyer).to.equal(account2.address);
            expect(bid.tokenPayment).to.equal(mockERC20.address);
            expect(bid.nftAddress).to.equal(mockToken.address);
            expect(bid.tokenId).to.equal(1);
            expect(bid.auctionId).to.equal(ethers.BigNumber.from(1));
            expect(await marketPlace.bidId()).to.equal(1);
            expect(tx).to.changeEtherBalance(
                [account1, marketPlace],
                [higherBidPrice.mul(-1), higherBidPrice],
            );
            expect(treasury).to.equal(
                treasuryBefore.add(ethers.BigNumber.from(2)),
            );
        });
        it("Should accept bid successfully", async () => {
            await mockToken.approve(marketPlace.address, 1);
            await marketPlace
                .connect(account1)
                .createAuction(mockToken.address, 1, 2, mockERC20.address);

            await mockERC20.connect(account2).approve(marketPlace.address, 444);
            await marketPlace
                .connect(account2)
                .createBid(mockToken.address, 1, 2, mockERC20.address);

            const treasuryBefore = await marketPlace.treasury(account1.address, mockERC20.address);
            await marketPlace
                .connect(account1)
                .acceptBid(mockToken.address, 1, 1);

            const idToBid = await marketPlace.idToBid(1);
            const auctionId = await marketPlace.nftToAuctionId(mockToken.address, 1);
            const idToAuction = await marketPlace.idToAuction(auctionId);
            expect(idToBid.id).to.equal(ethers.BigNumber.from(0));
            expect(auctionId).to.equal(ethers.BigNumber.from(0));
            expect(idToAuction.id).to.equal(0);

            const treasury = await marketPlace.treasury(
                account1.address, mockERC20.address
            );
            expect(treasury).to.equal(
                treasuryBefore.add(ethers.BigNumber.from(2)),
            )
            expect(await mockToken.ownerOf(1)).to.equal(account2.address);
        });
    });

    describe("Should sell successfully", () => {
        it("Should list to sell successfully", async () => {
            await mockToken.approve(marketPlace.address, 1);
            await marketPlace
                .connect(account1)
                .listSell(mockToken.address, 1, 2, mockERC20.address);
            const id = await marketPlace.nftToSellId(mockToken.address, 1);
            const sell = await marketPlace.idToSell(id);
            expect(id).to.equal(1);
            expect(sell.id).to.equal(1);
            expect(sell.exist).to.equal(true);
            expect(sell.seller).to.equal(account1.address);
            expect(sell.price).to.equal(2);
            expect(sell.tokenId).to.equal(1);
            expect(sell.nftAddress).to.equal(mockToken.address);
            expect(sell.tokenPayment).to.equal(mockERC20.address);
        });
        it("Should promptBuy successfully", async () => {
            await mockToken.approve(marketPlace.address, 1);
            await marketPlace
                .connect(account1)
                .listSell(mockToken.address, 1, 2, mockERC20.address);
            const treasuryBefore = await marketPlace.treasury(account1.address, mockERC20.address);
            await mockERC20.connect(account2).approve(marketPlace.address, 444);
            const tx = await marketPlace
                .connect(account2)
                .promptBuy(1);
            const treasury = await marketPlace.treasury(account1.address, mockERC20.address);
            const idToSell = await marketPlace.idToSell(1);
            const nftToSellId = await marketPlace.nftToSellId(mockToken.address, 1);
            expect(tx).to.changeTokenBalance(
                mockERC20,
                [account1, marketPlace], [-2, 2]
            );
            expect(await mockToken.ownerOf(1)).to.equal(account2.address);
            expect(treasury).to.equal(treasuryBefore.add(2));
            expect(idToSell.id).to.equal(0);
            expect(nftToSellId).to.equal(0);
        });
    });
});
