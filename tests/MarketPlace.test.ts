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
} from "../typechain-types";
import { BigNumber, Signer } from "ethers";

describe("MarketPlace", () => {
    let account1: SignerWithAddress;
    let account2: SignerWithAddress;
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
        mockToken = <ERC721Token>await MockTokenFactory.deploy("BaseURI");
        const marketPlaceFactory: MarketPlace__factory =
            await ethers.getContractFactory("MarketPlace");
        marketPlace = await marketPlaceFactory.deploy();
        await mockToken.safeMint(account1.address, "");
        await mockToken.safeMint(account2.address, "");
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
                .createAsk(mockToken.address, 1, account2.address, 1);
            const asks = await marketPlace.asks(mockToken.address, 1);
            expect(asks.exist).to.equal(true);
            expect(asks.seller).to.equal(account1.address);
            expect(asks.to).to.equal(account2.address);
            expect(asks.price).to.equal(1);
        });
        it("Should accept ask successfully", async () => {
            const tx1 = await mockToken.approve(marketPlace.address, 1);
            tx1.wait();
            await marketPlace
                .connect(account1)
                .createAsk(mockToken.address, 1, account2.address, 1);
            const tx = await marketPlace
                .connect(account2)
                .acceptAsk(mockToken.address, 1, { value: 1 });
            const ask = await marketPlace.asks(mockToken.address, 1);
            const treasury = await marketPlace.treasury(ask.seller);
            const owner = await mockToken.ownerOf(1);

            expect(tx).to.changeEtherBalance([account1, marketPlace], [-1, 1]);
            expect(treasury).to;
            expect(owner).to.equal(account2.address);
        });
    });

    describe("Should bid successfully", () => {
        it("Should list to bid successfully", async () => {
            await mockToken.approve(marketPlace.address, 1);
            const tx = await marketPlace
                .connect(account1)
                .listToBid(mockToken.address, 1, 2);
            const bid = await marketPlace.bids(mockToken.address, 1);
            const bidOwner = await marketPlace.bidOwner(mockToken.address, 1);
            expect(bid.buyer).to.equal(address0);
            expect(bid.price).to.equal(2);
            expect(bidOwner).to.equal(account1.address);
        });
        it("Should create bid successfully", async () => {
            await mockToken.approve(marketPlace.address, 1);
            const bidBefore = await marketPlace.bids(mockToken.address, 1);
            const treasuryBefore = await marketPlace.treasury(account2.address);
            await marketPlace
                .connect(account1)
                .listToBid(mockToken.address, 1, 2);
            const tx = await marketPlace
                .connect(account2)
                .createBid(mockToken.address, 1, higherBidPrice, {
                    value: higherBidPrice,
                });
            const bid = await marketPlace.bids(mockToken.address, 1);
            const treasury = await marketPlace.treasury(bid.buyer);
            expect(bid.buyer).to.equal(account2.address);
            expect(tx).to.changeEtherBalance(
                [account1, marketPlace],
                [higherBidPrice.mul(-1), higherBidPrice],
            );
            expect(treasury).to.equal(
                treasuryBefore.add(ethers.BigNumber.from(higherBidPrice)),
            );
        });
        it("Should accept bid successfully", async () => {
            await mockToken.approve(marketPlace.address, 1);

            await marketPlace
                .connect(account1)
                .listToBid(mockToken.address, 1, 2);
            await marketPlace
                .connect(account2)
                .createBid(mockToken.address, 1, higherBidPrice, {
                    value: higherBidPrice,
                });
            const bid = await marketPlace.bids(mockToken.address, 1);
            const treasuryAccount1 = await marketPlace.treasury(
                account1.address,
            );
            const treasuryAccount2 = await marketPlace.treasury(bid.buyer);
            const tx = await marketPlace.acceptBid(mockToken.address, 1);
            const owner = await mockToken.ownerOf(1);
            const treasuryAfterAccount1 = await marketPlace.treasury(
                account1.address,
            );
            const treasuryAfterAccount2 = await marketPlace.treasury(
                account2.address,
            );
            expect(owner).to.equal(account2.address);
            expect(treasuryAfterAccount1).to.equal(
                treasuryAccount1.add(ethers.BigNumber.from(higherBidPrice)),
            );
            expect(treasuryAfterAccount2).to.equal(
                treasuryAccount2.sub(ethers.BigNumber.from(higherBidPrice)),
            );
            expect(
                (await marketPlace.asks(mockToken.address, 1)).exist,
            ).to.equal(false);
            expect(
                (await marketPlace.bids(mockToken.address, 1)).buyer,
            ).to.equal(address0);
            expect(
                (await marketPlace.bids(mockToken.address, 1)).price,
            ).to.equal(ethers.BigNumber.from(0));
        });
    });

    describe("Should sell successfully", () => {
        it("Should list to sell successfully", async () => {
            await mockToken.approve(marketPlace.address, 1);
            await marketPlace
                .connect(account1)
                .listSell(mockToken.address, 1, 2);
            const sellOwner = await marketPlace.sellOwner(mockToken.address, 1);
            const sell = await marketPlace.sells(mockToken.address, 1);
            expect(sellOwner).to.equal(account1.address);
            expect(sell.seller).to.equal(account1.address);
            expect(sell.price).to.equal(2);
        });
        it("Should promptBuy successfully", async () => {
            await mockToken.approve(marketPlace.address, 1);
            await marketPlace
                .connect(account1)
                .listSell(mockToken.address, 1, 2);
            const sell = await marketPlace.sells(mockToken.address, 1);
            const treasuryBefore = await marketPlace.treasury(sell.seller);
            const tx = await marketPlace
                .connect(account2)
                .promptBuy(mockToken.address, 1, {
                    value: higherBidPrice,
                });
            const treasury = await marketPlace.treasury(sell.seller);
            expect(treasury).to.equal(treasuryBefore.add(2));
            expect(tx).to.changeEtherBalance([account2, marketPlace], [-2, 2]);
            expect(await mockToken.ownerOf(1)).to.equal(account2.address);
            expect(
                (await marketPlace.sells(mockToken.address, 1)).seller,
            ).to.equal(address0);
            expect(
                (await marketPlace.sells(mockToken.address, 1)).price,
            ).to.equal(ethers.BigNumber.from(0));
            expect(
                (await marketPlace.bids(mockToken.address, 1)).buyer,
            ).to.equal(address0);
            expect(
                (await marketPlace.bids(mockToken.address, 1)).price,
            ).to.equal(ethers.BigNumber.from(0));
            expect(await marketPlace.sellOwner(mockToken.address, 1)).to.equal(
                address0,
            );
            expect(await marketPlace.bidOwner(mockToken.address, 1)).to.equal(
                address0,
            );
        });
    });
});
