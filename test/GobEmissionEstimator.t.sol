// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../contracts/GobEmissionEstimator.sol";

contract GobEmissionEstimatorTest is Test {
    GobEmissionEstimator public estimator;

    function setUp() public {
        estimator = new GobEmissionEstimator();
    }

    function test_getEpochForTailStart() public {
        uint256 expectedEpoch = 70;
        uint256 actualEpoch = estimator.getEpochForTailStart();
        assertEq(actualEpoch, expectedEpoch, "Epoch for tail start mismatch");
    }

    // Optional: Test the boundary condition for max epochs, expecting a revert.
    // This test requires adjusting the constants in a new GobEmissionEstimator deployment or a more complex setup.
    // For now, we will skip this to keep the test basic as per the plan.
    // function test_getEpochForTailStart_revertMaxEpochs() public {
    //     // To properly test this, we'd need to deploy a version of Estimator 
    //     // with extremely small INITIAL_WEEKLY_EMISSION or TAIL_START_THRESHOLD
    //     // or very small decay/growth factors to hit maxEpochs quickly, or allow setting maxEpochs.
    //     // For this exercise, we assume the main path test is sufficient.
    //     // vm.expectRevert(bytes("Calculation exceeded maximum epochs; tail start not found within limit."));
    //     // estimator.getEpochForTailStart(); // This would need a special estimator setup
    // }
}
