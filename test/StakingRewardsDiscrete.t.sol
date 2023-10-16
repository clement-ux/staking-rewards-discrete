// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "forge-std/Test.sol";

import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";

import {StakingRewardsDiscrete} from "src/StakingRewardsDiscrete.sol";

contract StakingRewardsDiscreteTest is Test {
    MockERC20 public rewardToken;
    MockERC20 public stakingToken;

    StakingRewardsDiscrete public gaugeD;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    function setUp() public {
        // Setup realistic environment.
        vm.roll(18000000);
        vm.warp(1700000000);

        // Deploy tokens.
        rewardToken = new MockERC20("Reward Token", "REW", 18);
        stakingToken = new MockERC20("Staking Token", "STK", 18);

        // Deploy Staking contract.
        gaugeD = new StakingRewardsDiscrete(address(stakingToken), address(rewardToken));

        // Infinite approval.
        rewardToken.approve(address(gaugeD), type(uint256).max);
        vm.startPrank(alice);
        stakingToken.approve(address(gaugeD), type(uint256).max);
        changePrank(bob);
        stakingToken.approve(address(gaugeD), type(uint256).max);
        vm.stopPrank();
    }

    /// @dev This test show the behavior of the discrete staking rewards contract.
    /// As it is demonstrated in this test, if a user arrive 1 week after the first one
    /// they will have the same rewards as the first one. So this is not a suitable. 
    function test_Discrete() public {
        // Mint tokens.
        stakingToken.mint(address(alice), 1000);
        stakingToken.mint(address(bob), 1000);

        // Deposit.
        vm.startPrank(alice);
        gaugeD.stake(1000);
        vm.warp(1 weeks);
        changePrank(bob);
        gaugeD.stake(1000);
        vm.stopPrank();

        // Checks rewards index.
        assertEq(gaugeD.rewardIndex(), 0);
        assertEq(gaugeD.rewardIndexOf(address(this)), 0);

        // Deposit rewards.
        rewardToken.mint(address(this), 1000);
        gaugeD.updateRewardIndex(1000);

        vm.startPrank(alice);
        gaugeD.claim();
        changePrank(bob);
        gaugeD.claim();
        vm.stopPrank();

        // Checks balances.
        assertEq(rewardToken.balanceOf(address(alice)), rewardToken.balanceOf(address(bob)));
    }
}
