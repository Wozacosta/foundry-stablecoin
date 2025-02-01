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

import { AggregatorV3Interface } from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
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
    mapping(address user => uint256 amountDscMinted) private s_DSCMinted;
    DecentralizedStableCoin private immutable i_dsc;
    address[] private s_collateralTokens;

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
            s_collateralTokens.push(tokenAddresses[i]);
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

    // Check if the collateral value > DSC amount.
    // Price feeds, values, etc...
    // $200 ETH -> $20 DSC (people could pick the value to mint)
    /**
     * @notice follows CEI (Checks, Effects, Interactions)
     * @param amountDscToMint The amount of decentralized stablecoin to mint
     * @notice they must have more collateral value than the minimum threshold
     */
    function mintDSC(uint256 amountDscToMint) external moreThanZero(amountDscToMint) nonReentrant {
        // mint DSC
        s_DSCMinted[msg.sender] += amountDscToMint;
        // if they minted too much ($150 DSC, $100 ETH), revert
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function burnDSC() external {}

    function liquidate() external {}

    function getHealthFactor() external view {}

    /* --------------------- 
    ------- PRIVATE & INTERNAL VIEW FUNCTIONS
    /* --------------------- */
    function _getAccountInformation(address user)
        private
        view
        returns (uint256 totalDscMinted, uint256 collateralValueInUsd)
    {
        // 1. Get the value of all collateral
        // 2. Get the value of all DSC minted
        // 3. Return the value of all DSC minted and the value of all collateral
        totalDscMinted = s_DSCMinted[user];
        collateralValueInUsd = getAccountCollateralValue(user);
    }

    /**
     * RATIO: COLLATERAL / DSCMINTED
     * Returns how close to liquidation a user is
     * If a user's ratio goes below 1, then they can get liquidated
     */
    function _healthFactor(address user) private view returns (uint256) {
        // 1. Get the value of all collateral
        // 2. Get the value of all DSC minted
        // 3. Return the ratio of collateral value to DSC value
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = _getAccountInformation(user);
    }

    function _revertIfHealthFactorIsBroken(address user) internal view {
        // 1. Check health factor (do they have enough collateral?)
        // 2. Revert if not
    }

    /* --------------------- 
    ------- PUBLIC & EXTERNAL VIEW FUNCTIONS
    /* --------------------- */
    function getAccountCollateralValue(address user) public view returns (uint256) {
        // toop through all the collateral tokens
        // get the amount of each token they have deposited
        // map it to the price to get the USD value
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposited[user][token];
            totalCollateralValueInUsd += 
        }
    }
    
    function getUsdValue(address token, uint256 amount) public view returns (uint256) {
        // get the price feed for the token
        // get the price of the token
        // return the price * amount
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price, , , ) = priceFeed.latestRoundData();
        // ETH / USD has 8 decimals (https://docs.chain.link/data-feeds/price-feeds/addresses?network=ethereum&page=1&search=eth+%2Fusd)
        // Same for BTC / USD
    }
}
