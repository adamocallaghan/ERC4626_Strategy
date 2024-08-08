// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC4626} from "lib/solmate/src/tokens/ERC4626.sol";
import {ERC20} from "lib/solmate/src/tokens/ERC20.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

interface Strategy {
    function deposit(uint256 _assets) external;
    function withdraw(uint256 _assets) external;
}

contract Vault is ERC4626, Ownable {
    // STORAGE VARS
    address strategy;

    constructor(ERC20 _asset, string memory _name, string memory _symbol)
        ERC4626(_asset, _name, _symbol)
        Ownable(msg.sender)
    {}

    function beforeWithdraw(uint256 assets, uint256 shares) internal override {
        // get assets from strategy contract
        Strategy(strategy).withdraw(assets);
    }

    function afterDeposit(uint256 assets, uint256 shares) internal override {
        // call deposit on strategy contract
        Strategy(strategy).deposit(assets);
    }

    function totalAssets() public view override returns (uint256) {
        return 1e18;
        // return asset.balanceOf(strategy) + asset.balanceOf(address(this))
        //     + asset.balanceOf(0x72a131650e1DC7373Cf278Be01C3dd7B94f63BAB);
    }

    function setStrategy(address _strategy) public onlyOwner {
        strategy = _strategy;
    }
}
