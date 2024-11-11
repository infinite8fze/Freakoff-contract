// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

/**
 * @title IVesting interface
 */
interface IFOTPreSale {
    /// @dev Thrown when an invalid address (zero address) is provided
    error InvalidAddress();

    /// @dev Thrown when an invalid payment token is used
    error InvalidPaymentToken();

    /// @dev Thrown when the amount is zero or insufficient
    error InsufficientAmount();

    /// @dev Thrown when the provided amount is less than required
    error InsufficientBalance();

    /// @dev Thrown when the allowance for token transfer is insufficient
    error InsufficientAllowance();

    /// @dev Thrown when the token transfer fails
    error TransferFailed();

    /// @dev Thrown when the daily buying limit is reached
    error DailyBuyingLimitReached();

    /// @dev Thrown when creating a vesting schedule fails
    error VestingCreationFailed();

    /// @dev Thrown when the sale is not active
    error SaleNotActive();

    /// @dev Thrown when the FOT limit is exceeded
    error FOTLimitExceeded();

    /// @dev Thrown when the amount is below the minimum FOT per user
    error BelowMinFOTPerUser();

    /// @dev Thrown when the user has reached the maximum FOT amount
    error MaxFOTAmountReached();

    /// @dev Thrown when the price data is too old
    error PriceTooOld();

    /// @dev Thrown when the caller doesn't have the required role
    error NotAdmin();

    /// @dev Thrown when the caller doesn't have the required role
    error NotSaleScript();


    /// @dev Thrown when the contract balance is insufficient for withdrawal
    error InsufficientContractBalance();

    /// @dev Thrown when the withdrawal transfer fails
    error WithdrawalFailed();

    error InvalidDiscountList();
    error InvalidDiscount();

    event UserDiscountUpdated(address user,uint256 discount);


    /**
     * @dev Emitted when FOT is purchased with stablecoin
     * @param recipient Address of token recipient
     * @param tokenAmount Amount of tokens purchased
     * @param amount Amount of stablecoins paid
     * @param token Address of stablecoin
     */
    event PurchasedByStableCoin(
        address recipient,
        uint256 tokenAmount,
        uint256 amount,
        address token
    );

    /**
     * @dev Emitted when FOT is purchased with native coin
     * @param recipient Address of token recipient
     * @param tokenAmount Amount of tokens purchased
     * @param amount Amount of native coins paid
     */
    event PurchasedByNativeCoin(
        address recipient,
        uint256 tokenAmount,
        uint256 amount
    );

    /**
     * @dev Emitted when FOT is purchased with ERC20 token
     * @param recipient Address of token recipient
     * @param tokenAmount Amount of tokens purchased
     * @param amount Amount of ERC20 tokens paid
     * @param token Address of ERC20 token
     */
    event PurchasedByERC20Token(
        address recipient,
        uint256 tokenAmount,
        uint256 amount,
        address token
    );

    /**
     * @dev Emitted when FOT is purchased with coin
     * @param recipient Address of token recipient
     * @param tokenAmount Amount of tokens purchased
     */
    event PurchasedByCoin(address recipient, uint256 tokenAmount);

    /**
     * @dev Emitted when payment is received
     * @param from Address payment received from
     * @param amount Amount received
     */
    event Received(address from, uint256 amount);

    /**
     * @dev Emitted when balance is withdrawn
     * @param _to Address to send funds to
     * @param _amount Amount to withdraw
     * @param _tokenAddress Address of token withdrawn
     */
    event WithdrawnBalance(
        address _to,
        uint256 _amount,
        address _tokenAddress
    );

    /**
     * @dev Emitted when coin balance is withdrawn
     * @param _to Address to send funds to
     * @param _amount Amount to withdraw
     */
    event WithdrawnCoinBalance(address _to, uint256 _amount);

    /**
     * @dev Emitted when sale status change
     * @param status status of sale
     */
    event SaleStatusSet(bool status);

    /**
     * @dev Emitted when payment token is set
     * @param symbol Token symbol
     * @param tokenAddress Token address
     */
    event PaymentTokenSet(bytes16 symbol, address tokenAddress);

    /**
     * @dev Emitted when aggregator address is set
     * @param symbol Token symbol
     * @param priceFeedAddress Token address
     */
    event AggregatorAddressSet(bytes16 symbol, address priceFeedAddress);

    /**
     * @dev Emitted when address is whitelisted
     * @param _address Address that is whitelisted
     */
    event EligibleAddressAdded(address _address);

    /**
     * @dev Emitted when FOT price is set
     * @param price New FOT price
     */
    event PriceSet(uint256 price);

    /**
     * @dev Emitted when plan ID is set
     * @param planId Plan ID
     */
    event PlanIdSet(uint256 planId);

    /**
     * @dev Emitted when FOT limit is set
     * @param fotLimit New FOT limit
     */
    event FotLimitSet(uint256 fotLimit);

    /**
     * @dev Emitted when minimum FOT price is set
     * @param _mintFot New minimum FOT price
     */
    event MinFotPriceSet(uint256 _mintFot);

    /**
     * @dev Emitted when treasury address is set
     * @param treasury Treasury address
     */
    event TreasurySet(address treasury);

    /**
     * @dev Emitted when sale discount is updated
     * @param _percentage Sale discount percentage
     */
    event SaleDiscountUpdated(uint256 _percentage);

    /**
     * @dev Emitted when user balance Limit for total FOT purchased per user based on dollar is updated
     * @param _amount User balance Limit
     */
    event UserBalanceLimitUpdated(uint256 _amount);

    /**
     * @dev Emitted when buy cap is updated
     * @param _buyCap cap count
     */
    event BuyCapUpdated(uint16 _buyCap);

    /**
     * @dev Purchases FOT with native coins
     * @param _fotAmount Amount of FOT to purchase
     */
    // function buyTokenByNativeCoin(uint256 _fotAmount) external payable;
    function buyTokenByNativeCoin(
        uint256 _fotAmount,
        uint80 _roundID
    ) external payable;

    /**
     * @dev Purchases FOT with stablecoin
     * @param _fotAmount Amount of FOT to purchase
     * @param _token Stablecoin to use
     */
    function buyTokenByStableCoin(uint256 _fotAmount, bytes16 _token) external;

    /**
     * @dev Purchases FOT with ERC20 token
     * @param _fotAmount Amount of FOT to purchase
     * @param _token ERC20 token to use
     * @param _roundID roundId
     */
    function buyTokenByERC20Token(
        uint256 _fotAmount,
        bytes16 _token,
        uint80 _roundID
    ) external;

    /**
     * @dev Purchases FOT with coin
     * @param _fotAmount Amount of FOT to purchase
     * @param _beneficiary Address to receive FOT
     */
    function buyTokenByCoin(uint256 _fotAmount, address _beneficiary) external;

     function updateDiscountBatch(
        address[] calldata _addresses,
        uint256[] calldata _discounts
    ) external;

    function updateDiscount(
        address _addr,
        uint256 _discount
    ) external;

    /**
     * @dev Withdraws funds
     * @param _amount Amount to withdraw
     * @param _stableCoin Stablecoin to withdraw
     */
    function withdraw(uint256 _amount, address _stableCoin) external;

    /**
     * @dev Withdraws matic funds to treasury
     * @param _amount Amount to withdraw
     */
    function withdrawCoins(uint256 _amount) external;

    /*
     * @dev Sets payment token
     * @param _symbol Token symbol
     * @param _addr Token address
     */
    function setPaymentTokens(bytes16 _symbol, address _addr) external;

    /**
     * @dev Sets FOT price
     * @param _price New FOT price
     */

    function setFotPrice(uint256 _price) external;

    /**
     * @dev Sets plan ID
     * @param _planID Plan ID
     */
    function setPlanID(uint256 _planID) external;

    /**
     * @dev Sets FOT limit
     * @param fotLimit_ New FOT limit
     */
    function setFotLimit(uint256 fotLimit_) external;

    /**
     * @dev Sets sale status
     * @param status_ sale status
     */
    function setSaleStatus(bool status_) external;

    /**
     * @dev Sets treasury address
     * @param _treasury Treasury address
     */
    function setTreasuryAddress(address _treasury) external;

    /**
     * @dev Sets minimum FOT purchase per user
     * @param _mintFot Minimum FOT purchase per user
     */
    function setMinFotPerUser(uint256 _mintFot) external;

    /**
     * @dev Sets max buy cap count
     * @param _buyCap buy max cap count
     */
    function setBuyCap(uint16 _buyCap) external;

    /*
     * @dev sets Limit for total FOT purchased per user based on dollar
     * @param _amount buy total FOT purchased per user
     */
    function setUserBalanceLimit(uint256 _amount) external;

    /**
     * @dev Sets aggregator address
     * @param _symbol Token symbol
     * @param _addr aggregtor price feed address
     */
    function setAggregator(bytes16 _symbol, address _addr) external;

    /**
     * @dev Gets current FOT price
     * @return Current FOT price
     */
    function fotPrice() external view returns (uint256);

    /*
     * @dev Gets Limit for total FOT purchased per user based on dollar
     * @param _amount buy total FOT purchased per user
     */
    function userBalanceLimit() external view returns (uint256);

    /**
     * @dev Gets current plan ID
     * @return Current plan ID
     */
    function planID() external view returns (uint256);

    /**
     * @dev Gets total FOT sold
     * @return Total FOT sold
     */
    function fotSold() external view returns (uint256);

    /**
     * @dev Gets FOT limit
     * @return FOT limit
     */
    function fotLimit() external view returns (uint256);

    /**
     * @dev Gets sale status
     * @return sale status
     */
    function isActive() external view returns (bool);

    /**
     * @dev Gets minimum FOT purchase per user
     * @return Minimum FOT purchase per user
     */
    function minFotPerUser() external view returns (uint256);

    /**
     * @dev Gets purchase max capacity count
     * @return purchase max capacity count
     */
    function buyCap() external view returns (uint16);

    /**
     * @dev Gets treasury address
     * @return Treasury address
     */
    function treasury() external view returns (address);

    /**
     * @dev Gets payment token address
     * @param token Token symbol
     * @return Address of payment token
     */
    function paymentTokens(bytes16 token) external view returns (address);

    /**
     * @dev Gets price feed address
     * @param token Token symbol
     * @return Address of priceFeed
     */
    function priceFeeds(bytes16 token) external view returns (address);

    /**
     * @dev Checks if address is whitelisted
     * @param addr Address to check
     * @return uint256 true if address is whitelisted
     */
    function discounts(address addr) external view returns (uint256);

    /**
     * @dev Gets FOT purchased for address
     * @param addr Address to check
     * @return FOT purchased for address
     */
    function fotTokenShare(address addr) external view returns (uint256);

    /**
     * @dev Gets FOT purchased for address
     * @param addr Address to check
     * @return FOT purchased for address
     */
    function userDailyPurchaseCount(
        address addr
    ) external view returns (uint16);

    /**
     * @dev Gets FOT purchased for address
     * @param addr Address to check
     * @return FOT purchased for address
     */
    function lastPurchaseDate(address addr) external view returns (uint64);
}
