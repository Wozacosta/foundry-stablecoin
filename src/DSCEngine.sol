// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// This is considered an Exogenous, Decentralized, Anchored (pegged), Crypto Collateralized low volitility coin

// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

/**
 * @title DSCEngine
 * @author Wozacosta
 *
 * The system is designed to be as minimal as possible, and have the tokens
 * maintain a 1 token == $1 peg.
 * This stablecoin has those properties:
 * - Exogenous Collateral
 * - Dollar pegged
 * - Algorithmically stable
 *
 * It is similar to DAI if DAI had no governance, no fees, and was only
 * backed by wETH and wBTC.
 *
 * Our DSC system should always be "overcollateralized". At no point, should the value of
 * all collateral < the $ backed value of all the DSC.
 *
 *
 * @notice This contract is the core of the Decentralized Stablecoin system. It handles all the logic
 * for minting and redeeming DSC, as well as depositing and withdrawing collateral.
 * @notice This contract is based on the MakerDAO DSS system // https://github.com/makerdao/dss
 */
contract DSCEngine {
    /* --------------------- 
    ------- ERRORS ---------
    /* --------------------- */
    error DSCEngine__NeedsMoreThanZero();
    /* --------------------- 
    ------- STATE VARIABLES
    /* --------------------- */
    mapping(address token => address priceFeed) private s_priceFeeds;

    /* --------------------- 
    ------- MODIFIERS ------
    /* --------------------- */
    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert DSCEngine__NeedsMoreThanZero();
        }
        _;
    }
    modifier isAllowedToken(address tokenAddress) {
        require(tokenAddress != address(0), "DSCEngine__NotZeroAddress");
        _;
    }

    /* --------------------- 
    ------- FUNCTIONS ------
    /* --------------------- */
    constructor() {}

    /* --------------------- 
    ------- EXTERNAL FUNCTIONS
    /* --------------------- */
    function depositCollateralAndMintDSC() external {
        // deposit collateral
        // mint DSC
    }

    /**
     * @param tokenCollateralAddress The address of the token to deposit as collateral
     * @param amountCollateral The amount of collateral to deposit
     */
    function depositCollateral(
        address tokenCollateralAddress,
        uint256 amountCollateral
    ) external moreThanZero(amountCollateral) {
        // deposit collateral
    }

    function redeemCollateralForDSC() external {
        // redeem DSC
        // withdraw collateral
    }

    function redeemCollateral() external {
        // withdraw collateral
    }

    function mintDSC() external {
        // mint DSC
    }

    function burnDSC() external {}

    function liquidate() external {}

    function getHealthFactor() external view {}
}
