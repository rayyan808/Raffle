// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.5.0
pragma solidity ^0.8.19;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract AliceToken is ERC20 {
    constructor() ERC20("Alice Token", "ALICE") {
        _mint(msg.sender, 1000000 * 10 ** 18); // Mint 1M tokens
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
