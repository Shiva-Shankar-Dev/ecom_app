import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:intl/intl.dart';
import 'package:ecom_app/models/order.dart';

class OrdersTab extends StatefulWidget {
  final List<Order> orders;
  final VoidCallback onRefresh;

  const OrdersTab({super.key, required this.orders, required this.onRefresh});

  @override
  State<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<OrdersTab> {
  // Track local status selection per orderId
  final Map<String, String> _statusSelections = {};
  // Track in-flight updates per orderId
  final Map<String, bool> _isUpdating = {};

  static const List<String> _statusOptions = [
    'confirmed',
    'packed',
    'shipped',
    'delivered',
  ];

  String _selectedStatusFor(Order order) {
    final current = _statusSelections[order.orderId] ?? order.status;
    return current.toLowerCase();
  }

  String _formatStatus(String status) {
    if (status.isEmpty) return 'Confirmed';
    return status[0].toUpperCase() + status.substring(1).toLowerCase();
  }

  Color _colorForStatus(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return Color(0xFF2196F3);
      case 'packed':
        return Color(0xFFFF9800);
      case 'shipped':
        return Color(0xFF9C27B0);
      case 'delivered':
        return Color(0xFF4CAF50);
      default:
        return Colors.grey;
    }
  }

  Future<void> _updateOrderStatus(Order order) async {
    final newStatus = _selectedStatusFor(order);

    setState(() {
      _isUpdating[order.orderId] = true;
    });

    try {
      final docRef = FirebaseFirestore.instance
          .collection('user_orders')
          .doc(order.orderId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) {
          throw Exception('Order not found');
        }

        final data = snapshot.data() as Map<String, dynamic>;
        final itemsRaw = data['items'];

        List<Map<String, dynamic>> updatedItems = [];
        if (itemsRaw is List) {
          for (final item in itemsRaw) {
            if (item is Map<String, dynamic>) {
              final sellerId = item['sellerId']?.toString() ?? '';
              if (sellerId == order.sellerId) {
                updatedItems.add({...item, 'status': newStatus});
              } else {
                updatedItems.add(item);
              }
            }
          }
        }

        transaction.update(docRef, {
          'status': newStatus,
          'lastUpdated': FieldValue.serverTimestamp(),
          'items': updatedItems.isNotEmpty ? updatedItems : itemsRaw,
        });
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Status updated to ${_formatStatus(newStatus)}'),
            duration: Duration(seconds: 2),
            backgroundColor: _colorForStatus(newStatus),
          ),
        );
      }

      widget.onRefresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Update failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating[order.orderId] = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Orders',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[100],
              ),
              child: IconButton(
                icon: Icon(Icons.refresh),
                onPressed: () {
                  widget.onRefresh();
                },
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        if (widget.orders.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.shopping_bag_outlined,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  SizedBox(height: 20),
                  Text(
                    'No Orders Yet',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Orders will appear here once customers purchase your products.',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      widget.onRefresh();
                    },
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                    ),
                    child: Text("Refresh Orders"),
                  ),
                ],
              ),
            ),
          )
        else
          _buildOrdersList(),
      ],
    );
  }

  Widget _buildOrdersList() {
    if (widget.orders.isEmpty) return SizedBox.shrink();

    Map<String, List<Order>> ordersByDate = {};
    for (Order order in widget.orders) {
      String dateKey = DateFormat('yyyy-MM-dd').format(order.orderDate);
      ordersByDate[dateKey] ??= [];
      ordersByDate[dateKey]!.add(order);
    }

    List<String> sortedDates = ordersByDate.keys.toList();
    sortedDates.sort((a, b) => b.compareTo(a));

    return Expanded(
      child: ListView.builder(
        padding: EdgeInsets.only(bottom: 16),
        itemCount: sortedDates.length,
        itemBuilder: (context, index) {
          String dateKey = sortedDates[index];
          List<Order> dayOrders = ordersByDate[dateKey]!;
          DateTime date = DateTime.parse(dateKey);
          String formattedDate = DateFormat('EEEE, MMM dd, yyyy').format(date);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                child: Text(
                  formattedDate,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              ...dayOrders.map((order) => _buildOrderCard(order)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOrderCard(Order order) {
    final displayStatus = _selectedStatusFor(order);
    final statusColor = _colorForStatus(displayStatus);
    final isUpdating = _isUpdating[order.orderId] == true;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row - Product Image, Details, Status
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      order.productImage,
                      width: 90,
                      height: 90,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.image, size: 40, color: Colors.grey),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  // Product Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.productName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[900],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'ID: ${order.orderId.substring(0, order.orderId.length > 8 ? 8 : order.orderId.length)}...',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withAlpha(25),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: statusColor, width: 1.5),
                          ),
                          child: Text(
                            _formatStatus(displayStatus).toUpperCase(),
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              // Quick Info Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildQuickInfo('Qty', '${order.quantity}'),
                  _buildQuickInfo(
                    'Amount',
                    '\$${order.totalAmount.toStringAsFixed(2)}',
                  ),
                  _buildQuickInfo(
                    'Date',
                    DateFormat('MMM dd').format(order.orderDate),
                  ),
                ],
              ),
              SizedBox(height: 16),
              Divider(height: 1, color: Colors.grey[200]),
              SizedBox(height: 16),
              // Customer Info
              Row(
                children: [
                  Icon(Icons.person_outline, size: 16, color: Colors.grey[600]),
                  SizedBox(width: 8),
                  Text(
                    order.buyerName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
              // Variant Info if available
              if (order.variantName.trim().isNotEmpty) ...[
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Variant: ${order.variantName}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[900],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (order.variantAttributes.isNotEmpty) ...[
                        SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: order.variantAttributes.entries
                              .map(
                                (attr) => Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[100],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${attr.key}: ${attr.value}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.blue[900],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              // Status Update Section
              SizedBox(height: 14),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Update Status',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: displayStatus,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                            items: _statusOptions
                                .map(
                                  (status) => DropdownMenuItem(
                                    value: status,
                                    child: Text(_formatStatus(status)),
                                  ),
                                )
                                .toList(),
                            onChanged: isUpdating
                                ? null
                                : (value) {
                                    if (value == null) return;
                                    setState(() {
                                      _statusSelections[order.orderId] = value;
                                    });
                                  },
                          ),
                        ),
                        SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: isUpdating
                              ? null
                              : () => _updateOrderStatus(order),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: statusColor,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: isUpdating
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : Text(
                                  'Update',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Last Updated
              if (order.lastUpdated != null) ...[
                SizedBox(height: 10),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.schedule, size: 13, color: Colors.grey[600]),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Updated: ${DateFormat('MMM dd, hh:mm a').format(order.lastUpdated!)}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.grey[900],
          ),
        ),
      ],
    );
  }
}
