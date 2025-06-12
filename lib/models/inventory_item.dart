class InventoryItem {
  final int? id;
  final String name;
  final String category;
  final int quantity;
  final int? lowStockThreshold;

  InventoryItem({
    this.id,
    required this.name,
    required this.category,
    required this.quantity,
    this.lowStockThreshold,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'quantity': quantity,
      'lowStockThreshold': lowStockThreshold,
    };
  }

  factory InventoryItem.fromMap(Map<String, dynamic> map) {
    return InventoryItem(
      id: map['id'] as int?,
      name: map['name'] as String,
      category: map['category'] as String,
      quantity: map['quantity'] as int,
      lowStockThreshold: map['lowStockThreshold'] != null
          ? map['lowStockThreshold'] as int
          : null,
    );
  }

  InventoryItem copyWith({
    int? id,
    String? name,
    String? category,
    int? quantity,
    int? lowStockThreshold,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
    );
  }
}
