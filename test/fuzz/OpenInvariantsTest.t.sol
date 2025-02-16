// SPDX-License-Identifier: MIT

// What are open tests?
// https://www.rareskills.io/post/invariant-testing-solidity

// Have our invariants, aka properties that should always hold

// What are our invariants?

// 1. The total supply of DSC should be less than the total value of collateral
// 2. Getter view functions should never revert <- evergreen invariant

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
// import { ERC20Mock } from "@openzeppelin/contracts/mocks/ERC20Mock.sol"; Updated mock location
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {console} from "forge-std/console.sol";

contract OpenInvariantsTest is StdInvariant, Test {
    DSCEngine public dsce;
    DecentralizedStableCoin public dsc;
    HelperConfig public helperConfig;

    address public ethUsdPriceFeed;
    address public btcUsdPriceFeed;
    address public weth;
    address public wbtc;

    uint256 amountCollateral = 10 ether;
    uint256 amountToMint = 100 ether;

    uint256 public constant STARTING_USER_BALANCE = 10 ether;
    address public constant USER = address(1);
    uint256 public constant MIN_HEALTH_FACTOR = 1e18;
    uint256 public constant LIQUIDATION_THRESHOLD = 50;

    // Liquidation
    address public liquidator = makeAddr("liquidator");
    uint256 public collateralToCover = 20 ether;

    function setUp() external {
        DeployDSC deployer = new DeployDSC();
        (dsc, dsce, helperConfig) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, weth, wbtc, ) = helperConfig
            .activeNetworkConfig();
        targetContract(address(dsce));
    }

    function invariant_protocolMustHaveMoreValueThatTotalSupplyDollars()
        public
        view
    {
        // get all the debt
        uint256 totalSupply = dsc.totalSupply();
        // get the value of all the collateral in the protocol
        uint256 wethDeposted = ERC20Mock(weth).balanceOf(address(dsce));
        uint256 wbtcDeposited = ERC20Mock(wbtc).balanceOf(address(dsce));

        uint256 wethValue = dsce.getUsdValue(weth, wethDeposted);
        uint256 wbtcValue = dsce.getUsdValue(wbtc, wbtcDeposited);

        console.log("wethValue: %s", wethValue);
        console.log("wbtcValue: %s", wbtcValue);

        assert(wethValue + wbtcValue >= totalSupply);
    }

    function invariant_gettersCantRevert() public view {
        dsce.getAdditionalFeedPrecision();
        dsce.getCollateralTokens();
        dsce.getLiquidationBonus();
        dsce.getLiquidationThreshold();
        dsce.getMinHealthFactor();
        dsce.getPrecision();
        dsce.getDsc();
        // dsce.getTokenAmountFromUsd();
        // dsce.getCollateralTokenPriceFeed();
        // dsce.getCollateralBalanceOfUser();
        // getAccountCollateralValue();
    }
}
