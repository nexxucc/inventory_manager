import 'package:flutter/material.dart';
import 'models/inventory_item.dart';
import 'helpers/database_helper.dart';

void main() => runApp(const InventoryApp());

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

  @override
  void initState() {
    super.initState();
    _refreshItems();
  }

  void _refreshItems() {
    setState(() {
      _itemsFuture = dbHelper.getItems();
    });
  }

  void _openForm({InventoryItem? item}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ItemFormPage(item: item),
      ),
    );
    _refreshItems();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inventory Items')),
      body: FutureBuilder<List<InventoryItem>>(
        future: _itemsFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final items = snapshot.data!;
          if (items.isEmpty) return const Center(child: Text('No items. Tap + to add.'));
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (ctx, i) {
              final it = items[i];
              return ListTile(
                title: Text(it.name),
                subtitle: Text('${it.category} • Qty: ${it.quantity}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _openForm(item: it),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () {
                        dbHelper.deleteItem(it.id!).then((_) => _refreshItems());
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

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
  final _qtyCtrl = TextEditingController();

  final dbHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    if (widget.item != null) {
      _nameCtrl.text = widget.item!.name;
      _categoryCtrl.text = widget.item!.category;
      _qtyCtrl.text = widget.item!.quantity.toString();
    }
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      final newItem = InventoryItem(
        id: widget.item?.id,
        name: _nameCtrl.text,
        category: _categoryCtrl.text,
        quantity: int.parse(_qtyCtrl.text),
      );
      final future = widget.item == null
        ? dbHelper.insertItem(newItem)
        : dbHelper.updateItem(newItem);
      future.then((_) => Navigator.of(context).pop());
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
          child: Column(
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Item Name'),
                validator: (v) => v!.isEmpty ? 'Enter name' : null,
              ),
              TextFormField(
                controller: _categoryCtrl,
                decoration: const InputDecoration(labelText: 'Category'),
                validator: (v) => v!.isEmpty ? 'Enter category' : null,
              ),
              TextFormField(
                controller: _qtyCtrl,
                decoration: const InputDecoration(labelText: 'Quantity'),
                keyboardType: TextInputType.number,
                validator: (v) => (v == null || int.tryParse(v) == null)
                  ? 'Enter a valid number'
                  : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _save,
                child: Text(isEdit ? 'Update' : 'Add'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
