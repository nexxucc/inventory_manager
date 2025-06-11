import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/inventory_item.dart';

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
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE items(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            category TEXT NOT NULL,
            quantity INTEGER NOT NULL
          )
        ''');
      },
    );
  }

  Future<int> insertItem(InventoryItem item) async {
    final database = await db;
    return await database.insert('items', item.toMap());
  }

  Future<List<InventoryItem>> getItems() async {
    final database = await db;
    final maps = await database.query('items', orderBy: 'name');
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
}
