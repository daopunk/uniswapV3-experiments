// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.7.6;
pragma abicoder v2;

import {UniswapV3Setup} from 'test/UniswapV3Setup.t.sol';
import {SafeMath} from '@openzeppelin/math/SafeMath.sol';
import {IUniswapV3MintCallback} from 'lib/v3-core/contracts/interfaces/callback/IUniswapV3MintCallback.sol';
import {MintableERC20} from 'src/MintableERC20.sol';
import {Router} from 'src/Router.sol';

contract UniswapV3FeeInit is UniswapV3Setup {
  uint160 public constant SQRT_PRICE_X96 = 79_228_162_514_264_337_593_543_950_336;

  int24 public constant INIT_TICK = -29_959;
  int24 public constant ZERO_TICK = 0;
  int24 public constant TICK_SPACING = 200;
  int24 public constant MAX_TICK = 887_272;
  int24 public constant MIN_TICK = -887_272;

  int24 public constant LOW_TICK1 = ZERO_TICK - TICK_SPACING * 10;
  int24 public constant LOW_TICK2 = LOW_TICK1 - TICK_SPACING * 10;
  int24 public constant HIGH_TICK1 = ZERO_TICK + TICK_SPACING * 10;
  int24 public constant HIGH_TICK2 = HIGH_TICK1 + TICK_SPACING * 10;

  uint128 public constant DEPOSIT = 50_000 ether;
  Router public routerH;

  function setUp() public virtual override {
    super.setUp();
    routerH = new Router(poolHigh);
    _setupUsers(routerH);

    poolHigh.initialize(SQRT_PRICE_X96);
  }
}

/// @notice RARESKILLS PROBLEM 1
contract UniswapV3FeeSingle is UniswapV3FeeInit {
  function setUp() public virtual override {
    super.setUp();
    vm.prank(alice);
    routerH.addLiquidity(-2000, 2000, DEPOSIT);

    vm.prank(bob);
    routerH.swap(true, 100 ether, 1 ether);

    vm.prank(cara);
    routerH.swap(true, 10 ether, 100 ether);
  }

  function testCollectFee() public {
    vm.startPrank(alice);
    // `burn` happens in NonfungiblePositionManager
    poolHigh.burn(-2000, 2000, DEPOSIT);
    (uint256 amount0, uint256 amount1) = poolHigh.collect(alice, -2000, 2000, type(uint128).max, type(uint128).max);
    assertGt(amount0, 0);
    assertGt(amount1, 0);

    // fees were already burned, so revert
    vm.expectRevert();
    poolHigh.burn(-2000, 2000, DEPOSIT);

    // no more fees to collect, since entire deposit was previously burned
    (uint256 amount0_x2, uint256 amount1_x2) =
      poolHigh.collect(alice, -2000, 2000, type(uint128).max, type(uint128).max);
    assertEq(amount0_x2, 0);
    assertEq(amount1_x2, 0);
    vm.stopPrank();
  }
}

/// @notice RARESKILLS PROBLEM 2
contract UniswapV3FeeDouble is UniswapV3FeeInit {
  function setUp() public virtual override {
    super.setUp();
    vm.prank(alice);
    routerH.addLiquidity(-2000, 2000, DEPOSIT);

    vm.prank(deb);
    routerH.addLiquidity(-2000, 2000, DEPOSIT);

    vm.prank(bob);
    routerH.swap(true, 100 ether, 1 ether);

    vm.prank(cara);
    routerH.swap(true, 10 ether, 100 ether);
  }

  /**
   * @notice alice & deb have same exact position,
   * thus same `CollectParams.tokenId` that tracks the fees,
   * so if they burn & collect at the same time, the fees
   * will be distributed 50/50
   */
  function testCollectFeeEqual() public {
    vm.startPrank(alice);
    poolHigh.burn(-2000, 2000, DEPOSIT);
    (uint256 amount0_a, uint256 amount1_a) = poolHigh.collect(alice, -2000, 2000, type(uint128).max, type(uint128).max);
    vm.stopPrank();

    vm.startPrank(deb);
    poolHigh.burn(-2000, 2000, DEPOSIT);
    (uint256 amount0_d, uint256 amount1_d) = poolHigh.collect(alice, -2000, 2000, type(uint128).max, type(uint128).max);
    vm.stopPrank();

    assertEq(amount0_a, amount0_d);
    assertEq(amount1_a, amount1_d);
  }

  /**
   * @notice alice & deb have same exact position,
   * but alice burn/collects fees before bob swaps, then
   * deb burn/collects fees, so she gets additional fees
   */
  function testCollectFeeNotEqual() public {
    vm.startPrank(alice);
    poolHigh.burn(-2000, 2000, DEPOSIT);
    (uint256 amount0_a, uint256 amount1_a) = poolHigh.collect(alice, -2000, 2000, type(uint128).max, type(uint128).max);
    vm.stopPrank();

    vm.prank(bob);
    routerH.swap(true, 90 ether, 1 ether);

    vm.startPrank(deb);
    poolHigh.burn(-2000, 2000, DEPOSIT);
    (uint256 amount0_d, uint256 amount1_d) = poolHigh.collect(alice, -2000, 2000, type(uint128).max, type(uint128).max);
    vm.stopPrank();

    assertNotEq(amount0_a, amount0_d);
    assertNotEq(amount1_a, amount1_d);
  }
}

/**
 * @notice RARESKILLS PROBLEM 3 & 4
 *
 * As tick price moves at rate of 10 ticks per second (tick spacing is 10),
 * it checks if the tick is initialized, which the lower and upper tick of
 * each position will be initialized.
 *
 * Protocol tracks secondsOutside (either side of an initialized tick, reset when crossing over tick)
 */
