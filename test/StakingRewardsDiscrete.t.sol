// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import "forge-std/Test.sol";

import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";

import {StakingRewards} from "src/StakingRewards.sol";
import {StakingRewardsDiscrete} from "src/StakingRewardsDiscrete.sol";

contract StakingRewardsDiscreteTest is Test {
    MockERC20 public rewardToken;
    MockERC20 public stakingToken;

    StakingRewards public gauge;
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
        gauge = new StakingRewards(address(stakingToken), address(rewardToken));
        gaugeD = new StakingRewardsDiscrete(address(stakingToken), address(rewardToken));

        // Infinite approval.
        rewardToken.approve(address(gaugeD), type(uint256).max);
        vm.startPrank(alice);
        stakingToken.approve(address(gauge), type(uint256).max);
        stakingToken.approve(address(gaugeD), type(uint256).max);
        changePrank(bob);
        stakingToken.approve(address(gauge), type(uint256).max);
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

    /// @dev This test show the behavior of the non discrete staking rewards contract.
    /// First user will have more rewards than the second one because he arrived first.
    /// Issue with this contract is that there is no memory for rewards. i.e. if a user
    /// don't claim reward for the period, rewards are streamed to all users on the following period.
    function test_NonDiscrete() public {
        stakingToken.mint(address(alice), 1 ether);
        stakingToken.mint(address(bob), 1 ether);
        gauge.setRewardsDuration(1 weeks);

        // Deposit rewards tokens.
        rewardToken.mint(address(gauge), 1 ether);
        gauge.notifyRewardAmount(1 ether);

        // Deposit.
        vm.startPrank(alice);
        gauge.stake(1 ether);
        skip(3 days);
        changePrank(bob);
        gauge.stake(1 ether);

        skip(1 weeks);
        uint256 aliceEarnedBefore = gauge.earned(address(alice));
        assertGt(gauge.earned(address(alice)), gauge.earned(address(bob)));

        // Only bob claim.
        changePrank(bob);
        gauge.getReward();
        assertGt(rewardToken.balanceOf(address(bob)), 0);

        // Assert that reward distribution is finished.
        assertGt(block.timestamp, gauge.finishAt());

        // Notify remaining rewards for new rewards distribution period.
        changePrank(address(this));
        gauge.notifyRewardAmount(rewardToken.balanceOf(address(gauge)));
        skip(1 weeks);

        // Assert that alice has lost last week rewards.
        assertLt(aliceEarnedBefore, gauge.earned(address(alice)));
        // Assert that bob claim new rewards.
        assertGt(gauge.earned(bob), 0);
    }
}
