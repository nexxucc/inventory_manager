// lib/helpers/database_helper.dart

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/inventory_item.dart';
import '../models/inventory_transaction.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'inventory.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: (database, version) async {
        await database.execute('''
          CREATE TABLE items(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            category TEXT NOT NULL,
            quantity INTEGER NOT NULL,
            lowStockThreshold INTEGER
          )
        ''');
        await database.execute('''
          CREATE TABLE transactions(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            itemId INTEGER NOT NULL,
            dateTime TEXT NOT NULL,
            changeAmount INTEGER NOT NULL,
            note TEXT,
            FOREIGN KEY(itemId) REFERENCES items(id) ON DELETE CASCADE
          )
        ''');
      },
      onUpgrade: (database, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Add lowStockThreshold column
          try {
            await database.execute('ALTER TABLE items ADD COLUMN lowStockThreshold INTEGER;');
          } catch (_) {}
          // Create transactions table if not exists
          await database.execute('''
            CREATE TABLE IF NOT EXISTS transactions(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              itemId INTEGER NOT NULL,
              dateTime TEXT NOT NULL,
              changeAmount INTEGER NOT NULL,
              note TEXT,
              FOREIGN KEY(itemId) REFERENCES items(id) ON DELETE CASCADE
            )
          ''');
        }
      },
    );
  }

  // ---------- Item CRUD ----------

  Future<int> insertItem(InventoryItem item) async {
    final database = await db;
    return await database.insert('items', item.toMap());
  }

  Future<List<InventoryItem>> getItems({
    String? searchQuery,
    String? categoryFilter,
    String sortBy = 'name',
    bool ascending = true,
  }) async {
    final database = await db;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (searchQuery != null && searchQuery.isNotEmpty) {
      whereClauses.add('name LIKE ?');
      whereArgs.add('%$searchQuery%');
    }
    if (categoryFilter != null && categoryFilter.isNotEmpty && categoryFilter != 'All') {
      whereClauses.add('category = ?');
      whereArgs.add(categoryFilter);
    }
    String whereString = whereClauses.isNotEmpty ? whereClauses.join(' AND ') : '';

    String orderByClause;
    switch (sortBy) {
      case 'quantity':
        orderByClause = 'quantity ${ascending ? 'ASC' : 'DESC'}';
        break;
      case 'category':
        orderByClause = 'category ${ascending ? 'ASC' : 'DESC'}';
        break;
      case 'lowStock':
        // Items with quantity ≤ threshold first
        orderByClause =
            '(quantity - IFNULL(lowStockThreshold, -999999)) ASC, name ASC';
        break;
      case 'name':
      default:
        orderByClause = 'name ${ascending ? 'ASC' : 'DESC'}';
    }

    final maps = await database.query(
      'items',
      where: whereString.isNotEmpty ? whereString : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: orderByClause,
    );
    return List.generate(maps.length, (i) => InventoryItem.fromMap(maps[i]));
  }

  Future<int> updateItem(InventoryItem item) async {
    final database = await db;
    return await database.update(
      'items',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<int> deleteItem(int id) async {
    final database = await db;
    return await database.delete(
      'items',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<String>> getAllCategories() async {
    final database = await db;
    final result = await database.rawQuery('SELECT DISTINCT category FROM items ORDER BY category ASC');
    return result.map((row) => row['category'] as String).toList();
  }

  // ---------- Transaction CRUD ----------

  Future<int> insertTransaction(InventoryTransaction txn) async {
    final database = await db;
    return await database.transaction((txnDb) async {
      final id = await txnDb.insert('transactions', txn.toMap());
      // Update item quantity
      final itemMapList = await txnDb.query(
        'items',
        columns: ['quantity'],
        where: 'id = ?',
        whereArgs: [txn.itemId],
      );
      if (itemMapList.isNotEmpty) {
        final currentQty = itemMapList.first['quantity'] as int;
        final newQty = currentQty + txn.changeAmount;
        await txnDb.update(
          'items',
          {'quantity': newQty},
          where: 'id = ?',
          whereArgs: [txn.itemId],
        );
      }
      return id;
    });
  }

  Future<List<InventoryTransaction>> getTransactionsForItem(int itemId) async {
    final database = await db;
    final maps = await database.query(
      'transactions',
      where: 'itemId = ?',
      whereArgs: [itemId],
      orderBy: 'dateTime DESC',
    );
    return List.generate(maps.length, (i) => InventoryTransaction.fromMap(maps[i]));
  }

  Future<int> deleteTransaction(int txnId) async {
    final database = await db;
    return await database.transaction((txnDb) async {
      final maps = await txnDb.query(
        'transactions',
        where: 'id = ?',
        whereArgs: [txnId],
      );
      if (maps.isEmpty) return 0;
      final txn = InventoryTransaction.fromMap(maps.first);
      final itemMaps = await txnDb.query(
        'items',
        columns: ['quantity'],
        where: 'id = ?',
        whereArgs: [txn.itemId],
      );
      if (itemMaps.isNotEmpty) {
        final currentQty = itemMaps.first['quantity'] as int;
        final newQty = currentQty - txn.changeAmount;
        await txnDb.update(
          'items',
          {'quantity': newQty},
          where: 'id = ?',
          whereArgs: [txn.itemId],
        );
      }
      return await txnDb.delete(
        'transactions',
        where: 'id = ?',
        whereArgs: [txnId],
      );
    });
  }

  Future<int> updateTransaction(InventoryTransaction txn) async {
    final database = await db;
    return await database.transaction((txnDb) async {
      final maps = await txnDb.query(
        'transactions',
        where: 'id = ?',
        whereArgs: [txn.id],
      );
      if (maps.isEmpty) return 0;
      final oldTxn = InventoryTransaction.fromMap(maps.first);
      final itemMaps = await txnDb.query(
        'items',
        columns: ['quantity'],
        where: 'id = ?',
        whereArgs: [oldTxn.itemId],
      );
      if (itemMaps.isNotEmpty) {
        int qty = itemMaps.first['quantity'] as int;
        qty -= oldTxn.changeAmount;
        qty += txn.changeAmount;
        await txnDb.update(
          'items',
          {'quantity': qty},
          where: 'id = ?',
          whereArgs: [oldTxn.itemId],
        );
      }
      return await txnDb.update(
        'transactions',
        txn.toMap(),
        where: 'id = ?',
        whereArgs: [txn.id],
      );
    });
  }

  Future<String> getDatabasePath() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'inventory.db');
    return path;
  }
}
