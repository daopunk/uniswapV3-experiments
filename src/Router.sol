// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.7.6;

import {IERC20} from '@openzeppelin/token/ERC20/IERC20.sol';
import {UniswapV3Pool, IUniswapV3Pool} from 'lib/v3-core/contracts/UniswapV3Pool.sol';
import {IUniswapV3MintCallback} from 'lib/v3-core/contracts/interfaces/callback/IUniswapV3MintCallback.sol';
import {IUniswapV3SwapCallback} from 'lib/v3-core/contracts/interfaces/callback/IUniswapV3SwapCallback.sol';

contract Router is IUniswapV3MintCallback, IUniswapV3SwapCallback {
  IUniswapV3Pool public pool;
  address private _caller;
  bool private _locked;

  modifier lock() {
    require(!_locked, 'Locked');
    _locked = true;
    _;
    _locked = false;
  }

  constructor(IUniswapV3Pool _pool) {
    pool = _pool;
  }

  function addLiquidity(
    int24 _bottomTick,
    int24 _topTick,
    uint128 _amount
  ) external lock returns (uint256 amount0, uint256 amount1) {
    _caller = msg.sender;
    (amount0, amount1) = pool.mint(msg.sender, _bottomTick, _topTick, _amount, '');
  }

  function swap(
    bool zeroForOne,
    int256 amountSpecified,
    uint160 sqrtPriceLimitX96
  ) external lock returns (int256 amount0, int256 amount1) {
    _caller = msg.sender;
    (amount0, amount1) = pool.swap(msg.sender, zeroForOne, amountSpecified, sqrtPriceLimitX96, '');
  }

  function uniswapV3MintCallback(uint256 amount0Owed, uint256 amount1Owed, bytes calldata data) external override {
    require(address(pool) == msg.sender, 'NotAuthed');
    IERC20(pool.token0()).transferFrom(_caller, address(pool), amount0Owed);
    IERC20(pool.token1()).transferFrom(_caller, address(pool), amount1Owed);
  }

  function uniswapV3SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata data) external override {
    require(address(pool) == msg.sender, 'NotAuthed');
    if (amount0Delta > 0) IERC20(pool.token0()).transferFrom(_caller, address(pool), uint256(amount0Delta));
    else IERC20(pool.token1()).transferFrom(_caller, address(pool), uint256(amount1Delta));
  }
}
