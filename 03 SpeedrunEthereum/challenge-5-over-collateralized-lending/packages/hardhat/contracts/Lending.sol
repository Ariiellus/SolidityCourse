// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./Corn.sol";
import "./CornDEX.sol";

error Lending__InvalidAmount();
error Lending__TransferFailed();
error Lending__UnsafePositionRatio();
error Lending__BorrowingFailed();
error Lending__RepayingFailed();
error Lending__PositionSafe();
error Lending__NotLiquidatable();
error Lending__InsufficientLiquidatorCorn();
error FlashLoan__FlashLoanFailed();

contract Lending is Ownable {
    uint256 private constant COLLATERAL_RATIO = 120; // 120% collateralization required
    uint256 private constant LIQUIDATOR_REWARD = 10; // 10% reward for liquidators

    Corn private i_corn;
    CornDEX private i_cornDEX;

    mapping(address => uint256) public s_userCollateral; // User's collateral balance
    mapping(address => uint256) public s_userBorrowed; // User's borrowed corn balance

    event CollateralAdded(address indexed user, uint256 indexed amount, uint256 price);
    event CollateralWithdrawn(address indexed user, uint256 indexed amount, uint256 price);
    event AssetBorrowed(address indexed user, uint256 indexed amount, uint256 price);
    event AssetRepaid(address indexed user, uint256 indexed amount, uint256 price);
    event Liquidation(
        address indexed user,
        address indexed liquidator,
        uint256 amountForLiquidator,
        uint256 liquidatedUserDebt,
        uint256 price
    );

    constructor(address _cornDEX, address _corn) Ownable(msg.sender) {
        i_cornDEX = CornDEX(_cornDEX);
        i_corn = Corn(_corn);
        i_corn.approve(address(this), type(uint256).max);
    }

    /**
     * @notice Allows users to add collateral to their account
     */
    function addCollateral() public payable {
        if (msg.value == 0) {
            revert Lending__InvalidAmount();
        }
        s_userCollateral[msg.sender] += msg.value;
        emit CollateralAdded(msg.sender, msg.value, i_cornDEX.currentPrice());
    }

    /**
     * @notice Allows users to withdraw collateral as long as it doesn't make them liquidatable
     * @param amount The amount of collateral to withdraw
     */
    function withdrawCollateral(uint256 amount) public {
        if (amount == 0 || s_userCollateral[msg.sender] < amount) {
            revert Lending__InvalidAmount();
        }

        s_userCollateral[msg.sender] -= amount;
        _validatePosition(msg.sender);

        (bool success, ) = msg.sender.call{value: amount}("");
        if (success) {
            emit CollateralWithdrawn(msg.sender, amount, i_cornDEX.currentPrice());
        } else {
            revert Lending__TransferFailed();
        }
    }

    /**
     * @notice Calculates the total collateral value for a user based on their collateral balance
     * @param user The address of the user to calculate the collateral value for
     * @return uint256 The collateral value
     */
    function calculateCollateralValue(address user) public view returns (uint256) {
        return s_userCollateral[user] * i_cornDEX.currentPrice() / 1e18;
    }

    /**
     * @notice Calculates the position ratio for a user to ensure they are within safe limits
     * @param user The address of the user to calculate the position ratio for
     * @return uint256 The position ratio
     */
    function _calculatePositionRatio(address user) internal view returns (uint256) {
        uint256 borrowedAmount = s_userBorrowed[user];
        uint256 collateralValue = calculateCollateralValue(user);

        if (borrowedAmount == 0) return type(uint256).max;
        return (collateralValue * 1e18) / borrowedAmount;
    }

    /**
     * @notice Checks if a user's position can be liquidated
     * @param user The address of the user to check
     * @return bool True if the position is liquidatable, false otherwise
     */
    function isLiquidatable(address user) public view returns (bool) {
        uint256 positionRatio = _calculatePositionRatio(user);
        
        // If no debt, position is always safe (positionRatio is type(uint256).max)
        if (positionRatio == type(uint256).max) {
            return false;
        }
        
        return (positionRatio * 100) < COLLATERAL_RATIO * 1e18;
    }

    /**
     * @notice Internal view method that reverts if a user's position is unsafe
     * @param user The address of the user to validate
     */
    function _validatePosition(address user) internal view {
        if (isLiquidatable(user)) {
            revert Lending__UnsafePositionRatio();
        }
    }

    /**
     * @notice Allows users to borrow corn based on their collateral
     * @param borrowAmount The amount of corn to borrow
     */
    function borrowCorn(uint256 borrowAmount) public {
        if (borrowAmount == 0) {
            revert Lending__InvalidAmount();
        }
        s_userBorrowed[msg.sender] += borrowAmount;
        _validatePosition(msg.sender);

        bool success = i_corn.transfer(msg.sender, borrowAmount);
        if (!success) {
            revert Lending__BorrowingFailed();
        }

				emit AssetBorrowed(msg.sender, borrowAmount, i_cornDEX.currentPrice());
		}

    /**
     * @notice Allows users to repay corn and reduce their debt
     * @param repayAmount The amount of corn to repay
     */
    function repayCorn(uint256 repayAmount) public {
				if (repayAmount == 0 || repayAmount > s_userBorrowed[msg.sender]) {
					revert Lending__InvalidAmount();
				}

				s_userBorrowed[msg.sender] -= repayAmount;
				bool success = i_corn.transferFrom(msg.sender, address(this), repayAmount);
				if (!success) {
					revert Lending__RepayingFailed();
				}
			
				emit AssetRepaid(msg.sender, repayAmount, i_cornDEX.currentPrice());
		}

    /**
     * @notice Allows liquidators to liquidate unsafe positions
     * @param user The address of the user to liquidate
     * @dev The caller must have enough CORN to pay back user's debt
     * @dev The caller must have approved this contract to transfer the debt
     */
    function liquidate(address user) public {

				// Check if the user's position is liquidatable
				if (!isLiquidatable(user)) {
					revert Lending__NotLiquidatable();
				}
				
				// Check if the liquidator has enough CORN to pay back the user's debt
				if (i_corn.balanceOf(msg.sender) < s_userBorrowed[user]) {
					revert Lending__InsufficientLiquidatorCorn();
				}
				
				uint256 oldDebt = s_userBorrowed[user];
				uint256 collateralToPay = s_userCollateral[user] * 100 / COLLATERAL_RATIO;
				uint256 reward = s_userCollateral[user] * LIQUIDATOR_REWARD / COLLATERAL_RATIO;
				uint256 amountToReceive = collateralToPay + reward;
				uint256 remainingCollateral = s_userCollateral[user] - collateralToPay;

				s_userBorrowed[user] = 0;
				s_userCollateral[user] = remainingCollateral;

				i_corn.transferFrom(msg.sender, user, s_userBorrowed[user]);
				(bool success, ) = msg.sender.call{value: amountToReceive}("");
				if (success) {
					emit Liquidation(msg.sender, user, amountToReceive, oldDebt, i_cornDEX.currentPrice());
				} else {
					revert Lending__TransferFailed();
				}

		}

		function createFlashLoan(IFlashLoanRecipient _recipient, uint256 _amount, address _extraParam) public {
			i_corn.mintTo(address(_recipient), _amount);

			bool success = IFlashLoanRecipient(_recipient).executeOperation(_amount, address(this), _extraParam);
			require(success, "Operation was unsuccessful");

			bool success2 = i_corn.burnFrom(address(this), _amount);
			if (!success2) {
				revert FlashLoan__FlashLoanFailed();
			}
		}
}

interface IFlashLoanRecipient {
	function executeOperation(uint256 amount, address initiator, address extraParam) external returns (bool);
}
