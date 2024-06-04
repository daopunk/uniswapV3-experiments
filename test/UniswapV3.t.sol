// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.7.6;
pragma abicoder v2;

import {UniswapV3Setup} from 'test/UniswapV3Setup.t.sol';
import {SafeMath} from '@openzeppelin/math/SafeMath.sol';
import {IUniswapV3MintCallback} from '@uniswapv3/interfaces/callback/IUniswapV3MintCallback.sol';
import {MintableERC20} from 'src/MintableERC20.sol';

contract UniswapV3Init is UniswapV3Setup {
  /// @dev values generated @ https://uniswap-v3-calculator.netlify.app/

  uint160 public constant SQRT_PRICE_X96 = 17_715_955_711_429_571_029_610_171_616; // 1 token / 20 tokens
  int24 public constant INIT_TICK = -29_959;
  int24 public constant ZERO_TICK = 0;

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
    assertTrue(_tick == INIT_TICK);
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
    ) = poolLow.ticks(ZERO_TICK);
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

    router.swap(false, 1 ether, SQRT_PRICE_X96 * 2);

    router.swap(true, 1 ether, SQRT_PRICE_X96 / 2);

    vm.expectRevert(); // SPL Error
    router.swap(false, 1 ether, SQRT_PRICE_X96 / 2);
  }

  function test_addLiquidityAbovePrice() public {
    vm.prank(alice);
    router.addLiquidity(ZERO_TICK + TICK_SPACING * 2, ZERO_TICK + TICK_SPACING * 3, DEPOSIT);
    (uint160 _sqrtPriceX96, int24 _tick,,,,,) = poolLow.slot0();
    emit log_named_uint('SqrtPriceX96', _sqrtPriceX96);
    emit log_named_int('Tick', _tick);
  }

  function test_addLiquidityBelowPrice() public {
    vm.prank(alice);
    router.addLiquidity(ZERO_TICK - TICK_SPACING * 3, ZERO_TICK - TICK_SPACING * 2, DEPOSIT);
    (uint160 _sqrtPriceX96, int24 _tick,,,,,) = poolLow.slot0();
    emit log_named_uint('SqrtPriceX96', _sqrtPriceX96);
    emit log_named_int('Tick', _tick);
  }

  function test_addLiquidityAtAbovePrice() public {
    vm.prank(alice);
    router.addLiquidity(ZERO_TICK, ZERO_TICK + TICK_SPACING * 3, DEPOSIT);
    (uint160 _sqrtPriceX96, int24 _tick,,,,,) = poolLow.slot0();
    emit log_named_uint('SqrtPriceX96', _sqrtPriceX96);
    emit log_named_int('Tick', _tick);
  }

  function test_addLiquidityAtBelowPrice() public {
    vm.prank(alice);
    router.addLiquidity(ZERO_TICK - TICK_SPACING * 3, ZERO_TICK, DEPOSIT);
    (uint160 _sqrtPriceX96, int24 _tick,,,,,) = poolLow.slot0();
    emit log_named_uint('SqrtPriceX96', _sqrtPriceX96);
    emit log_named_int('Tick', _tick);
  }

  function test_addLiquidityAtPriceRevert() public {
    vm.expectRevert();
    router.addLiquidity(ZERO_TICK + TICK_SPACING, ZERO_TICK - TICK_SPACING, DEPOSIT);
  }
}

contract UniswapV3PostLiquidity is UniswapV3Init {
  int24 public constant LOW_TICK1 = ZERO_TICK - TICK_SPACING * 100;
  int24 public constant LOW_TICK2 = LOW_TICK1 - TICK_SPACING * 100;

  int24 public constant HIGH_TICK1 = ZERO_TICK + TICK_SPACING * 100;
  int24 public constant HIGH_TICK2 = HIGH_TICK1 + TICK_SPACING * 100;

  function setUp() public virtual override {
    super.setUp();
    vm.startPrank(alice);
    router.addLiquidity(LOW_TICK2, LOW_TICK1, DEPOSIT);
    router.addLiquidity(HIGH_TICK1, HIGH_TICK2, DEPOSIT * 2);
    vm.stopPrank();
  }

  function test_tickAndSqrt() public {
    (uint160 _sqrtPriceX96, int24 _tick,,,,,) = poolLow.slot0();
    emit log_named_uint('SqrtPriceX96', _sqrtPriceX96);
    emit log_named_int('Tick', _tick);
  }

  /**
   * @notice Upper and Lower ticks are initialized, but not ticks inbetween upper and lower
   */
  function test_initializedTicksHigh() public {
    emit log_named_int('Upper High Tick', HIGH_TICK2);
    emit log_named_int('Lower High Tick', HIGH_TICK1);
    (uint128 _liquidityGrossTop, int128 _liquidityNetTop,,,,,, bool _initializedTop) = poolLow.ticks(HIGH_TICK2);
    assertTrue(_initializedTop);
    emit log_named_uint('liqGross Top', _liquidityGrossTop);
    emit log_named_int('liqNet   Top', _liquidityNetTop);
    (,,,,,,, bool _initializedMid) = poolLow.ticks(HIGH_TICK1 + TICK_SPACING * 50);
    assertFalse(_initializedMid);
    (uint128 _liquidityGrossBtm, int128 _liquidityNetBtm,,,,,, bool _initializedBtm) = poolLow.ticks(HIGH_TICK1);
    assertTrue(_initializedBtm);
    emit log_named_uint('liqGross Btm', _liquidityGrossBtm);
    emit log_named_int('liqNet   Btm', _liquidityNetBtm);
  }

  function test_initializedTicksLow() public {
    emit log_named_int('Upper Low Tick', LOW_TICK1);
    emit log_named_int('Lower Low Tick', LOW_TICK2);
    (uint128 _liquidityGrossTop, int128 _liquidityNetTop,,,,,, bool _initializedTop) = poolLow.ticks(LOW_TICK1);
    assertTrue(_initializedTop);
    emit log_named_uint('liqGross Top', _liquidityGrossTop);
    emit log_named_int('liqNet   Top', _liquidityNetTop);
    (,,,,,,, bool _initializedMid) = poolLow.ticks(LOW_TICK1 - TICK_SPACING * 50);
    assertFalse(_initializedMid);
    (uint128 _liquidityGrossBtm, int128 _liquidityNetBtm,,,,,, bool _initializedBtm) = poolLow.ticks(LOW_TICK2);
    assertTrue(_initializedBtm);
    emit log_named_uint('liqGross Btm', _liquidityGrossBtm);
    emit log_named_int('liqNet   Btm', _liquidityNetBtm);
  }
}

contract UniswapV3Liquidity is UniswapV3Init {
  /**
   * @notice Bob spent less money for position farther from the SqrtPrice
   * than Alice who was closer to the SqrtPrice
   */
  function test_tokenAmount1() public {
    vm.prank(alice);
    router.addLiquidity(ZERO_TICK + TICK_SPACING, ZERO_TICK + TICK_SPACING * 2, DEPOSIT);
    uint256 alicetokenA = tokenA.balanceOf(alice);
    uint256 aliceTokenB = tokenB.balanceOf(alice);

    vm.prank(bob);
    router.addLiquidity(ZERO_TICK + TICK_SPACING * 10, ZERO_TICK + TICK_SPACING * 11, DEPOSIT);
    uint256 bobTokenA = tokenA.balanceOf(bob);
    uint256 bobTokenB = tokenB.balanceOf(bob);

    assertEq(alicetokenA, bobTokenA);
    assertTrue(aliceTokenB < bobTokenB);

    emit log_named_uint('Alice USDC bal', alicetokenA);
    emit log_named_uint('Alice DAI  bal', aliceTokenB);
    emit log_named_uint('Bob  USDC  bal', bobTokenA);
    emit log_named_uint('Bob  DAI   bal', bobTokenB);
  }

  /**
   * @notice Bob spent same money for same position as Alice
   */
  function test_tokenAmount2() public {
    vm.prank(alice);
    router.addLiquidity(ZERO_TICK + TICK_SPACING, ZERO_TICK + TICK_SPACING * 2, DEPOSIT);
    uint256 alicetokenA = tokenA.balanceOf(alice);
    uint256 aliceTokenB = tokenB.balanceOf(alice);

    vm.prank(bob);
    router.addLiquidity(ZERO_TICK + TICK_SPACING, ZERO_TICK + TICK_SPACING * 2, DEPOSIT);
    uint256 bobTokenA = tokenA.balanceOf(bob);
    uint256 bobTokenB = tokenB.balanceOf(bob);

    assertEq(alicetokenA, bobTokenA);
    assertEq(aliceTokenB, bobTokenB);

    emit log_named_uint('Alice USDC bal', alicetokenA);
    emit log_named_uint('Alice DAI  bal', aliceTokenB);
    emit log_named_uint('Bob  USDC  bal', bobTokenA);
    emit log_named_uint('Bob  DAI   bal', bobTokenB);
  }
}

contract UniswapV3Tick is UniswapV3Init {
  mapping(bytes32 => uint256) public tokensBals;

  function setUp() public virtual override {
    super.setUp();
    tokensBals[TA] = MintableERC20(tokens[TA]).balanceOf(alice);
    tokensBals[TB] = MintableERC20(tokens[TB]).balanceOf(alice);
  }

  /**
   * @notice all liquidity concentrated in tickBit -1, and some at 2
   * wider liquidity = more tokens spent
   */
  function test_negativeTenAndPositiveTen() public {
    emit log_named_uint('liq var before', poolLow.liquidity());
    vm.prank(alice);
    router.addLiquidity(-10, 10, 1000);
    /// liqGross = determine if tick has an active position
    /// liqNet = liquidity removed/added when crossing a tick
    /// liqDelta = liqBefore +- liqAfter to change the price n amount
    (uint128 _liquidityGrossTop, int128 _liquidityNetTop,,,,,, bool _initializedTop) = poolLow.ticks(-20);
    (uint128 _liquidityGrossBtm, int128 _liquidityNetBtm,,,,,, bool _initializedBtm) = poolLow.ticks(-10);
    emit log_named_uint('liqGross Top', _liquidityGrossTop);
    emit log_named_int('liqNet   Top', _liquidityNetTop);
    emit log_named_uint('liqGross Btm', _liquidityGrossBtm);
    emit log_named_int('liqNet   Btm', _liquidityNetBtm);
    uint256 _tickBitP1 = poolLow.tickBitmap(1);
    emit log_named_uint('tickBit    1', _tickBitP1);
    uint256 _tickBit0 = poolLow.tickBitmap(0);
    emit log_named_uint('tickBit    0', _tickBit0);
    uint256 _tickBitN1 = poolLow.tickBitmap(-1);
    emit log_named_uint('tickBit   -1', _tickBitN1);
    uint256 _tickBitN2 = poolLow.tickBitmap(-2);
    emit log_named_uint('tickBit   -2', _tickBitN2);
    _tokensDifference();
    emit log_named_uint('liq var after', poolLow.liquidity());
  }

  /**
   * @notice all liquidity concentrated in tickBit -1
   * narrower liquidity = less tokens spent
   */
  function test_negativeTwentyAndNegativeTen() public {
    vm.prank(alice);
    router.addLiquidity(-20, -10, 10_000);
    (uint128 _liquidityGrossTop, int128 _liquidityNetTop,,,,,, bool _initializedTop) = poolLow.ticks(-20);
    (uint128 _liquidityGrossBtm, int128 _liquidityNetBtm,,,,,, bool _initializedBtm) = poolLow.ticks(-10);
    emit log_named_uint('liqGross Top', _liquidityGrossTop);
    emit log_named_int('liqNet   Top', _liquidityNetTop);
    emit log_named_uint('liqGross Btm', _liquidityGrossBtm);
    emit log_named_int('liqNet   Btm', _liquidityNetBtm);
    uint256 _tickBit0 = poolLow.tickBitmap(0);
    emit log_named_uint('tickBit    0', _tickBit0);
    uint256 _tickBitN1 = poolLow.tickBitmap(-1);
    emit log_named_uint('tickBit   -1', _tickBitN1);
    uint256 _tickBitN2 = poolLow.tickBitmap(-2);
    emit log_named_uint('tickBit   -2', _tickBitN2);
    _tokensDifference();
  }

  function test_initializedTick() public {
    vm.prank(alice);
    router.addLiquidity(INIT_TICK - 11, INIT_TICK - 1, 10_000);
    (uint128 _liquidityGrossTop, int128 _liquidityNetTop,,,,,, bool _initializedTop) = poolLow.ticks(INIT_TICK - 1);
    (uint128 _liquidityGrossBtm, int128 _liquidityNetBtm,,,,,, bool _initializedBtm) = poolLow.ticks(INIT_TICK - 11);
    emit log_named_uint('liqGross Top', _liquidityGrossTop);
    emit log_named_int('liqNet   Top', _liquidityNetTop);
    emit log_named_uint('liqGross Btm', _liquidityGrossBtm);
    emit log_named_int('liqNet   Btm', _liquidityNetBtm);
    // uint256 _tickBit0 = poolLow.tickBitmap(int16(INIT_TICK) + 5);
    // emit log_named_uint('tickBit    0', _tickBit0);
    // uint256 _tickBitN1 = poolLow.tickBitmap(int16(INIT_TICK) + 6);
    // emit log_named_uint('tickBit   -1', _tickBitN1);
    // uint256 _tickBitN2 = poolLow.tickBitmap(int16(INIT_TICK) - 12);
    // emit log_named_uint('tickBit   -2', _tickBitN2);
    _tokensDifference();
  }

  /**
   * @notice not possible to mint liquidity within a single tick
   */
  function test_positiveTenAndPositiveTen() public {
    vm.prank(alice);
    vm.expectRevert();
    router.addLiquidity(10, 10, 10_000);
  }

  function _tokensDifference() internal {
    emit log_named_uint('TokenA Spent', tokensBals[TA] - MintableERC20(tokens[TA]).balanceOf(alice));
    emit log_named_uint('TokenB Spent', tokensBals[TB] - MintableERC20(tokens[TB]).balanceOf(alice));
  }
}
