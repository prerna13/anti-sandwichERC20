// test/sandwich.test.js
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("AntiMEVToken – Sandwich Attack Tests", function () {
    let token, pool;
    let owner, attacker1, attacker2, victim;

    beforeEach(async () => {
        [owner, attacker1, attacker2, victim] = await ethers.getSigners();

        const Pool = await ethers.getContractFactory("MockPool");
        pool = await Pool.deploy();

        const Token = await ethers.getContractFactory("AntiMEVToken");
        token = await Token.deploy(
            "AntiMEV",
            "AMV",
            pool.address,
            3 // k = 3 blocks
        );

        // mint tokens
        await token.transfer(attacker1.address, 1000);
        await token.transfer(attacker2.address, 1000);
        await token.transfer(victim.address, 1000);
    });

    /* -------------------------------------------------- */
    /* Same-address sandwich (same block)                 */
    /* -------------------------------------------------- */
    it("Blocks same-address sandwich attack", async () => {
        // frontrun: attacker sells
        await token.connect(attacker1).transfer(pool.address, 100);

        // victim trade
        await token.connect(victim).transfer(pool.address, 50);

        // backrun: attacker buys (reverse direction)
        await expect(
            token.connect(attacker1).transferFrom(pool.address, attacker1.address, 100)
        ).to.be.revertedWith("DirectionalCooldownActive");
    });

    /* -------------------------------------------------- */
    /* Multi-address sandwich                             */
    /* -------------------------------------------------- */
    it("Blocks multi-address sandwich attack", async () => {
        // frontrun by attacker1
        await token.connect(attacker1).transfer(pool.address, 100);

        // victim trade
        await token.connect(victim).transfer(pool.address, 50);

        // backrun by attacker2
        await expect(
            token.connect(attacker2).transferFrom(pool.address, attacker2.address, 100)
        ).to.be.revertedWith("DirectionalCooldownActive");
    });

    /* -------------------------------------------------- */
    /* k-block delayed sandwich                           */
    /* -------------------------------------------------- */
    it("Blocks k-block delayed sandwich attack", async () => {
        await token.connect(attacker1).transfer(pool.address, 100);

        // advance 2 blocks (< k)
        await ethers.provider.send("evm_mine");
        await ethers.provider.send("evm_mine");

        await expect(
            token.connect(attacker1).transferFrom(pool.address, attacker1.address, 100)
        ).to.be.reverted;
    });

    /* -------------------------------------------------- */
    /* Legitimate reversal after cooldown                 */
    /* -------------------------------------------------- */
    it("Allows reversal after cooldown window", async () => {
        await token.connect(attacker1).transfer(pool.address, 100);

        // advance k blocks
        for (let i = 0; i < 3; i++) {
            await ethers.provider.send("evm_mine");
        }

        await expect(
            token.connect(attacker1).transferFrom(pool.address, attacker1.address, 100)
        ).to.not.be.reverted;
    });
});
