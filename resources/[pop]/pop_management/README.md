# POP Management

Run a company from a configurable management point or the management command. Eligible players can manage employees, transfer company funds, pay bonuses and issue invoices. Hiring and invoicing require the recipient's consent.

## Installation

1. Start oxmysql and ESX, QBCore or Qbox before `ensure pop_management`.
2. Configure your enabled jobs, boss grades, locations, invoice permissions, preset amounts, limits and language in `config.lua`.
3. Select the society account backend or leave it on automatic detection. For the ESX addon account backend, create the `society_<job>` account for each enabled job. The built-in backend uses its own SQL accounts.
4. The script creates its SQL tables at startup. `sql/install.sql` is available for manual provisioning.

Configure the menu choices in `Config.AmountPresets`. Each choice maps a short string key to a positive whole amount. The server resolves the key and applies the corresponding transfer or invoice limit.

Standalone mode supports the built-in society account exports. The management panel and invoicing require framework jobs.

## Server exports

- `exports.pop_management:GetSocietyMoney(job)`
- `exports.pop_management:AddSocietyMoney(job, amount, note)`
- `exports.pop_management:RemoveSocietyMoney(job, amount, note)`
- `exports.pop_management:IsBoss(source)`

In game, check online and offline grade changes, offer expiry, client consent and interrupted transfers on each enabled account backend.
