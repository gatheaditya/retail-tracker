class Order {
  final String? id;
  final String clientId;
  final DateTime orderDate;
  final double totalAmount;
  final String status;

  Order({
    this.id,
    required this.clientId,
    DateTime? orderDate,
    this.totalAmount = 0.0,
    this.status = 'PENDING',
  }) : orderDate = orderDate ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'clientId': clientId,
      'orderDate': orderDate.toIso8601String(),
      'totalAmount': totalAmount,
      'status': status,
    };
  }

  factory Order.fromMap(Map<String, dynamic> map) {
    return Order(
      id: map['id'] as String?,
      clientId: map['clientId'] as String,
      orderDate: DateTime.parse(map['orderDate'] as String),
      totalAmount: map['totalAmount'] as double,
      status: map['status'] as String,
    );
  }
}
