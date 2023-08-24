// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {Splitter, InvalidToken, AlreadyAMember, NoTargets, NotAMember, NoDebt, ValueNotZero} from "src/Splitter.sol";

// Solmate
import {ERC20} from "solmate/tokens/ERC20.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";

contract SplitterTest is Test {
    MockERC20 token = new MockERC20("ERC20", "ERC20", 18);
    address[] public users;
    Splitter public splitter;

    event ExpenseAdded(
        bytes metadata,
        uint256 amount,
        address paidBy,
        address[] targets
    );

    function setUp() public {
        /// @dev initialize users
        users.push(address(10));
        users.push(address(11));
        users.push(address(12));

        /// @dev Mint tokens for all users
        token.mint(users[0], 1e9);
        token.mint(users[1], 1e9);
        token.mint(users[2], 1e9);

        /// @dev initialize splitter
        splitter = new Splitter();
        splitter.init(new bytes(0), ERC20(token), users);
    }

    function testCanAddMember() public {
        splitter.addMember(address(20));
    }

    function testCannotAddExistingMember() public {
        /// @dev Initial member
        vm.expectRevert(AlreadyAMember.selector);
        splitter.addMember(address(10));

        /// @dev New member
        splitter.addMember(address(20));

        vm.expectRevert(AlreadyAMember.selector);
        splitter.addMember(address(20));
    }

    function testCanAddExpenses() public {
        /// @dev Add expense for user 0
        vm.prank(users[0]);
        vm.expectEmit(true, true, false, false);
        emit ExpenseAdded(new bytes(123), 300, users[0], users);
        splitter.addExpense(new bytes(123), 300, users[0], users);

        /// @dev Check debts
        assertEq(splitter.debts(users[0]), -200);
        assertEq(splitter.debts(users[1]), 100);
        assertEq(splitter.debts(users[2]), 100);
    }

    function testCanAddExpenseWithWeirdRounding() public {
        /// @dev Add expense for user 0
        vm.prank(users[0]);
        splitter.addExpense(new bytes(123), 17, users[0], users);

        /// @dev Check debts
        assertEq(splitter.debts(users[0]), -10);
        assertEq(splitter.debts(users[1]), 5);
        assertEq(splitter.debts(users[2]), 5);
    }

    function testCanNegateExpenses() public {
        /// @dev Add expenses that result in a balance of 0
        vm.startPrank(users[0]);
        splitter.addExpense(new bytes(123), 600, users[0], users);
        splitter.addExpense(new bytes(123), 390, users[1], users);
        splitter.addExpense(new bytes(123), 210, users[1], users);
        splitter.addExpense(new bytes(123), 90, users[2], users);
        splitter.addExpense(new bytes(123), 510, users[2], users);

        /// @dev Check debts
        assertEq(splitter.debts(users[0]), 0);
        assertEq(splitter.debts(users[1]), 0);
        assertEq(splitter.debts(users[2]), 0);
    }

    function testCanAddExpenseForSpecificUsers() public {
        address[] memory targets = new address[](2);
        targets[0] = users[0];
        targets[1] = users[1];

        /// @dev Add expenses that don't concern users[2]
        vm.startPrank(users[0]);
        splitter.addExpense(new bytes(123), 420, users[0], targets);
        splitter.addExpense(new bytes(123), 600, users[0], targets);
        splitter.addExpense(new bytes(123), 900, users[1], targets);
        splitter.addExpense(new bytes(123), 1200, users[2], targets);

        /// @dev Check debts
        assertEq(splitter.debts(users[0]), 540);
        assertEq(splitter.debts(users[1]), 660);
        assertEq(splitter.debts(users[2]), -1200);
    }

    function testCannotAddExpenseForNoOne() public {
        vm.prank(users[0]);
        vm.expectRevert(NoTargets.selector);
        splitter.addExpense(new bytes(123), 123456, users[0], new address[](0));
    }

    function testCannotAddExpensePaidByANonMember() public {
        vm.prank(users[0]);
        vm.expectRevert(abi.encodeWithSelector(NotAMember.selector, 999));
        splitter.addExpense(new bytes(123), 123456, address(999), users);
    }

    function testCannotAddExpenseAsANonMember() public {
        vm.prank(address(998));
        vm.expectRevert(abi.encodeWithSelector(NotAMember.selector, 998));
        splitter.addExpense(new bytes(123), 123456, users[0], users);
    }

    function testCannotAddExpenseForANonMember() public {
        address[] memory targets = new address[](3);
        targets[0] = users[0];
        targets[1] = address(997);
        targets[2] = users[1];

        vm.prank(users[0]);
        vm.expectRevert(abi.encodeWithSelector(NotAMember.selector, 997));
        splitter.addExpense(new bytes(123), 123456, users[0], targets);
    }

    function testCannotSettleInexistantDebt() public {
        vm.prank(users[0]);
        vm.expectRevert(abi.encodeWithSelector(NoDebt.selector, users[0], 0));
        splitter.settleDebts();
    }

    function testCannotSettleNegativeDebt() public {
        vm.startPrank(users[0]);

        splitter.addExpense(new bytes(123), 600, users[0], users);

        vm.expectRevert(
            abi.encodeWithSelector(NoDebt.selector, users[0], -400)
        );
        splitter.settleDebts();
    }

    function testCanSettleDebts() public {
        address[] memory targets = new address[](2);
        targets[0] = users[0];
        targets[1] = users[1];

        /// @dev Mint tokens for the two first users
        token.mint(users[0], 540);
        token.mint(users[0], 660);

        /// @dev Add expenses that don't concern users[2]
        vm.startPrank(users[0]);
        splitter.addExpense(new bytes(123), 420, users[0], targets);
        splitter.addExpense(new bytes(123), 600, users[0], targets);
        splitter.addExpense(new bytes(123), 900, users[1], targets);
        splitter.addExpense(new bytes(123), 1200, users[2], targets);

        /// @dev Check debts
        vm.stopPrank();

        /// @dev Settle debts for users[0] and check debts
        vm.startPrank(users[0]);
        token.approve(address(splitter), 540);
        splitter.settleDebts(users[0]);
        vm.stopPrank();
        assertBalancedDebts();

        /// @dev Settle debts for users[0] and check debts
        vm.startPrank(users[1]);
        token.approve(address(splitter), 660);
        splitter.settleDebts(users[1]);
        vm.stopPrank();
        assertBalancedDebts();

        /// @dev Check that all debts are settled
        assertEq(splitter.debts(users[0]), 0);
        assertEq(splitter.debts(users[1]), 0);
        assertEq(splitter.debts(users[2]), 0);
    }

    function testCannotSettleDebtsWithValue() public {
        vm.startPrank(users[0]);

        splitter.addExpense(new bytes(123), 600, users[1], users);

        // Value added
        vm.deal(users[0], 1);
        vm.expectRevert(ValueNotZero.selector);
        splitter.settleDebts{value: 1}();

        // Sanity check
        token.approve(address(splitter), 200);
        splitter.settleDebts();
    }

    /// @dev Utility functions
    function assertBalancedDebts() private {
        int256 balance = 0;
        uint256 usersLength = users.length;

        for (uint256 i = 0; i < usersLength; ) {
            balance += splitter.debts(users[i]);

            unchecked {
                i++;
            }
        }

        assertEq(balance, 0);
    }
}
