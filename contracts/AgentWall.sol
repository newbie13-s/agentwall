// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @notice Minimal interface for the Binance Agent ID registry (ERC-721).
///         Mainnet (BNB Chain) address: 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F
interface IAgentIdRegistry {
    function balanceOf(address owner) external view returns (uint256);
}

/// @title AgentWall — the Agent ID holders' wall
/// @notice A public on-chain guestbook that only Binance Agent ID holders can sign.
///         Agent ID is used as identity + access control: holding an Agent ID
///         (an ERC-721 in the registry contract) is the only requirement to sign.
///
///         Safety design:
///         - No payable functions: the contract can never receive or hold BNB.
///         - No admin/owner functions, no upgradeability, no withdraw.
///         - No tokens, no rewards, no promises of return. It is just a wall.
///         - One sign per address per 24 hours, messages capped at 280 bytes.
contract AgentWall {
    /// @notice The Agent ID registry used for the holder check.
    IAgentIdRegistry public immutable registry;

    uint256 public constant COOLDOWN = 24 hours;
    uint256 public constant MAX_MESSAGE_BYTES = 280;
    uint256 public constant MAX_PAGE_SIZE = 100;

    struct Sign {
        address signer;
        string message;
        uint256 timestamp;
    }

    Sign[] private _signs;

    /// @notice Last time each address signed (0 = never).
    mapping(address => uint256) public lastSignAt;

    event Signed(address indexed signer, uint256 indexed index, string message, uint256 timestamp);

    error ZeroRegistry();
    error NotAgentIdHolder(address account);
    error EmptyMessage();
    error MessageTooLong(uint256 length);
    error CooldownActive(uint256 availableAt);

    /// @param registry_ The Agent ID registry contract.
    ///        On BNB Chain mainnet: 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F
    constructor(address registry_) {
        if (registry_ == address(0)) revert ZeroRegistry();
        registry = IAgentIdRegistry(registry_);
    }

    /// @notice True if `account` holds at least one Agent ID.
    function hasAgentId(address account) public view returns (bool) {
        return registry.balanceOf(account) > 0;
    }

    /// @notice Sign the wall. Caller must hold an Agent ID.
    /// @param message The message to store (1..280 bytes, UTF-8 bytes counted).
    function sign(string calldata message) external {
        if (!hasAgentId(msg.sender)) revert NotAgentIdHolder(msg.sender);

        uint256 len = bytes(message).length;
        if (len == 0) revert EmptyMessage();
        if (len > MAX_MESSAGE_BYTES) revert MessageTooLong(len);

        uint256 last = lastSignAt[msg.sender];
        if (last != 0 && block.timestamp < last + COOLDOWN) {
            revert CooldownActive(last + COOLDOWN);
        }

        uint256 index = _signs.length;
        _signs.push(Sign({signer: msg.sender, message: message, timestamp: block.timestamp}));
        lastSignAt[msg.sender] = block.timestamp;

        emit Signed(msg.sender, index, message, block.timestamp);
    }

    /// @notice Total number of signs on the wall.
    function totalSigns() external view returns (uint256) {
        return _signs.length;
    }

    /// @notice Read a single sign by index.
    function getSign(uint256 index) external view returns (Sign memory) {
        return _signs[index];
    }

    /// @notice Read a page of signs in stored order (oldest first within the page).
    ///         The frontend reverses for newest-first display.
    /// @param offset Start index (returns empty if beyond the end).
    /// @param limit  Max items to return (capped at MAX_PAGE_SIZE).
    function getSigns(uint256 offset, uint256 limit) external view returns (Sign[] memory page) {
        uint256 total = _signs.length;
        if (offset >= total) return new Sign[](0);
        if (limit > MAX_PAGE_SIZE) limit = MAX_PAGE_SIZE;
        uint256 end = offset + limit;
        if (end > total) end = total;
        page = new Sign[](end - offset);
        for (uint256 i = offset; i < end; i++) {
            page[i - offset] = _signs[i];
        }
    }
}
