// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract AntiMEVToken is ERC20, Ownable {

    struct TradeState {
        uint256 lastBlock;
        int8 lastDirection; // +1 = buy, -1 = sell
    }

    // pool => trade state
    mapping(address => TradeState) private poolState;

    uint256 public cooldownBlocks;

    // Explicitly supported AMM pool (single-pool scope)
    address public immutable ammPool;

    error DirectionalCooldownActive();

    constructor(
        string memory name_,
        string memory symbol_,
        address _ammPool,
        uint256 _cooldownBlocks
    ) ERC20(name_, symbol_) Ownable(msg.sender) {
        require(_ammPool != address(0), "Invalid pool");
        require(_cooldownBlocks > 0, "Invalid cooldown");

        ammPool = _ammPool;
        cooldownBlocks = _cooldownBlocks;
    }

    function setCooldown(uint256 newCooldown) external onlyOwner {
        require(newCooldown > 0, "Invalid cooldown");
        cooldownBlocks = newCooldown;
    }

    /* ---------------------------------------------------------- */
    /*                  CORE ANTI-SANDWICH LOGIC                  */
    /* ---------------------------------------------------------- */

    function _update(
        address from,
        address to,
        uint256 amount
    ) internal override {

        // Only enforce when interacting with the AMM pool
        if (from == ammPool || to == ammPool) {

            int8 currentDirection =
                (to == ammPool) ? int8(-1) : int8(+1); // sell : buy

            TradeState storage state = poolState[ammPool];

            if (
                state.lastDirection != 0 &&
                state.lastDirection != currentDirection &&
                block.number - state.lastBlock < cooldownBlocks
            ) {
                revert DirectionalCooldownActive();
            }

            // Update pool-level state
            state.lastDirection = currentDirection;
            state.lastBlock = block.number;
        }

        super._update(from, to, amount);
    }

    /* ---------------------------------------------------------- */
    /*                       VIEW HELPERS                         */
    /* ---------------------------------------------------------- */

    function getPoolState()
        external
        view
        returns (int8 direction, uint256 lastBlock)
    {
        TradeState memory s = poolState[ammPool];
        return (s.lastDirection, s.lastBlock);
    }
}
