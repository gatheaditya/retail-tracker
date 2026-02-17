import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../models/order_item.dart';
import '../models/client.dart';
import '../services/email_service.dart';
import 'dart:developer' as developer;

class OrderDetailsScreen extends StatefulWidget {
  final String orderId;

  const OrderDetailsScreen({super.key, required this.orderId});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  Map<String, dynamic>? _orderData;
  Client? _client;
  List<OrderItem> _orderItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOrderDetails();
  }

  Future<void> _loadOrderDetails() async {
    final orderData = await _dbHelper.getOrderWithClient(widget.orderId);
    final items = await _dbHelper.getOrderItems(widget.orderId);
    
    Client? client;
    if (orderData != null) {
      client = await _dbHelper.getClientById(orderData['clientId'] as String);
    }

    setState(() {
      _orderData = orderData;
      _client = client;
      _orderItems = items;
      _isLoading = false;
    });
  }

  String _formatPrice(double price) {
    return NumberFormat.currency(symbol: '\$').format(price);
  }

  String _formatDate(String dateStr) {
    final date = DateTime.parse(dateStr);
    return DateFormat('MMM dd, yyyy HH:mm').format(date);
  }

  Future<void> _sendEmail() async {
    if (_orderData == null || _client == null) return;

    try {
      setState(() => _isLoading = true);
      
      await EmailService.instance.sendOrderEmail(
        orderId: widget.orderId,
        orderDate: _orderData!['orderDate'] as String,
        totalAmount: _orderData!['totalAmount'] as double,
        client: _client!,
        items: _orderItems,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order sharing initialized')),
        );
      }
    } catch (e) {
      developer.log('Error sending email: $e', name: 'OrderDetailsScreen', level: 1000);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing order: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildStatusChip(String status) {
    Color color;
    Color bgColor;
    switch (status.toUpperCase()) {
      case 'COMPLETED':
        color = Colors.green;
        bgColor = Colors.green.shade50;
        break;
      case 'PENDING':
        color = Colors.orange;
        bgColor = Colors.orange.shade50;
        break;
      case 'CANCELLED':
        color = Colors.red;
        bgColor = Colors.red.shade50;
        break;
      default:
        color = Colors.blue;
        bgColor = Colors.blue.shade50;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _orderData == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_orderData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Order Details')),
        body: const Center(child: Text('Order not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share via Email (Excel)',
            onPressed: _sendEmail,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Order Header
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Order #${widget.orderId.substring(0, 8)}',
                            style: Theme.of(context).textTheme.headlineSmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _buildStatusChip(_orderData!['status'] as String),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatDate(_orderData!['orderDate'] as String),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Customer Info
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Customer Info',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const Divider(),
                    Text(
                      _client?.name ?? 'Unknown Client',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (_client?.contactPerson.isNotEmpty == true)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('Attn: ${_client!.contactPerson}', style: const TextStyle(fontStyle: FontStyle.italic)),
                      ),
                    const SizedBox(height: 8),
                    if (_client?.city.isNotEmpty == true)
                      Row(
                        children: [
                          const Icon(Icons.location_city, size: 16, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text('${_client!.city}${_client!.postalCode.isNotEmpty ? " (${_client!.postalCode})" : ""}'),
                        ],
                      ),
                    if (_client?.phone.isNotEmpty == true)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.phone, size: 16, color: Colors.grey),
                            const SizedBox(width: 8),
                            Text(_client!.phone),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Items
            Text(
              'Order Items',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ..._orderItems.map((item) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.productName,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          Text(
                            '${_formatPrice(item.unitPrice)} x ${item.quantity}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _formatPrice(item.totalPrice),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            )),
            const SizedBox(height: 16),
            // Total
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Amount',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      _formatPrice(_orderData!['totalAmount'] as double),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _sendEmail,
        icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.email),
        label: const Text('Send Order'),
      ),
    );
  }
}
