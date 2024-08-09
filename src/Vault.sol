// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC4626} from "lib/solmate/src/tokens/ERC4626.sol";
import {ERC20} from "lib/solmate/src/tokens/ERC20.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

interface Strategy {
    function deposit(uint256 _assets) external;
    function withdraw(uint256 _assets) external;
}

interface TroveManager {
    function getTroveColl(address _borrower, address _collateral) external view returns (uint256);
}

contract Vault is ERC4626, Ownable {
    // Storage vars
    address strategy;
    ERC20 icETH = ERC20(0xd2b93816A671A7952DFd2E347519846DD8bF5af2);
    TroveManager TROVE_MANAGER = TroveManager(0xB8E7f7a8763F12f1a4Cfeb87efF1e1886A68152a);

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
        uint256 troveCollateral = TROVE_MANAGER.getTroveColl(address(strategy), address(icETH)); // borrower & collateral
        return troveCollateral;
    }

    function setStrategy(address _strategy) public onlyOwner {
        strategy = _strategy;
    }
}
