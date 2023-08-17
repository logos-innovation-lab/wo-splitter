// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;
import "forge-std/Test.sol";

// Solmate
import {Bytes32AddressLib} from "solmate/utils/Bytes32AddressLib.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";

// Custom
import {Splitter} from "src/Splitter.sol";
import {SplitterFactory} from "src/SplitterFactory.sol";

contract SplitterFactoryTest is Test {
    /// @dev Events
    event SplitterCreated(
        address indexed addr,
        bytes _metadata,
        ERC20 _token,
        address[] _members
    );

    /// @dev Variables
    address[] public users;
    SplitterFactory public factory;

    function setUp() public {
        /// @dev initialize users
        users.push(address(0x10));
        users.push(address(0x11));
        users.push(address(0x12));

        /// @dev deploy factory
        factory = new SplitterFactory();
    }

    function testCanCreateSplitter() public {
        // Expect an event to be emitted
        vm.expectEmit(false, false, false, true);
        emit SplitterCreated(
            address(0),
            new bytes(123),
            ERC20(address(234)),
            users
        );

        // Create the marketplace and record logs
        vm.recordLogs();
        Splitter splitter = factory.create(
            new bytes(123),
            ERC20(address(234)),
            users
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();

        // Check if the address emitted in the event is right
        address emitted;

        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == SplitterCreated.selector) {
                emitted = Bytes32AddressLib.fromLast20Bytes(logs[i].topics[1]);
                break;
            }
        }

        // Check metadata
        assertEq(splitter.metadata(), new bytes(123));
        assertEq(address(splitter.token()), address(234));
        assertEq(splitter.getMembers(), users);
        assertEq(address(splitter), emitted);
    }
}
