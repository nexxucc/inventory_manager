// lib/main.dart

import 'package:flutter/material.dart';
import 'models/inventory_item.dart';
import 'models/inventory_transaction.dart';
import 'helpers/database_helper.dart';
import 'helpers/notification_helper.dart';
import 'utils/csv_exporter.dart';
import 'package:intl/intl.dart';

// Entry point
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize notifications
  await NotificationHelper.initialize();
  await NotificationHelper.createNotificationChannel();

  runApp(const InventoryApp());
}

class InventoryApp extends StatelessWidget {
  const InventoryApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Inventory Manager',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const ItemListPage(),
    );
  }
}

class ItemListPage extends StatefulWidget {
  const ItemListPage({super.key});
  @override
  State<ItemListPage> createState() => _ItemListPageState();
}

class _ItemListPageState extends State<ItemListPage> {
  final dbHelper = DatabaseHelper();
  late Future<List<InventoryItem>> _itemsFuture;

  // Search & filter state
  String _searchQuery = '';
  String _categoryFilter = 'All';
  List<String> _allCategories = [];
  // Sort state
  String _sortBy = 'name'; // 'name', 'quantity', 'category', 'lowStock'
  bool _ascending = true;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refreshCategories();
    _refreshItems();
    // Optionally: on startup, notify existing low-stock items once.
    // If desired, implement a method to check all items and call NotificationHelper.showLowStockNotificationIfNeeded(item)
    // but careful to avoid spamming user every app launch.
  }

  Future<void> _refreshCategories() async {
    final categories = await dbHelper.getAllCategories();
    setState(() {
      _allCategories = ['All'] + categories;
      if (!_allCategories.contains(_categoryFilter)) {
        _categoryFilter = 'All';
      }
    });
  }

  void _refreshItems() {
    setState(() {
      _itemsFuture = dbHelper.getItems(
        searchQuery: _searchQuery,
        categoryFilter: _categoryFilter,
        sortBy: _sortBy,
        ascending: _ascending,
      );
    });
  }

  Future<void> _onRefresh() async {
    await _refreshCategories();
    _refreshItems();
  }

  void _openAddItem() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ItemFormPage()),
    );
    await _onRefresh();
  }

  void _onSearchChanged(String val) {
    _searchQuery = val;
    _refreshItems();
  }

  void _onCategorySelected(String? category) {
    if (category == null) return;
    _categoryFilter = category;
    _refreshItems();
  }

  void _onSortSelected(String sortBy) {
    if (_sortBy == sortBy) {
      _ascending = !_ascending;
    } else {
      _sortBy = sortBy;
      _ascending = true;
    }
    _refreshItems();
  }

  Widget _buildSortMenu() {
    return PopupMenuButton<String>(
      onSelected: _onSortSelected,
      itemBuilder: (context) => <PopupMenuEntry<String>>[
        CheckedPopupMenuItem(
          value: 'name',
          checked: _sortBy == 'name',
          child: const Text('Sort by Name'),
        ),
        CheckedPopupMenuItem(
          value: 'quantity',
          checked: _sortBy == 'quantity',
          child: const Text('Sort by Quantity'),
        ),
        CheckedPopupMenuItem(
          value: 'category',
          checked: _sortBy == 'category',
          child: const Text('Sort by Category'),
        ),
        CheckedPopupMenuItem(
          value: 'lowStock',
          checked: _sortBy == 'lowStock',
          child: const Text('Low-Stock First'),
        ),
      ],
      icon: const Icon(Icons.sort),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Items'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4),
            child: Row(
              children: [
                // Search field
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by name...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onChanged: _onSearchChanged,
                  ),
                ),
                const SizedBox(width: 8),
                _buildSortMenu(),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Category filter dropdown and export inventory
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4),
            child: Row(
              children: [
                const Text('Category:'),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _categoryFilter,
                  items: _allCategories
                      .map((cat) => DropdownMenuItem(
                            value: cat,
                            child: Text(cat),
                          ))
                      .toList(),
                  onChanged: _onCategorySelected,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                  onPressed: _onRefresh,
                ),
                IconButton(
                  icon: const Icon(Icons.file_upload),
                  tooltip: 'Export Inventory to CSV',
                  onPressed: () async {
                    final items = await dbHelper.getItems();
                    final path = await CsvExporter.exportItemsToCsv(items);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Exported items to $path')),
                    );
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<InventoryItem>>(
              future: _itemsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final items = snapshot.data!;
                if (items.isEmpty) {
                  return const Center(child: Text('No items. Tap + to add.'));
                }
                return RefreshIndicator(
                  onRefresh: _onRefresh,
                  child: ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (ctx, i) {
                      final it = items[i];
                      final lowThreshold = it.lowStockThreshold;
                      final isLow = (lowThreshold != null && it.quantity <= lowThreshold);
                      return Dismissible(
                        key: ValueKey(it.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        confirmDismiss: (direction) async {
                          return await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Confirm Delete'),
                              content: Text('Delete item "${it.name}"? This cannot be undone.'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(true),
                                  child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );
                        },
                        onDismissed: (direction) async {
                          if (it.id != null) {
                            await dbHelper.deleteItem(it.id!);
                            _refreshCategories();
                            _refreshItems();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Deleted "${it.name}"')),
                            );
                          }
                        },
                        child: ListTile(
                          tileColor: isLow ? Colors.red.shade50 : null,
                          title: Text(it.name),
                          subtitle: Text('${it.category} • Qty: ${it.quantity}'
                              '${lowThreshold != null ? ' (Low≤$lowThreshold)' : ''}'),
                          onTap: () {
                            if (it.id != null) {
                              Navigator.of(context)
                                  .push(MaterialPageRoute(builder: (_) => ItemDetailPage(item: it)))
                                  .then((_) => _onRefresh());
                            }
                          },
                          trailing: IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () {
                              if (it.id != null) {
                                Navigator.of(context)
                                    .push(MaterialPageRoute(builder: (_) => ItemFormPage(item: it)))
                                    .then((_) => _onRefresh());
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddItem,
        child: const Icon(Icons.add),
      ),
    );
  }
}

// ItemFormPage: Add/Edit item. On insert/update, check low-stock and notify.
class ItemFormPage extends StatefulWidget {
  final InventoryItem? item;
  const ItemFormPage({super.key, this.item});

  @override
  State<ItemFormPage> createState() => _ItemFormPageState();
}

class _ItemFormPageState extends State<ItemFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _thresholdCtrl = TextEditingController();
  final _initQtyCtrl = TextEditingController();

  final dbHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      _nameCtrl.text = widget.item!.name;
      _categoryCtrl.text = widget.item!.category;
      _thresholdCtrl.text = widget.item!.lowStockThreshold?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _categoryCtrl.dispose();
    _thresholdCtrl.dispose();
    _initQtyCtrl.dispose();
    super.dispose();
  }

  void _save() async {
    if (_formKey.currentState!.validate()) {
      final name = _nameCtrl.text.trim();
      final category = _categoryCtrl.text.trim();
      final thresholdText = _thresholdCtrl.text.trim();
      final threshold = thresholdText.isNotEmpty ? int.parse(thresholdText) : null;

      if (widget.item == null) {
        // Create new item: require initial quantity
        final qtyText = _initQtyCtrl.text.trim();
        final qty = int.tryParse(qtyText) ?? 0;
        final newItem = InventoryItem(
          name: name,
          category: category,
          quantity: qty,
          lowStockThreshold: threshold,
        );
        final newId = await dbHelper.insertItem(newItem);
        // Fetch saved item
        final savedList = await dbHelper.getItems();
        final savedItem = savedList.firstWhere((it) => it.id == newId);
        // Notify if low-stock
        if (savedItem.lowStockThreshold != null) {
          // prevQty unknown; pass null so helper notifies if needed
          await NotificationHelper.showLowStockNotificationIfNeeded(savedItem, prevQty: null);
        }
      } else {
        // Edit existing: note previous quantity
        final prevQty = widget.item!.quantity;
        final updatedItem = widget.item!.copyWith(
          name: name,
          category: category,
          lowStockThreshold: threshold,
        );
        await dbHelper.updateItem(updatedItem);
        // Fetch fresh
        final freshList = await dbHelper.getItems();
        final freshItem = freshList.firstWhere((it) => it.id == updatedItem.id);
        // Notify if crossing threshold due to threshold change or existing quantity
        await NotificationHelper.showLowStockNotificationIfNeeded(freshItem, prevQty: prevQty);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.item != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit Item' : 'Add New Item')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Item Name'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Enter name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _categoryCtrl,
                decoration: const InputDecoration(labelText: 'Category'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Enter category' : null,
              ),
              const SizedBox(height: 12),
              if (!isEdit) ...[
                TextFormField(
                  controller: _initQtyCtrl,
                  decoration: const InputDecoration(labelText: 'Initial Quantity'),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Enter quantity';
                    if (int.tryParse(v.trim()) == null) return 'Enter a valid number';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
              ] else ...[
                TextFormField(
                  initialValue: widget.item!.quantity.toString(),
                  decoration: const InputDecoration(
                    labelText: 'Current Quantity',
                  ),
                  readOnly: true,
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _thresholdCtrl,
                decoration: const InputDecoration(labelText: 'Low Stock Threshold (optional)'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final parsed = int.tryParse(v.trim());
                  if (parsed == null) return 'Enter a valid number';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _save,
                child: Text(isEdit ? 'Update Item' : 'Add Item'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ItemDetailPage: show details and transaction history, and handle notifications on transaction insert/delete.
class ItemDetailPage extends StatefulWidget {
  final InventoryItem item;
  const ItemDetailPage({super.key, required this.item});

  @override
  State<ItemDetailPage> createState() => _ItemDetailPageState();
}

class _ItemDetailPageState extends State<ItemDetailPage> {
  final dbHelper = DatabaseHelper();
  late InventoryItem _item; // refreshed locally
  late Future<List<InventoryTransaction>> _txnsFuture;
  final DateFormat _dateFormat = DateFormat.yMd().add_jm();

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _refreshData();
  }

  Future<void> _refreshData() async {
    if (_item.id != null) {
      final items = await dbHelper.getItems();
      final fresh = items.firstWhere((it) => it.id == _item.id, orElse: () => _item);
      setState(() {
        _item = fresh;
        _txnsFuture = dbHelper.getTransactionsForItem(_item.id!);
      });
    }
  }

  void _openEditItem() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ItemFormPage(item: _item)),
    );
    await _refreshData();
  }

  void _addTransaction() async {
    if (_item.id == null) return;
    final prevQty = _item.quantity;
    final result = await showDialog<InventoryTransaction>(
      context: context,
      builder: (ctx) => AddTransactionDialog(item: _item),
    );
    if (result != null) {
      await dbHelper.insertTransaction(result);
      await _refreshData();
      // Notify if crossing threshold
      await NotificationHelper.showLowStockNotificationIfNeeded(_item, prevQty: prevQty);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction added')),
      );
    }
  }

  void _exportTransactions() async {
    if (_item.id == null) return;
    final txns = await dbHelper.getTransactionsForItem(_item.id!);
    final path = await CsvExporter.exportTransactionsToCsv(txns);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Exported transactions to $path')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lowThreshold = _item.lowStockThreshold;
    final isLow = (lowThreshold != null && _item.quantity <= lowThreshold);
    return Scaffold(
      appBar: AppBar(
        title: Text(_item.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _openEditItem,
            tooltip: 'Edit Item',
          ),
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: _exportTransactions,
            tooltip: 'Export Transactions',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Category: ${_item.category}', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              'Current Quantity: ${_item.quantity}'
              '${lowThreshold != null ? ' (Low≤$lowThreshold)' : ''}',
              style: TextStyle(
                fontSize: 16,
                color: isLow ? Colors.red : null,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _addTransaction,
              icon: const Icon(Icons.swap_horiz),
              label: const Text('Add Transaction'),
            ),
            const SizedBox(height: 16),
            const Text('Transactions:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: FutureBuilder<List<InventoryTransaction>>(
                future: _txnsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  final txns = snapshot.data!;
                  if (txns.isEmpty) {
                    return const Center(child: Text('No transactions yet.'));
                  }
                  return ListView.builder(
                    itemCount: txns.length,
                    itemBuilder: (ctx, i) {
                      final txn = txns[i];
                      final isPositive = txn.changeAmount >= 0;
                      return ListTile(
                        leading: Icon(
                          isPositive ? Icons.add_circle : Icons.remove_circle,
                          color: isPositive ? Colors.green : Colors.red,
                        ),
                        title: Text(
                          '${isPositive ? '+' : ''}${txn.changeAmount} on ${_dateFormat.format(txn.dateTime)}',
                          style: const TextStyle(fontSize: 14),
                        ),
                        subtitle: txn.note != null && txn.note!.isNotEmpty
                            ? Text(txn.note!)
                            : null,
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Delete Transaction'),
                                content: const Text(
                                    'Are you sure you want to delete this transaction? This will adjust quantity accordingly.'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(ctx).pop(false),
                                    child: const Text('Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.of(ctx).pop(true),
                                    child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true && txn.id != null) {
                              final prevQty = _item.quantity;
                              await dbHelper.deleteTransaction(txn.id!);
                              await _refreshData();
                              // After deletion, quantity may increase: reset alert flag if needed
                              await NotificationHelper.showLowStockNotificationIfNeeded(_item, prevQty: prevQty);
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Transaction deleted')),
                              );
                            }
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Dialog to add a transaction
class AddTransactionDialog extends StatefulWidget {
  final InventoryItem item;
  const AddTransactionDialog({super.key, required this.item});

  @override
  State<AddTransactionDialog> createState() => _AddTransactionDialogState();
}

class _AddTransactionDialogState extends State<AddTransactionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _changeCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _isPositive = true; // stock in vs out

  @override
  void dispose() {
    _changeCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final amtText = _changeCtrl.text.trim();
      final amt = int.tryParse(amtText) ?? 0;
      final changeAmt = _isPositive ? amt : -amt;
      final note = _noteCtrl.text.trim();
      final txn = InventoryTransaction(
        itemId: widget.item.id!,
        dateTime: DateTime.now(),
        changeAmount: changeAmt,
        note: note.isNotEmpty ? note : null,
      );
      Navigator.of(context).pop(txn);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Transaction'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text('Type:'),
                const SizedBox(width: 12),
                ChoiceChip(
                  label: const Text('In'),
                  selected: _isPositive,
                  onSelected: (sel) {
                    setState(() {
                      _isPositive = true;
                    });
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Out'),
                  selected: !_isPositive,
                  onSelected: (sel) {
                    setState(() {
                      _isPositive = false;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _changeCtrl,
              decoration: const InputDecoration(labelText: 'Quantity'),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Enter quantity';
                final parsed = int.tryParse(v.trim());
                if (parsed == null || parsed <= 0) return 'Enter a positive number';
                if (!_isPositive && widget.item.quantity < parsed) {
                  return 'Cannot remove more than current (${widget.item.quantity})';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _noteCtrl,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(onPressed: _submit, child: const Text('Add')),
      ],
    );
  }
}
