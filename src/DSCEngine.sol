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

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
// The correct path for ReentrancyGuard in latest Openzeppelin contracts is
//"import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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
contract DSCEngine is ReentrancyGuard {
    /* --------------------- 
    ------- ERRORS ---------
    /* --------------------- */
    error DSCEngine__NeedsMoreThanZero();
    error DSCEngine__TokenAddressesAndPriceFeedAddressesLengthMismatch();
    error DSCEngine__NotAllowedToken();
    error DSCEngine__TransferFailed();

    /* --------------------- 
    ------- STATE VARIABLES
    /* --------------------- */

    mapping(address token => address priceFeed) private s_priceFeeds;
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;
    DecentralizedStableCoin private immutable i_dsc;

    /* --------------------- 
    ------- EVENTS ---------
    /* --------------------- */

    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);

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
        if (s_priceFeeds[tokenAddress] == address(0)) {
            revert DSCEngine__NotAllowedToken();
        }
        _;
    }

    /* --------------------- 
    ------- FUNCTIONS ------
    /* --------------------- */
    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, address dscAddress) {
        // tokenAddresses[0] maps to priceFeedAddresses[0]
        // tokenAddresses[1] maps to priceFeedAddresses[1]
        // etc...
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert DSCEngine__TokenAddressesAndPriceFeedAddressesLengthMismatch();
        }
        // USD Price Feeds (ETH/USD, BTC/USD, MKR/USD)
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
        }
        i_dsc = DecentralizedStableCoin(dscAddress);
    }

    /* --------------------- 
    ------- EXTERNAL FUNCTIONS
    /* --------------------- */
    function depositCollateralAndMintDSC() external {
        // deposit collateral
        // mint DSC
    }

    /**
     * @notice follows CEI (Checks, Effects, Interactions)
     * @param tokenCollateralAddress The address of the token to deposit as collateral
     * @param amountCollateral The amount of collateral to deposit
     */
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        external
        moreThanZero(amountCollateral)
        isAllowedToken(tokenCollateralAddress)
        nonReentrant
    {
        // Effects
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);
        // Interactions
        // TODO: allowance checks?
        // https://ethereum.stackexchange.com/questions/28972/who-is-msg-sender-when-calling-a-contract-from-a-contract
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
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
