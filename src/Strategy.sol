// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC4626} from "lib/solmate/src/tokens/ERC4626.sol";
import {ERC20} from "lib/solmate/src/tokens/ERC20.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {IRouter} from "./interfaces/IRouter.sol";

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

interface IroncladRewarder {
    function claimAllRewardsToSelf(address[] calldata assets)
        external
        returns (address[] memory rewardTokens, uint256[] memory claimedAmounts);
}

interface IroncladOptionToken {
    function exercise(uint256 amount, address recipient, address option, bytes calldata params) external;
}

interface RedstoneOracle {
    function priceOfEth() external returns (uint256);
    function latestAnswer() external view returns (int256);
    function getBlockTimestamp() external view returns (uint256);
    function getOracleNumericValueFromTxMsg(bytes32) external view returns (uint256);
    function getValueForDataFeedUnsafe(bytes32) external view returns (uint256);
}

struct DiscountExerciseParams {
    uint256 maxPaymentAmount;
    uint256 deadline;
}

contract Strategy {
    // STORAGE VARS
    ERC20 asset;
    ERC20 icETH = ERC20(0xd2b93816A671A7952DFd2E347519846DD8bF5af2);
    address vault;

    Ironclad IRONCLAD_BORROW = Ironclad(0x72a131650e1DC7373Cf278Be01C3dd7B94f63BAB);
    IroncladSP IRONCLAD_SP = IroncladSP(0x193aDcE432205b3FF34B764230E81430c9E3A7B5);
    IroncladRewarder IRONCLAD_REWARDER = IroncladRewarder(0xC043BA54F34C9fb3a0B45d22e2Ef1f171272Bc9D);
    IroncladOptionToken IRONCLAD_OPTION_TOKEN = IroncladOptionToken(0x3B6eA0fA8A487c90007ce120a83920fd52b06f6D);
    address IRONCLAD_OPTION_TOKEN_EXERCISE_ADDRESS = 0xcb727532e24dFe22E74D3892b998f5e915676Da8;

    address[] rewarderAssetList = [
        0xe7334Ad0e325139329E747cF2Fc24538dD564987,
        0xe5415Fa763489C813694D7A79d133F0A7363310C,
        0x02CD18c03b5b3f250d2B29C87949CDAB4Ee11488,
        0xBcE07537DF8AD5519C1d65e902e10aA48AF83d88,
        0x9c29a8eC901DBec4fFf165cD57D4f9E03D4838f7,
        0x06D38c309d1dC541a23b0025B35d163c25754288,
        0x272CfCceFbEFBe1518cd87002A8F9dfd8845A6c4,
        0x5eEA43129024eeE861481f32c2541b12DDD44c08,
        0x58254000eE8127288387b04ce70292B56098D55C,
        0x05249f9Ba88F7d98fe21a8f3C460f4746689Aea5,
        0xe3f709397e87032E61f4248f53Ee5c9a9aBb6440,
        0x083E519E76fe7e68C15A6163279eAAf87E2addAE,
        0xC17312076F48764d6b4D263eFdd5A30833E311DC,
        0x3F332f38926b809670b3cac52Df67706856a1555,
        0x4522DBc3b2cA81809Fa38FEE8C1fb11c78826268,
        0xF8D68E1d22FfC4f09aAA809B21C46560174afE9c,
        0x0F4f2805a6d15dC534d43635314444181A0e82CD,
        0xe57Bf381Fc0a7C5e6c2A3A38Cc09de37b29CC4C3
    ];

    RedstoneOracle REDSTONE = RedstoneOracle(0x7C1DAAE7BB0688C9bfE3A918A4224041c7177256);
    RedstoneOracle REDSTONE_PROXY = RedstoneOracle(0x0e2d75D760b12ac1F2aE84CD2FF9fD13Cb632942);
    bytes32 REDSTONE_ETH_FEED_ID = 0x4554480000000000000000000000000000000000000000000000000000000000;

    IRouter VELODROME_ROUTER = IRouter(0xa062aE8A9c5e11aaA026fc2670B0D65cCc8B2858);

    uint256 timesDepositCalled = 0;

    constructor(ERC20 _asset, address _vault) {
        asset = _asset;
        vault = _vault;
    }

    // ***************
    // *** DEPOSIT ***
    // ***************

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

        if (timesDepositCalled == 0) {
            IRONCLAD_BORROW.openTrove(
                address(icETH), _assets, 5000000000000000, availableToBorrowInUsd, address(0), address(this)
            );
        } else {
            IRONCLAD_BORROW.adjustTrove(
                address(icETH), 5000000000000000, _assets, 0, availableToBorrowInUsd, true, address(0), address(this)
            );
        }

        timesDepositCalled++;

        return availableToBorrowInUsd;
    }

    // Deposit iUSD into Ironclad stability pool...
    function _depositIusdToStabilityPool(uint256 _iUsdBorrowAmount) internal {
        IRONCLAD_SP.provideToSP(_iUsdBorrowAmount);
    }

    // ****************
    // *** WITHDRAW ***
    // ****************

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
        asset.transfer(address(vault), _assets);
    }

    // ***************
    // *** HARVEST ***
    // ***************

    function _harvest() internal {
        // claim Ironclad oICL rewards to this contract
        (address[] memory rewardTokens, uint256[] memory claimedAmounts) =
            IRONCLAD_REWARDER.claimAllRewardsToSelf(rewarderAssetList);

        // get the amount of oICL we can exercise
        uint256 optionTokenExerciseAmount;

        for (uint256 i = 0; i < rewardTokens.length; i++) {
            if (rewardTokens[i] == address(IRONCLAD_OPTION_TOKEN)) {
                optionTokenExerciseAmount = claimedAmounts[i];
            }
        }

        // construct slippage & deadline params
        DiscountExerciseParams memory params =
            DiscountExerciseParams({maxPaymentAmount: type(uint256).max, deadline: type(uint256).max}); // @todo maxPaymentAmount to be calc'd

        // We need $MODE tokens to exercise the options... swap? Flash loan?
        // In tests I will top up the contract with $MODE using deal()

        // call exerise on oICL token
        IRONCLAD_OPTION_TOKEN.exercise(
            optionTokenExerciseAmount, address(this), IRONCLAD_OPTION_TOKEN_EXERCISE_ADDRESS, abi.encode(params)
        );

        // swap ICL tokens into WETH on Velodrom
        // weth = 0x4200000000000000000000000000000000000006
        // icl = 0x95177295a394f2b9b04545fff58f4af0673e839d
        IRouter.route[] memory wethToIclRoutes;
        IRouter.route memory wethToIcl;
        wethToIcl.from = address(asset);
        wethToIcl.to = 0x95177295A394f2b9B04545FFf58f4aF0673E839d;
        wethToIcl.stable = false;
        wethToIclRoutes[0] = wethToIcl;

        VELODROME_ROUTER.swapExactTokensForTokens(
            optionTokenExerciseAmount, 0, wethToIclRoutes, address(this), type(uint256).max
        );

        // redeposit WETH into Ironclad, mint iUSD, and deposit into the SP again
    }
}
