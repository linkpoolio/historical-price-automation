// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/interfaces/automation/AutomationCompatibleInterface.sol";
import "@src/interfaces/IAggregatorV3Interface.sol";
import "@src/interfaces/IHistoricalPrice.sol";

/**
 * @title HistoricalPrice
 * @notice A contract to fetch and store historical prices of a data feed using Chainlink Automation.
 */
contract HistoricalPrice is IHistoricalPrice, AutomationCompatibleInterface {
    address public owner;
    AggregatorV3Interface internal priceFeed; // The address of the data feed
    address public keeperRegistryAddress; // The address of the Keeper Registry contract
    uint256 public historicalPriceRoundId; // The round ID of the historical price
    uint256 public historicalPrice; // The historical price of the data feed
    string public pricePairName; // The name of the price pair
    uint256 public targetDatetime; // The target datetime to fetch the historical price
    uint256 public maxTimeDifference; // The maximum time difference between the target datetime and the current datetime
    bool public requestCompleted; // Whether the historical price has been fetched
    /**
     * Modifiers ***********************************************
     */

    modifier onlyKeeperRegistry() {
        if (msg.sender != keeperRegistryAddress) {
            revert OnlyKeeperRegistry();
        }
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    /**
     * Constructor *********************************************
     */

    /**
     * @notice Set the address of the Keeper Registry contract.
     * @param _keeperRegistryAddress The address of the Keeper Registry contract.
     */
    constructor(address _keeperRegistryAddress, uint256 _maxTimeDifference) {
        owner = msg.sender;
        setKeeperRegistryAddress(_keeperRegistryAddress);
        setMaxtimeDifference(_maxTimeDifference);
    }

    /**
     * Admin **************************************************
     */

    /**
     * @notice This method is called to set the Keeper Registry Address
     */
    function setKeeperRegistryAddress(
        address _keeperRegistryAddress
    ) public onlyOwner {
        if (_keeperRegistryAddress == address(0)) {
            revert ZeroAddress();
        }
        keeperRegistryAddress = _keeperRegistryAddress;
    }

    /**
     * @notice This method is called to set the max time difference between the target datetime and the current datetime
     */
    function setMaxtimeDifference(uint256 _maxTimeDifference) public onlyOwner {
        maxTimeDifference = _maxTimeDifference;
    }

    /**
     * @notice This method is called to transfer ownership of the contract
     */
    function transferOwnership(address _newOwner) public onlyOwner {
        owner = _newOwner;
    }

    /**
     * External ***********************************************
     */

    /**
     * @notice Set the target datetime and aggregator address to fetch historical price.
     * @param datetime The target datetime to fetch the historical price.
     * @param aggregatorAddress The address of the Chainlink aggregator contract.
     */
    function setTarget(
        uint256 datetime,
        address aggregatorAddress
    ) external onlyOwner {
        priceFeed = AggregatorV3Interface(aggregatorAddress);
        targetDatetime = datetime;
        requestCompleted = false;
        emit HistoricalPriceRequested(datetime, aggregatorAddress);
    }

    /**
     * @notice Get the address of the price feed aggregator.
     * @return address address of the price feed aggregator.
     */
    function getPriceFeedAddress() external view returns (address) {
        return address(priceFeed);
    }

    /**
     * @notice Check if the historical price is available and return the price, round ID and description.
     * @return upkeepNeeded Whether the historical price is available.
     * @return performData The encoded historical price, round ID and description.
     */
    function checkUpkeep(
        bytes calldata /* checkData */
    )
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        if (requestCompleted) {
            upkeepNeeded = false;
            performData = bytes("");
        } else {
            uint256 answer;
            uint80 roundId;
            (answer, roundId) = _fetchHistoricalPrice();
            if (answer != 0) {
                upkeepNeeded = true;
                string memory description = priceFeed.description();
                performData = abi.encode(answer, roundId, description);
            } else {
                upkeepNeeded = false;
                performData = bytes("");
            }
        }
    }

    /**
     * @notice Perform the upkeep by storing the historical price and emitting an event.
     * @param performData The encoded historical price and description.
     */
    function performUpkeep(
        bytes calldata performData
    ) external override onlyKeeperRegistry {
        require(!requestCompleted, "Historical price already fetched");
        (uint256 answer, uint80 roundId, string memory description) = abi
            .decode(performData, (uint256, uint80, string));
        historicalPrice = answer;
        historicalPriceRoundId = roundId;
        pricePairName = description;
        requestCompleted = true;
        emit HistoricalPriceUpdated(answer, roundId, description); // Update this line
        _customCallbackLogic();
    }

    /**
     * Internal ***********************************************
     */

    /**
     * @notice Fetch the historical price for the target timestamp using binary search.
     * @return uint256 historical price for the target timestamp.
     * @return uint80 round ID of the historical price.
     */
    function _fetchHistoricalPrice() private view returns (uint256, uint80) {
        uint256 answer; // The historical price
        uint80 roundId; // The round ID of the historical price

        uint80 currentRound = priceFeed.latestRound(); // The latest round ID
        uint80 startRound = 0; // The start round ID
        uint80 endRound = currentRound; // The end round ID
        uint256 targetTimestamp = targetDatetime; // The target timestamp

        uint256 closestTimestampDiff = type(uint256).max; // The closest timestamp difference
        int256 closestPrice; // The closest price
        uint80 closestRoundId; // The closest round ID
        // Binary search
        while (startRound <= endRound) {
            uint80 midRound = (startRound + endRound) / 2;
            uint256 timestamp;
            int256 price;
            // Try to get the round data
            try priceFeed.getRoundData(midRound) returns (
                uint80,
                int256 returnedPrice,
                uint256,
                uint256 returnedTimestamp,
                uint80
            ) {
                price = returnedPrice;
                timestamp = returnedTimestamp;
                roundId = midRound;
            } catch {
                timestamp = 0;
            }
            // If the round data is available
            if (timestamp > 0) {
                uint256 timestampDiff = timestamp > targetTimestamp
                    ? timestamp - targetTimestamp
                    : targetTimestamp - timestamp;
                // Update the closest timestamp difference, price and round ID
                if (timestampDiff < closestTimestampDiff) {
                    closestTimestampDiff = timestampDiff;
                    closestPrice = price;
                    closestRoundId = roundId;
                }
                // If the timestamp is equal to the target timestamp, return the price and round ID
                if (timestamp == targetTimestamp) {
                    answer = uint256(price);
                    break;
                } else if (timestamp < targetTimestamp) {
                    startRound = midRound + 1;
                } else {
                    endRound = midRound - 1;
                }
            } else {
                startRound = midRound + 1;
            }
        }
        // If the closest timestamp difference is less than the max time difference, return the price and round ID
        if (answer == 0) {
            if (closestTimestampDiff <= maxTimeDifference) {
                answer = uint256(closestPrice);
                roundId = closestRoundId;
            } else {
                return (0, 0);
            }
        }
        return (answer, roundId);
    }

    /**
     * @notice Implement custom callback logic, e.g. updating the protocol's internal oracle for option contract settlement.
     */
    function _customCallbackLogic() private {
        // Add custom logic here
    }
}
