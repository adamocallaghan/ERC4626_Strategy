// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC4626} from "lib/solmate/src/tokens/ERC4626.sol";
import {ERC20} from "lib/solmate/src/tokens/ERC20.sol";

contract Vault is ERC4626 {
    // ERRORS
    error Error__AssetsMustBeMoreThanZero();
    error Error__SharesMustBeMoreThanZero();

    constructor(ERC20 _asset, string memory _name, string memory _symbol) ERC4626(_asset, _name, _symbol) {}

    function _deposit(uint256 _assets) public {
        if (_assets <= 0) {
            revert Error__AssetsMustBeMoreThanZero();
        }
        deposit(_assets, msg.sender);
    }

    function _withdraw(uint256 _shares) public {
        if (_shares <= 0) {
            revert Error__SharesMustBeMoreThanZero();
        }
        withdraw(_shares, msg.sender, msg.sender);
    }

    function beforeWithdraw(uint256 assets, uint256 shares) internal override {
        // get assets from strategy contract
    }

    function afterDeposit(uint256 assets, uint256 shares) internal override {
        // pass assets to strategy contract
    }

    function totalAssets() public view override returns (uint256) {
        return asset.balanceOf(address(this));
    }
}
