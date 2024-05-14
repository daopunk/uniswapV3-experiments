// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.7.6;
pragma abicoder v2;

import {UniswapV3Setup} from 'test/UniswapV3Setup.t.sol';
import {SafeMath} from '@openzeppelin/math/SafeMath.sol';
import {IUniswapV3MintCallback} from '@uniswapv3/interfaces/callback/IUniswapV3MintCallback.sol';

contract UniswapV3Init is UniswapV3Setup {
  /// @dev values generated @ https://uniswap-v3-calculator.netlify.app/
  // uint160 public constant SQRT_PRICE_X96 = 79_228_162_514_264_337_593_543_950_336; // reserve0 = 1, reserve1 = 1
  int24 public constant INIT_TICK = 0;

  uint160 public constant SQRT_PRICE_X96 = 25_054_144_837_504_793_118_641_380_156; // reserve0 = 1, reserve1 = 20
  // int24 public constant INIT_TICK = -23_028;

  int24 public constant TICK_SPACING = 10;

  int24 public constant MAX_TICK = 887_272;
  int24 public constant MIN_TICK = -887_272;

  uint128 public constant DEPOSIT = 10_000 ether;

  function setUp() public virtual override {
    super.setUp();

    poolLow.initialize(SQRT_PRICE_X96);
  }
}

contract UniswapV3PreLiquidity is UniswapV3Init {
  function test_initialPrice() public {
    (uint160 _sqrtPriceX96, int24 _tick,,,,, bool _unlocked) = poolLow.slot0();
    emit log_named_uint('SqrtPriceX96 from Pool', _sqrtPriceX96);
    assertTrue(_sqrtPriceX96 == SQRT_PRICE_X96);
    // assertTrue(_tick == INIT_TICK);
    assertTrue(_unlocked);
  }

  function test_liquidity() public {
    assertTrue(poolLow.liquidity() == 0);
  }

  function test_protocolFees() public {
    (uint128 _token0, uint128 _token1) = poolLow.protocolFees();
    assertTrue(_token0 == 0);
    assertTrue(_token1 == 0);
  }

  function test_priceAtTick() public {
    (
      uint128 _liquidityGross,
      int128 _liquidityNet,
      uint256 _feeGrowthOutside0X128,
      uint256 _feeGrowthOutside1X128,
      int56 _tickCumulativeOutside,
      uint160 _secondsPerLiquidityOutsideX128,
      uint32 _secondsOutside,
      bool _initialized
    ) = poolLow.ticks(INIT_TICK);
    assertTrue(_liquidityGross == 0 && _liquidityNet == 0);
    assertTrue(_feeGrowthOutside0X128 == 0 && _feeGrowthOutside1X128 == 0);
    assertTrue(_tickCumulativeOutside == 0 && _secondsPerLiquidityOutsideX128 == 0);
    assertTrue(_secondsOutside == 0);
    assertFalse(_initialized);
  }

  function test_router() public {
    assertEq(address(poolLow), address(router.pool()));
  }

  /**
   * @notice swapping before adding liquidity reverts
   * some reverts are due to SPL (Sqrt Price Limit)
   */
  function test_swapPriorToLiquidity() public {
    vm.prank(alice);
    vm.expectRevert(); // SPL Error
    router.swap(true, 1 ether, SQRT_PRICE_X96 * 2);

    vm.expectRevert();
    router.swap(false, 1 ether, SQRT_PRICE_X96 * 2);

    vm.expectRevert();
    router.swap(true, 1 ether, SQRT_PRICE_X96 / 2);

    vm.expectRevert(); // SPL Error
    router.swap(false, 1 ether, SQRT_PRICE_X96 / 2);
  }

  function test_addLiquidityAbovePrice() public {
    vm.prank(alice);
    router.addLiquidity(INIT_TICK + TICK_SPACING * 2, INIT_TICK + TICK_SPACING * 3, DEPOSIT);
    (uint160 _sqrtPriceX96, int24 _tick,,,,,) = poolLow.slot0();
    emit log_named_uint('SqrtPriceX96', _sqrtPriceX96);
    emit log_named_int('Tick', _tick);
  }

  function test_addLiquidityBelowPrice() public {
    vm.prank(alice);
    router.addLiquidity(INIT_TICK - TICK_SPACING * 3, INIT_TICK - TICK_SPACING * 2, DEPOSIT);
    (uint160 _sqrtPriceX96, int24 _tick,,,,,) = poolLow.slot0();
    emit log_named_uint('SqrtPriceX96', _sqrtPriceX96);
    emit log_named_int('Tick', _tick);
  }

  function test_addLiquidityAtAbovePrice() public {
    vm.prank(alice);
    router.addLiquidity(INIT_TICK, INIT_TICK + TICK_SPACING * 3, DEPOSIT);
    (uint160 _sqrtPriceX96, int24 _tick,,,,,) = poolLow.slot0();
    emit log_named_uint('SqrtPriceX96', _sqrtPriceX96);
    emit log_named_int('Tick', _tick);
  }

  function test_addLiquidityAtBelowPrice() public {
    vm.prank(alice);
    router.addLiquidity(INIT_TICK - TICK_SPACING * 3, INIT_TICK, DEPOSIT);
    (uint160 _sqrtPriceX96, int24 _tick,,,,,) = poolLow.slot0();
    emit log_named_uint('SqrtPriceX96', _sqrtPriceX96);
    emit log_named_int('Tick', _tick);
  }

  function test_addLiquidityAtPriceRevert() public {
    vm.expectRevert();
    router.addLiquidity(INIT_TICK + TICK_SPACING, INIT_TICK - TICK_SPACING, DEPOSIT);
  }
}

contract UniswapV3PostLiquidity is UniswapV3Init {
  int24 public constant LOW_TICK1 = INIT_TICK - TICK_SPACING * 100;
  int24 public constant LOW_TICK2 = LOW_TICK1 - TICK_SPACING * 100;

  int24 public constant HIGH_TICK1 = INIT_TICK + TICK_SPACING * 100;
  int24 public constant HIGH_TICK2 = HIGH_TICK1 + TICK_SPACING * 100;

  function setUp() public virtual override {
    super.setUp();
    vm.startPrank(alice);
    router.addLiquidity(LOW_TICK2, LOW_TICK1, DEPOSIT);
    router.addLiquidity(HIGH_TICK1, HIGH_TICK2, DEPOSIT * 2);
    vm.stopPrank();

    (uint160 _sqrtPriceX96, int24 _tick,,,,,) = poolLow.slot0();
    emit log_named_uint('SqrtPriceX96', _sqrtPriceX96);
    emit log_named_int('Tick', _tick);
  }

  /**
   * @notice Upper and Lower ticks are initialized, but not ticks inbetween upper and lower
   */
  function test_initializedTicksHigh() public {
    (,,,,,,, bool _initializedTop) = poolLow.ticks(HIGH_TICK2);
    assertTrue(_initializedTop);
    (,,,,,,, bool _initializedMid) = poolLow.ticks(HIGH_TICK1 + TICK_SPACING * 50);
    assertFalse(_initializedMid);
    (,,,,,,, bool _initializedBttm) = poolLow.ticks(HIGH_TICK1);
    assertTrue(_initializedBttm);
  }

  function test_initializedTicksLow() public {
    (,,,,,,, bool _initializedTop) = poolLow.ticks(LOW_TICK1);
    assertTrue(_initializedTop);
    (,,,,,,, bool _initializedMid) = poolLow.ticks(LOW_TICK1 - TICK_SPACING * 50);
    assertFalse(_initializedMid);
    (,,,,,,, bool _initializedBttm) = poolLow.ticks(LOW_TICK2);
    assertTrue(_initializedBttm);
  }
}

contract UniswapV3Liquidity is UniswapV3Init {
  /**
   * @notice Bob spent less money for position farther from the SqrtPrice
   */
  function test_tokenAmount1() public {
    vm.prank(alice);
    router.addLiquidity(INIT_TICK + TICK_SPACING, INIT_TICK + TICK_SPACING * 2, DEPOSIT);
    uint256 aliceUsdcBal = usdcTkn.balanceOf(alice);
    uint256 aliceDaiBal = daiTkn.balanceOf(alice);

    vm.prank(bob);
    router.addLiquidity(INIT_TICK + TICK_SPACING * 10, INIT_TICK + TICK_SPACING * 11, DEPOSIT);
    uint256 bobUsdcBal = usdcTkn.balanceOf(bob);
    uint256 bobDaiBal = daiTkn.balanceOf(bob);

    assertEq(aliceUsdcBal, bobUsdcBal);
    assertTrue(aliceDaiBal < bobDaiBal);

    emit log_named_uint('Alice USDC bal', aliceUsdcBal);
    emit log_named_uint('Alice DAI  bal', aliceDaiBal);
    emit log_named_uint('Bob  USDC  bal', bobUsdcBal);
    emit log_named_uint('Bob  DAI   bal', bobDaiBal);
  }

  /**
   * @notice Bob spent same money for same position after Alice
   */
  function test_tokenAmount2() public {
    vm.prank(alice);
    router.addLiquidity(INIT_TICK + TICK_SPACING, INIT_TICK + TICK_SPACING * 2, DEPOSIT);
    uint256 aliceUsdcBal = usdcTkn.balanceOf(alice);
    uint256 aliceDaiBal = daiTkn.balanceOf(alice);

    vm.prank(bob);
    router.addLiquidity(INIT_TICK + TICK_SPACING, INIT_TICK + TICK_SPACING * 2, DEPOSIT);
    uint256 bobUsdcBal = usdcTkn.balanceOf(bob);
    uint256 bobDaiBal = daiTkn.balanceOf(bob);

    assertEq(aliceUsdcBal, bobUsdcBal);
    assertEq(aliceDaiBal, bobDaiBal);

    emit log_named_uint('Alice USDC bal', aliceUsdcBal);
    emit log_named_uint('Alice DAI  bal', aliceDaiBal);
    emit log_named_uint('Bob  USDC  bal', bobUsdcBal);
    emit log_named_uint('Bob  DAI   bal', bobDaiBal);
  }
}
