// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";
import { MockERC721 } from "solmate/test/utils/mocks/MockERC721.sol";
import "./interfaces/IERC20.sol";
import {CompoundLoop} from "../contracts/CompoundLoop.sol";


import "forge-std/Test.sol";

contract Loop is Test {

    // @notice          erc20 is an ERC20
    MockERC20 erc20;
    MockERC20 erc20two;
    // @notice          erc721 is an ERC721

    IERC20 IAAVE;
    CompoundLoop loop;
    IERC20 IUSDC;
    // ILendingPool LendingPool;
    uint256 totalCollateralETH;
    uint256 totalDebtETH;
    uint256 availableBorrowsETH;
    uint256 currentLiquidationThreshold;
    uint256 ltv;
    uint256 healthFactor;
    
    // AaveLoop looper;
    uint256 ALICE_PK = 0xCAFE;
    address ALICE = vm.addr(ALICE_PK);
    uint256 BOB_PK = 0xBEEF;
    address BOB = vm.addr(BOB_PK);
    uint256 EVE_PK = 0xADAD;
    address EVE = vm.addr(EVE_PK);
    address RichDudeAddy = address(0xee5B5B923fFcE93A870B3104b7CA09c3db80047A);

    function setUp() public {
        // erc20 = new MockERC20("DAI", "DAI", 18);
        // erc20two = new MockERC20("CNV", "CNV", 18);
        IAAVE = IERC20(0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9);
        IUSDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

        loop = new CompoundLoop(RichDudeAddy);
        vm.label(address(erc20), " ERC20 ");
        vm.label(ALICE, " ALICE ");
        vm.label(BOB, " BOB ");
        vm.deal(BOB, 10_000 ether);
    }

    // Write test cases around compound loop lets list what we plan to do

    function testMoveFundsIntoContract() public {
        vm.startPrank(RichDudeAddy);
        loop.setManager(address(loop));
        IUSDC.approve(address(loop), type(uint256).max);
        // IUSDC.transfer(address(loop), IUSDC.balanceOf(RichDudeAddy));
        uint256 usdcBalance = loop.underlyingBalance();
        console.log("USDC Balance", usdcBalance);
        uint256[] memory err = loop.enterPosition(88120744944210, 1e18, 1e18);
        console.log(err[0]);
        uint256 cTokenBalance = loop.cTokenBalance();
        console.log("C Token Balance", cTokenBalance);
        console.log(IUSDC.balanceOf(RichDudeAddy));
    }

    // function testGetPendingRewards() public {
    //     uint256 positionData = looper.getPendingRewards(BOB); 
    //     emit log_string("Pending Rewards");
    //     emit log_uint(positionData);
    // }
}
