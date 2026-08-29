import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

enum AccountType { cash, bank, eWallet, creditCard, other }

enum CategoryType { income, expense }

enum TransactionType { income, expense, transfer }

enum EntryType { incoming, outgoing }

@TableIndex(name: 'accounts_archived_idx', columns: {#isArchived})
class Accounts extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get accountType => textEnum<AccountType>()();
  TextColumn get currency => text().withDefault(const Constant('IDR'))();
  IntColumn get initialBalance => integer()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
        'CHECK (length(trim(name)) > 0)',
        'CHECK (length(currency) = 3 AND currency = upper(currency))',
      ];
}

@TableIndex(name: 'categories_parent_idx', columns: {#parentId})
@TableIndex(name: 'categories_type_archived_idx', columns: {#categoryType, #isArchived})
class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get parentId => text().nullable().references(
        Categories,
        #id,
        onDelete: KeyAction.restrict,
      )();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get categoryType => textEnum<CategoryType>()();
  TextColumn get icon => text().nullable()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
        'CHECK (length(trim(name)) > 0)',
        'CHECK (parent_id IS NULL OR parent_id <> id)',
      ];
}

@TableIndex(name: 'transactions_date_idx', columns: {#transactionDate})
@TableIndex(name: 'transactions_category_idx', columns: {#categoryId})
@TableIndex(name: 'transactions_type_date_idx', columns: {#transactionType, #transactionDate})
class Transactions extends Table {
  TextColumn get id => text()();
  TextColumn get transactionType => textEnum<TransactionType>()();
  TextColumn get categoryId => text().nullable().references(
        Categories,
        #id,
        onDelete: KeyAction.restrict,
      )();
  IntColumn get amount => integer()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get transactionDate => dateTime()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
        'CHECK (amount > 0)',
        "CHECK ((transaction_type = 'transfer' AND category_id IS NULL) OR "
            "(transaction_type IN ('income', 'expense') AND category_id IS NOT NULL))",
      ];
}

@TableIndex(name: 'entries_transaction_idx', columns: {#transactionId})
@TableIndex(name: 'entries_account_idx', columns: {#accountId})
class TransactionEntries extends Table {
  TextColumn get id => text()();
  TextColumn get transactionId => text().references(
        Transactions,
        #id,
        onDelete: KeyAction.cascade,
      )();
  TextColumn get accountId => text().references(
        Accounts,
        #id,
        onDelete: KeyAction.restrict,
      )();
  TextColumn get entryType => textEnum<EntryType>()();
  IntColumn get amount => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
        {transactionId, accountId},
      ];

  @override
  List<String> get customConstraints => ['CHECK (amount > 0)'];
}

@DriftDatabase(tables: [Accounts, Categories, Transactions, TransactionEntries])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  /// Current balance is derived; it is never persisted as source of truth.
  Future<int> accountBalance(String accountId) async {
    final result = await customSelect(
      '''
      SELECT a.initial_balance + COALESCE(SUM(
        CASE te.entry_type
          WHEN 'incoming' THEN te.amount
          WHEN 'outgoing' THEN -te.amount
        END
      ), 0) AS balance
      FROM accounts a
      LEFT JOIN transaction_entries te ON te.account_id = a.id
      WHERE a.id = ?
      GROUP BY a.id, a.initial_balance
      ''',
      variables: [Variable.withString(accountId)],
      readsFrom: {accounts, transactionEntries},
    ).getSingleOrNull();

    return result?.read<int>('balance') ?? 0;
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (migrator) async {
          await migrator.createAll();
          await customStatement('PRAGMA foreign_keys = ON');
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File(p.join(directory.path, 'montra.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
