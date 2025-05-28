// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

/**
 * @title GobEmissionEstimator
 * @notice Estimates the epoch at which the Gob token's primary weekly emission is expected to fall below the TAIL_START threshold (890e18).
 * @dev This contract provides a pure calculation based on the emission logic defined in the Minter.sol contract.
 * It assumes "tail emission rate 890 a week" refers to when the Minter.sol#weekly variable,
 * which governs emissions before the tail phase, drops below Minter.sol#TAIL_START.
 * An epoch's emissions are calculated, and then that value is checked to see if it's below the threshold,
 * determining if that epoch operates in tail mode.
 * Epochs are 0-indexed. Epoch 0 is the first epoch.
 */
contract GobEmissionEstimator {

    uint256 public constant INITIAL_WEEKLY_EMISSION = 1000 * 1e18; // Based on Minter.sol's `weekly` state variable
    uint256 public constant TAIL_START_THRESHOLD = 890 * 1e18;    // Based on Minter.sol's `TAIL_START` constant
    uint256 public constant WEEKLY_GROWTH_RATE = 10300;           // 1.03 represented as 10300 / MAX_BPS
    uint256 public constant WEEKLY_DECAY_RATE = 9900;             // 0.99 represented as 9900 / MAX_BPS
    uint256 public constant MAX_BPS = 10000;
    uint256 public constant GROWTH_PHASE_EPOCHS = 15; // Epochs 0..14 are growth epochs (15 total)

    /**
     * @notice Calculates the 0-indexed epoch number which is the first to have its weekly emission fall below TAIL_START_THRESHOLD.
     * @dev Simulates epoch by epoch:
     * - Epoch 0 to Epoch 14 (15 epochs total): emissions grow.
     * - Epoch 15 onwards: emissions decay.
     * The function determines for which epoch its calculated emission value first meets the condition.
     * @return epochNumber The 0-indexed epoch number.
     */
    function getEpochForTailStart() public pure returns (uint256 epochNumber) {
        uint256 currentWeeklyEmissionBase = INITIAL_WEEKLY_EMISSION; // Represents emission value *before* current epoch's calc
        uint256 epoch = 0;

        uint256 maxEpochs = 100; // Safety break

        // Special case: If initial emission itself is already below threshold for epoch 0.
        // The prompt's logic calculates for epoch 0 first, then checks.
        // If INITIAL_WEEKLY_EMISSION is the base for epoch 0's calculation, then the first calculated
        // emission (emissionForThisEpoch) will be based on INITIAL_WEEKLY_EMISSION * rate.
        // This differs if INITIAL_WEEKLY_EMISSION itself is considered "epoch 0's emission".
        // The new logic implies INITIAL_WEEKLY_EMISSION is a base, and epoch 0's emission is derived from it.

        // Let's strictly follow the new loop structure provided:
        // currentWeeklyEmissionBase is used to calculate emissionForThisEpoch (for current 'epoch')
        // then emissionForThisEpoch is checked.

        while (epoch < maxEpochs) {
            uint256 emissionForThisEpoch;

            // For epoch 0, currentWeeklyEmissionBase is INITIAL_WEEKLY_EMISSION.
            // The rate (growth/decay) is applied to this base to get epoch 0's actual emission.
            if (epoch < GROWTH_PHASE_EPOCHS) { // Applies to epoch 0..14
                emissionForThisEpoch = (currentWeeklyEmissionBase * WEEKLY_GROWTH_RATE) / MAX_BPS;
            } else { // Applies to epoch 15 onwards
                emissionForThisEpoch = (currentWeeklyEmissionBase * WEEKLY_DECAY_RATE) / MAX_BPS;
            }

            if (emissionForThisEpoch < TAIL_START_THRESHOLD) {
                return epoch; // This 'epoch' is the first one whose calculated emissions are below threshold
            }
            
            currentWeeklyEmissionBase = emissionForThisEpoch; // Update base for the next epoch's calculation
            epoch++;
        }
        
        revert("Calculation exceeded maximum epochs; tail start not found within limit.");
    }
}
