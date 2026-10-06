// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {XPower} from "../contracts/XPower.sol";
import {XStorkFactory} from "../contracts/XStorkFactory.sol";
import {XStorkPair} from "../contracts/XStorkPair.sol";
import {XStorkRouter} from "../contracts/XStorkRouter.sol";
import {XStorkStaking} from "../contracts/XStorkStaking.sol";

contract XStorkTest is Test {
    XPower reward;
    XPower assetA; // 模拟 xTSLA 股票资产
    XPower assetB; // 模拟 xAAPL 股票资产
    XStorkFactory factory;
    XStorkRouter router;
    XStorkStaking staking;

    address alice = address(0x1111);
    address bob = address(0x2222);

    function setUp() public {
        reward = new XPower(21e6 * 1e18);          // XPR 2100万
        assetA = new XPower(0);                     // xStock 资产（无预铸）
        assetB = new XPower(0);
        factory = new XStorkFactory();
        router = new XStorkRouter(address(factory));
        staking = new XStorkStaking(address(reward));

        assetA.mint(alice, 100_000e18);
        assetB.mint(alice, 100_000e18);
        assetA.mint(bob, 50_000e18);
        reward.transfer(address(staking), 1_000_000e18); // 奖励池
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
    }

    function test_swap_flow() public {
        vm.startPrank(alice);
        address pair = factory.createPair(address(assetA), address(assetB));
        assertTrue(pair != address(0));

        assetA.approve(address(router), type(uint256).max);
        assetB.approve(address(router), type(uint256).max);

        uint balA0 = assetA.balanceOf(alice); // 100_000
        uint balB0 = assetB.balanceOf(alice); // 100_000
        (uint a0, uint b0, uint liq) = router.addLiquidity(
            address(assetA), address(assetB), 10_000e18, 10_000e18, 0, 0, alice, block.timestamp
        );
        assertEq(liq, 10_000e18 - 1000);
        console.log("LP minted:", liq);

        // 兑换 A→B
        uint balB1 = assetB.balanceOf(alice); // 90_000（已减 1 万入池）
        uint out = router.getAmountsOut(1_000e18, _path())[1];
        assertGt(out, 0);
        uint[] memory amts = router.swapExactTokensForTokens(1_000e18, 0, _path(), alice, block.timestamp);
        assertEq(amts[1], out);
        console.log("swap out:", amts[1]);
        assertEq(assetB.balanceOf(alice), balB1 + out);

        // 移除流动性
        XStorkPair lp = XStorkPair(pair);
        uint lpBal = lp.balanceOf(alice);
        lp.approve(address(router), type(uint256).max);
        (uint ra, uint rb) = router.removeLiquidity(address(assetA), address(assetB), lpBal, 0, 0, alice, block.timestamp);
        console.log("ra", ra, "rb", rb);
        (uint112 r0, uint112 r1,) = lp.getReserves(); console.log("reserves:", r0, r1);
        console.log("aliceA", assetA.balanceOf(alice), "aliceB", assetB.balanceOf(alice));
        assertApproxEqAbs(ra, 11_000e18, 1e18); // 池内 assetA ≈ 1万+1千(swap入)
        console.log("removed:", ra, rb);
        vm.stopPrank();
    }

    function test_staking_flow() public {
        uint pid = staking.createPool(address(assetA), 100e18); // 每秒 100 XPR
        vm.startPrank(alice);
        assetA.approve(address(staking), type(uint256).max);
        staking.stake(pid, 1_000e18);
        vm.warp(block.timestamp + 10);
        uint pending = staking.pendingReward(pid, alice);
        assertGt(pending, 0);
        assertApproxEqAbs(pending, 1000e18, 100e18); // ~10秒 * 100
        staking.claim(pid);
        assertEq(reward.balanceOf(alice), 1000e18);
        staking.withdraw(pid, 1_000e18);
        assertEq(assetA.balanceOf(alice), 100_000e18);
        vm.stopPrank();
    }

    function _path() internal view returns (address[] memory p) {
        p = new address[](2);
        p[0] = address(assetA);
        p[1] = address(assetB);
    }
}
