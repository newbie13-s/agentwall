# AgentWall — The Agent ID Holders' Wall

**Sign the chain, prove your Agent ID.**

AgentWall is a minimal on-chain guestbook on **BNB Chain** that only
**Binance Agent ID** holders can sign. It demonstrates Agent ID used the way it
is meant to be used: as **identity + access control** for an on-chain
application.

- Live check, not a claim: when you call `sign()`, the contract asks the
  official Agent ID registry whether your address holds an Agent ID
  (`balanceOf(address) > 0`). No Agent ID → the transaction reverts.
- Agent ID registry (BNB Chain mainnet):
  `0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F`
- One sign per address per 24 hours; messages are capped at 280 bytes.
- Every sign is stored on-chain and emitted as a `Signed` event.

Built for the **Binance Wallet Agent ID Hackathon** (Project Awards).

## Deployed

AgentWall is **live on BNB Chain mainnet** (chainId 56):

- **Contract:** `0xa9689f8c6e397ea6dfa61ef83dbd2916e5913ee3`
- **BscScan:** https://bscscan.com/address/0xa9689f8c6e397ea6dfa61ef83dbd2916e5913ee3
- **Deploy transaction:**
  [`0x09c524081b0989d3d9518b1fcb929bdfef53e90900bbc86fff1e033125775d63`](https://bscscan.com/tx/0x09c524081b0989d3d9518b1fcb929bdfef53e90900bbc86fff1e033125775d63)
  (deployed via the canonical CREATE2 deployment proxy; constructor argument
  is the Agent ID registry `0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F`)
- **Compiler:** solc 0.8.26, optimizer enabled, 200 runs.

The frontend in this repo already points at this address
(`CONTRACT_ADDRESS` in `frontend/index.html`).

## Safety design

AgentWall is deliberately boring — that is the point:

- **No funds, ever.** The contract has no payable functions and cannot receive
  or hold BNB. There is nothing to withdraw because there is nothing in it.
- **No admin.** No owner, no privileged functions, no upgradeability, no proxy.
  What is deployed is what runs, forever.
- **No tokens, no rewards, no promises.** Signing the wall gives you exactly
  one thing: your message on a wall. Nothing about returns, yield, or income.
- **No credential collection.** The frontend connects with the standard
  injected wallet (`window.ethereum`). There are **no QR-code login flows, no
  pairing codes**, and nothing is sent to any server — the page is fully static.
- **Small and auditable.** One contract, ~120 lines, fully covered by tests.

## Repository layout

```
contracts/AgentWall.sol    The wall contract (registry address is a constructor arg)
contracts/MockAgentId.sol  Test-only registry stub (never deploy this)
test/AgentWall.t.sol       Foundry test suite (10 tests, no external deps)
frontend/index.html        Static frontend (ethers v6 via CDN)
foundry.toml               Foundry config (solc 0.8.26, optimizer 200 runs)
```

## How Agent ID is used

| Piece | How it works |
|---|---|
| Holder check | `AgentWall.hasAgentId(address)` → `registry.balanceOf(address) > 0` |
| Gate | `sign()` reverts with `NotAgentIdHolder` unless the caller holds an Agent ID |
| Identity | The signer address stored with each message *is* an Agent ID holder address — the wall is a public, verifiable roster of holders |
| Frontend | Before enabling the form, the page checks `hasAgentId(connectedAddress)` and shows a friendly pointer to claim an Agent ID in the Binance app if the check fails |

## Run the tests

Requires [Foundry](https://getfoundry.sh):

```bash
forge build
forge test -v
```

Expected: **10 passed, 0 failed** — holder can sign, non-holder reverts,
cooldown (24h, per-address) enforced, empty/overlong messages revert,
280-byte boundary accepted, pagination works, `Signed` event emitted.

## Deploy (reference — the live deployment is listed above)

1. Deploy with the real registry address:

   ```bash
   forge create contracts/AgentWall.sol:AgentWall \
     --rpc-url <BNB_CHAIN_RPC> \
     --constructor-args 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F \
     --private-key <DEPLOYER_KEY>
   ```

2. Verify the source on BscScan (hackathon requirement):

   ```bash
   forge verify-contract <DEPLOYED_ADDRESS> contracts/AgentWall.sol:AgentWall \
     --constructor-args $(cast abi-encode "constructor(address)" 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F)
   ```

3. Put the deployed address into `frontend/index.html` (`CONTRACT_ADDRESS`)
   and host the single static file anywhere.

Measured deployment cost (Foundry gas report, solc 0.8.26, optimizer 200):
**651,133 gas** for contract creation, 2,958 bytes of runtime code — roughly
0.0007 BNB at 1 gwei or 0.002 BNB at 3 gwei including transaction overhead.

## License

MIT — see [LICENSE](LICENSE).
