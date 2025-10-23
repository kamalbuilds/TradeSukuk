// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./TradeSukukToken.sol";

/**
 * @title SecondaryMarketplace
 * @notice Shariah-compliant order book for fractional sukuk trading
 * @dev Implements atomic swaps with maker-taker fee structure
 *
 * Shariah Compliance:
 * - Immediate settlement (no futures/derivatives)
 * - Asset-backed trading only
 * - Transparent pricing
 * - No interest-based mechanisms
 * - Bay' (immediate exchange) contract type
 *
 * Features:
 * - Limit orders with partial fills
 * - Maker-taker fee model
 * - Multiple payment tokens (USDC, USDT, etc.)
 * - Order cancellation
 * - Price discovery
 */
contract SecondaryMarketplace is
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    // ============ Roles ============
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant FEE_MANAGER_ROLE = keccak256("FEE_MANAGER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    // ============ Structs ============

    enum OrderType { BUY, SELL }
    enum OrderStatus { ACTIVE, FILLED, CANCELLED, EXPIRED }

    struct Order {
        uint256 orderId;
        address maker;              // Order creator
        address sukukToken;         // Sukuk token address
        address paymentToken;       // Payment token (USDC, USDT, etc.)
        OrderType orderType;        // BUY or SELL
        uint256 price;              // Price per token (in payment token decimals)
        uint256 amount;             // Total amount of sukuk tokens
        uint256 filledAmount;       // Amount already filled
        uint256 createdAt;          // Creation timestamp
        uint256 expiresAt;          // Expiration timestamp (0 = no expiry)
        OrderStatus status;
    }

    struct Trade {
        uint256 tradeId;
        uint256 buyOrderId;
        uint256 sellOrderId;
        address buyer;
        address seller;
        address sukukToken;
        address paymentToken;
        uint256 price;
        uint256 amount;
        uint256 makerFee;
        uint256 takerFee;
        uint256 timestamp;
    }

    // ============ State Variables ============

    /// @notice Counter for order IDs
    uint256 public orderIdCounter;

    /// @notice Counter for trade IDs
    uint256 public tradeIdCounter;

    /// @notice Maker fee in basis points (e.g., 25 = 0.25%)
    uint256 public makerFeeBps;

    /// @notice Taker fee in basis points (e.g., 50 = 0.50%)
    uint256 public takerFeeBps;

    /// @notice Fee recipient address
    address public feeRecipient;

    /// @notice Mapping of order ID to Order
    mapping(uint256 => Order) public orders;

    /// @notice Mapping of trade ID to Trade
    mapping(uint256 => Trade) public trades;

    /// @notice Mapping of sukuk token => payment token => buy orders
    mapping(address => mapping(address => uint256[])) public buyOrderBook;

    /// @notice Mapping of sukuk token => payment token => sell orders
    mapping(address => mapping(address => uint256[])) public sellOrderBook;

    /// @notice Mapping of user => their order IDs
    mapping(address => uint256[]) public userOrders;

    /// @notice Whitelisted payment tokens
    mapping(address => bool) public whitelistedPaymentTokens;

    /// @notice Whitelisted sukuk tokens
    mapping(address => bool) public whitelistedSukukTokens;

    // ============ Events ============
    event OrderCreated(
        uint256 indexed orderId,
        address indexed maker,
        address indexed sukukToken,
        address paymentToken,
        OrderType orderType,
        uint256 price,
        uint256 amount
    );

    event OrderFilled(
        uint256 indexed orderId,
        address indexed taker,
        uint256 filledAmount,
        uint256 remainingAmount
    );

    event OrderCancelled(uint256 indexed orderId, address indexed maker);

    event TradeExecuted(
        uint256 indexed tradeId,
        uint256 indexed buyOrderId,
        uint256 indexed sellOrderId,
        address buyer,
        address seller,
        uint256 price,
        uint256 amount
    );

    event FeesUpdated(uint256 makerFeeBps, uint256 takerFeeBps);
    event FeeRecipientUpdated(address indexed feeRecipient);
    event PaymentTokenWhitelisted(address indexed token, bool whitelisted);
    event SukukTokenWhitelisted(address indexed token, bool whitelisted);

    // ============ Errors ============
    error InvalidPrice();
    error InvalidAmount();
    error InvalidExpiry();
    error OrderNotFound();
    error OrderNotActive();
    error OrderExpired();
    error UnauthorizedCancellation();
    error PaymentTokenNotWhitelisted();
    error SukukTokenNotWhitelisted();
    error InsufficientBalance();
    error InsufficientAllowance();
    error InvalidFee();
    error NoMatchingOrders();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the marketplace
     * @param _makerFeeBps Maker fee in basis points
     * @param _takerFeeBps Taker fee in basis points
     * @param _feeRecipient Fee recipient address
     * @param admin Address to grant admin role
     */
    function initialize(
        uint256 _makerFeeBps,
        uint256 _takerFeeBps,
        address _feeRecipient,
        address admin
    ) external initializer {
        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        if (_makerFeeBps > 1000 || _takerFeeBps > 1000) revert InvalidFee(); // Max 10%

        makerFeeBps = _makerFeeBps;
        takerFeeBps = _takerFeeBps;
        feeRecipient = _feeRecipient;

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(OPERATOR_ROLE, admin);
        _grantRole(FEE_MANAGER_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);
    }

    // ============ Order Creation ============

    /**
     * @notice Creates a limit order
     * @param sukukToken Sukuk token address
     * @param paymentToken Payment token address
     * @param orderType BUY or SELL
     * @param price Price per token
     * @param amount Amount of tokens
     * @param expiresAt Expiration timestamp (0 for no expiry)
     */
    function createOrder(
        address sukukToken,
        address paymentToken,
        OrderType orderType,
        uint256 price,
        uint256 amount,
        uint256 expiresAt
    )
        external
        whenNotPaused
        nonReentrant
        returns (uint256 orderId)
    {
        if (!whitelistedSukukTokens[sukukToken]) revert SukukTokenNotWhitelisted();
        if (!whitelistedPaymentTokens[paymentToken]) revert PaymentTokenNotWhitelisted();
        if (price == 0) revert InvalidPrice();
        if (amount == 0) revert InvalidAmount();
        if (expiresAt > 0 && expiresAt <= block.timestamp) revert InvalidExpiry();

        orderId = ++orderIdCounter;

        // Lock tokens based on order type
        if (orderType == OrderType.SELL) {
            // Lock sukuk tokens
            IERC20 sukuk = IERC20(sukukToken);
            if (sukuk.balanceOf(msg.sender) < amount) revert InsufficientBalance();
            if (sukuk.allowance(msg.sender, address(this)) < amount) {
                revert InsufficientAllowance();
            }
            sukuk.transferFrom(msg.sender, address(this), amount);
        } else {
            // Lock payment tokens
            uint256 totalCost = (amount * price) / (10 ** 18);
            IERC20 payment = IERC20(paymentToken);
            if (payment.balanceOf(msg.sender) < totalCost) revert InsufficientBalance();
            if (payment.allowance(msg.sender, address(this)) < totalCost) {
                revert InsufficientAllowance();
            }
            payment.transferFrom(msg.sender, address(this), totalCost);
        }

        // Create order
        orders[orderId] = Order({
            orderId: orderId,
            maker: msg.sender,
            sukukToken: sukukToken,
            paymentToken: paymentToken,
            orderType: orderType,
            price: price,
            amount: amount,
            filledAmount: 0,
            createdAt: block.timestamp,
            expiresAt: expiresAt,
            status: OrderStatus.ACTIVE
        });

        // Add to order book
        if (orderType == OrderType.BUY) {
            buyOrderBook[sukukToken][paymentToken].push(orderId);
        } else {
            sellOrderBook[sukukToken][paymentToken].push(orderId);
        }

        userOrders[msg.sender].push(orderId);

        emit OrderCreated(
            orderId,
            msg.sender,
            sukukToken,
            paymentToken,
            orderType,
            price,
            amount
        );
    }

    // ============ Order Execution ============

    /**
     * @notice Fills an order (market taker)
     * @param orderId Order to fill
     * @param fillAmount Amount to fill (0 = fill completely)
     */
    function fillOrder(uint256 orderId, uint256 fillAmount)
        external
        whenNotPaused
        nonReentrant
    {
        Order storage order = orders[orderId];

        if (order.orderId == 0) revert OrderNotFound();
        if (order.status != OrderStatus.ACTIVE) revert OrderNotActive();
        if (order.expiresAt > 0 && order.expiresAt <= block.timestamp) {
            order.status = OrderStatus.EXPIRED;
            revert OrderExpired();
        }

        uint256 remainingAmount = order.amount - order.filledAmount;
        uint256 amountToFill = fillAmount == 0 ? remainingAmount : fillAmount;

        if (amountToFill > remainingAmount) {
            amountToFill = remainingAmount;
        }

        if (amountToFill == 0) revert InvalidAmount();

        // Calculate payment
        uint256 paymentAmount = (amountToFill * order.price) / (10 ** 18);
        uint256 makerFee = (paymentAmount * makerFeeBps) / 10000;
        uint256 takerFee = (paymentAmount * takerFeeBps) / 10000;

        // Execute trade based on order type
        if (order.orderType == OrderType.SELL) {
            // Taker is buying
            IERC20(order.paymentToken).transferFrom(
                msg.sender,
                address(this),
                paymentAmount + takerFee
            );
            IERC20(order.sukukToken).transfer(msg.sender, amountToFill);
            IERC20(order.paymentToken).transfer(order.maker, paymentAmount - makerFee);
        } else {
            // Taker is selling
            IERC20(order.sukukToken).transferFrom(
                msg.sender,
                order.maker,
                amountToFill
            );
            IERC20(order.paymentToken).transfer(
                msg.sender,
                paymentAmount - takerFee
            );
        }

        // Transfer fees
        if (makerFee + takerFee > 0) {
            IERC20(order.paymentToken).transfer(feeRecipient, makerFee + takerFee);
        }

        // Update order
        order.filledAmount += amountToFill;
        if (order.filledAmount >= order.amount) {
            order.status = OrderStatus.FILLED;
        }

        // Record trade
        uint256 tradeId = ++tradeIdCounter;
        trades[tradeId] = Trade({
            tradeId: tradeId,
            buyOrderId: order.orderType == OrderType.BUY ? orderId : 0,
            sellOrderId: order.orderType == OrderType.SELL ? orderId : 0,
            buyer: order.orderType == OrderType.BUY ? order.maker : msg.sender,
            seller: order.orderType == OrderType.SELL ? order.maker : msg.sender,
            sukukToken: order.sukukToken,
            paymentToken: order.paymentToken,
            price: order.price,
            amount: amountToFill,
            makerFee: makerFee,
            takerFee: takerFee,
            timestamp: block.timestamp
        });

        emit OrderFilled(orderId, msg.sender, amountToFill, order.amount - order.filledAmount);
        emit TradeExecuted(
            tradeId,
            order.orderType == OrderType.BUY ? orderId : 0,
            order.orderType == OrderType.SELL ? orderId : 0,
            trades[tradeId].buyer,
            trades[tradeId].seller,
            order.price,
            amountToFill
        );
    }

    // ============ Order Management ============

    /**
     * @notice Cancels an order
     * @param orderId Order to cancel
     */
    function cancelOrder(uint256 orderId) external nonReentrant {
        Order storage order = orders[orderId];

        if (order.orderId == 0) revert OrderNotFound();
        if (order.maker != msg.sender && !hasRole(OPERATOR_ROLE, msg.sender)) {
            revert UnauthorizedCancellation();
        }
        if (order.status != OrderStatus.ACTIVE) revert OrderNotActive();

        uint256 remainingAmount = order.amount - order.filledAmount;

        // Return locked tokens
        if (order.orderType == OrderType.SELL) {
            IERC20(order.sukukToken).transfer(order.maker, remainingAmount);
        } else {
            uint256 remainingPayment = (remainingAmount * order.price) / (10 ** 18);
            IERC20(order.paymentToken).transfer(order.maker, remainingPayment);
        }

        order.status = OrderStatus.CANCELLED;

        emit OrderCancelled(orderId, order.maker);
    }

    // ============ Configuration Functions ============

    /**
     * @notice Updates fees
     */
    function setFees(uint256 _makerFeeBps, uint256 _takerFeeBps)
        external
        onlyRole(FEE_MANAGER_ROLE)
    {
        if (_makerFeeBps > 1000 || _takerFeeBps > 1000) revert InvalidFee();
        makerFeeBps = _makerFeeBps;
        takerFeeBps = _takerFeeBps;
        emit FeesUpdated(_makerFeeBps, _takerFeeBps);
    }

    /**
     * @notice Updates fee recipient
     */
    function setFeeRecipient(address _feeRecipient)
        external
        onlyRole(FEE_MANAGER_ROLE)
    {
        feeRecipient = _feeRecipient;
        emit FeeRecipientUpdated(_feeRecipient);
    }

    /**
     * @notice Whitelists payment token
     */
    function whitelistPaymentToken(address token, bool whitelisted)
        external
        onlyRole(OPERATOR_ROLE)
    {
        whitelistedPaymentTokens[token] = whitelisted;
        emit PaymentTokenWhitelisted(token, whitelisted);
    }

    /**
     * @notice Whitelists sukuk token
     */
    function whitelistSukukToken(address token, bool whitelisted)
        external
        onlyRole(OPERATOR_ROLE)
    {
        whitelistedSukukTokens[token] = whitelisted;
        emit SukukTokenWhitelisted(token, whitelisted);
    }

    // ============ View Functions ============

    /**
     * @notice Gets order details
     */
    function getOrder(uint256 orderId) external view returns (Order memory) {
        return orders[orderId];
    }

    /**
     * @notice Gets trade details
     */
    function getTrade(uint256 tradeId) external view returns (Trade memory) {
        return trades[tradeId];
    }

    /**
     * @notice Gets user's orders
     */
    function getUserOrders(address user) external view returns (uint256[] memory) {
        return userOrders[user];
    }

    /**
     * @notice Gets buy orders for sukuk/payment pair
     */
    function getBuyOrders(address sukukToken, address paymentToken)
        external
        view
        returns (uint256[] memory)
    {
        return buyOrderBook[sukukToken][paymentToken];
    }

    /**
     * @notice Gets sell orders for sukuk/payment pair
     */
    function getSellOrders(address sukukToken, address paymentToken)
        external
        view
        returns (uint256[] memory)
    {
        return sellOrderBook[sukukToken][paymentToken];
    }

    // ============ Emergency Functions ============

    function pause() external onlyRole(OPERATOR_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(OPERATOR_ROLE) {
        _unpause();
    }

    // ============ Upgrade Functions ============

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(UPGRADER_ROLE)
    {}
}
