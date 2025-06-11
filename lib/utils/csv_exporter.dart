// lib/utils/csv_exporter.dart

import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import '../models/inventory_item.dart';
import '../models/inventory_transaction.dart';

class CsvExporter {
  // Export items list to CSV. Returns file path.
  static Future<String> exportItemsToCsv(List<InventoryItem> items) async {
    // Prepare rows: header + data
    final rows = <List<dynamic>>[];
    rows.add(['ID', 'Name', 'Category', 'Quantity', 'LowStockThreshold']);
    for (var item in items) {
      rows.add([
        item.id,
        item.name,
        item.category,
        item.quantity,
        item.lowStockThreshold ?? '',
      ]);
    }
    String csvData = const ListToCsvConverter().convert(rows);

    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/inventory_export_${DateTime.now().millisecondsSinceEpoch}.csv';
    final file = File(path);
    await file.writeAsString(csvData);
    return path;
  }

  // Export transactions for a specific item to CSV. Returns file path.
  static Future<String> exportTransactionsToCsv(List<InventoryTransaction> txns) async {
    final rows = <List<dynamic>>[];
    rows.add(['ID', 'ItemID', 'DateTime', 'ChangeAmount', 'Note']);
    for (var txn in txns) {
      rows.add([
        txn.id,
        txn.itemId,
        txn.dateTime.toIso8601String(),
        txn.changeAmount,
        txn.note ?? '',
      ]);
    }
    String csvData = const ListToCsvConverter().convert(rows);

    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/transactions_export_${DateTime.now().millisecondsSinceEpoch}.csv';
    final file = File(path);
    await file.writeAsString(csvData);
    return path;
  }
}
