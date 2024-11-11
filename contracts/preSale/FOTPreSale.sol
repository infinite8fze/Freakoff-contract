// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IAccessRestriction} from "../access/IAccessRestriction.sol";
import {IFOTVesting} from "../vesting/IFOTVesting.sol";
import {IFOTPreSale} from "./IFOTPreSale.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/**
 * @title FOTPreSale contract
 * @dev FOT presale implementation
 */

contract FOTPreSale is ReentrancyGuard, IFOTPreSale {
    // Constants
    /// @dev Role identifier for admin
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /// @dev Role identifier for sale script
    bytes32 public constant SALE_SCRIPT_ROLE = keccak256("SALE_SCRIPT_ROLE");
    /**
     * @dev Minimum time required between purchases
     *
     * Set to 1 day to limit each address to 1 purchase per day.
     */
    uint32 public constant TIME_BETWEEN_PURCHASES = 1 days;
    // State Variables

    /**
     * @dev Current FOT token price
     */
    uint256 public override fotPrice;

    /**
     * @dev Vesting plan ID for purchased FOT
     */
    uint256 public override planID;

    /**
     * @dev Total FOT tokens sold through presale
     */
    uint256 public override fotSold;

    /**
     * @dev Maximum FOT tokens allocated to presale
     */
    uint256 public override fotLimit;

    /**
     * @dev Minimum FOT tokens user can purchase
     */
    uint256 public override minFotPerUser;


    /**
     * @dev Limit for total FOT purchased per user based on dollar
     */
    uint256 public override userBalanceLimit;

    /**
     * @dev Address to withdraw presale funds
     */
    address public override treasury;

    /**
     * @dev sale status
     */
    bool public override isActive;

    /**
     * @dev buy cap for buy orders
     */
    uint16 public override buyCap;

    /**
     * @dev FOT vesting contract
     */
    IFOTVesting public fotVesting;

    /**
     * @dev Access restriction contract
     */
    IAccessRestriction public accessRestriction;

    // Mappings

    /**
     * @dev Maps token symbol to token address
     */
    mapping(bytes16 => address) public override paymentTokens;

    /**
     * @dev Maps token symbol to chainLink price feed address
     */
    mapping(bytes16 => address) public override priceFeeds;
    /**
     * @dev Whitelisted addresses that get discount
     */
    mapping(address => uint256) public override discounts;

    /**
     * @dev Tracks FOT purchased by user
     */
    mapping(address => uint256) public override fotTokenShare;
    /**
     * @dev Tracks number of purchases per day for each user
     */
    mapping(address => uint16) public override userDailyPurchaseCount;

    /**
     * @dev Tracks last purchase timestamp for each user
     */
    mapping(address => uint64) public override lastPurchaseDate;

    // External Contracts
    /**
     * @dev Reverts if caller is not admin
     */
    modifier onlyAdmin() {
        if (!accessRestriction.hasRole(ADMIN_ROLE, msg.sender)) {
            revert NotAdmin();
        }
        _;
    }

    /**
     * @dev Reverts if caller is not script
     */
    modifier onlyScript() {
        if (!accessRestriction.hasRole(SALE_SCRIPT_ROLE, msg.sender)) {
            revert NotSaleScript();
        }
        _;
    }

    /**
     * @dev Reverts if address is invalid
     * @param _addr The address to validate
     */
    modifier validAddress(address _addr) {
        if (_addr == address(0)) {
            revert InvalidAddress();
        }
        _;
    }

    /**
     * @dev Reverts if token is not a valid payment token
     * @param _token The token symbol to validate
     */
    modifier onlyValidToken(bytes16 _token) {
        if (paymentTokens[_token] == address(0)) {
            revert InvalidPaymentToken();
        }
        _;
    }

    /**
     * @dev Reverts if amount is 0
     * @param _amount The amount to validate
     */
    modifier onlyValidAmount(uint256 _amount) {
        if (_amount <= 0) {
            revert InsufficientAmount();
        }
        _;
    }

    constructor(address _fotVestingAddress, address _accessRestrictionAddress) {
        accessRestriction = IAccessRestriction(_accessRestrictionAddress);
        fotVesting = IFOTVesting(_fotVestingAddress);
    }

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    /**
     * @dev Purchases FOT with native coins
     * @param _fotAmount Number of FOT tokens to purchase
     */
    function buyTokenByNativeCoin(
        uint256 _fotAmount,
        uint80 _roundID
    ) external payable override nonReentrant {
        // Calculate payment amount
        uint256 totalCost = _calculateTotalPayment(_fotAmount, msg.sender);

        // get matic price
        uint256 price = _getTokenPrice(bytes16("MATIC"), _roundID);
        if (msg.value < (totalCost / price) * 1e8) {
            revert InsufficientBalance();
        }

        // Emit event
        emit PurchasedByNativeCoin(msg.sender, _fotAmount, msg.value);

        // Process purchase
        _processPurchase(_fotAmount, msg.sender);
    }

    /**
     * @dev Purchases FOT with ERC20 token
     * @param _fotAmount Number of FOT tokens to purchase
     * @param _token ERC20 token to use for payment
    * @param _roundID roundId

     */
    function buyTokenByERC20Token(
        uint256 _fotAmount,
        bytes16 _token,
        uint80 _roundID
    ) external override nonReentrant onlyValidToken(_token) {
        // Calculate payment
        uint256 totalCost = _calculateTotalPayment(_fotAmount, msg.sender);

        // Get estimated swap amount
        uint256 price = _getTokenPrice(_token, _roundID);

        //calculate approvedAmount
        uint256 approvedAmount = 0;
        if (_token == bytes16("WBTC")) {
            approvedAmount = totalCost / (price * 1e2);
        } else {
            approvedAmount = (totalCost / price) * 1e8;
        }

        // Get token address
        address tokenAddress = paymentTokens[_token];

        // Validate allowance
        if (
            IERC20(tokenAddress).allowance(msg.sender, address(this)) <
            approvedAmount
        ) {
            revert InsufficientAllowance();
        }

        // Transfer tokens
        bool success = IERC20(tokenAddress).transferFrom(
            msg.sender,
            address(this),
            approvedAmount
        );

        // Validate transfer
        if (!success) {
            revert TransferFailed();
        }

        // Emit event
        emit PurchasedByERC20Token(
            msg.sender,
            _fotAmount,
            approvedAmount,
            tokenAddress
        );

        // Process purchase
        _processPurchase(_fotAmount, msg.sender);
    }

    /**
     * @dev Purchases FOT with stablecoin
     * @param _fotAmount Number of FOT tokens to purchase
     * @param _token Stablecoin to use
     */
    function buyTokenByStableCoin(
        uint256 _fotAmount,
        bytes16 _token
    ) external override nonReentrant onlyValidToken(_token) {
        // Calculate payment
        uint256 totalCost = _calculateTotalPayment(_fotAmount, msg.sender);

        // Get token address
        address tokenAddress = paymentTokens[_token];

        // Adjust stablecoin amount for decimals
        if (_token == bytes16("USDC") || _token == bytes16("USDT")) {
            totalCost /= 1e12;
        }

        // Validate allowance
        if (
            IERC20(tokenAddress).allowance(msg.sender, address(this)) <
            totalCost
        ) {
            revert InsufficientAllowance();
        }

        // Transfer tokens
        bool success = IERC20(tokenAddress).transferFrom(
            msg.sender,
            address(this),
            totalCost
        );

        // Validate transfer
        if (!success) {
            revert TransferFailed();
        }
        // Emit event
        emit PurchasedByStableCoin(
            msg.sender,
            _fotAmount,
            totalCost,
            tokenAddress
        );

        // Process purchase
        _processPurchase(_fotAmount, msg.sender);
    }

    /**
     * @dev Purchases FOT with coin
     * @param _fotAmount Number of FOT tokens to purchase
     * @param _beneficiary Address to receive purchased FOT
     */
    function buyTokenByCoin(
        uint256 _fotAmount,
        address _beneficiary
    ) external override nonReentrant validAddress(_beneficiary) onlyScript {
        // Calculate payment
        _calculateTotalPayment(_fotAmount, _beneficiary);

        // Emit event
        emit PurchasedByCoin(_beneficiary, _fotAmount);

        // Process purchase
        _processPurchase(_fotAmount, _beneficiary);
    }

    /**
     * @dev Withdraws funds to treasury
     * @param _amount Amount to withdraw
     * @param _tokenAddress Token to withdraw
     */
    function withdraw(
        uint256 _amount,
        address _tokenAddress
    )
        external
        override
        validAddress(_tokenAddress)
        onlyAdmin
        onlyValidAmount(_amount)
    {
        // Validate balance
        if (IERC20(_tokenAddress).balanceOf(address(this)) < _amount) {
            revert InsufficientContractBalance();
        }

        // Withdraw tokens
        bool success = IERC20(_tokenAddress).transfer(treasury, _amount);

        if (!success) {
            revert WithdrawalFailed();
        }

        // Emit event
        emit WithdrawnBalance(treasury, _amount, _tokenAddress);
    }

    /**
     * @dev Withdraws matic funds to treasury
     * @param _amount Amount to withdraw
     */
    function withdrawCoins(
        uint256 _amount
    ) external override onlyAdmin onlyValidAmount(_amount) nonReentrant {
        if (_amount > address(this).balance) {
            revert InsufficientContractBalance();
        }
        payable(treasury).transfer(_amount);
        emit WithdrawnCoinBalance(treasury, _amount);
    }

    /**
     * @dev Sets payment token address
     * @param _symbol Token symbol
     * @param _addr Token address
     */
    function setPaymentTokens(
        bytes16 _symbol,
        address _addr
    ) external override validAddress(_addr) onlyAdmin {
        paymentTokens[_symbol] = _addr;

        emit PaymentTokenSet(_symbol, _addr);
    }

    /**
     * @dev Adds address to whitelist
     * @param _addr Address to whitelist
     * @param _discount discount to whitelist

     */
    function updateDiscount(
        address _addr,
        uint256 _discount
    ) external override onlyScript {
        _updateDiscount(_addr, _discount);
    }

    /**
     * @dev Adds address to whitelist
     * @param _addresses Address array to whitelist
     * @param _discounts Address array to whitelist

     */
    function updateDiscountBatch(
        address[] calldata _addresses,
        uint256[] calldata _discounts
    ) external override onlyScript {
        if (_addresses.length != _discounts.length)
            revert InvalidDiscountList();

        for (uint256 i = 0; i < _addresses.length; i++) {
            _updateDiscount(_addresses[i], _discounts[i]);
        }
    }

    /**
     * @dev Sets FOT token price
     * @param _price New FOT price
     */
    function setFotPrice(uint256 _price) external override onlyAdmin {
        fotPrice = _price;

        emit PriceSet(_price);
    }

    function setUserBalanceLimit(uint256 _amount) external override onlyAdmin {
        userBalanceLimit = _amount;

        emit UserBalanceLimitUpdated(_amount);
    }

    /**
     * @dev Sets vesting plan ID
     * @param _planID Plan ID
     */
    function setPlanID(uint256 _planID) external override onlyAdmin {
        planID = _planID;

        emit PlanIdSet(_planID);
    }

    /**
     * @dev Sets max FOT tokens for sale
     * @param fotLimit_ New limit
     */
    function setFotLimit(uint256 fotLimit_) external override onlyAdmin {
        fotLimit = fotLimit_;

        emit FotLimitSet(fotLimit_);
    }

    /**
     * @dev Sets sale status
     * @param status_ sale status
     */
    function setSaleStatus(bool status_) external override onlyAdmin {
        isActive = status_;
        emit SaleStatusSet(status_);
    }

    /**
     * @dev Sets treasury address
     * @param _treasury Treasury address
     */
    function setTreasuryAddress(
        address _treasury
    ) external override onlyAdmin validAddress(_treasury) {
        treasury = _treasury;

        emit TreasurySet(_treasury);
    }

    /**
     * @dev Sets minimum FOT purchase per user
     * @param _mintFot Minimum FOT purchase
     */
    function setMinFotPerUser(uint256 _mintFot) external override onlyAdmin {
        minFotPerUser = _mintFot;
        emit MinFotPriceSet(_mintFot);
    }

    /**
     * @dev Sets max buy cap count
     * @param _buyCap buy max cap count
     */
    function setBuyCap(uint16 _buyCap) external override onlyAdmin {
        buyCap = _buyCap;
        emit BuyCapUpdated(_buyCap);
    }

    /**
     * @dev Sets aggregator address
     * @param _symbol Token symbol
     * @param _addr aggregtor price feed address
     */
    function setAggregator(
        bytes16 _symbol,
        address _addr
    ) external override validAddress(_addr) onlyAdmin {
        priceFeeds[_symbol] = _addr;

        emit AggregatorAddressSet(_symbol, _addr);
    }

    /**
     * @dev Processes FOT purchase
     * @param _fotAmount Amount of FOT purchased
     * @param _buyer Address of purchaser
     */
    function _processPurchase(uint256 _fotAmount, address _buyer) private {
        // Apply purchase limit if enabled
        if (buyCap > 0) {
            // Ensure purchase is allowed
            if (!_canMakePurchase(_buyer)) {
                revert DailyBuyingLimitReached();
            }

            // Update last purchase timestamp
            lastPurchaseDate[_buyer] = uint64(block.timestamp);

            // Increment daily purchases
            userDailyPurchaseCount[_buyer]++;
        }

        // Update total FOT sold
        fotSold += _fotAmount;

        // Update FOT purchased by user
        fotTokenShare[_buyer] += _fotAmount;

        discounts[_buyer] = 0;

        // Create vesting schedule
        bool success = fotVesting.createVesting(_buyer, _fotAmount, planID);

        if (!success) {
            revert VestingCreationFailed();
        }
    }

    /**
     * @dev Checks if purchase is allowed for buyer
     * @param _buyer Address of purchaser
     * @return bool True if purchase is allowed
     */
    function _canMakePurchase(address _buyer) private returns (bool) {
        uint256 lastPurchase = lastPurchaseDate[_buyer];
        uint256 dailyPurchaseCount = userDailyPurchaseCount[_buyer];

        // If daily limit reached and time window hasn't passed
        if (
            dailyPurchaseCount >= buyCap &&
            block.timestamp < lastPurchase + TIME_BETWEEN_PURCHASES
        ) {
            return false;
        }

        // If time window has passed, reset limit
        if (block.timestamp >= lastPurchase + TIME_BETWEEN_PURCHASES) {
            userDailyPurchaseCount[_buyer] = 0;
        }

        // Purchase allowed
        return true;
    }

    function _updateDiscount(
        address _addr,
        uint256 _discount
    ) private validAddress(_addr) {
        if (_discount > 10000) revert InvalidDiscount();
        discounts[_addr] = _discount;

        emit UserDiscountUpdated(_addr, _discount);
    }

    /**
     * @dev Calculates total payment for FOT purchase
     * @param _fotAmount Amount of FOT to purchase
     * @param _buyer Address purchasing FOT
     * @return Total payment amount required
     */
    function _calculateTotalPayment(
        uint256 _fotAmount,
        address _buyer
    ) private view returns (uint256) {
        //check sale status

        if (!isActive) {
            revert SaleNotActive();
        }

        // Validate purchase amount
        _validateAmount(_fotAmount);

        // Calculate payment
        uint256 totalCost = (_fotAmount * fotPrice) / 1e18;

        // Apply discount if buyer is whitelisted
        if (discounts[_buyer] > 0) {
            totalCost = ((10000 - discounts[_buyer] ) * totalCost) / 10000;
        }

        // Validate user fot balance limit
        if (userBalanceLimit > 0) {
            _validateUserBalanceLimit(totalCost, _buyer);
        }

        return totalCost;
    }

    /**
     * @dev Validates purchase amount
     * @param _fotAmount Amount of FOT to purchase
     */
    function _validateAmount(uint256 _fotAmount) private view {
        // FOT limit not exceeded
        if (fotSold + _fotAmount > fotLimit) {
            revert FOTLimitExceeded();
        }

        // Purchase amount exceeds minimum
        if (_fotAmount < minFotPerUser) {
            revert BelowMinFOTPerUser();
        }
    }

    /**
     * @dev Validates user purchase limit
     * @param _fotvalue Amount of current purchase
     * @param userAddress Address of purchaser
     */
    function _validateUserBalanceLimit(
        uint256 _fotvalue,
        address userAddress
    ) private view {
        // Get user's existing purchase value
        uint256 oldFotValue = (fotTokenShare[userAddress] * fotPrice) / 1e18;

        // Check total value doesn't exceed limit
        if (oldFotValue + _fotvalue > userBalanceLimit) {
            revert MaxFOTAmountReached();
        }
    }

    /**
     * @dev Gets token price for chainlink
     * @param _token Token symbol
     * @param _roundID round id
     * @return token price
     */
    function _getTokenPrice(
        bytes16 _token,
        uint80 _roundID
    ) private view validAddress(priceFeeds[_token]) returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            priceFeeds[_token]
        );

        (uint80 roundID, , , , ) = priceFeed.latestRoundData();
        if (roundID - _roundID > 600) {
            revert PriceTooOld();
        }
        (, int price, , , ) = priceFeed.getRoundData(_roundID);

        return uint256(price);
    }
}
