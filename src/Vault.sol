// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC4626} from "lib/solmate/src/tokens/ERC4626.sol";
import {ERC20} from "lib/solmate/src/tokens/ERC20.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

contract Vault is ERC4626, Ownable {
    // STORAGE VARS
    address strategy;

    constructor(ERC20 _asset, string memory _name, string memory _symbol, address _strategy)
        ERC4626(_asset, _name, _symbol)
        Ownable(msg.sender)
    {
        strategy = _strategy;
    }

    function beforeWithdraw(uint256 assets, uint256 shares) internal override {
        // get assets from strategy contract
        asset.transferFrom(strategy, address(this), assets);
    }

    function afterDeposit(uint256 assets, uint256 shares) internal override {
        // pass assets to strategy contract
        asset.transfer(strategy, assets);
    }

    function totalAssets() public view override returns (uint256) {
        return asset.balanceOf(strategy) + asset.balanceOf(address(this));
    }
}
