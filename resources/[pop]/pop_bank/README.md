# pop_bank

Simple, clean banking for FiveM: **deposit**, **withdraw**, **transfer** and **history**, on the framework's own
`bank` account. No parallel accounts, no heavy UI: a small side panel, one accent color, ~0.00 ms at idle.

- **Bank counters** (Fleeca branches + Pacific Standard): deposit, withdraw, transfer, history.
- **ATMs** (every ATM prop on the map): short "inserting card" step, then deposit, withdraw (capped per
  operation) and history. Transfers are counter-only.
- **Transfers** to an online player by **server ID** or **account number** (QBCore/Qbox citizenid, ESX identifier).
  The recipient gets a notification with the sender's name.
- **History** of the last operations per character, old rows purged automatically at startup.
- 10 languages (en, fr, es, de, it, pt, nl, pl, tr, ar with right-to-left layout).

## Requirements

| | |
|---|---|
| Framework | ESX (Legacy and older), QBCore or Qbox — detected automatically. Standalone: banking is disabled. |
| Database | [oxmysql](https://github.com/overextended/oxmysql) (required) |
| Target | ox_target or qb-target if started, otherwise a built-in native prompt (`[E]`) |
| ox_lib | **not** required |

## Installation

1. Copy `pop_bank` into your `resources/[pop]/` folder.
2. In `server.cfg`, start it **after** oxmysql and your framework:
   ```cfg
   ensure oxmysql
   ensure qb-core        # or es_extended / qbx_core
   ensure ox_target      # optional
   ensure [pop]
   ```
3. Done. The `pop_bank_transactions` table is created automatically on first start
   (`sql/install.sql` is provided if you prefer to run it manually).

## Configuration (`config.lua`)

Common POP keys (`Config.Locale`, `Config.Framework`, `Config.Target`, `Config.Notify`, `Config.AccentColor`, ...)
plus:

| Key | Default | Description |
|---|---|---|
| `Config.Banks` | 8 counters | Counter positions (interaction zone centered on the desk) |
| `Config.AtmModels` | 4 models | ATM props that open the ATM screen |
| `Config.Blip` | `{ sprite = 108, color = 2, scale = 0.7 }` | Counter blips (`false` = none) |
| `Config.MaxAmount` | `1000000` | Max per deposit / counter withdrawal |
| `Config.AtmWithdraw` | `5000` | Max per ATM withdrawal |
| `Config.MaxTransfer` | `100000` | Max per transfer |
| `Config.HistorySize` | `20` | Operations shown in the panel |
| `Config.HistoryDays` | `30` | Older rows are deleted at startup |

## Exports

Server:

```lua
-- Add a history line (salaries, invoices from other scripts).
-- type: 'deposit' | 'withdraw' | 'transfer_out' | 'transfer_in' ; amount: integer > 0
exports.pop_bank:AddTransaction(identifier, type, amount, other) --> bool

-- Read a character's history, newest first (limit defaults to Config.HistorySize, max 100).
exports.pop_bank:GetHistory(identifier, limit) --> { { type, amount, other, time }, ... }
```

`AddTransaction` only records the line: it does **not** move money (use your framework for that).

Client:

```lua
exports.pop_bank:IsOpen() --> bool, true while the bank panel is open
```

## Security

Everything is checked server-side: integer amounts only (negative, decimal, NaN, infinite values and strings are
rejected), per-operation caps, player distance to the counter / ATM, one operation at a time per player with a
1-second delay, dead players blocked, and refunds if a money movement fails halfway. Amounts and identifiers are
never trusted from the client, and a player can only read their own history.

## Languages

Set `Config.Locale` to `en`, `fr`, `es`, `de`, `it`, `pt`, `nl`, `pl`, `tr` or `ar`. Missing keys fall back to
English. To add a language, copy `locales/en.lua`, change the code and translate the values.
