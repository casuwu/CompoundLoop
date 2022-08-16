// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import "@openzeppelin/access/Ownable.sol";
import "@openzeppelin/token/ERC20/ERC20.sol";
import "./Exponential.sol";
import "./Interfaces.sol";
import "../lib/solmate/src/utils/FixedPointMathLib.sol";

interface Erc20 {
    function approve(address, uint256) external returns (bool);

    function transfer(address, uint256) external returns (bool);
}


interface CErc20 {
    function mint(uint256) external returns (uint256);

    function exchangeRateCurrent() external returns (uint256);

    function supplyRatePerBlock() external returns (uint256);

    function redeem(uint) external returns (uint);

    function redeemUnderlying(uint) external returns (uint);
}

contract CompoundLoop is Ownable, Exponential {
    using FixedPointMathLib for uint256;

    // --- fields ---
    address public constant UNITROLLER = address(0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B);
    address public constant CUSDC = address(0x39AA39c021dfbaE8faC545936693aC917d5E7563);
    address public constant USDC = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    address public constant COMP = address(0xc00e94Cb662C3520282E6f5717214004A7f26888);
    address public manager;

    // --- events ---
    event ManagerUpdated(address prevManager, address newManager);
    event LogMint(address token, address owner, uint256 tokenAmount);
    event LogBorrow(address token, address owner, uint256 tokenAmount);
    event LogRedeem(address token, address owner, uint256 tokenAmount);
    event LogRedeemUnderlying(address token, address owner, uint256 tokenAmount);
    event LogRepay(address token, address owner, uint256 tokenAmount);

    constructor(address _manager) {
        setManager(_manager);
    }

    // --- views ---

    function cTokenBalance() public view returns (uint256) {
        return IERC20(CUSDC).balanceOf(msg.sender);
    }

    function underlyingBalance() public view returns (uint256) {
        return IERC20(USDC).balanceOf(msg.sender);
    }

    function getAccountLiquidity()
        public
        view
        returns (
            uint256 err,
            uint256 liquidity,
            uint256 shortfall
        )
    {
        return Comptroller(UNITROLLER).getAccountLiquidity(msg.sender);
    }

    // --- unrestricted actions ---

    function borrowBalanceCurrent() public returns (uint256) {
        return CERC20(CUSDC).borrowBalanceCurrent(msg.sender);
    }

    function claimComp() public returns (uint256) {
        Comptroller(UNITROLLER).claimComp(msg.sender);
        return IERC20(COMP).balanceOf(msg.sender);
    }

    function claimComp(
        address[] memory holders,
        address[] memory cTokens,
        bool borrowers,
        bool suppliers
    ) public {
        Comptroller(UNITROLLER).claimComp(holders, cTokens, borrowers, suppliers);
    }

    function getAccountLiquidityWithInterest()
        public
        returns (
            uint256 err,
            uint256 accountLiquidity,
            uint256 accountShortfall
        )
    {
        require(CERC20(CUSDC).accrueInterest() == 0, "accrueInterest failed");
        return Comptroller(UNITROLLER).getAccountLiquidity(msg.sender);
    }

    // --- main ---

    function supplyErc20ToCompound(
        address _erc20Contract,
        address _cErc20Contract,
        uint256 _numTokensToSupply
    ) public returns (uint) {
        // Create a reference to the underlying asset contract, like DAI.
        Erc20 underlying = Erc20(USDC);

        // Create a reference to the corresponding cToken contract, like cDAI
        CErc20 cToken = CErc20(CUSDC);

        // Amount of current exchange rate from cToken to underlying
        uint256 exchangeRateMantissa = cToken.exchangeRateCurrent();

        // // Amount added to you supply balance this block
        uint256 supplyRateMantissa = cToken.supplyRatePerBlock();
        // emit MyLog("Supply Rate: (scaled up)", supplyRateMantissa);

        // // Approve transfer on the ERC20 contract
        underlying.approve(_cErc20Contract, _numTokensToSupply);

        // Mint cTokens
        uint mintResult = cToken.mint(_numTokensToSupply);
        return mintResult;

    }

    // --- internal ---

    function eighteenToUSDC(uint256 amount18Decimals) internal pure returns (uint256) {
        return amount18Decimals / (10**12);
    }

    function setApprove() public {
        if (IERC20(USDC).allowance(msg.sender, CUSDC) != type(uint256).max) {
            IERC20(USDC).approve(CUSDC, type(uint256).max);
        }
    }

    // --- withdraw assets by owner ---

    function claimAndTransferAllCompToOwner() public {
        uint256 balance = claimComp();
        if (balance > 0) {
            IERC20(COMP).transfer(owner(), balance);
        }
    }

    function safeTransferUSDCToOwner() public {
        uint256 usdcBalance = underlyingBalance();
        if (usdcBalance > 0) {
            IERC20(USDC).transfer(owner(), usdcBalance);
        }
    }

    function safeTransferAssetToOwner(address src) public {
        uint256 balance = IERC20(src).balanceOf(address(this));
        if (balance > 0) {
            IERC20(src).transfer(owner(), balance);
        }
    }

    function transferFrom(address src_, uint256 amount_) public {
        IERC20(USDC).transferFrom(src_, msg.sender, amount_);
    }

    // --- administration ---

    function setManager(address _newManager) public {
        require(_newManager != address(0), "_newManager is null");
        emit ManagerUpdated(manager, _newManager);
        manager = _newManager;
    }

    function borrow(uint256 amount) public {
        require(CERC20(CUSDC).borrow(amount) == 0, "borrow has failed");
        emit LogBorrow(CUSDC, address(this), amount);
    }

    function repayBorrowAll() public {
        uint256 usdcBalance = underlyingBalance();
        if (usdcBalance > borrowBalanceCurrent()) {
            require(CERC20(CUSDC).repayBorrow(type(uint256).max) == 0, "repayBorrow -1 failed");
            emit LogRepay(CUSDC, address(this), type(uint256).max);
        } else {
            require(CERC20(CUSDC).repayBorrow(usdcBalance) == 0, "repayBorrow failed");
            emit LogRepay(CUSDC, address(this), usdcBalance);
        }
    }
}
