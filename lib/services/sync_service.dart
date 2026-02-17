import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'dart:developer' as developer;
import '../database/database_helper.dart';
import '../models/client.dart';
import '../models/product.dart';
import '../models/order.dart';
import '../models/order_item.dart';
import 'sheets_service.dart';

class SyncService {
  static final SyncService instance = SyncService._();
  static const _tabNames = {
    'clients': 'Clients',
    'products': 'Products',
    'orders': 'Orders',
    'order_items': 'OrderItems',
  };

  String? _spreadsheetId;
  http.Client? _authClient;
  bool _isOnline = true;
  StreamSubscription? _connectivitySubscription;

  SyncService._();

  /// Initialize sync service with spreadsheet ID and auth client
  Future<void> initialize(String spreadsheetId, http.Client authClient) async {
    _spreadsheetId = spreadsheetId;
    _authClient = authClient;
    developer.log('SyncService initialized with spreadsheet: $_spreadsheetId', name: 'SyncService');
  }

  /// Pull all data from Google Sheets and replace local database
  Future<void> pullFromSheets() async {
    if (_spreadsheetId == null || _authClient == null) return;
    
    try {
      developer.log('Starting pull from Sheets', name: 'SyncService');
      final dbHelper = DatabaseHelper.instance;

      // Pull Clients
      final clientRows = await SheetsService.instance.readSheet(_authClient!, _spreadsheetId!, _tabNames['clients']!);
      if (clientRows.length > 1) { // Only replace if there's data (excluding header)
        final clients = _parseClients(clientRows);
        await dbHelper.replaceAllClients(clients);
        developer.log('Pulled ${clients.length} clients from Sheets', name: 'SyncService');
      }
      await Future.delayed(const Duration(seconds: 1)); // Rate limit

      // Pull Products
      final productRows = await SheetsService.instance.readSheet(_authClient!, _spreadsheetId!, _tabNames['products']!);
      if (productRows.length > 1) {
        final products = _parseProducts(productRows);
        await dbHelper.replaceAllProducts(products);
        developer.log('Pulled ${products.length} products from Sheets', name: 'SyncService');
      }
      await Future.delayed(const Duration(seconds: 1)); // Rate limit

      // Pull Orders
      final orderRows = await SheetsService.instance.readSheet(_authClient!, _spreadsheetId!, _tabNames['orders']!);
      if (orderRows.length > 1) {
        final orders = _parseOrders(orderRows);
        await dbHelper.replaceAllOrders(orders);
        developer.log('Pulled ${orders.length} orders from Sheets', name: 'SyncService');
      }
      await Future.delayed(const Duration(seconds: 1)); // Rate limit

      // Pull OrderItems
      final itemRows = await SheetsService.instance.readSheet(_authClient!, _spreadsheetId!, _tabNames['order_items']!);
      if (itemRows.length > 1) {
        final items = _parseOrderItems(itemRows);
        await dbHelper.replaceAllOrderItems(items);
        developer.log('Pulled ${items.length} order items from Sheets', name: 'SyncService');
      }
    } catch (e) {
      developer.log('Error pulling from Sheets: $e', name: 'SyncService', level: 1000);
      rethrow;
    }
  }

  /// Push all local data to Sheets (useful for initial sync)
  Future<void> pushToSheets() async {
    if (_spreadsheetId == null || _authClient == null) return;
    
    try {
      developer.log('🚀 Starting full push to Sheets...', name: 'SyncService');
      
      final db = DatabaseHelper.instance;
      
      // Push Clients
      final clients = await db.getAllClients();
      for (var client in clients) {
        await syncRecord(
          tableName: 'clients',
          id: client.id!,
          row: client.toMap(),
          operation: SyncOperation.upsert,
        );
      }
      
      // Push Products
      final products = await db.getAllProducts();
      for (var product in products) {
        await syncRecord(
          tableName: 'products',
          id: product.id!,
          row: product.toMap(),
          operation: SyncOperation.upsert,
        );
      }
      
      // Push Orders
      final orders = await db.getAllOrders();
      for (var order in orders) {
        await syncRecord(
          tableName: 'orders',
          id: order.id!,
          row: order.toMap(),
          operation: SyncOperation.upsert,
        );
      }

      // Push OrderItems
      final orderIds = orders.map((o) => o.id!).toList();
      for (var orderId in orderIds) {
        final items = await db.getOrderItems(orderId);
        for (var item in items) {
          await syncRecord(
            tableName: 'order_items',
            id: item.id!,
            row: item.toMap(),
            operation: SyncOperation.upsert,
          );
        }
      }
      
      developer.log('✅ Full push to Sheets complete', name: 'SyncService');
    } catch (e) {
      developer.log('❌ Error pushing to Sheets: $e', name: 'SyncService', level: 1000);
    }
  }

  /// Sync a single record to Sheets
  Future<void> syncRecord({
    required String tableName,
    required String id,
    required Map<String, dynamic> row,
    required SyncOperation operation,
  }) async {
    try {
      if (_spreadsheetId == null || _authClient == null) {
        developer.log('SyncService not initialized, skipping sync', name: 'SyncService');
        return;
      }

      if (!_isOnline) {
        developer.log('Offline: skipping sync for $tableName:$id', name: 'SyncService');
        return;
      }

      final tabName = _tabNames[tableName];
      if (tabName == null) {
        throw Exception('Unknown table: $tableName');
      }

      developer.log('Syncing $tableName:$id (${operation.name})', name: 'SyncService');

      final sheetsService = SheetsService.instance;

      if (operation == SyncOperation.delete) {
        await sheetsService.deleteFromSheet(_authClient!, _spreadsheetId!, tabName, id);
      } else {
        // upsert
        final rowValues = _mapToRow(tableName, row);

        // Check if row exists
        final allRows = await sheetsService.readSheet(_authClient!, _spreadsheetId!, tabName);
        bool exists = false;
        for (int i = 1; i < allRows.length; i++) {
          if (allRows[i].isNotEmpty && allRows[i][0].toString() == id) {
            exists = true;
            break;
          }
        }

        if (exists) {
          await sheetsService.updateRow(_authClient!, _spreadsheetId!, tabName, id, rowValues);
        } else {
          await sheetsService.appendRow(_authClient!, _spreadsheetId!, tabName, rowValues);
        }
      }

      // Mark as synced in local database
      await DatabaseHelper.instance.markSynced(tableName, id);
      developer.log('Synced $tableName:$id successfully', name: 'SyncService');
    } catch (e) {
      developer.log('Error syncing $tableName:$id: $e', name: 'SyncService', level: 1000);
      // Don't rethrow - let the app continue even if sync fails
    }
  }

  /// Flush all pending sync records
  Future<void> flushPendingSync() async {
    try {
      developer.log('Flushing pending sync records', name: 'SyncService');
      if (!_isOnline) {
        developer.log('Offline: skipping flush', name: 'SyncService');
        return;
      }

      final pending = await DatabaseHelper.instance.getPendingSyncRecords();

      int totalCount = 0;
      for (final tableName in _tabNames.keys) {
        final records = pending[tableName] ?? [];
        totalCount += records.length;

        for (final record in records) {
          final id = record['id'] as String;
          await syncRecord(
            tableName: tableName,
            id: id,
            row: record,
            operation: SyncOperation.upsert,
          );
        }
      }

      developer.log('Flushed $totalCount pending records', name: 'SyncService');
    } catch (e) {
      developer.log('Error flushing pending sync: $e', name: 'SyncService', level: 1000);
    }
  }

  /// Start watching for connectivity changes
  void startConnectivityWatcher() {
    developer.log('Starting connectivity watcher', name: 'SyncService');
    final connectivity = Connectivity();

    _connectivitySubscription = connectivity.onConnectivityChanged.listen((results) {
      final wasOnline = _isOnline;
      _isOnline = !results.contains(ConnectivityResult.none);

      developer.log('Connectivity changed: online=$_isOnline (was $wasOnline)', name: 'SyncService');

      // If just came back online, flush pending records
      if (!wasOnline && _isOnline) {
        developer.log('Back online, flushing pending records', name: 'SyncService');
        flushPendingSync(); // Fire and forget
      }
    });
  }

  /// Stop watching connectivity
  void stopConnectivityWatcher() {
    _connectivitySubscription?.cancel();
  }

  // Parsing helpers
  List<Client> _parseClients(List<List<Object?>> rows) {
    return rows.skip(1).map((row) {
      if (row.isEmpty) return null;
      try {
        return Client(
          id: row.isNotEmpty ? row[0].toString() : null,
          name: row.length > 1 ? row[1].toString() : '',
          phone: row.length > 2 ? row[2].toString() : '',
          email: row.length > 3 ? row[3].toString() : '',
          address: row.length > 4 ? row[4].toString() : '',
          city: row.length > 5 ? row[5].toString() : '',
          postalCode: row.length > 6 ? row[6].toString() : '',
          contactPerson: row.length > 7 ? row[7].toString() : '',
        );
      } catch (e) {
        developer.log('Error parsing client row: $e', name: 'SyncService', level: 1000);
        return null;
      }
    }).whereType<Client>().toList();
  }

  List<Product> _parseProducts(List<List<Object?>> rows) {
    return rows.skip(1).map((row) {
      if (row.isEmpty) return null;
      try {
        final price = row.length > 3 ? double.tryParse(row[3].toString()) ?? 0.0 : 0.0;
        return Product(
          id: row.isNotEmpty ? row[0].toString() : null,
          name: row.length > 1 ? row[1].toString() : '',
          description: row.length > 2 ? row[2].toString() : '',
          price: price,
          sku: row.length > 4 ? row[4].toString() : '',
          category: row.length > 5 ? row[5].toString() : 'General',
        );
      } catch (e) {
        developer.log('Error parsing product row: $e', name: 'SyncService', level: 1000);
        return null;
      }
    }).whereType<Product>().toList();
  }

  List<Order> _parseOrders(List<List<Object?>> rows) {
    return rows.skip(1).map((row) {
      if (row.isEmpty) return null;
      try {
        final totalAmount = row.length > 3 ? double.tryParse(row[3].toString()) ?? 0.0 : 0.0;
        return Order(
          id: row.isNotEmpty ? row[0].toString() : null,
          clientId: row.length > 1 ? row[1].toString() : '',
          orderDate: row.length > 2 ? DateTime.tryParse(row[2].toString()) ?? DateTime.now() : DateTime.now(),
          totalAmount: totalAmount,
          status: row.length > 4 ? row[4].toString() : 'PENDING',
        );
      } catch (e) {
        developer.log('Error parsing order row: $e', name: 'SyncService', level: 1000);
        return null;
      }
    }).whereType<Order>().toList();
  }

  List<OrderItem> _parseOrderItems(List<List<Object?>> rows) {
    return rows.skip(1).map((row) {
      if (row.isEmpty) return null;
      try {
        final quantity = row.length > 4 ? int.tryParse(row[4].toString()) ?? 0 : 0;
        final unitPrice = row.length > 5 ? double.tryParse(row[5].toString()) ?? 0.0 : 0.0;
        return OrderItem(
          id: row.isNotEmpty ? row[0].toString() : null,
          orderId: row.length > 1 ? row[1].toString() : '',
          productId: row.length > 2 ? row[2].toString() : '',
          productName: row.length > 3 ? row[3].toString() : '',
          quantity: quantity,
          unitPrice: unitPrice,
        );
      } catch (e) {
        developer.log('Error parsing order item row: $e', name: 'SyncService', level: 1000);
        return null;
      }
    }).whereType<OrderItem>().toList();
  }

  // Convert map to row values for Sheets
  List<Object?> _mapToRow(String tableName, Map<String, dynamic> row) {
    switch (tableName) {
      case 'clients':
        return [
          row['id'],
          row['name'],
          row['phone'] ?? '',
          row['email'] ?? '',
          row['address'] ?? '',
          row['city'] ?? '',
          row['postalCode'] ?? '',
          row['contactPerson'] ?? '',
        ];
      case 'products':
        return [
          row['id'],
          row['name'],
          row['description'] ?? '',
          row['price'],
          row['sku'] ?? '',
          row['category'] ?? 'General',
        ];
      case 'orders':
        return [
          row['id'],
          row['clientId'],
          row['orderDate'],
          row['totalAmount'],
          row['status'],
        ];
      case 'order_items':
        return [
          row['id'],
          row['orderId'],
          row['productId'],
          row['productName'],
          row['quantity'],
          row['unitPrice'],
        ];
      default:
        throw Exception('Unknown table: $tableName');
    }
  }
}

enum SyncOperation { upsert, delete }
