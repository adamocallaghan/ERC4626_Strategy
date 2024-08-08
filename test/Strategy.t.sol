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
    ERC20 oICL = ERC20(0x3B6eA0fA8A487c90007ce120a83920fd52b06f6D);
    ERC20 ModeToken = ERC20(0xDfc7C877a950e49D2610114102175A06C2e3167a);
    address oICLImplementationContract = 0x14A291BE13B6b7CeF070C41C65ea9756Ed5A9b58;
    address oICLExerciseContract = 0xcb727532e24dFe22E74D3892b998f5e915676Da8;
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

        // approve Ironclad to spend strat's weth
        vm.startPrank(address(strategy));
        weth.approve(address(IRONCLAD_BORROW), type(uint256).max);
        vm.stopPrank();

        // approve Ironclad to spend strat's iUsd
        vm.startPrank(address(strategy));
        iUSD.approve(address(IRONCLAD_BORROW), type(uint256).max);
        vm.stopPrank();
    }

    function test_UserCanDepositToVaultAndMintIUsd() public {
        vm.startPrank(user);
        weth.approve(address(vault), type(uint256).max); // approve vault to spend user's weth
        vault.deposit(2000000000000000000, user); // call deposit on vault
        vm.stopPrank();
    }

    function test_UserCanRepayIUsdAndWithdrawFromVault() public {
        // deposit and mint as user
        address _user = makeAddr("user");
        depositEthAndMintIUsd(_user);

        // prank and withdraw as user
        vm.prank(user);
        vault.withdraw(1000000000000000000, _user, _user); // call withdraw on vault
    }

    function test_multipleUsersCanDepositToVaultAndMintIUsd() public {
        address _user1 = makeAddr("user1");
        address _user2 = makeAddr("user2");
        address _user3 = makeAddr("user3");

        deal(address(weth), _user1, 100e18, false);
        deal(address(weth), _user2, 100e18, false);
        deal(address(weth), _user3, 100e18, false);

        depositEthAndMintIUsd(_user1);
        depositEthAndMintIUsd(_user2);
        depositEthAndMintIUsd(_user3);
    }

    function test_harvestRewards() public {
        deal(address(oICL), address(strategy), 1000e18, true);
        deal(address(ModeToken), address(strategy), 100000e18, true);

        vm.startPrank(address(strategy));
        ERC20(address(oICL)).approve(oICLExerciseContract, type(uint256).max);
        ERC20(address(oICL)).approve(oICLImplementationContract, type(uint256).max);
        ERC20(address(ModeToken)).approve(oICLExerciseContract, type(uint256).max);
        ERC20(address(ModeToken)).approve(oICLImplementationContract, type(uint256).max);
        vm.stopPrank();

        strategy.harvest();
    }

    function depositEthAndMintIUsd(address _user) public {
        vm.startPrank(_user);
        weth.approve(address(vault), type(uint256).max); // approve vault to spend user's weth
        vault.deposit(2000000000000000000, _user); // call deposit on vault
        vm.stopPrank();
    }
}
