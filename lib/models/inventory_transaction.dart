class InventoryTransaction {
  final int? id;
  final int itemId;
  final DateTime dateTime;
  final int changeAmount;
  final String? note;

  InventoryTransaction({
    this.id,
    required this.itemId,
    required this.dateTime,
    required this.changeAmount,
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'itemId': itemId,
      'dateTime': dateTime.toIso8601String(),
      'changeAmount': changeAmount,
      'note': note,
    };
  }

  factory InventoryTransaction.fromMap(Map<String, dynamic> map) {
    return InventoryTransaction(
      id: map['id'] as int?,
      itemId: map['itemId'] as int,
      dateTime: DateTime.parse(map['dateTime'] as String),
      changeAmount: map['changeAmount'] as int,
      note: map['note'] as String?,
    );
  }
}
