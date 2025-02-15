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

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
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
    error DSCEngine__BreaksHealthFactor(uint256 healthFactor);
    error DSCEngine__HealthFactorOk();
    error DSCEngine__MintFailed();
    error DSCEngine__HealthFactorNotImproved();

    /* --------------------- 
    ------- STATE VARIABLES
    /* --------------------- */
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;

    uint256 private constant MIN_HEALTH_FACTOR = 1e18;

    uint256 private constant LIQUIDATION_THRESHOLD = 50; // 1/2 = you need to have double the collateral value
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant LIQUIDATION_BONUS = 10; // this means a 10% bonus
    // NEED TO BE 200% OVERCOLLATERALIZED

    mapping(address token => address priceFeed) private s_priceFeeds;
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;
    mapping(address user => uint256 amountDscMinted) private s_DSCMinted;
    DecentralizedStableCoin private immutable i_dsc;
    address[] private s_collateralTokens;

    /* --------------------- 
    ------- EVENTS ---------
    /* --------------------- */

    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);
    event CollateralRedeemed(
        address indexed redeemedFrom, address indexed redeemedTo, address indexed token, uint256 amount
    );

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

    /**
     *
     * @param tokenCollateralAddress The address of the token to deposit as collateral
     * @param amountCollateral The amount of collateral to deposit
     * @param amountDscToMint The amount of decentralized stablecoin to mint
     * @notice this function will deposit your collateral and mint DSC in one transaction
     */
    function depositCollateralAndMintDSC(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        uint256 amountDscToMint
    ) external {
        depositCollateral(tokenCollateralAddress, amountCollateral);
        mintDSC(amountDscToMint);
    }

    /**
     * @notice follows CEI (Checks, Effects, Interactions)
     * @param tokenCollateralAddress The address of the token to deposit as collateral
     * @param amountCollateral The amount of collateral to deposit
     */
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
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

    /**
     *
     * @param tokenCollateralAddress  The collateral token address to redeem
     * @param amountCollateral  The amount of collateral to redeem
     * @param amountDscToBurn  The amount of DSC to burn
     * This function burns DSC and redeems underlying collateral in one transaction
     */
    function redeemCollateralForDSC(address tokenCollateralAddress, uint256 amountCollateral, uint256 amountDscToBurn)
        external
    {
        burnDSC(amountDscToBurn);
        redeemCollateral(tokenCollateralAddress, amountCollateral);
        // note: redeemCollateral already checks health factor
    }

    // in order to redeem:
    // 1. health factor must be above 1 AFTER collateral pulled out
    // CEI, checks effects interactions
    function redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral)
        nonReentrant
    {
        _redeemCollateral(msg.sender, msg.sender, tokenCollateralAddress, amountCollateral);
        _revertIfHealthFactorIsBroken(msg.sender);
        // $100 ETH collateral AND $20 DSC minted
        // Try to redeem $100 ETH and burn $20 DSC
        // 1. if redeem first
        // $0 ETH, $20 DSC minted
        // Then breaks health factor
        // note: we need to burn DSC first, then redeem collateral
    }

    // Check if the collateral value > DSC amount.
    // Price feeds, values, etc...
    // $200 ETH -> $20 DSC (people could pick the value to mint)
    /**
     * @notice follows CEI (Checks, Effects, Interactions)
     * @param amountDscToMint The amount of decentralized stablecoin to mint
     * @notice they must have more collateral value than the minimum threshold
     */
    function mintDSC(uint256 amountDscToMint) public moreThanZero(amountDscToMint) nonReentrant {
        // mint DSC
        s_DSCMinted[msg.sender] += amountDscToMint;
        // if they minted too much ($150 DSC, $100 ETH), revert
        _revertIfHealthFactorIsBroken(msg.sender);
        bool minted = i_dsc.mint(msg.sender, amountDscToMint);
        if (!minted) {
            revert DSCEngine__MintFailed();
        }
    }

    function burnDSC(uint256 amount) public moreThanZero(amount) {
        _burnDSC(amount, msg.sender, msg.sender);
        // NOTE: only as a backup, it shouldn't ever break the health factor
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    // If someone is almost undercollateralized, we will pay you to liquidate them
    /**
     * @notice this function will liquidate a user if their health factor is below 1
     * @param collateral The erc20 collateral address to liquidate from the user
     * @param user The user who has broken the health factor. Their _healthFactor should be below MIN_HEALTH_FACTOR
     * @param debtToCover The amount of DSC you want to burn to improve the users health factor
     * @notice msg.sender The one who is liquidating the user, by paying off their debt
     * @notice You can partially liquidate a user.
     * @notice You will get a liquidation bonus for taking a user's funds.
     * @notice This function working assumes the protocol will be roughly 200% overcollateralized in order
     * for this to work
     * @notice A known bug would be if the protocol were 100% or less collateralized, then we wouldn't be able to incentivize the liquidators.
     * For example, if the price of the collateral plummeted before anyone could be liquidated.
     *
     * Follows CEI: Checks, Effects, Interactions
     */
    function liquidate(address collateral, address user, uint256 debtToCover)
        external
        moreThanZero(debtToCover)
        nonReentrant
    {
        // need to check health factor of the user
        uint256 startingUserHealthFactor = _healthFactor(user);
        if (startingUserHealthFactor >= MIN_HEALTH_FACTOR) {
            revert DSCEngine__HealthFactorOk();
        }
        // We want to burn their DSC "debt"
        // And take their collateral
        // Bad User: $140 wETH, $100 DSC.
        // debtToCover = $100
        uint256 tokenAmountFromDebtCovered = getTokenAmountFromUsd(collateral, debtToCover);
        // = 0.05 ETH
        // And give them a 10% bonus
        // So we are giving the liquidator $110 of wETH for 100 DSC
        // TODO: We should implement a feature to liquidate in the event the protocol is insolvent
        // TODO:     And sweep extra amounts into a treasury
        uint256 bonusCollateral = (tokenAmountFromDebtCovered * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;
        uint256 totalCollateralToRedeem = tokenAmountFromDebtCovered + bonusCollateral;
        _redeemCollateral(user, msg.sender, collateral, totalCollateralToRedeem);
        _burnDSC(debtToCover, user, msg.sender);
        uint256 endingUserHealthFactor = _healthFactor(user);
        // we didn't improve the health factor
        if (endingUserHealthFactor <= startingUserHealthFactor) {
            revert DSCEngine__HealthFactorNotImproved();
        }
        // if this process ruined their health factor, we shouldn't let them liquidate
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    function getHealthFactor() external view {}

    /* --------------------- 
    ------- PRIVATE & INTERNAL VIEW FUNCTIONS
    /* --------------------- */
    /**
     *
     * @param amountDscToBurn how much DSC to burn
     * @param onBehalfOf whose debt are we paying off, whose Dsc are we burning
     * @param dscFrom whose DSC are we burning
     * @dev low-level internal function, do not call unless function calling it is checking for health factors being broken
     */
    function _burnDSC(uint256 amountDscToBurn, address onBehalfOf, address dscFrom)
        private
        moreThanZero(amountDscToBurn)
    {
        // note: why don't we decrease [dscFrom] instead?
        // fixme: might be error prone
        s_DSCMinted[onBehalfOf] -= amountDscToBurn;
        // note: why not burn it directly?
        // -> because i_dsc.burn(amount) is onlyOwner, but still checks
        // if the balance is enough
        // NOTE: why dsc from ????
        bool success = i_dsc.transferFrom(dscFrom, address(this), amountDscToBurn);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
        i_dsc.burn(amountDscToBurn);
    }

    function _redeemCollateral(address from, address to, address tokenCollateralAddress, uint256 amountCollateral)
        private
    {
        // 100 - 1000 will revert with "panic: arithmetic underflow or overflow (0x11)"
        s_collateralDeposited[from][tokenCollateralAddress] -= amountCollateral;
        emit CollateralRedeemed(from, to, tokenCollateralAddress, amountCollateral);
        // NOTE: transfer, FROM assumed to be sender
        // NOTE:     transferfrom, set the FROM as the first argument
        bool success = IERC20(tokenCollateralAddress).transfer(to, amountCollateral);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

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
        uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateralAdjustedForThreshold * PRECISION) / totalDscMinted;
        // WITHOUT THRESHOLD if collateral / dscminted:
        //      $150 ETH / 100 DSC = 1.5    👌
        // NOW WITH THRESHOLD:
        //      LIQUIDATION_THRESHOLD = 50
        //      1000 ETH * 50 = 50,000 / 100 = 500
        // OR  150 * 50= 7500 /  100= (75/100) <1  😭
    }

    // 1. Check health factor (do they have enough collateral?)
    // 2. Revert if not
    function _revertIfHealthFactorIsBroken(address user) internal view {
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine__BreaksHealthFactor(userHealthFactor);
        }
    }

    /* --------------------- 
    ------- PUBLIC & EXTERNAL VIEW FUNCTIONS
    /* --------------------- */
    function getTokenAmountFromUsd(address token, uint256 usdAmountInWei) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        // 1000$(price) / ETH
        // 50$(usdAmountInWei) = usdAmountInWei / price
        uint256 priceWithPrecision = uint256(price) * ADDITIONAL_FEED_PRECISION;
        return (usdAmountInWei * PRECISION) / priceWithPrecision;
    }

    function getAccountCollateralValue(address user) public view returns (uint256 totalCollateralValueInUsd) {
        // toop through all the collateral tokens
        // get the amount of each token they have deposited
        // map it to the price to get the USD value
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposited[user][token];
            totalCollateralValueInUsd += getUsdValue(token, amount);
        }
        return totalCollateralValueInUsd;
    }

    /**
     * https://www.rareskills.io/post/solidity-fixed-point
     */
    function getUsdValue(address token, uint256 amount) public view returns (uint256) {
        // get the price feed for the token
        // get the price of the token
        // return the price * amount
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,,,) = priceFeed.latestRoundData();
        // ETH / USD has 8 decimals (https://docs.chain.link/data-feeds/price-feeds/addresses?network=ethereum&page=1&search=eth+%2Fusd)
        // Same for BTC / USD
        // ETH / USD is a tradin pair, this means that the price is the amount of USD you get for 1 ETH
        uint256 priceWithPrecision = uint256(price) * ADDITIONAL_FEED_PRECISION; // 1e18
        // amount has 1e18 precision
        // PRECISION = 1e18
        return (priceWithPrecision * amount) / PRECISION;
    }
}
