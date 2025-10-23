// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ISecondaryMarketplace
 * @notice Interface for compliant secondary trading of tokenized Sukuk
 * @dev Implements order book, price discovery, and compliance-checked transfers
 * @custom:security-contact security@tradesukuk.com
 */
interface ISecondaryMarketplace {

    // ============ Enums ============

    /**
     * @notice Order type classification
     */
    enum OrderType {
        MARKET,             // Execute at current market price
        LIMIT,              // Execute only at specified price or better
        STOP_LOSS,          // Trigger market order when price reaches stop price
        STOP_LIMIT          // Trigger limit order when price reaches stop price
    }

    /**
     * @notice Order side (buy or sell)
     */
    enum OrderSide {
        BUY,                // Buy order
        SELL                // Sell order
    }

    /**
     * @notice Order status
     */
    enum OrderStatus {
        PENDING,            // Order placed but not yet processed
        OPEN,               // Active and available for matching
        PARTIALLY_FILLED,   // Some tokens filled, remainder still open
        FILLED,             // Completely executed
        CANCELLED,          // Cancelled by creator
        EXPIRED,            // Expired due to time limit
        REJECTED            // Rejected due to compliance failure
    }

    /**
     * @notice Fee structure type
     */
    enum FeeType {
        PERCENTAGE,         // Fee as percentage of trade value
        FLAT,               // Fixed fee amount
        TIERED              // Volume-based tiered fees
    }

    // ============ Structs ============

    /**
     * @notice Order book entry
     * @param orderId Unique order identifier
     * @param token Security token contract address
     * @param creator Address that created the order
     * @param orderType Type of order (market, limit, etc.)
     * @param side Buy or sell
     * @param tokenAmount Number of tokens in order
     * @param pricePerToken Price per token in base currency (0 for market orders)
     * @param filledAmount Number of tokens already filled
     * @param status Current order status
     * @param createdAt Timestamp of order creation
     * @param expiresAt Expiration timestamp (0 for no expiration)
     * @param stopPrice Trigger price for stop orders (0 if not stop order)
     */
    struct Order {
        uint256 orderId;
        address token;
        address creator;
        OrderType orderType;
        OrderSide side;
        uint256 tokenAmount;
        uint256 pricePerToken;
        uint256 filledAmount;
        OrderStatus status;
        uint256 createdAt;
        uint256 expiresAt;
        uint256 stopPrice;
    }

    /**
     * @notice Trade execution record
     * @param tradeId Unique trade identifier
     * @param token Security token traded
     * @param buyOrderId Buy order that was filled
     * @param sellOrderId Sell order that was filled
     * @param buyer Address of token buyer
     * @param seller Address of token seller
     * @param tokenAmount Number of tokens traded
     * @param pricePerToken Execution price per token
     * @param totalValue Total trade value
     * @param buyerFee Fee paid by buyer
     * @param sellerFee Fee paid by seller
     * @param executedAt Timestamp of execution
     */
    struct Trade {
        uint256 tradeId;
        address token;
        uint256 buyOrderId;
        uint256 sellOrderId;
        address buyer;
        address seller;
        uint256 tokenAmount;
        uint256 pricePerToken;
        uint256 totalValue;
        uint256 buyerFee;
        uint256 sellerFee;
        uint256 executedAt;
    }

    /**
     * @notice Market statistics for a token
     * @param lastPrice Most recent trade price
     * @param volume24h Trading volume in last 24 hours
     * @param highPrice24h Highest price in last 24 hours
     * @param lowPrice24h Lowest price in last 24 hours
     * @param priceChange24h Price change percentage
     * @param totalTrades Total number of trades executed
     * @param openBuyOrders Number of active buy orders
     * @param openSellOrders Number of active sell orders
     */
    struct MarketStats {
        uint256 lastPrice;
        uint256 volume24h;
        uint256 highPrice24h;
        uint256 lowPrice24h;
        int256 priceChange24h;
        uint256 totalTrades;
        uint256 openBuyOrders;
        uint256 openSellOrders;
    }

    /**
     * @notice Fee configuration
     * @param feeType Type of fee structure
     * @param makerFee Fee for order creators (in basis points or flat amount)
     * @param takerFee Fee for order takers (in basis points or flat amount)
     * @param feeRecipient Address that receives collected fees
     * @param minFee Minimum fee amount
     * @param maxFee Maximum fee amount
     */
    struct FeeConfig {
        FeeType feeType;
        uint256 makerFee;
        uint256 takerFee;
        address feeRecipient;
        uint256 minFee;
        uint256 maxFee;
    }

    // ============ Events ============

    /**
     * @notice Emitted when a new order is created
     * @param orderId Unique order identifier
     * @param token Token being traded
     * @param creator Address that created the order
     * @param side Buy or sell
     * @param orderType Type of order
     * @param tokenAmount Number of tokens
     * @param pricePerToken Price per token
     */
    event OrderCreated(
        uint256 indexed orderId,
        address indexed token,
        address indexed creator,
        OrderSide side,
        OrderType orderType,
        uint256 tokenAmount,
        uint256 pricePerToken
    );

    /**
     * @notice Emitted when an order is cancelled
     * @param orderId Order identifier
     * @param creator Address that created the order
     * @param reason Cancellation reason
     */
    event OrderCancelled(
        uint256 indexed orderId,
        address indexed creator,
        string reason
    );

    /**
     * @notice Emitted when orders are matched and trade executed
     * @param tradeId Unique trade identifier
     * @param token Token traded
     * @param buyer Buyer address
     * @param seller Seller address
     * @param tokenAmount Number of tokens traded
     * @param pricePerToken Execution price
     * @param totalValue Total trade value
     */
    event TradeExecuted(
        uint256 indexed tradeId,
        address indexed token,
        address buyer,
        address seller,
        uint256 tokenAmount,
        uint256 pricePerToken,
        uint256 totalValue
    );

    /**
     * @notice Emitted when order is partially filled
     * @param orderId Order identifier
     * @param filledAmount Amount filled in this execution
     * @param remainingAmount Amount still open
     */
    event OrderPartiallyFilled(
        uint256 indexed orderId,
        uint256 filledAmount,
        uint256 remainingAmount
    );

    /**
     * @notice Emitted when order is completely filled
     * @param orderId Order identifier
     * @param totalFilled Total amount filled
     */
    event OrderFilled(
        uint256 indexed orderId,
        uint256 totalFilled
    );

    /**
     * @notice Emitted when order is rejected due to compliance
     * @param orderId Order identifier
     * @param creator Order creator
     * @param reason Rejection reason
     */
    event OrderRejected(
        uint256 indexed orderId,
        address indexed creator,
        string reason
    );

    /**
     * @notice Emitted when fee configuration is updated
     * @param token Token for which fees were updated
     * @param makerFee New maker fee
     * @param takerFee New taker fee
     */
    event FeeConfigUpdated(
        address indexed token,
        uint256 makerFee,
        uint256 takerFee
    );

    /**
     * @notice Emitted when trading is paused/unpaused
     * @param token Token affected
     * @param isPaused New pause status
     */
    event TradingPaused(
        address indexed token,
        bool isPaused
    );

    // ============ Order Management ============

    /**
     * @notice Creates a new buy or sell order
     * @dev Performs compliance checks before creating order
     * @param token Security token to trade
     * @param side Buy or sell
     * @param orderType Type of order (market, limit, etc.)
     * @param tokenAmount Number of tokens to trade
     * @param pricePerToken Price per token (0 for market orders)
     * @param expiresAt Expiration timestamp (0 for no expiration)
     * @param stopPrice Trigger price for stop orders (0 if not stop)
     * @return orderId Unique identifier for created order
     */
    function createOrder(
        address token,
        OrderSide side,
        OrderType orderType,
        uint256 tokenAmount,
        uint256 pricePerToken,
        uint256 expiresAt,
        uint256 stopPrice
    ) external returns (uint256 orderId);

    /**
     * @notice Cancels an existing order
     * @dev Only order creator or admin can cancel
     * @param orderId Order identifier to cancel
     * @param reason Cancellation reason
     */
    function cancelOrder(uint256 orderId, string calldata reason) external;

    /**
     * @notice Modifies price of existing limit order
     * @dev Only order creator can modify, resets order queue position
     * @param orderId Order identifier
     * @param newPricePerToken New price per token
     */
    function modifyOrderPrice(
        uint256 orderId,
        uint256 newPricePerToken
    ) external;

    /**
     * @notice Executes a market order against best available orders
     * @dev Automatically matches with best price orders in book
     * @param orderId Market order to execute
     * @return trades Array of trade IDs generated from execution
     */
    function executeMarketOrder(uint256 orderId)
        external
        returns (uint256[] memory trades);

    /**
     * @notice Matches compatible buy and sell orders
     * @dev Called by matching engine or admin
     * @param buyOrderId Buy order identifier
     * @param sellOrderId Sell order identifier
     * @param amount Number of tokens to match
     * @return tradeId Unique identifier for executed trade
     */
    function matchOrders(
        uint256 buyOrderId,
        uint256 sellOrderId,
        uint256 amount
    ) external returns (uint256 tradeId);

    /**
     * @notice Batch cancels multiple orders
     * @param orderIds Array of order identifiers to cancel
     * @param reason Cancellation reason
     */
    function batchCancelOrders(
        uint256[] calldata orderIds,
        string calldata reason
    ) external;

    // ============ Order Queries ============

    /**
     * @notice Returns complete order details
     * @param orderId Order identifier
     * @return Order struct with all order information
     */
    function getOrder(uint256 orderId) external view returns (Order memory);

    /**
     * @notice Returns orders for a specific token
     * @param token Token contract address
     * @param side Filter by buy or sell (optional, use type(uint8).max for all)
     * @param status Filter by status (optional, use type(uint8).max for all)
     * @return Array of Order structs
     */
    function getOrdersByToken(
        address token,
        OrderSide side,
        OrderStatus status
    ) external view returns (Order[] memory);

    /**
     * @notice Returns orders created by a specific address
     * @param creator Address that created orders
     * @return Array of Order structs
     */
    function getUserOrders(address creator) external view returns (Order[] memory);

    /**
     * @notice Returns order book depth (best buy/sell orders)
     * @param token Token contract address
     * @param depth Number of price levels to return
     * @return buyOrders Array of best buy orders
     * @return sellOrders Array of best sell orders
     */
    function getOrderBookDepth(address token, uint256 depth)
        external
        view
        returns (Order[] memory buyOrders, Order[] memory sellOrders);

    /**
     * @notice Returns best bid (highest buy) price
     * @param token Token contract address
     * @return Best bid price (0 if no buy orders)
     */
    function getBestBid(address token) external view returns (uint256);

    /**
     * @notice Returns best ask (lowest sell) price
     * @param token Token contract address
     * @return Best ask price (0 if no sell orders)
     */
    function getBestAsk(address token) external view returns (uint256);

    /**
     * @notice Returns bid-ask spread
     * @param token Token contract address
     * @return spread Difference between best ask and best bid
     */
    function getSpread(address token) external view returns (uint256 spread);

    // ============ Trade History & Stats ============

    /**
     * @notice Returns trade details
     * @param tradeId Trade identifier
     * @return Trade struct with execution details
     */
    function getTrade(uint256 tradeId) external view returns (Trade memory);

    /**
     * @notice Returns trades for a specific token
     * @param token Token contract address
     * @param limit Maximum number of trades to return
     * @return Array of Trade structs (most recent first)
     */
    function getTradesByToken(address token, uint256 limit)
        external
        view
        returns (Trade[] memory);

    /**
     * @notice Returns trades involving a specific address
     * @param account Address to query (buyer or seller)
     * @param limit Maximum number of trades to return
     * @return Array of Trade structs
     */
    function getUserTrades(address account, uint256 limit)
        external
        view
        returns (Trade[] memory);

    /**
     * @notice Returns market statistics for a token
     * @param token Token contract address
     * @return MarketStats struct with trading metrics
     */
    function getMarketStats(address token)
        external
        view
        returns (MarketStats memory);

    /**
     * @notice Returns trading volume for a time period
     * @param token Token contract address
     * @param startTime Start of period (timestamp)
     * @param endTime End of period (timestamp)
     * @return volume Total trading volume in base currency
     */
    function getVolumeByPeriod(
        address token,
        uint256 startTime,
        uint256 endTime
    ) external view returns (uint256 volume);

    // ============ Fee Management ============

    /**
     * @notice Calculates fees for a trade
     * @param token Token being traded
     * @param tokenAmount Number of tokens
     * @param pricePerToken Price per token
     * @param isMaker Whether user is maker (true) or taker (false)
     * @return fee Fee amount in base currency
     */
    function calculateFee(
        address token,
        uint256 tokenAmount,
        uint256 pricePerToken,
        bool isMaker
    ) external view returns (uint256 fee);

    /**
     * @notice Sets fee configuration for a token
     * @dev Only callable by admin
     * @param token Token contract address
     * @param config FeeConfig struct with fee parameters
     */
    function setFeeConfig(address token, FeeConfig calldata config) external;

    /**
     * @notice Returns fee configuration for a token
     * @param token Token contract address
     * @return FeeConfig struct with current fees
     */
    function getFeeConfig(address token) external view returns (FeeConfig memory);

    /**
     * @notice Withdraws collected fees
     * @dev Only callable by fee recipient
     * @param token Token for which to withdraw fees
     * @param amount Amount to withdraw
     */
    function withdrawFees(address token, uint256 amount) external;

    /**
     * @notice Returns accumulated fees for a token
     * @param token Token contract address
     * @return Collected fee amount in base currency
     */
    function getAccumulatedFees(address token) external view returns (uint256);

    // ============ Compliance Integration ============

    /**
     * @notice Checks if trade is compliant before execution
     * @dev Validates both parties pass compliance checks
     * @param token Token to trade
     * @param buyer Buyer address
     * @param seller Seller address
     * @param amount Number of tokens to trade
     * @return True if trade is compliant, false otherwise
     */
    function isTradeCompliant(
        address token,
        address buyer,
        address seller,
        uint256 amount
    ) external view returns (bool);

    /**
     * @notice Sets compliance module for verification
     * @param complianceModule Address of compliance contract
     */
    function setComplianceModule(address complianceModule) external;

    /**
     * @notice Returns current compliance module address
     * @return Address of compliance contract
     */
    function getComplianceModule() external view returns (address);

    // ============ Administrative Functions ============

    /**
     * @notice Pauses trading for a specific token
     * @dev Emergency function, only callable by admin
     * @param token Token to pause
     */
    function pauseTrading(address token) external;

    /**
     * @notice Resumes trading for a token
     * @param token Token to unpause
     */
    function resumeTrading(address token) external;

    /**
     * @notice Checks if trading is paused for a token
     * @param token Token to check
     * @return True if paused, false otherwise
     */
    function isTradingPaused(address token) external view returns (bool);

    /**
     * @notice Adds a token to the marketplace
     * @dev Only whitelisted tokens can be traded
     * @param token Token contract address
     */
    function listToken(address token) external;

    /**
     * @notice Removes a token from the marketplace
     * @param token Token contract address
     */
    function delistToken(address token) external;

    /**
     * @notice Checks if token is listed for trading
     * @param token Token contract address
     * @return True if listed, false otherwise
     */
    function isTokenListed(address token) external view returns (bool);

    /**
     * @notice Sets minimum order size for a token
     * @param token Token contract address
     * @param minSize Minimum order size
     */
    function setMinOrderSize(address token, uint256 minSize) external;

    /**
     * @notice Returns minimum order size for a token
     * @param token Token contract address
     * @return Minimum order size
     */
    function getMinOrderSize(address token) external view returns (uint256);
}
