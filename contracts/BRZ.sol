// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract BRZ is ERC20 {
    constructor(string memory name, uint256 initialSupply) ERC20(name, name) {
        _mint(msg.sender, initialSupply);
    }
}
