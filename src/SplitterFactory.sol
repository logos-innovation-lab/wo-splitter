// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.15;

// Solmate
import {ERC20} from "solmate/tokens/ERC20.sol";

// OpenZeppelin
import "openzeppelin/proxy/Clones.sol";

// Custom
import {Splitter} from "./Splitter.sol";

contract SplitterFactory {
    event SplitterCreated(
        address indexed addr,
        bytes _metadata,
        ERC20 _token,
        address[] _members
    );

    address public masterSplitter;

    constructor() {
        masterSplitter = address(new Splitter());
    }

    function create(
        bytes calldata _metadata,
        ERC20 _token,
        address[] calldata _members
    ) public returns (Splitter splitter) {
        /// @dev create the Splitter
        splitter = Splitter(Clones.clone(masterSplitter));
        splitter.init(_metadata, _token, _members);

        /// @dev emit SplitterCreated event
        emit SplitterCreated(address(splitter), _metadata, _token, _members);
    }
}
