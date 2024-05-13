// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.6;

import {ERC20} from '@openzeppelin/token/ERC20/ERC20.sol';

/**
 * @title  MintableERC20
 * @dev This ERC20 contract is used for testing purposes, to allow users to mint tokens
 */
contract MintableERC20 is ERC20 {
  uint8 internal _decimals;

  constructor(string memory _name, string memory _symbol, uint8 __decimals) ERC20(_name, _symbol) {
    _decimals = __decimals;
  }

  function decimals() public view virtual override returns (uint8 __decimals) {
    return _decimals;
  }

  function mint(uint256 _wei) external {
    _mint(msg.sender, uint256(uint192(_wei)));
  }

  function mint(address _usr, uint256 _wei) external {
    _mint(_usr, uint256(uint192(_wei)));
  }
}
