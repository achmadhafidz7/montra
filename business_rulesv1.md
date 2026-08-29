# Montra Business Rules v1

## Scope / Principles

- Montra v1 is a fully local, single-person application.
- v1 has no user entity, login, authentication, workspace, or ownership relationship.
- Tables do not include `user_id` in v1.
- The authoritative financial history consists of accounts and their ledger records.
- Prefer derived values and strict relationships over duplicated financial state.
- All monetary `amount` values are stored as positive values. Transaction type and direction determine their effect on a balance.

## Accounts

- An account stores an `initial_balance` representing its balance when it is first added to Montra.
- `initial_balance` may be edited only while the account has no transaction or transfer ledger records.
- After the first ledger record exists, balance corrections must be recorded as normal `INCOME` or `EXPENSE` transactions. There is no `ADJUSTMENT` transaction type.
- An account with transaction history must not be hard-deleted. It must be archived instead.
- An archived account remains available to historical views and reports.
- An archived account cannot be selected for a new transaction or as the source or destination of a new transfer.
- Archiving an account must not modify or detach its existing ledger records.

## Transactions

- Supported transaction types are:
  - `INCOME`
  - `EXPENSE`
  - `TRANSFER`
- `amount` must always be greater than zero and stored as a positive value.
- `INCOME` increases an account balance.
- `EXPENSE` decreases an account balance.
- Negative account balances are allowed. The UI may warn the user, but creation or editing must not be blocked solely because the resulting balance is negative.
- A normal `INCOME` or `EXPENSE` transaction may be fully edited, including its amount, type-compatible category, date, note, and account.
- Moving a transaction to another account must update the derived balances of both the old and new accounts.
- A normal transaction may be hard-deleted.
- Editing or deleting a transaction must immediately be reflected in all derived balances and reports.
- Corrections are ordinary `INCOME` or `EXPENSE` transactions, optionally assigned to an appropriate correction category. No special correction behavior is required.

## Categories

- Every `INCOME` and `EXPENSE` transaction must have a category.
- Each category has exactly one category type: `INCOME` or `EXPENSE`.
- A transaction may only use a category whose type matches the transaction type.
- Montra provides default categories for new local data stores.
- Montra provides separate system `Uncategorized` categories for `INCOME` and `EXPENSE`.
- System `Uncategorized` categories cannot be deleted.
- Deleting a category that is already used must reassign its transactions to the matching system `Uncategorized` category in the same operation.
- Category deletion must never leave an `INCOME` or `EXPENSE` transaction without a valid category.
- Transfers do not use categories.

## Transfers

- A transfer is one logical operation represented internally by two linked ledger records:
  - a `TRANSFER` record with direction `OUT` for the source account;
  - a `TRANSFER` record with direction `IN` for the destination account.
- Both records use the same positive amount and share a stable transfer identifier.
- The source and destination accounts must be different.
- `TRANSFER OUT` decreases the source account balance.
- `TRANSFER IN` increases the destination account balance.
- Transfers must not be counted as income or expense in summaries and reports.
- Transfers have no category. Any "Transfer" label shown in the UI is derived from the transaction type rather than stored as a category.
- Transfer fees are not supported in v1.
- The application exposes a transfer as one logical object. Users must not edit or delete an individual transfer leg directly.
- Creating, editing, or deleting a transfer must be atomic: both ledger records succeed together or neither change is persisted.
- Editing a transfer may change its amount, date, source account, destination account, or note, provided all transfer invariants remain valid.

## Dates & Balance

- Transactions may use a past, current, or future `transaction_date`.
- Reports group and filter transactions using `transaction_date`, not `created_at`.
- `created_at` records when data was entered and remains metadata only.
- A transaction is eligible to affect the current balance only when `transaction_date <= today` in the app's local calendar.
- Future-dated transactions are upcoming transactions and do not affect the current balance until their date becomes eligible.
- The authoritative current balance is derived, not stored as an independently editable account value.
- For an account, current balance is calculated as:

  ```text
  initial_balance
  + eligible INCOME amounts
  - eligible EXPENSE amounts
  + eligible TRANSFER IN amounts
  - eligible TRANSFER OUT amounts
  ```

- Only valid, non-deleted ledger records are included in the calculation.
- A cached balance or snapshot may be added later as a performance optimization, but it must not become an independent source of truth.

## Data Integrity

- A ledger record must always reference an existing account. `account_id` must not become `NULL` because an account is archived.
- New transactions and transfers must reject archived accounts.
- Category type compatibility must be enforced when creating or editing an `INCOME` or `EXPENSE` transaction.
- Transfer legs must always have opposite directions, the same amount and date, and the same transfer identifier.
- A transfer must have exactly one `OUT` leg and one `IN` leg.
- Transfer creation, editing, and deletion require a database transaction or equivalent atomic local persistence operation.
- Reassigning transactions during category deletion must be atomic with the category deletion.
- Derived balances and reports must use the same eligibility and sign rules to avoid inconsistent totals.
- Because v1 is fully local, ownership checks and `user_id` constraints are intentionally absent.

## Out of Scope v1

- User accounts, login, authentication, cloud sync, shared databases, and multi-user ownership.
- An `ADJUSTMENT` transaction type.
- Transfer fees.
- Categories on transfers.
- Hard deletion of accounts that have history.
- Authoritative stored account balances.
- Balance snapshots or caching unless later required strictly as a transparent performance optimization.
- Recurring transaction automation, budgets, goals, tags, reminders, and other post-MVP features.

## Rules Summary

| Area | v1 rule |
|---|---|
| App model | Fully local and single-person; no login, user entity, ownership relation, or `user_id` |
| Transaction types | `INCOME`, `EXPENSE`, `TRANSFER` |
| Amount | Always positive and greater than zero |
| Initial balance | Stored on account; editable only before any ledger record exists |
| Corrections | Normal `INCOME` or `EXPENSE`; no `ADJUSTMENT` type |
| Current balance | Derived from `initial_balance` and eligible ledger records |
| Negative balance | Allowed |
| Normal transaction edit | Fully editable, including account |
| Normal transaction delete | Hard delete |
| Account deletion | Accounts with history are archived, not deleted |
| Archived account | Visible in history/reports; unavailable for new transactions and transfers |
| Category requirement | Required for `INCOME` and `EXPENSE`; type must match |
| Default categories | Provided by Montra |
| Uncategorized | Separate protected system category for each category type |
| Used category deletion | Reassign transactions atomically to matching `Uncategorized` |
| Transfer storage | Two linked `TRANSFER` ledger records: `OUT` and `IN` |
| Transfer category | None |
| Transfer fee | Not supported |
| Transfer mutation | Edit/delete atomically as one logical transfer |
| Transaction dates | Past, today, and future are allowed |
| Reporting date | Uses `transaction_date`; `created_at` is metadata |
| Future transaction | Does not affect current balance until `transaction_date <= today` |
