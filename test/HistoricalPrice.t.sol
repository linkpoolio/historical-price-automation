// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "forge-std/StdJson.sol";
import {HistoricalPrice} from "@src/HistoricalPrice.sol";

contract HistoricalPriceNetworkForkTest is Test {
    using stdJson for string;

    HistoricalPrice historicalPrice;
    uint256 network;
    Config config;

    struct Config {
        address keeperRegistryAddress;
        uint256 maxTimeDifference;
    }

    function configureNetwork(
        string memory input
    ) internal view returns (Config memory) {
        string memory inputDir = string.concat(
            vm.projectRoot(),
            "/script/input/"
        );
        string memory chainDir = string.concat(vm.toString(block.chainid), "/");
        string memory file = string.concat(input, ".json");
        string memory data = vm.readFile(
            string.concat(inputDir, chainDir, file)
        );
        bytes memory rawConfig = data.parseRaw("");
        return abi.decode(rawConfig, (Config));
    }

    function setUp() public {
        network = vm.createSelectFork(vm.rpcUrl("mainnet"));
        config = configureNetwork("config");
        historicalPrice = new HistoricalPrice(
            config.keeperRegistryAddress,
            config.maxTimeDifference
        );
    }

    function testFork_SetTargetDatetime() public {
        vm.selectFork(network);
        historicalPrice.setTarget(
            1670862014,
            0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419
        );
        assertEq(historicalPrice.targetDatetime(), 1670862014);
        assertEq(historicalPrice.requestCompleted(), false);
        assertEq(
            historicalPrice.getPriceFeedAddress(),
            0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419
        );
    }

    function testFork_CheckUpkeep() public {
        vm.selectFork(network);
        historicalPrice.setTarget(
            1670862014,
            0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419
        );
        (bool upkeepNeeded, bytes memory performData) = historicalPrice
            .checkUpkeep("");
        assertEq(upkeepNeeded, true);
    }

    // Case 1: Timestamp is within the maxTimeDifference
    function testFork_PerformUpkeepCase1() public {
        vm.selectFork(network);
        historicalPrice.setTarget(
            1670862014,
            0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419
        );
        (bool upkeepNeeded, bytes memory performData) = historicalPrice
            .checkUpkeep("");
        vm.prank(config.keeperRegistryAddress);
        historicalPrice.performUpkeep(performData);
        assertEq(historicalPrice.requestCompleted(), true);
        assertEq(historicalPrice.historicalPrice(), 124956000000);
        assertEq(
            historicalPrice.historicalPriceRoundId(),
            92233720368547796857
        );
    }

    // Case 2: Timestamp is outside the maxTimeDifference
    function testFork_PerformUpkeepCase2() public {
        vm.selectFork(network);
        historicalPrice.setTarget(
            1355329214,
            0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419
        );
        (bool upkeepNeeded, bytes memory performData) = historicalPrice
            .checkUpkeep("");
        assertEq(upkeepNeeded, false);
    }
}
