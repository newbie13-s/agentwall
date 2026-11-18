// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Test-only stub of the Agent ID registry: just a balanceOf ledger.
///         NOT for deployment — it exists so AgentWall can be tested locally
///         without touching the real registry.
contract MockAgentId {
    mapping(address => uint256) private _balances;

    function setBalance(address account, uint256 amount) external {
        _balances[account] = amount;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }
}
