// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IHistoricalPrice {
    function setTarget(uint256 datetime, address aggregatorAddress) external;

    function getPriceFeedAddress() external view returns (address);

    event HistoricalPriceUpdated(uint256 historicalPrice, string pricePairName);

    event HistoricalPriceRequested(uint256 targetDatetime, address priceFeed);

    error OnlyKeeperRegistry();
    error ZeroAddress();
}
