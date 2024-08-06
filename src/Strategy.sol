// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC4626} from "lib/solmate/src/tokens/ERC4626.sol";
import {ERC20} from "lib/solmate/src/tokens/ERC20.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

interface Ironclad {
    function openTrove(
        address _collateral,
        uint256 _collAmount,
        uint256 _maxFeePercentage,
        uint256 _LUSDAmount,
        address _upperHint,
        address _lowerHint
    ) external;
}

interface AggregatorV3Interface {
    function latestAnswer() external view returns (int256);
}

interface RedstoneOracle {
    function priceOfEth() external returns (uint256);
}

contract Strategy {
    // STORAGE VARS
    ERC20 asset;
    address vault;
    Ironclad IRONCLAD = Ironclad(0x72a131650e1DC7373Cf278Be01C3dd7B94f63BAB);
    RedstoneOracle REDSTONE = RedstoneOracle(0x7C1DAAE7BB0688C9bfE3A918A4224041c7177256);

    constructor(ERC20 _asset, address _vault) {
        asset = _asset;
        vault = _vault;
    }

    // STRATEGY FUNCTIONS

    // IRONCLAD DEPOSIT
    function deposit(uint256 _assets) public {
        asset.transferFrom(vault, address(this), _assets); // approve strategy to spend max asset on deploy
        _depositWethAndMintIusd(_assets);
    }

    // DEPOSIT WETH + MINT iUSD ON IRONCLAD (MODE)
    function _depositWethAndMintIusd(uint256 _assets) internal {
        // get ETH price using oracle
        uint256 ethPrice = REDSTONE.priceOfEth();

        // ensure that there's a 150% CR
        uint256 totalCollateralInUsd = _assets * ethPrice;
        uint256 availableToBorrowInUsd = (totalCollateralInUsd / 3) * 2;

        IRONCLAD.openTrove(
            address(asset), _assets, 5000000000000000, availableToBorrowInUsd, address(this), address(this)
        );
    }

    // DEPOSIT iUSD INTO IRONCLAD STABILITY POOL (MODE)
    function _depositIusdToStabilityPool() internal {}
}
