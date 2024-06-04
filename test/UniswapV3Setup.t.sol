// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.7.6;
pragma abicoder v2;

import {Test, console} from 'forge-std/Test.sol';
import {UniswapV3Factory, IUniswapV3Factory} from '@uniswapv3/UniswapV3Factory.sol';
import {UniswapV3Pool, IUniswapV3Pool} from '@uniswapv3/UniswapV3Pool.sol';
import {MintableERC20} from 'src/MintableERC20.sol';
import {Router} from 'src/Router.sol';

contract UniswapV3Setup is Test {
  bytes32 public constant TA = bytes32('TA');
  bytes32 public constant TB = bytes32('TB');
  uint256 public constant MINT = 100_000 ether;

  uint24 public constant FEE_LOW = 500;
  uint24 public constant FEE_MED = 3000;
  uint24 public constant FEE_HIGH = 10_000;

  address public deployer = address(this);
  address public alice = address(0xa11ce);
  address public bob = address(0xb0b);
  address public cara = address(0xca7a);
  address public deb = address(0xdeb);

  /// uniswap contracts
  UniswapV3Factory public factory;
  UniswapV3Pool public poolLow;
  UniswapV3Pool public poolMed;
  UniswapV3Pool public poolHigh;

  // periphery contracts
  Router public router;

  // erc20 tokens
  MintableERC20 public tokenA;
  MintableERC20 public tokenB;

  // data structures
  address[] public usrs;
  mapping(bytes32 => address) public tokens;

  function setUp() public virtual {
    _setupTokens();

    factory = new UniswapV3Factory();

    /// @notice TA = tokenA, TB = tokenB
    poolLow = UniswapV3Pool(factory.createPool(tokens[TA], tokens[TB], FEE_LOW));
    poolMed = UniswapV3Pool(factory.createPool(tokens[TA], tokens[TB], FEE_MED));
    poolHigh = UniswapV3Pool(factory.createPool(tokens[TA], tokens[TB], FEE_HIGH));

    router = new Router(poolLow);

    _setupUsers(router);
  }

  function _setupUsers(Router _router) public {
    usrs = new address[](4);
    usrs[0] = alice;
    usrs[1] = bob;
    usrs[2] = cara;
    usrs[3] = deb;
    for (uint256 i = 0; i < usrs.length; i++) {
      vm.startPrank(usrs[i]);
      tokenA.mint(MINT);
      tokenA.approve(address(_router), MINT);
      tokenB.mint(MINT);
      tokenB.approve(address(_router), MINT);
      vm.stopPrank();
    }
  }

  function _setupTokens() internal {
    tokenA = new MintableERC20('TA', 'TA', 18);
    tokenB = new MintableERC20('TB', 'TB', 18);
    tokens[TA] = address(tokenA);
    tokens[TB] = address(tokenB);
  }
}

contract UniswapV3SetupTest is UniswapV3Setup {
  function test_userBalances() public view {
    for (uint256 i = 0; i < usrs.length; i++) {
      assertEq(tokenA.balanceOf(usrs[i]), MINT);
      assertEq(tokenB.balanceOf(usrs[i]), MINT);
    }
  }

  function test_poolfactory() public view {
    assertEq(poolLow.factory(), address(factory));
  }

  function test_poolTokens() public {
    if (tokens[TA] < tokens[TB]) {
      assertEq(poolLow.token0(), tokens[TA]);
      assertEq(poolLow.token1(), tokens[TB]);
      emit log_named_address('token0 is TA', tokens[TA]);
      emit log_named_address('token1 is TB', tokens[TB]);
    } else {
      assertEq(poolLow.token0(), tokens[TB]);
      assertEq(poolLow.token1(), tokens[TA]);
      emit log_named_address('token0 is TB', tokens[TB]);
      emit log_named_address('token1 is TA', tokens[TA]);
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
