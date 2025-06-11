class InventoryItem {
  final int? id;
  final String name;
  final String category;
  final int quantity;

  InventoryItem({
    this.id,
    required this.name,
    required this.category,
    required this.quantity,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'quantity': quantity,
    };
  }

  factory InventoryItem.fromMap(Map<String, dynamic> map) {
    return InventoryItem(
      id: map['id'],
      name: map['name'],
      category: map['category'],
      quantity: map['quantity'],
    );
  }
}
