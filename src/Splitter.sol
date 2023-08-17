// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

error NoTargets();
error AlreadyAMember();
error NotAMember(address target);
error NoDebt(address user, int256 debt);
error AlreadyInitialized();
error InvalidToken();

// TODO: Should this only work with ERC-20?
contract Splitter {
    bytes public metadata;
    ERC20 public token;

    address[] public members;
    mapping(address => bool) public isMember;
    mapping(address => int256) public debts;

    event ExpenseAdded(
        bytes metadata,
        uint256 amount,
        address paidBy,
        address[] targets
    );

    function init(
        bytes calldata _metadata,
        ERC20 _token,
        address[] calldata _members
    ) public {
        if (address(token) != address(0)) {
            revert AlreadyInitialized();
        }

        if (address(_token) == address(0)) {
            revert InvalidToken();
        }

        /// @dev create config data
        metadata = _metadata;
        token = _token;

        /// @dev copy members to storage
        uint256 length = _members.length;
        for (uint256 i = 0; i < length; ) {
            _addMember(_members[i]);

            unchecked {
                i++;
            }
        }
    }

    function _addMember(address member) private {
        members.push(member);
        isMember[member] = true;
    }

    function addMember(address member) public {
        if (isMember[member]) {
            revert AlreadyAMember();
        }

        _addMember(member);
    }

    /// @param _targets List of users affected by this expense
    function addExpense(
        bytes calldata _metadata,
        uint256 _amount,
        address _payor,
        address[] calldata _targets
    ) public {
        /// @dev Targets need to be set to avoid race conditions.
        /// @dev Cache the targets length for gas efficiency
        uint256 targetsLength = _targets.length;
        if (targetsLength == 0) {
            revert NoTargets();
        }

        /// @dev make sure that the msg.sender is a member
        if (!isMember[msg.sender]) {
            revert NotAMember(msg.sender);
        }

        /// @dev make sure that the msg.sender is a member
        if (!isMember[_payor]) {
            revert NotAMember(_payor);
        }

        /// @dev debt share (not using amount to avoid rounding errors)
        int256 share = int256(_amount / targetsLength);
        debts[_payor] -= int256(targetsLength) * share;

        /// @dev copy members to storage and update debts
        for (uint256 i = 0; i < targetsLength; ) {
            /// @dev cache target for gas efficiency
            address target = _targets[i];

            /// @dev if the target isn't a member, revert
            /// @dev we could call _addMember(target) instead, but explicit errors are more explicit
            if (!isMember[target]) {
                revert NotAMember(target);
            }

            /// @dev copy target to expense and update debt
            debts[target] += share;

            unchecked {
                i++;
            }
        }

        emit ExpenseAdded(_metadata, _amount, _payor, _targets);
    }

    function getHighestCreditor(
        address payer
    ) internal view returns (address highestCreditor, int256 highestCredit) {
        /// @dev cache membersLength for gas efficiency
        uint256 membersLength = members.length;

        for (uint256 i = 0; i < membersLength; ) {
            address member = members[i];

            unchecked {
                i++;
            }

            if (member == payer) {
                continue;
            }

            if (debts[member] < highestCredit) {
                highestCredit = debts[member];
                highestCreditor = member;
            }
        }

        return (highestCreditor, -highestCredit);
    }

    function settleDebts(address user) public {
        int256 debt = debts[user];
        if (debt <= 0) {
            revert NoDebt(user, debt);
        }

        while (debt != 0) {
            (
                address highestCreditor,
                int256 highestCredit
            ) = getHighestCreditor(user);

            /// @dev Transfer either the current debt or the highest credit amount
            int256 amount = debt > highestCredit ? highestCredit : debt;
            SafeTransferLib.safeTransferFrom(
                token,
                msg.sender,
                highestCreditor,
                uint256(amount)
            );
            debt -= amount;

            /// @dev Update debts
            debts[highestCreditor] += amount;
            debts[user] -= amount;
        }
    }

    function settleDebts() public {
        settleDebts(msg.sender);
    }

    function getMembers() public view returns (address[] memory) {
        return members;
    }
}
