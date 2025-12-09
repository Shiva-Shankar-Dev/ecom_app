import 'package:cloud_firestore/cloud_firestore.dart';

class Order {
  final String orderId;
  final String sellerId;
  final String buyerId;
  final String productId;
  final String productName;
  final String productImage;
  final double price;
  final int quantity;
  final double totalAmount;
  final String
  status; // 'pending', 'confirmed', 'shipped', 'delivered', 'cancelled'
  final DateTime orderDate;
  final String buyerName;
  final String buyerEmail;
  final String buyerPhone;
  final String shippingAddress;

  Order({
    required this.orderId,
    required this.sellerId,
    required this.buyerId,
    required this.productId,
    required this.productName,
    required this.productImage,
    required this.price,
    required this.quantity,
    required this.totalAmount,
    required this.status,
    required this.orderDate,
    required this.buyerName,
    required this.buyerEmail,
    required this.buyerPhone,
    required this.shippingAddress,
  });

  factory Order.fromFirestore(Map<String, dynamic> data) {
    return Order(
      orderId: data['orderId'] ?? '',
      sellerId: data['sellerId'] ?? '',
      buyerId: data['buyerId'] ?? '',
      productId: data['productId'] ?? '',
      productName: data['productName'] ?? '',
      productImage: data['productImage'] ?? '',
      price: (data['price'] is num) ? (data['price'] as num).toDouble() : 0.0,
      quantity: data['quantity'] ?? 1,
      totalAmount: (data['totalAmount'] is num)
          ? (data['totalAmount'] as num).toDouble()
          : 0.0,
      status: data['status'] ?? 'pending',
      orderDate: data['orderDate'] != null
          ? (data['orderDate'] as Timestamp).toDate()
          : DateTime.now(),
      buyerName: data['buyerName'] ?? '',
      buyerEmail: data['buyerEmail'] ?? '',
      buyerPhone: data['buyerPhone'] ?? '',
      shippingAddress: data['shippingAddress'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'orderId': orderId,
      'sellerId': sellerId,
      'buyerId': buyerId,
      'productId': productId,
      'productName': productName,
      'productImage': productImage,
      'price': price,
      'quantity': quantity,
      'totalAmount': totalAmount,
      'status': status,
      'orderDate': Timestamp.fromDate(orderDate),
      'buyerName': buyerName,
      'buyerEmail': buyerEmail,
      'buyerPhone': buyerPhone,
      'shippingAddress': shippingAddress,
    };
  }
}
