// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {Splitter, AlreadyInitialized} from "src/Splitter.sol";

// Solmate
import {ERC20} from "solmate/tokens/ERC20.sol";

contract SplitterInitTest is Test {
    address[] public users;
    Splitter public splitter = new Splitter();

    function setUp() public {
        /// @dev initialize users
        users.push(address(0x10));
        users.push(address(0x11));
        users.push(address(0x12));
    }

    function testCanInit() public {
        splitter.init(new bytes(123), ERC20(address(1)), users);

        assertEq(splitter.metadata(), new bytes(123));
        assertEq(address(splitter.token()), address(1));
        assertEq(splitter.getMembers(), users);
    }

    function testCanInitWithZeroToken() public {
        splitter.init(new bytes(0), ERC20(address(0)), users);
    }

    function testCannotReinit() public {
        splitter.init(new bytes(0), ERC20(address(1)), users);

        vm.expectRevert(AlreadyInitialized.selector);
        splitter.init(new bytes(0), ERC20(address(1)), users);
    }
}
