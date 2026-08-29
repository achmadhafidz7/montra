# Montra V1 — Data Model & Business Rules

## 1. MVP Scope

### Goal

Montra V1 adalah personal money tracker yang fokus pada satu hal:

> Membuat pencatatan keuangan sehari-hari cepat, sederhana, dan mudah dipahami tanpa user harus mengatur terlalu banyak hal.

V1 tidak ditujukan untuk menjadi aplikasi accounting atau financial planning lengkap.

### In Scope

#### Account

User dapat:

* Membuat account
* Mengubah nama dan informasi account
* Mengarsipkan account
* Melihat saldo account

Jenis account awal:

* Cash
* Bank
* E-Wallet
* Credit Card
* Other

Setiap account memiliki satu currency.

V1 menggunakan `IDR` sebagai default currency.

---

#### Category

User dapat membuat dan menggunakan category untuk mengelompokkan transaksi.

Category memiliki dua tipe:

* `INCOME`
* `EXPENSE`

Contoh:

```text
Food
Transportation
Shopping
Salary
Freelance
```

Category dapat memiliki parent category.

Contoh:

```text
Food
├── Restaurant
├── Groceries
└── Coffee
```

---

#### Transaction

V1 mendukung tiga jenis transaksi utama:

```text
INCOME
EXPENSE
TRANSFER
```

User dapat:

* Membuat transaksi
* Mengubah transaksi
* Menghapus transaksi
* Melihat transaction history
* Melihat transaksi berdasarkan account
* Melihat transaksi berdasarkan category

---

#### Income

Mencatat uang yang masuk ke suatu account.

Contoh:

```text
Salary
Rp10.500.000
→ BCA
```

---

#### Expense

Mencatat uang yang keluar dari suatu account.

Contoh:

```text
Food
Rp35.000
← BCA
```

---

#### Transfer

Mencatat perpindahan uang antar-account milik user.

Contoh:

```text
BCA
↓ Rp500.000
GoPay
```

Transfer tidak dianggap sebagai income maupun expense.

---

#### Basic Summary

V1 minimal dapat menampilkan:

* Total balance
* Balance per account
* Total income periode tertentu
* Total expense periode tertentu
* Expense berdasarkan category
* Recent transactions

### Out of Scope V1

Fitur berikut sengaja belum dibuat:

* Budget
* Saving goals
* Recurring transactions
* Tags
* Debt/loan management
* Investment tracking
* Financial health score
* Financial planning
* Receipt attachment
* Import/export
* Multi-user/shared wallet
* Advanced analytics
* Bank synchronization

Fitur tersebut dapat ditambahkan setelah core transaction flow V1 stabil.

---

# 2. Data Dictionary

## ACCOUNT

Merepresentasikan tempat uang disimpan atau sumber pembayaran.

| Field             | Type     | Required | Description                              |
| ----------------- | -------- | -------- | ---------------------------------------- |
| `id`              | UUID     | Yes      | Primary key                              |
| `name`            | TEXT     | Yes      | Nama account                             |
| `initial_balance` | INTEGER  | Yes      | Saldo ketika account pertama kali dibuat |
| `is_archived`     | BOOLEAN  | Yes      | Status archive                           |
| `created_at`      | DATETIME | Yes      | Waktu dibuat                             |
| `updated_at`      | DATETIME | Yes      | Waktu terakhir diubah                    |


# CATEGORY

Merepresentasikan tujuan atau sumber suatu income/expense.

| Field           | Type     | Required | Description           |
| --------------- | -------- | -------- | --------------------- |
| `id`            | UUID     | Yes      | Primary key           |
| `parent_id`     | UUID     | No       | Parent category       |
| `name`          | TEXT     | Yes      | Nama category         |
| `category_type` | ENUM     | Yes      | Income atau expense   |
| `icon`          | TEXT     | No       | Identifier icon       |
| `is_archived`   | BOOLEAN  | Yes      | Status archive        |
| `created_at`    | DATETIME | Yes      | Waktu dibuat          |
| `updated_at`    | DATETIME | Yes      | Waktu terakhir diubah |

### `category_type`

```text
INCOME
EXPENSE
```

### Hierarchy

`parent_id` mereferensikan `CATEGORY.id`.

Contoh:

```text
Transportation
├── Public Transport
├── Fuel
└── Parking
```

V1 dapat membatasi hierarchy maksimal satu level pada UI walaupun struktur database memungkinkan hierarchy lebih dalam.

---

# TRANSACTION

Merepresentasikan satu aktivitas finansial yang dilakukan user.

| Field              | Type     | Required    | Description             |
| ------------------ | -------- | ----------- | ----------------------- |
| `id`               | UUID     | Yes         | Primary key             |
| `transaction_type` | ENUM     | Yes         | Jenis transaksi         |
| `category_id`      | UUID     | Conditional | Category transaksi      |
| `amount`           | INTEGER  | Yes         | Nominal transaksi       |
| `note`             | TEXT     | No          | Catatan opsional        |
| `transaction_date` | DATETIME | Yes         | Waktu transaksi terjadi |
| `created_at`       | DATETIME | Yes         | Waktu record dibuat     |
| `updated_at`       | DATETIME | Yes         | Waktu terakhir diubah   |

### `transaction_type`

```text
INCOME
EXPENSE
TRANSFER
```

`transaction_date` berbeda dengan `created_at`.

Contoh:

User pada tanggal 28 Agustus baru memasukkan transaksi makan tanggal 26 Agustus.

```text
transaction_date = 2026-08-26
created_at        = 2026-08-28
```

---

# TRANSACTION_ENTRY

Merepresentasikan perubahan saldo sebuah account akibat suatu transaction.

| Field            | Type    | Required | Description                    |
| ---------------- | ------- | -------- | ------------------------------ |
| `id`             | UUID    | Yes      | Primary key                    |
| `transaction_id` | UUID    | Yes      | Transaction terkait            |
| `account_id`     | UUID    | Yes      | Account yang terkena perubahan |
| `entry_type`     | ENUM    | Yes      | Arah perubahan saldo           |
| `amount`         | INTEGER | Yes      | Nominal perubahan              |

### `entry_type`

```text
IN
OUT
```

`IN` menambah saldo account.

`OUT` mengurangi saldo account.

---

# 3. Business Rules

## General Transaction Rules

Semua transaksi harus memiliki:

```text
amount > 0
transaction_date != null
```

`amount` selalu disimpan positif.

Arah perubahan uang ditentukan oleh `entry_type`, bukan tanda nominal.

Benar:

```text
amount = 50000
entry_type = OUT
```

Bukan:

```text
amount = -50000
```

---

## Expense

Expense harus memiliki:

* `transaction_type = EXPENSE`
* Satu category bertipe `EXPENSE`
* Tepat satu `TRANSACTION_ENTRY`
* Entry harus bertipe `OUT`

Contoh:

```text
TRANSACTION

type       EXPENSE
amount     50000
category   FOOD

ENTRY

account    BCA
type       OUT
amount     50000
```

Efek:

```text
BCA -50.000
```

---

## Income

Income harus memiliki:

* `transaction_type = INCOME`
* Satu category bertipe `INCOME`
* Tepat satu `TRANSACTION_ENTRY`
* Entry harus bertipe `IN`

Contoh:

```text
TRANSACTION

type       INCOME
amount     10.500.000
category   SALARY

ENTRY

account    BCA
type       IN
amount     10.500.000
```

Efek:

```text
BCA +10.500.000
```

---

## Transfer

Transfer harus memiliki:

* `transaction_type = TRANSFER`
* `category_id = null`
* Tepat dua transaction entries
* Satu `OUT`
* Satu `IN`
* Source dan destination account berbeda
* Nominal kedua entry sama

Contoh:

```text
TRANSACTION

type       TRANSFER
amount     500000
category   null
```

```text
ENTRY 1

account    BCA
type       OUT
amount     500000
```

```text
ENTRY 2

account    GOPAY
type       IN
amount     500000
```

Efek:

```text
BCA      -500.000
GoPay    +500.000

Net Worth change = 0
```

Transfer tidak boleh masuk perhitungan income atau expense.

---

## Account Balance

`ACCOUNT` tidak menyimpan current balance sebagai source of truth.

Current balance dihitung dari:

```text
initial_balance
+ total IN entries
- total OUT entries
```

Contoh:

```text
Initial Balance       1.000.000
Salary              +10.500.000
Food                    -50.000
Transfer to GoPay       -500.000
────────────────────────────────
Current Balance       10.950.000
```

---

## Total Balance

Total balance user adalah jumlah balance seluruh account aktif yang relevan terhadap net worth.

Transfer antar-account tidak mengubah total balance.

```text
Before transfer

BCA       5.000.000
GoPay       100.000
───────────────────
Total     5.100.000


Transfer BCA -> GoPay 500.000


After transfer

BCA       4.500.000
GoPay       600.000
───────────────────
Total     5.100.000
```

---

## Category Rules

Income hanya boleh menggunakan category bertipe `INCOME`.

Expense hanya boleh menggunakan category bertipe `EXPENSE`.

Transfer tidak memiliki category.

Archived category:

* Tetap muncul pada historical transaction
* Tidak dapat dipilih untuk transaksi baru

Category yang sudah digunakan transaksi tidak dihapus secara permanen melalui UI, tetapi di-archive.

---

## Account Archive Rules

Account yang di-archive:

* Tetap menyimpan transaction history
* Tetap dapat ditampilkan pada historical transaction
* Tidak dapat dipilih untuk transaksi baru
* Tidak menghapus transaction entries sebelumnya

Account dengan historical transaction tidak dihapus secara permanen melalui UI.

---

# Core Relationship

```text
ACCOUNT
   │
   │ 1:N
   ▼
TRANSACTION_ENTRY
   ▲
   │ N:1
   │
TRANSACTION
   │
   │ N:1
   ▼
CATEGORY
```

Secara konseptual:

```text
EXPENSE

Food Rp50k
    │
    └── BCA OUT Rp50k


INCOME

Salary Rp10.5jt
    │
    └── BCA IN Rp10.5jt


TRANSFER

BCA -> GoPay Rp500k
    │
    ├── BCA   OUT Rp500k
    └── GoPay IN  Rp500k
```

# V1 Design Principle

Ketika ada pilihan antara menambah fleksibilitas dan menjaga pengalaman penggunaan tetap sederhana, Montra V1 memprioritaskan kesederhanaan.

Data model boleh menyediakan fondasi untuk berkembang, tetapi fitur tersebut tidak harus langsung diekspos ke user.
