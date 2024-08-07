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
    function adjustTrove(
        address _collateral,
        uint256 _maxFeePercentage,
        uint256 _collTopUp,
        uint256 _collWithdrawal,
        uint256 _LUSDChange,
        bool _isDebtIncrease,
        address _upperHint,
        address _lowerHint
    ) external;
}

interface IroncladSP {
    function provideToSP(uint256 _amount) external;
    function withdrawFromSP(uint256 _amount) external;
}

interface RedstoneOracle {
    function priceOfEth() external returns (uint256);
    function latestAnswer() external view returns (int256);
    function getBlockTimestamp() external view returns (uint256);
    function getOracleNumericValueFromTxMsg(bytes32) external view returns (uint256);
    function getValueForDataFeedUnsafe(bytes32) external view returns (uint256);
}

contract Strategy {
    // STORAGE VARS
    ERC20 asset;
    ERC20 icETH = ERC20(0xd2b93816A671A7952DFd2E347519846DD8bF5af2);
    address vault;
    Ironclad IRONCLAD_BORROW = Ironclad(0x72a131650e1DC7373Cf278Be01C3dd7B94f63BAB);
    IroncladSP IRONCLAD_SP = IroncladSP(0x193aDcE432205b3FF34B764230E81430c9E3A7B5);
    RedstoneOracle REDSTONE = RedstoneOracle(0x7C1DAAE7BB0688C9bfE3A918A4224041c7177256);
    RedstoneOracle REDSTONE_PROXY = RedstoneOracle(0x0e2d75D760b12ac1F2aE84CD2FF9fD13Cb632942);
    bytes32 REDSTONE_ETH_FEED_ID = 0x4554480000000000000000000000000000000000000000000000000000000000;

    constructor(ERC20 _asset, address _vault) {
        asset = _asset;
        vault = _vault;
    }

    // ==================
    // STRATEGY FUNCTIONS
    // ==================

    // Deposit entrypoint...
    function deposit(uint256 _assets) public {
        asset.transferFrom(vault, address(this), _assets); // strat has to be approved to spend vault's weth beforhand
        uint256 iUsdBorrowAmount = _depositWethAndMintIusd(_assets);
        _depositIusdToStabilityPool(iUsdBorrowAmount);
    }

    // Deposit WETH & Mint iUSD on Ironclad...
    function _depositWethAndMintIusd(uint256 _assets) internal returns (uint256) {
        uint256 ethPrice = REDSTONE_PROXY.getValueForDataFeedUnsafe(REDSTONE_ETH_FEED_ID);

        // ensure that there is a 150% collateralisation ratio on minted iUSD
        uint256 totalCollateralInUsd = _assets * (ethPrice * 1e10); // ethPrice returned in 1e8, needs rounding up by 1e10
        uint256 availableToBorrowInUsd = ((totalCollateralInUsd / 3) * 2) / 1e18; // total needs to be rounded down for Ironclad

        IRONCLAD_BORROW.openTrove(
            address(icETH), _assets, 5000000000000000, availableToBorrowInUsd, address(0), address(this)
        );

        return availableToBorrowInUsd;
    }

    // Deposit iUSD into Ironclad stability pool...
    function _depositIusdToStabilityPool(uint256 _iUsdBorrowAmount) internal {
        IRONCLAD_SP.provideToSP(_iUsdBorrowAmount);
    }

    // Withdraw entrypoint...
    function withdraw(uint256 _assets) public {
        uint256 amountInIUsdToRepay = _calculateIUsdAmountAndRemoveFromStabilityPool(_assets);
        _repayDebtAndWithdrawCollateral(_assets, amountInIUsdToRepay);
    }

    // Calculate iUSD to withdraw from Stability Pool and withdraw it...
    function _calculateIUsdAmountAndRemoveFromStabilityPool(uint256 _assets) internal returns (uint256) {
        uint256 ethPrice = REDSTONE_PROXY.getValueForDataFeedUnsafe(REDSTONE_ETH_FEED_ID);

        uint256 withdrawalCollateralInUsd = _assets * (ethPrice * 1e10);
        uint256 amountInIUsdToWithdraw = ((withdrawalCollateralInUsd / 3) * 2) / 1e18;

        IRONCLAD_SP.withdrawFromSP(amountInIUsdToWithdraw);

        return amountInIUsdToWithdraw;
    }

    // Repay iUSD debt and withdraw collateral...
    function _repayDebtAndWithdrawCollateral(uint256 _assets, uint256 _iUsdRepayAmount) internal {
        IRONCLAD_BORROW.adjustTrove(
            address(icETH), 5000000000000000, 0, _assets, _iUsdRepayAmount, false, address(0), address(this)
        );
    }
}
