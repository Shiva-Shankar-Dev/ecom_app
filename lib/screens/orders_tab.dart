import 'package:flutter/material.dart';
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

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showRequestsOnly = false;

  int get _pendingRequestCount {
    return widget.orders
        .where(
          (o) =>
              o.status.toLowerCase() == 'request for return' ||
              o.status.toLowerCase() == 'request for replacement',
        )
        .length;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  static const List<String> _statusOptions = [
    'confirmed',
    'packed',
    'shipped',
    'delivered',
  ];

  String _selectedStatusFor(Order order) {
    final current = _statusSelections[order.orderId] ?? order.status;
    // Normalize standard statuses to lowercase to match _statusOptions
    if (_statusOptions.contains(current.toLowerCase())) {
      return current.toLowerCase();
    }
    return current;
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
      case 'request for return':
      case 'return approved':
      case 'return rejected':
        return Colors.red;
      case 'request for replacement':
      case 'replacement approved':
      case 'replacement rejected':
        return Colors.purple;
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
    // Only show "No Orders Yet" if there are truly no orders and no search is active.
    // However, the original logic showed it if list was empty.
    // If we want search to work, we need to let the list build but maybe show empty state inside list if filtered.
    // But if widget.orders is globally empty, we can keep the original empty state.
    if (widget.orders.isEmpty) {
      return CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: false,
            floating: true,
            expandedHeight: 120,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: EdgeInsets.all(8.0),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Orders',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
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
                ],
              ),
            ),
          ),
          SliverFillRemaining(
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
          ),
        ],
      );
    }

    return _buildModernOrdersList();
  }

  Widget _buildModernOrdersList() {
    List<Order> filteredOrders = widget.orders;

    // First, filter by Request Status if toggled
    if (_showRequestsOnly) {
      filteredOrders = filteredOrders
          .where(
            (o) =>
                o.status.toLowerCase() == 'request for return' ||
                o.status.toLowerCase() == 'request for replacement',
          )
          .toList();
    }

    if (_searchQuery.isNotEmpty) {
      filteredOrders = filteredOrders.where((order) {
        return order.orderId.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // Hide main empty check here because we want to allow search
    // But if filtered list is empty, we handle it below.

    Map<String, List<Order>> ordersByDate = {};
    for (Order order in filteredOrders) {
      String dateKey = DateFormat('yyyy-MM-dd').format(order.orderDate);
      ordersByDate[dateKey] ??= [];
      ordersByDate[dateKey]!.add(order);
    }

    List<String> sortedDates = ordersByDate.keys.toList();
    sortedDates.sort((a, b) => b.compareTo(a));

    // Create flat list of widgets: date headers + order cards
    List<Widget> sliverItems = [];

    if (filteredOrders.isEmpty) {
      sliverItems.add(
        Padding(
          padding: EdgeInsets.only(top: 50),
          child: Center(
            child: Text(
              _showRequestsOnly
                  ? "No orders with pending requests found"
                  : "No orders found matching '$_searchQuery'",
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ),
        ),
      );
    } else {
      for (String dateKey in sortedDates) {
        List<Order> dayOrders = ordersByDate[dateKey]!;
        DateTime date = DateTime.parse(dateKey);
        String formattedDate = DateFormat('EEEE, MMM dd, yyyy').format(date);

        sliverItems.add(_buildDateHeader(formattedDate));

        for (Order order in dayOrders) {
          sliverItems.add(_buildOrderCard(order));
        }
      }
    }

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: false,
          floating: true,
          toolbarHeight: 65,
          titleSpacing: 7,
          automaticallyImplyLeading: false,
          surfaceTintColor: Colors.transparent,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Orders',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[900],
                    ),
                  ),
                  Row(
                    children: [
                      // Notification Icon for Requests
                      Stack(
                        children: [
                          IconButton(
                            icon: Icon(
                              _showRequestsOnly
                                  ? Icons.notifications_active
                                  : Icons.notifications_none,
                              color: _showRequestsOnly
                                  ? Colors.blue
                                  : Colors.grey[700],
                            ),
                            onPressed: () {
                              setState(() {
                                _showRequestsOnly = !_showRequestsOnly;
                              });
                            },
                          ),
                          if (_pendingRequestCount > 0)
                            Positioned(
                              right: 8,
                              top: 8,
                              child: Container(
                                padding: EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                constraints: BoxConstraints(
                                  minWidth: 16,
                                  minHeight: 16,
                                ),
                                child: Text(
                                  '$_pendingRequestCount',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey[100],
                        ),
                        child: IconButton(
                          icon: Icon(Icons.refresh, color: Colors.grey[700]),
                          onPressed: () {
                            widget.onRefresh();
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Text(
                '${filteredOrders.length} order${filteredOrders.length != 1 ? 's' : ''}',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search Order ID...",
                prefixIcon: Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 0,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => sliverItems[index],
            childCount: sliverItems.length,
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.only(bottom: 20),
          sliver: SliverToBoxAdapter(child: SizedBox.shrink()),
        ),
      ],
    );
  }

  Widget _buildDateHeader(String formattedDate) {
    return Padding(
      padding: EdgeInsets.fromLTRB(5, 20, 16, 12),
      child: Row(
        spacing: 20,
        children: [
          Expanded(child: Divider()),
          Text(
            formattedDate,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.grey[700],
              letterSpacing: 0.3,
            ),
          ),
          Expanded(child: Divider()),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Order order) {
    final displayStatus = _selectedStatusFor(order);
    final statusColor = _colorForStatus(displayStatus);
    final isUpdating = _isUpdating[order.orderId] == true;
    final isDelivered = order.status.toLowerCase() == 'delivered';

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withAlpha(3),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 15.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row - Product Image, Details, Status
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Image with Border
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!, width: 1),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: Image.network(
                        order.productImage,
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Icon(
                            Icons.image,
                            size: 40,
                            color: Colors.grey,
                          ),
                        ),
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
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[900],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 2),
                        Text(
                          'ID: ${order.orderId}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                            fontFamily: 'monospace',
                          ),
                        ),
                        SizedBox(height: 15),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withAlpha(20),
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
                        SizedBox(height: 10),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              // Quick Info Row
              Container(
                margin: EdgeInsets.symmetric(horizontal: 5),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildQuickInfo('Qty', '${order.quantity}'),
                    Container(height: 30, width: 1, color: Colors.grey[300]),
                    _buildQuickInfo(
                      'Amount',
                      '\$${order.totalAmount.toStringAsFixed(2)}',
                    ),
                    Container(height: 30, width: 1, color: Colors.grey[300]),
                    _buildQuickInfo(
                      'Date',
                      DateFormat('MMM dd').format(order.orderDate),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              // Customer Info
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 10.0),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.person_outline,
                        size: 14,
                        color: Colors.blue[600],
                      ),
                    ),
                    SizedBox(width: 10),
                    Text(
                      order.buyerName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
              ),
              // Variant Info if available
              if (order.variantName.trim().isNotEmpty) ...[
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.blue[100],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Icon(
                              Icons.style,
                              size: 12,
                              color: Colors.blue[700],
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Variant: ${order.variantName}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.blue[900],
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      if (order.variantAttributes.isNotEmpty) ...[
                        SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: order.variantAttributes.entries
                              .map(
                                (attr) => Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[100],
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${attr.key}: ${attr.value}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.blue[900],
                                      fontWeight: FontWeight.w600,
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
              // Action Required Section for Requests
              // Action Required Section for Requests
              if (displayStatus.toLowerCase() == 'request for return' ||
                  displayStatus.toLowerCase() == 'request for replacement') ...[
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 6),
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: statusColor.withAlpha(80),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: statusColor,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              displayStatus.toLowerCase() ==
                                      'request for return'
                                  ? 'Customer requested Return'
                                  : 'Customer requested Replacement',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: isUpdating
                                  ? null
                                  : () {
                                      final newStatus =
                                          displayStatus.toLowerCase() ==
                                              'request for return'
                                          ? 'Return Rejected'
                                          : 'Replacement Rejected';
                                      setState(() {
                                        _statusSelections[order.orderId] =
                                            newStatus;
                                      });
                                      _updateOrderStatus(order);
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red[50],
                                foregroundColor: Colors.red,
                                elevation: 0,
                                padding: EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(color: Colors.red),
                                ),
                              ),
                              child: Text('Reject'),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: isUpdating
                                  ? null
                                  : () {
                                      final newStatus =
                                          displayStatus.toLowerCase() ==
                                              'request for return'
                                          ? 'Return Approved'
                                          : 'Replacement Approved';
                                      setState(() {
                                        _statusSelections[order.orderId] =
                                            newStatus;
                                      });
                                      _updateOrderStatus(order);
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text('Approve'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ] else if (isDelivered ||
                  order.status.toLowerCase().contains('approved') ||
                  order.status.toLowerCase().contains('rejected')) ...[
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 6),
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDelivered
                        ? Colors.green[50]
                        : statusColor.withAlpha(15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDelivered
                          ? Colors.green[300]!
                          : statusColor.withAlpha(80),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isDelivered
                              ? Colors.green[200]
                              : statusColor.withAlpha(30),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isDelivered ||
                                  displayStatus.toLowerCase().contains(
                                    'approved',
                                  )
                              ? Icons.check_circle
                              : Icons.cancel,
                          color: isDelivered ? Colors.green[700] : statusColor,
                          size: 18,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isDelivered
                                  ? 'Order Delivered'
                                  : _formatStatus(displayStatus),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isDelivered
                                    ? Colors.green[900]
                                    : statusColor,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Status updates are completed for this order',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDelivered
                                    ? Colors.green[700]
                                    : statusColor.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ] else
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 6),
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(8),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: statusColor.withAlpha(80),
                      width: 1.5,
                    ),
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
                              initialValue: displayStatus,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                    color: Colors.grey[300]!,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
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
                              items:
                                  {
                                        ..._statusOptions,
                                        if (!_statusOptions.contains(
                                          displayStatus.toLowerCase(),
                                        ))
                                          displayStatus,
                                      }
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
                                        _statusSelections[order.orderId] =
                                            value;
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
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 2,
                            ),
                            child: Text(
                              'Update',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              // Last Updated
              if (order.lastUpdated != null) ...[
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 14,
                        color: Colors.green[600],
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Updated: ${DateFormat('MMM dd, hh:mm a').format(order.lastUpdated!)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.green[700],
                            fontWeight: FontWeight.w600,
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
