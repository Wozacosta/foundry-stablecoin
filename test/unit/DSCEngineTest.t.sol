// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol"; //Updated mock location
// import { ERC20Mock } from "../mocks/ERC20Mock.sol";
// import { MockV3Aggregator } from "../mocks/MockV3Aggregator.sol";
// import { MockMoreDebtDSC } from "../mocks/MockMoreDebtDSC.sol";
// import { MockFailedMintDSC } from "../mocks/MockFailedMintDSC.sol";
// import { MockFailedTransferFrom } from "../mocks/MockFailedTransferFrom.sol";
// import { MockFailedTransfer } from "../mocks/MockFailedTransfer.sol";
import {Test, console} from "forge-std/Test.sol";
// import { StdCheats } from "forge-std/StdCheats.sol";

contract DSCEngineTest is Test {
    DeployDSC deployer;
    DecentralizedStableCoin dsc;
    DSCEngine dsce;
    HelperConfig public helperConfig;

    address public ethUsdPriceFeed;
    address public btcUsdPriceFeed;
    address public weth;
    address public wbtc;
    uint256 public deployerKey;

    address public USER = makeAddr("user");
    uint256 public constant AMOUNT_COLLATERAL = 10 ether; // ie. 10e18

    function setUp() external {
        deployer = new DeployDSC();
        (dsc, dsce, helperConfig) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, weth, wbtc, deployerKey) = helperConfig.activeNetworkConfig();
        // if (block.chainid == 31_337) {
        //     vm.deal(user, STARTING_USER_BALANCE);
        // }
    }

    //////////////////
    // Price Tests //
    //////////////////

    // function testGetTokenAmountFromUsd() public {
    //     // If we want $100 of WETH @ $2000/WETH, that would be 0.05 WETH
    //     uint256 expectedWeth = 0.05 ether;
    //     uint256 amountWeth = dsce.getTokenAmountFromUsd(weth, 100 ether);
    //     assertEq(amountWeth, expectedWeth);
    // }

    function testGetUsdValue() public {
        uint256 ethAmount = 15e18;
        // $2000/ETH since we've put in script/HelperConfig.s.sol:
        //  MockV3Aggregator ethUsdPriceFeed = new MockV3Aggregator(DECIMALS, 2000);

        // 15e18 ETH * $2000/ETH = $30,000e18
        uint256 expectedUsd = 30_000e18;
        uint256 usdValue = dsce.getUsdValue(weth, ethAmount);
        assertEq(usdValue, expectedUsd);
    }

    ///////////////////////////////////////
    // depositCollateral Tests //
    ///////////////////////////////////////

    // this test needs it's own setup

    // function testRevertsIfTransferFromFails() public {
    //     // Arrange - Setup
    //     address owner = msg.sender;
    //     vm.prank(owner);
    //     MockFailedTransferFrom mockDsc = new MockFailedTransferFrom();
    //     tokenAddresses = [address(mockDsc)];
    //     feedAddresses = [ethUsdPriceFeed];
    //     vm.prank(owner);
    //     DSCEngine mockDsce = new DSCEngine(tokenAddresses, feedAddresses, address(mockDsc));
    //     mockDsc.mint(user, amountCollateral);

    //     vm.prank(owner);
    //     mockDsc.transferOwnership(address(mockDsce));
    //     // Arrange - User
    //     vm.startPrank(user);
    //     ERC20Mock(address(mockDsc)).approve(address(mockDsce), amountCollateral);
    //     // Act / Assert
    //     vm.expectRevert(DSCEngine.DSCEngine__TransferFailed.selector);
    //     mockDsce.depositCollateral(address(mockDsc), amountCollateral);
    //     vm.stopPrank();
    // }

    function testRevertsIfCollateralZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(dsce), AMOUNT_COLLATERAL);
        /*
            function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }
        */

        vm.expectRevert(DSCEngine.DSCEngine__NeedsMoreThanZero.selector);
        dsce.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    // function testRevertsWithUnapprovedCollateral() public {
    //     ERC20Mock randToken = new ERC20Mock("RAN", "RAN", user, 100e18);
    //     vm.startPrank(user);
    //     vm.expectRevert(abi.encodeWithSelector(DSCEngine.DSCEngine__TokenNotAllowed.selector, address(randToken)));
    //     dsce.depositCollateral(address(randToken), amountCollateral);
    //     vm.stopPrank();
    // }

    // modifier depositedCollateral() {
    //     vm.startPrank(user);
    //     ERC20Mock(weth).approve(address(dsce), amountCollateral);
    //     dsce.depositCollateral(weth, amountCollateral);
    //     vm.stopPrank();
    //     _;
    // }

    // function testCanDepositCollateralWithoutMinting() public depositedCollateral {
    //     uint256 userBalance = dsc.balanceOf(user);
    //     assertEq(userBalance, 0);
    // }

    // function testCanDepositedCollateralAndGetAccountInfo() public depositedCollateral {
    //     (uint256 totalDscMinted, uint256 collateralValueInUsd) = dsce.getAccountInformation(user);
    //     uint256 expectedDepositedAmount = dsce.getTokenAmountFromUsd(weth, collateralValueInUsd);
    //     assertEq(totalDscMinted, 0);
    //     assertEq(expectedDepositedAmount, amountCollateral);
    // }
}
