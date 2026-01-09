// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title AntiMEVToken with Context-Aware Directional Constraint (CADC)
/// @notice Single-pool CADC: execution context C = (T, P) with P = ammPool.
contract CADC is ERC20, Ownable {
    struct TradeState {
        uint256 lastBlock;
        int8 lastDirection; // +1 = buy, -1 = sell, 0 = uninitialized
    }

    // Single execution context C = (T, ammPool)
    TradeState private poolState;

    // Exploitation window k (in blocks)
    uint256 public cooldownBlocks;

    // Explicitly supported AMM pool (single-pool scope)
    address public immutable ammPool;

    error DirectionalCooldownActive();
    error InvalidPool();
    error InvalidCooldown();

    /// @param name_ Token name
    /// @param symbol_ Token symbol
    /// @param _ammPool AMM pool address P
    /// @param _cooldownBlocks Exploitation window k in blocks
    /// @param initialSupply Initial supply to mint to the deployer
    constructor(
        string memory name_,
        string memory symbol_,
        address _ammPool,
        uint256 _cooldownBlocks,
        uint256 initialSupply
    ) ERC20(name_, symbol_) Ownable(msg.sender) {
        if (_ammPool == address(0)) revert InvalidPool();
        if (_cooldownBlocks == 0) revert InvalidCooldown();

        ammPool = _ammPool;
        cooldownBlocks = _cooldownBlocks;

        // Mint initial supply to the deployer (owner)
        if (initialSupply > 0) {
            _mint(msg.sender, initialSupply);
        }
    }
    
    function setCooldown(uint256 newCooldown) external onlyOwner {
        if (newCooldown == 0) revert InvalidCooldown();
        cooldownBlocks = newCooldown;
    }

    /* ---------------------------------------------------------- */
    /* CORE CADC ANTI-SANDWICH LOGIC                             */
    /* ---------------------------------------------------------- */

    function _update(
        address from,
        address to,
        uint256 amount
    ) internal override {
        // Only enforce when interacting with the AMM pool (context C = (T, ammPool))
        if (from == ammPool || to == ammPool) {
            // to == ammPool  => user -> pool: sell T
            // from == ammPool => pool -> user: buy T
            int8 currentDirection = (to == ammPool) ? int8(-1) : int8(1); // ✅ FIXED: +1

            TradeState storage state = poolState;

            // If state.lastDirection == 0, this is the first trade: no constraint.
            if (
                state.lastDirection != 0 &&
                state.lastDirection != currentDirection &&
                block.number - state.lastBlock < cooldownBlocks
            ) {
                revert DirectionalCooldownActive();
            }

            // Update context state (C = (T, ammPool))
            state.lastDirection = currentDirection;
            state.lastBlock = block.number;
        }

        // Perform the ERC20 state changes
        super._update(from, to, amount);
    }

    /* ---------------------------------------------------------- */
    /* VIEW HELPERS                                               */
    /* ---------------------------------------------------------- */

    function getPoolState()
        external
        view
        returns (int8 direction, uint256 lastBlock)
    {
        TradeState memory s = poolState;
        return (s.lastDirection, s.lastBlock);
    }
}
