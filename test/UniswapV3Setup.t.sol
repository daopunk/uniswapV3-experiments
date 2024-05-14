// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.7.6;
pragma abicoder v2;

import {Test, console} from 'forge-std/Test.sol';
import {UniswapV3Factory, IUniswapV3Factory} from '@uniswapv3/UniswapV3Factory.sol';
import {UniswapV3Pool, IUniswapV3Pool} from '@uniswapv3/UniswapV3Pool.sol';
import {MintableERC20} from 'src/MintableERC20.sol';
import {Router} from 'src/Router.sol';

contract UniswapV3Setup is Test {
  bytes32 public constant USDC = bytes32('USDC');
  bytes32 public constant DAI = bytes32('DAI');
  uint256 public constant MINT = 100_000 ether;

  uint24 public constant FEE_LOW = 500;
  uint24 public constant FEE_MED = 3000;
  uint24 public constant FEE_HIGH = 10_000;

  address public deployer = address(this);
  address public alice = address(0xa11ce);
  address public bob = address(0xb0b);

  /// uniswap contracts
  UniswapV3Factory public factory;
  UniswapV3Pool public poolLow;
  UniswapV3Pool public poolMed;
  UniswapV3Pool public poolHigh;

  // periphery contracts
  Router public router;

  // erc20 tokens
  MintableERC20 public usdcTkn;
  MintableERC20 public daiTkn;

  // data structures
  address[] public usrs;
  mapping(bytes32 => address) public tokens;

  function setUp() public virtual {
    _setupTokens();

    factory = new UniswapV3Factory();

    /// @notice USDC = tokenA, DAI = tokenB
    poolLow = UniswapV3Pool(factory.createPool(tokens[USDC], tokens[DAI], FEE_LOW));
    poolMed = UniswapV3Pool(factory.createPool(tokens[USDC], tokens[DAI], FEE_MED));
    poolHigh = UniswapV3Pool(factory.createPool(tokens[USDC], tokens[DAI], FEE_HIGH));

    router = new Router(poolLow);

    _setupUsers();
  }

  function _setupUsers() public {
    usrs = new address[](3);
    usrs[0] = alice;
    usrs[1] = bob;
    usrs[2] = deployer;
    for (uint256 i = 0; i < usrs.length; i++) {
      vm.startPrank(usrs[i]);
      usdcTkn.mint(MINT);
      usdcTkn.approve(address(router), MINT);
      daiTkn.mint(MINT);
      daiTkn.approve(address(router), MINT);
      vm.stopPrank();
    }
  }

  function _setupTokens() internal {
    usdcTkn = new MintableERC20('USDC', 'X', 18);
    daiTkn = new MintableERC20('DAI', 'Y', 18);
    tokens[USDC] = address(usdcTkn);
    tokens[DAI] = address(daiTkn);
  }
}

contract UniswapV3SetupTest is UniswapV3Setup {
  function test_userBalances() public view {
    for (uint256 i = 0; i < usrs.length; i++) {
      assertEq(usdcTkn.balanceOf(usrs[i]), MINT);
      assertEq(daiTkn.balanceOf(usrs[i]), MINT);
    }
  }

  function test_poolfactory() public view {
    assertEq(poolLow.factory(), address(factory));
  }

  function test_poolTokens() public {
    if (tokens[USDC] < tokens[DAI]) {
      assertEq(poolLow.token0(), tokens[USDC]);
      assertEq(poolLow.token1(), tokens[DAI]);
      emit log_named_address('token0 is USDC', tokens[USDC]);
      emit log_named_address('token1 is DAI', tokens[DAI]);
    } else {
      assertEq(poolLow.token0(), tokens[DAI]);
      assertEq(poolLow.token1(), tokens[USDC]);
      emit log_named_address('token0 is DAI', tokens[DAI]);
      emit log_named_address('token1 is USDC', tokens[USDC]);
    }
  }

  function test_tickSpacing() public view {
    int24 tickFeeAmountLow = 10;
    int24 tickFeeAmountMed = 60;
    int24 tickFeeAmountHigh = 200;

    assertTrue(poolLow.fee() == FEE_LOW);
    assertTrue(poolLow.tickSpacing() == tickFeeAmountLow);

    assertTrue(poolMed.fee() == FEE_MED);
    assertTrue(poolMed.tickSpacing() == tickFeeAmountMed);

    assertTrue(poolHigh.fee() == FEE_HIGH);
    assertTrue(poolHigh.tickSpacing() == tickFeeAmountHigh);
  }

  function test_maxLiquidityPerTick() public {
    emit log_named_uint('MAX LIQ LOW ', poolLow.maxLiquidityPerTick());
    emit log_named_uint('MAX LIQ MED ', poolMed.maxLiquidityPerTick());
    emit log_named_uint('MAX LIQ HIGH', poolHigh.maxLiquidityPerTick());
  }
}
