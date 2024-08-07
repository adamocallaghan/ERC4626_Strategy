// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {Vault} from "../src/Vault.sol";
import {Strategy} from "../src/Strategy.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {ERC20} from "lib/solmate/src/tokens/ERC20.sol";

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

interface IroncladSP {
    function provideToSP(uint256 _amount) external;
}

contract StrategyTest is Test {
    // contract vars
    Vault vault;
    Strategy strategy;

    // fork vars
    uint256 modeFork;
    string MODE_RPC_URL = vm.envString("MODE_RPC_URL");

    // token vars
    ERC20 weth = ERC20(0x4200000000000000000000000000000000000006);
    ERC20 iUSD = ERC20(0xA70266C8F8Cf33647dcFEE763961aFf418D9E1E4);
    Ironclad IRONCLAD_BORROW = Ironclad(0x72a131650e1DC7373Cf278Be01C3dd7B94f63BAB);
    IroncladSP IRONCLAD_SP = IroncladSP(0x193aDcE432205b3FF34B764230E81430c9E3A7B5);

    // user vars
    address user = makeAddr("user");

    function setUp() public {
        // fork and select mode
        modeFork = vm.createFork(MODE_RPC_URL);
        vm.selectFork(modeFork);

        // create instances of vault and strat
        vault = new Vault(weth, "xWrappedEth", "xWETH");
        strategy = new Strategy(weth, address(vault));
        vault.setStrategy(address(strategy));

        // approve strat to spend vault's weth
        vm.startPrank(address(vault));
        weth.approve(address(strategy), type(uint256).max);
        vm.stopPrank();

        // give user some weth
        deal(address(weth), user, 100e18, false);

        // give strategy ironcladETH
        // deal(address(0xd2b93816A671A7952DFd2E347519846DD8bF5af2), address(strategy), 10000e18, false);

        // approve Ironclad to spend strat's weth
        vm.startPrank(address(strategy));
        weth.approve(address(IRONCLAD_BORROW), type(uint256).max);
        vm.stopPrank();
    }

    function test_UserCanDepositToVaultAndMintIUsd() public {
        vm.startPrank(user);
        weth.approve(address(vault), type(uint256).max); // approve vault to spend user's weth
        vault.deposit(2000000000000000000, msg.sender); // call deposit on vault
        vm.stopPrank();
    }

    function test_UserCanRepayIUsdAndWithdrawFromVault() public {
        deal(address(weth), address(vault), 100e18, false);
        // prank strat
        vm.startPrank(address(strategy));
        iUSD.approve(address(IRONCLAD_BORROW), type(uint256).max);
        vm.stopPrank();

        // deposit and mint as user
        depositEthAndMintIUsd();

        // prank user
        vm.startPrank(user);
        vault.withdraw(1000000000000000000, msg.sender, msg.sender); // call deposit on vault
        vm.stopPrank();
    }

    function depositEthAndMintIUsd() public {
        vm.startPrank(user);
        weth.approve(address(vault), type(uint256).max); // approve vault to spend user's weth
        vault.deposit(2000000000000000000, msg.sender); // call deposit on vault
        vm.stopPrank();
    }
}
