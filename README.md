# UniTrack Protocol

On-chain verification layer for Marketers Terminal products. Deployed on Base mainnet. Immutable contracts. No proxy. No admin upgrade.

## Deployed contracts

| Contract | Address | Status | Lines |
|---|---|---|---|
| **UniTrackRegistry** | [`0x55e93DdaB250C37df8489c3bee467c9bf6843739`](https://basescan.org/address/0x55e93DdaB250C37df8489c3bee467c9bf6843739#code) | LIVE + Basescan verified (2026-05-02 11:28 UTC, block 45465977) | 46 |
| **UniTrackPulse** | [`0xd27e39b0b9d21368ae866fff32ce43e9bed8cd33`](https://basescan.org/address/0xd27e39b0b9d21368ae866fff32ce43e9bed8cd33) | LIVE + [Sourcify Exact Match](https://repo.sourcify.dev/8453/0xd27e39b0b9d21368ae866fff32ce43e9bed8cd33) verified (2026-05-02 16:25 UTC, block 45474893) | 55 |

**Owner (both contracts):** `0x3FFE88deaE135a33A652C40f44C112076c7829B1` — set immutably at deployment, confirmed via on-chain `owner()` read.
**Chain:** Base Mainnet (chain ID 8453).
**Compiler:** Solidity v0.8.34+commit.80d5c536, optimization off, EVM default, MIT license.

## How it works

### Vault verification (UniTrackRegistry)

1. MT publishes a vault version hash on-chain via `publishVersion(versionId, hash)` — owner-only function.
2. Hash sits publicly on chain.
3. User receives the vault update via `git pull`, runs `make hash` locally.
4. User compares local hash to on-chain hash via `getVersion(versionId)`.
5. Match = authentic and untampered. Mismatch = stop, do not apply.

The hash covers the entire vault contents and file paths (SHA-256). One character change anywhere in the vault produces a completely different hash.

### Execution tracking (UniTrackPulse)

Every time a buyer runs a Store Scaler command, the system records a pulse on-chain. The purpose is productivity tracking — buyers and MT can see that commands are being executed, the product is actively generating value, and the vault is in use. Think of it as a transparent activity log that proves the product works without revealing what was run or who ran it.

How it works:

1. Claude Code command finishes executing on the user's machine.
2. The Stop hook fires `pulse.sh`, which reads the RW private key from local `.env`.
3. `pulse.sh` signs a `pulse(versionHash)` transaction locally — no API, no middleware.
4. The signed tx goes to Base RPC. Only data on-chain: wallet address + version hash + timestamp.
5. The contract emits a `PulseRecorded` event. MT sees nothing — there is no MT server in this loop.

The pulse contract gates writes via `registered[msg.sender]` — only wallets registered by the owner can pulse. This prevents spam from polluting the timeline. The wallet is random, holds only ~$0.001 ETH of gas, and reveals no user identity. The pulse count per wallet and global total are publicly readable, giving buyers a verifiable measure of their own execution activity.

## Why this is trustworthy

- **Both contracts verified on Basescan** — anyone can read the source and confirm it matches the deployed bytecode.
- **Each contract under 100 lines** — readable by any Solidity developer in 5 minutes. Simplicity is the audit.
- **No proxy. No UUPS. No admin upgrade function.** Once deployed, the contracts cannot be changed by anyone — including the owner. The vault evolves; the contracts are permanent.
- **Public read functions** — anyone can call `getVersion()`, `pulses()`, `registered()`, `totalPulses()`, `totalWallets()`, `owner()` without permission.
- **On-chain audit trail** — every published version, every registered wallet, every pulse is a public Base transaction.

View live signals at [unitrackmt.org](https://unitrackmt.org) (static page, reads contracts via ethers.js, no backend).

## Security model

The contracts have a single trust assumption: the `owner` keypair is securely stored. If the owner key is compromised, an attacker could publish fake version hashes (degrading the verification signal) or register unauthorized wallets (degrading the pulse signal). They could NOT modify existing data, pause the contract, or upgrade it.

To audit before trusting:
- Open the verified source on Basescan / Sourcify (links above)
- Run [Slither](https://github.com/crytic/slither) (Trail of Bits' static analyzer): `slither contracts/UniTrackPulse.sol`
- Run [Aderyn](https://github.com/Cyfrin/aderyn) (Cyfrin's analyzer) for a second opinion
- Read the source. Each contract is short enough to review in 5 minutes.

### v1.0 audit summary (UniTrackPulse)

Manual audit against 93 Slither detectors + 48 DeFiVulnLabs vulnerability types completed 2026-05-02. **0 critical, 0 high.** 3 actionable low/medium findings deferred to v1.1 (would require contract redeploy):

- Missing zero-address validation on `registerWallet` / `rotateWallet` — mitigated procedurally (the owner only registers freshly-generated random addresses, never `address(0)`)
- Stale state retention after `rotateWallet` — informational; off-chain indexers (e.g. unitrackmt.org) ignore stale entries
- No owner deregistration — mitigated by off-chain filtering: pulses with a `versionHash` not present in `UniTrackRegistry.versions[]` are silently dropped from public displays

A v1.1 contract with these patches will be deployed if/when a real-world incident occurs (compromised buyer wallet spamming garbage pulses). The current v1.0 contract is deliberately immutable and not pre-emptively upgraded.

## Links

- [Store Scaler](https://github.com/MarketersTerminal/StoreScaler) — the product the protocol verifies
- [UniTrack4D](https://github.com/MarketersTerminal/UniTrack4D) — desktop GUI for vault execution
- [Marketers Terminal](https://github.com/MarketersTerminal/MarketersTerminal) — organization hub
- [unitrackmt.org](https://unitrackmt.org) — verification page (live on-chain data)
- Registry on Basescan: https://basescan.org/address/0x55e93DdaB250C37df8489c3bee467c9bf6843739
- Registry deployment tx: https://basescan.org/tx/0x513b8039fd14efd918f80134f775a9b939b2c98be9cce91a42920a7957a58dc6
- Pulse on Basescan: https://basescan.org/address/0xd27e39b0b9d21368ae866fff32ce43e9bed8cd33
- Pulse on Sourcify: https://repo.sourcify.dev/8453/0xd27e39b0b9d21368ae866fff32ce43e9bed8cd33
- Pulse deployment tx: https://basescan.org/tx/0x9d97474988c2f211ad84855c53b06ff8ea8746655f292091a6caa0dd8dbb67d9
