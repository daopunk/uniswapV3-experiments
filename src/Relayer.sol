// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.7.6;

import {IERC20} from '@openzeppelin/token/ERC20/IERC20.sol';
import {IUniswapV3Factory} from 'lib/v3-core/contracts/interfaces/IUniswapV3Factory.sol';
import {OracleLibrary, IUniswapV3Pool} from 'lib/v3-periphery/contracts/libraries/OracleLibrary.sol';

contract Relayer {
  address public uniV3Pool;
  uint32 public quotePeriod;

  address public baseToken;
  address public quoteToken;

  constructor(address _uniV3Factory, address _baseToken, address _quoteToken, uint24 _feeTier, uint32 _quotePeriod) {
    uniV3Pool = IUniswapV3Factory(_uniV3Factory).getPool(_baseToken, _quoteToken, _feeTier);
    require(uniV3Pool != address(0), 'ZeroAddr');

    address _token0 = IUniswapV3Pool(uniV3Pool).token0();
    address _token1 = IUniswapV3Pool(uniV3Pool).token1();

    if (_token0 == _baseToken) {
      baseToken = _token0;
      quoteToken = _token1;
    } else {
      baseToken = _token1;
      quoteToken = _token0;
    }

    quotePeriod = _quotePeriod;
  }

  function read() external view returns (uint256 _price) {
    (int24 _arithmeticMeanTick,) = OracleLibrary.consult(uniV3Pool, quotePeriod);
    _price = OracleLibrary.getQuoteAtTick({
      tick: _arithmeticMeanTick,
      baseAmount: uint128(1e18),
      baseToken: baseToken,
      quoteToken: quoteToken
    });
  }

  function readWithCustomPeriod(uint32 _quotePeriod) external view returns (uint256 _price) {
    (int24 _arithmeticMeanTick,) = OracleLibrary.consult(uniV3Pool, _quotePeriod);
    _price = OracleLibrary.getQuoteAtTick({
      tick: _arithmeticMeanTick,
      baseAmount: uint128(1e18),
      baseToken: baseToken,
      quoteToken: quoteToken
    });
  }
}
