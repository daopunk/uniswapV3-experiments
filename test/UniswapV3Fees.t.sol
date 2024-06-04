// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.7.6;
pragma abicoder v2;

import {UniswapV3Setup} from 'test/UniswapV3Setup.t.sol';
import {SafeMath} from '@openzeppelin/math/SafeMath.sol';
import {IUniswapV3MintCallback} from '@uniswapv3/interfaces/callback/IUniswapV3MintCallback.sol';
import {MintableERC20} from 'src/MintableERC20.sol';
import {Router} from 'src/Router.sol';

contract UniswapV3FeeInit is UniswapV3Setup {
  uint160 public constant SQRT_PRICE_X96 = 79_228_162_514_264_337_593_543_950_336; // 1 token / 20 tokens

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

  function setUp() public virtual override {
    super.setUp();
    routerH = new Router(poolHigh);
    _setupUsers(routerH);

    poolHigh.initialize(SQRT_PRICE_X96);

    vm.prank(alice);
    routerH.addLiquidity(-2000, 2000, DEPOSIT * 2);

    vm.warp(block.timestamp + 10);
    vm.roll(block.number + 10);

    vm.prank(bob);
    routerH.swap(true, 100 ether, 1 ether);

    vm.prank(cara);
    routerH.swap(true, 10 ether, 100 ether);
  }
}

contract UniswapV3Fee is UniswapV3FeeInit {
  function testCollectFee() public {
    vm.warp(block.timestamp + 10);
    vm.roll(block.number + 10);
    vm.startPrank(alice);
    routerH.addLiquidity(-887_200, 887_200, DEPOSIT / 2);
    poolHigh.collect(alice, MIN_TICK, MAX_TICK, type(uint128).max, type(uint128).max);
    vm.stopPrank();
  }
}
