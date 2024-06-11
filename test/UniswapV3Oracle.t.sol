// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.7.6;
pragma abicoder v2;

import {UniswapV3Pool, IUniswapV3Pool} from 'lib/v3-core/contracts/UniswapV3Pool.sol';
import {IUniswapV3MintCallback} from 'lib/v3-core/contracts/interfaces/callback/IUniswapV3MintCallback.sol';
import {SafeMath} from '@openzeppelin/math/SafeMath.sol';
import {ERC20} from '@openzeppelin/token/ERC20/ERC20.sol';
import {UniswapV3Setup} from 'test/UniswapV3Setup.t.sol';
import {MintableERC20} from 'src/MintableERC20.sol';
import {Router} from 'src/Router.sol';
import {Relayer} from 'src/Relayer.sol';

contract UniswapV3Oracle is UniswapV3Setup {
  uint256 public constant MINUTE = 60;

  uint160 public constant SQRT_PRICE_X96_1_1 = 79_228_162_514_264_337_593_543_950_336; // 1 token / 1 token
  uint160 public constant SQRT_PRICE_X96_1_2 = 56_022_770_974_786_139_918_731_938_227; // 1 token / 2 token

  int24 public constant INIT_TICK = -29_959;
  int24 public constant ZERO_TICK = 0;
  int24 public constant TICK_SPACING = 200;
  int24 public constant MAX_TICK = 887_272;
  int24 public constant MIN_TICK = -887_272;

  int24 public constant LOW_TICK1 = ZERO_TICK - TICK_SPACING * 10;
  int24 public constant LOW_TICK2 = LOW_TICK1 - TICK_SPACING * 10;
  int24 public constant HIGH_TICK1 = ZERO_TICK + TICK_SPACING * 10;
  int24 public constant HIGH_TICK2 = HIGH_TICK1 + TICK_SPACING * 10;

  uint128 public constant DEPOSIT = 10_000 ether;
  Router public routerH;
  Relayer public relayer;

  uint256 public firstPriceRead;

  function setUp() public virtual override {
    super.setUp();
    routerH = new Router(poolHigh);
    _setupUsers(routerH);

    poolHigh.initialize(SQRT_PRICE_X96_1_1);

    relayer = new Relayer(address(factory), tokens[TA], tokens[TB], FEE_HIGH, uint32(MINUTE));
    vm.warp(MINUTE);

    vm.prank(alice);
    routerH.addLiquidity(-20_000, 20_000, DEPOSIT);
    vm.warp(MINUTE * 2);

    (uint160 _sqrtPriceX96, int24 _tick,, uint16 _observationCardinality, uint16 _observationCardinalityNext,,) =
      poolHigh.slot0();

    emit log_named_uint('_observationCardinality    ', _observationCardinality);
    emit log_named_uint('_observationCardinalityNext', _observationCardinalityNext);

    poolHigh.increaseObservationCardinalityNext(2);

    firstPriceRead = relayer.read();
  }

  function testRatio() public {
    uint256 _token0Amount = ERC20(poolHigh.token0()).balanceOf(address(poolHigh));
    uint256 _token1Amount = ERC20(poolHigh.token1()).balanceOf(address(poolHigh));
    emit log_named_uint('token0 amount', _token0Amount);
    emit log_named_uint('token1 amount', _token1Amount);

    (uint160 _sqrtPriceX96, int24 _tick,,,,,) = poolHigh.slot0();
    emit log_named_uint('SqrtPrice    ', _sqrtPriceX96);
    emit log_named_int('CurrentTick  ', _tick);

    uint256 _priceRead = relayer.read();
    emit log_named_uint('Price 60s Ago', _priceRead);
    emit log_named_uint('Price /  WAD ', _priceRead / 1 ether);
  }

  function testRatioAfterSwap() public {
    vm.prank(bob);
    routerH.swap(true, 4184.1 ether, 1 ether);
    vm.warp(MINUTE * 3);

    uint256 _token0Amount = ERC20(poolHigh.token0()).balanceOf(address(poolHigh));
    uint256 _token1Amount = ERC20(poolHigh.token1()).balanceOf(address(poolHigh));
    emit log_named_uint('token0 amount', _token0Amount);
    emit log_named_uint('token1 amount', _token1Amount);

    (uint160 _sqrtPriceX96, int24 _tick,,,,,) = poolHigh.slot0();
    emit log_named_uint('SqrtPrice    ', _sqrtPriceX96);
    emit log_named_int('CurrentTick  ', _tick);

    uint256 _priceRead = relayer.read(); // 60 seconds ago (default)
    emit log_named_uint('Initial Price', firstPriceRead);
    emit log_named_uint('Price 60s Ago', _priceRead);
    emit log_named_uint('Average Price', (_priceRead + firstPriceRead) / 2);
    emit log_named_uint('Price /  WAD ', _priceRead / 1 ether);

    uint256 _priceReadCustom = relayer.readWithCustomPeriod(uint32(59)); // 59 seconds ago
    // assertEq(_priceReadCustom, _priceRead);

    // vm.expectRevert();
    uint256 _priceRead2 = relayer.readWithCustomPeriod(uint32(90)); // 90 seconds ago
    emit log_named_uint('Price 90s Ago', _priceRead2);
  }
}
