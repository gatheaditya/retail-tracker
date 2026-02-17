import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';
import '../models/client.dart';
import '../models/product.dart';
import '../models/order.dart';
import '../models/order_item.dart';
import '../services/sync_service.dart' show SyncService, SyncOperation;
import 'dart:developer' as developer;

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  static const _uuid = Uuid();

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('order_app.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    String path;
    try {
      final dbPath = await getDatabasesPath();
      path = join(dbPath, filePath);
    } catch (e) {
      // On web, use in-memory database
      path = ':memory:';
    }

    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE clients (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        address TEXT,
        city TEXT,
        postalCode TEXT,
        contactPerson TEXT,
        pendingSync INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        price REAL NOT NULL,
        sku TEXT,
        category TEXT,
        pendingSync INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE orders (
        id TEXT PRIMARY KEY,
        clientId TEXT NOT NULL,
        orderDate TEXT NOT NULL,
        totalAmount REAL NOT NULL,
        status TEXT NOT NULL,
        pendingSync INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (clientId) REFERENCES clients (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE order_items (
        id TEXT PRIMARY KEY,
        orderId TEXT NOT NULL,
        productId TEXT NOT NULL,
        productName TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        unitPrice REAL NOT NULL,
        pendingSync INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (orderId) REFERENCES orders (id) ON DELETE CASCADE,
        FOREIGN KEY (productId) REFERENCES products (id) ON DELETE CASCADE
      )
    ''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Migrate version 1 to 2
      await db.execute('ALTER TABLE clients RENAME TO clients_old');
      await db.execute('ALTER TABLE products RENAME TO products_old');
      await db.execute('ALTER TABLE orders RENAME TO orders_old');
      await db.execute('ALTER TABLE order_items RENAME TO order_items_old');

      await _createDB(db, newVersion);

      await db.execute('''
        INSERT INTO clients (id, name, phone, email, address, pendingSync)
        SELECT CAST(id AS TEXT), name, phone, email, address, 0 FROM clients_old
      ''');
      // ... (other migrations)
    }
    
    if (oldVersion < 3) {
      // Add new columns to clients table
      await db.execute('ALTER TABLE clients ADD COLUMN city TEXT DEFAULT ""');
      await db.execute('ALTER TABLE clients ADD COLUMN postalCode TEXT DEFAULT ""');
      await db.execute('ALTER TABLE clients ADD COLUMN contactPerson TEXT DEFAULT ""');
      
      // Also ensure product category column exists
      try {
        await db.execute('ALTER TABLE products ADD COLUMN category TEXT DEFAULT "General"');
      } catch (e) {
        // Might already exist
      }
    }
  }

  // Client operations
  Future<String> insertClient(Client client) async {
    final db = await database;
    final id = client.id ?? _uuid.v4();
    try {
      developer.log('Inserting client: ${client.name}', name: 'DatabaseHelper');
      await db.insert('clients', {
        ...client.toMap(),
        'id': id,
        'pendingSync': 1,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await _triggerSync('clients', id, {...client.toMap(), 'id': id}, SyncOperation.upsert);
      return id;
    } catch (e) {
      developer.log('Error inserting client: $e', name: 'DatabaseHelper', level: 1000);
      rethrow;
    }
  }

  Future<List<Client>> getAllClients() async {
    final db = await database;
    final result = await db.query('clients', orderBy: 'name ASC');
    return result.map((map) => Client.fromMap(map)).toList();
  }

  Future<List<Client>> searchClients(String query) async {
    final db = await database;
    final result = await db.query(
      'clients',
      where: 'name LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'name ASC',
    );
    return result.map((map) => Client.fromMap(map)).toList();
  }

  Future<Client?> getClientById(String id) async {
    final db = await database;
    final result = await db.query(
      'clients',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (result.isNotEmpty) {
      return Client.fromMap(result.first);
    }
    return null;
  }

  Future<int> updateClient(Client client) async {
    final db = await database;
    try {
      final result = await db.update(
        'clients',
        {...client.toMap(), 'pendingSync': 1},
        where: 'id = ?',
        whereArgs: [client.id],
      );
      await _triggerSync('clients', client.id!, {...client.toMap(), 'id': client.id}, SyncOperation.upsert);
      return result;
    } catch (e) {
      rethrow;
    }
  }

  Future<int> deleteClient(String id) async {
    final db = await database;
    try {
      final result = await db.delete(
        'clients',
        where: 'id = ?',
        whereArgs: [id],
      );
      await _triggerSync('clients', id, {}, SyncOperation.delete);
      return result;
    } catch (e) {
      rethrow;
    }
  }

  // Product operations
  Future<String> insertProduct(Product product) async {
    final db = await database;
    final id = product.id ?? _uuid.v4();
    await db.insert('products', {
      ...product.toMap(),
      'id': id,
      'pendingSync': 1,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await _triggerSync('products', id, {...product.toMap(), 'id': id}, SyncOperation.upsert);
    return id;
  }

  Future<List<Product>> getAllProducts() async {
    final db = await database;
    final result = await db.query('products', orderBy: 'name ASC');
    return result.map((map) => Product.fromMap(map)).toList();
  }

  Future<List<String>> getDistinctCategories() async {
    final db = await database;
    final result = await db.rawQuery('SELECT DISTINCT category FROM products WHERE category IS NOT NULL AND category != "" ORDER BY category ASC');
    return result.map((row) => row['category'] as String).toList();
  }

  Future<List<Product>> getProductsByCategory(String category) async {
    final db = await database;
    final result = await db.query(
      'products',
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'name ASC',
    );
    return result.map((map) => Product.fromMap(map)).toList();
  }

  Future<List<Product>> searchProducts(String query) async {
    final db = await database;
    final result = await db.query(
      'products',
      where: 'name LIKE ? OR sku LIKE ? OR category LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
      orderBy: 'name ASC',
    );
    return result.map((map) => Product.fromMap(map)).toList();
  }

  Future<Product?> getProductById(String id) async {
    final db = await database;
    final result = await db.query(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (result.isNotEmpty) {
      return Product.fromMap(result.first);
    }
    return null;
  }

  Future<int> updateProduct(Product product) async {
    final db = await database;
    final result = await db.update(
      'products',
      {...product.toMap(), 'pendingSync': 1},
      where: 'id = ?',
      whereArgs: [product.id],
    );
    await _triggerSync('products', product.id!, {...product.toMap(), 'id': product.id}, SyncOperation.upsert);
    return result;
  }

  Future<int> deleteProduct(String id) async {
    final db = await database;
    final result = await db.delete(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );
    await _triggerSync('products', id, {}, SyncOperation.delete);
    return result;
  }

  // Order operations
  Future<String> insertOrder(Order order) async {
    final db = await database;
    final id = order.id ?? _uuid.v4();
    await db.insert('orders', {
      ...order.toMap(),
      'id': id,
      'pendingSync': 1,
    });
    await _triggerSync('orders', id, {...order.toMap(), 'id': id}, SyncOperation.upsert);
    return id;
  }

  Future<List<Order>> getAllOrders() async {
    final db = await database;
    final result = await db.query('orders', orderBy: 'orderDate DESC');
    return result.map((map) => Order.fromMap(map)).toList();
  }

  Future<List<Map<String, dynamic>>> getAllOrdersWithClients() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT
        orders.*,
        clients.name as clientName
      FROM orders
      INNER JOIN clients ON orders.clientId = clients.id
      ORDER BY orders.orderDate DESC
    ''');
    return result;
  }

  Future<Map<String, dynamic>?> getOrderWithClient(String orderId) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT
        orders.*,
        clients.name as clientName
      FROM orders
      INNER JOIN clients ON orders.clientId = clients.id
      WHERE orders.id = ?
    ''', [orderId]);
    if (result.isNotEmpty) {
      return result.first;
    }
    return null;
  }

  Future<int> updateOrder(Order order) async {
    final db = await database;
    final result = await db.update(
      'orders',
      {...order.toMap(), 'pendingSync': 1},
      where: 'id = ?',
      whereArgs: [order.id],
    );
    await _triggerSync('orders', order.id!, {...order.toMap(), 'id': order.id}, SyncOperation.upsert);
    return result;
  }

  Future<int> deleteOrder(String id) async {
    final db = await database;
    final result = await db.delete(
      'orders',
      where: 'id = ?',
      whereArgs: [id],
    );
    await _triggerSync('orders', id, {}, SyncOperation.delete);
    return result;
  }

  // Order Item operations
  Future<String> insertOrderItem(OrderItem orderItem) async {
    final db = await database;
    final id = orderItem.id ?? _uuid.v4();
    await db.insert('order_items', {
      ...orderItem.toMap(),
      'id': id,
      'pendingSync': 1,
    });
    await _triggerSync('order_items', id, {...orderItem.toMap(), 'id': id}, SyncOperation.upsert);
    return id;
  }

  Future<void> insertOrderItems(List<OrderItem> orderItems) async {
    final db = await database;
    final batch = db.batch();
    for (var item in orderItems) {
      final id = item.id ?? _uuid.v4();
      batch.insert('order_items', {
        ...item.toMap(),
        'id': id,
        'pendingSync': 1,
      });
    }
    await batch.commit(noResult: true);
    for (var item in orderItems) {
      final id = item.id ?? _uuid.v4();
      await _triggerSync('order_items', id, {...item.toMap(), 'id': id}, SyncOperation.upsert);
    }
  }

  Future<List<OrderItem>> getOrderItems(String orderId) async {
    final db = await database;
    final result = await db.query(
      'order_items',
      where: 'orderId = ?',
      whereArgs: [orderId],
    );
    return result.map((map) => OrderItem.fromMap(map)).toList();
  }

  // Bulk operations
  Future<void> replaceAllClients(List<Client> clients) async {
    final db = await database;
    await db.delete('clients');
    final batch = db.batch();
    for (var client in clients) {
      batch.insert('clients', {
        ...client.toMap(),
        'pendingSync': 0,
      });
    }
    await batch.commit(noResult: true);
  }

  Future<void> replaceAllProducts(List<Product> products) async {
    final db = await database;
    await db.delete('products');
    final batch = db.batch();
    for (var product in products) {
      batch.insert('products', {
        ...product.toMap(),
        'pendingSync': 0,
      });
    }
    await batch.commit(noResult: true);
  }

  Future<void> replaceAllOrders(List<Order> orders) async {
    final db = await database;
    await db.delete('orders');
    final batch = db.batch();
    for (var order in orders) {
      batch.insert('orders', {
        ...order.toMap(),
        'pendingSync': 0,
      });
    }
    await batch.commit(noResult: true);
  }

  Future<void> replaceAllOrderItems(List<OrderItem> orderItems) async {
    final db = await database;
    await db.delete('order_items');
    final batch = db.batch();
    for (var item in orderItems) {
      batch.insert('order_items', {
        ...item.toMap(),
        'pendingSync': 0,
      });
    }
    await batch.commit(noResult: true);
  }

  // Sync operations
  Future<void> markSynced(String tableName, String id) async {
    final db = await database;
    await db.update(
      tableName,
      {'pendingSync': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<Map<String, List<Map<String, dynamic>>>> getPendingSyncRecords() async {
    final db = await database;
    final result = <String, List<Map<String, dynamic>>>{};

    result['clients'] = await db.query('clients', where: 'pendingSync = 1');
    result['products'] = await db.query('products', where: 'pendingSync = 1');
    result['orders'] = await db.query('orders', where: 'pendingSync = 1');
    result['order_items'] = await db.query('order_items', where: 'pendingSync = 1');

    return result;
  }

  Future<void> _triggerSync(String tableName, String id, Map<String, dynamic> row, SyncOperation operation) async {
    try {
      SyncService.instance.syncRecord(
        tableName: tableName,
        id: id,
        row: row,
        operation: operation,
      ).ignore();
    } catch (e) {
      developer.log('Error triggering sync: $e', name: 'DatabaseHelper');
    }
  }

  Future close() async {
    final db = await database;
    db.close();
  }
}
