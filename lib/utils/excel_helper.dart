import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../models/product.dart';
import '../models/client.dart';
import '../database/database_helper.dart';
import 'dart:developer' as developer;

class ExcelHelper {
  static Future<int> seedProductsFromAsset() async {
    final db = DatabaseHelper.instance;
    final existing = await db.getAllProducts();
    if (existing.isNotEmpty) {
      developer.log('Database already has ${existing.length} products, skipping seed', name: 'ExcelHelper');
      return 0;
    }

    developer.log('Seeding products from bundled Excel...', name: 'ExcelHelper');
    final bytes = await rootBundle.load('assets/products.xlsx');
    final products = parseGaganFoodsExcel(bytes.buffer.asUint8List());

    for (final product in products) {
      await db.insertProduct(product);
    }

    return products.length;
  }

  static Future<int> seedClientsFromAsset() async {
    final db = DatabaseHelper.instance;
    final existing = await db.getAllClients();
    if (existing.isNotEmpty) {
      developer.log('Database already has ${existing.length} clients, skipping seed', name: 'ExcelHelper');
      return 0;
    }

    developer.log('Seeding clients from bundled Excel...', name: 'ExcelHelper');
    try {
      final bytes = await rootBundle.load('assets/clients.xlsx');
      final clients = parseClientsExcel(bytes.buffer.asUint8List());

      for (final client in clients) {
        await db.insertClient(client);
      }

      return clients.length;
    } catch (e) {
      developer.log('Error seeding clients: $e', name: 'ExcelHelper', level: 1000);
      return 0;
    }
  }

  static List<Client> parseClientsExcel(Uint8List bytes) {
    try {
      final excel = Excel.decodeBytes(bytes);
      final clients = <Client>[];
      final sheetName = excel.tables.keys.first;
      final sheet = excel[sheetName];

      for (var i = 1; i < sheet.maxRows; i++) {
        final row = sheet.row(i);
        if (row.isEmpty) continue;

        // B: Name (index 1), C: Address (index 2), D: City (index 3), 
        // E: PostalCode (index 4), F: ContactPerson (index 5), G: Phone (index 6)
        final name = row.length > 1 ? row[1]?.value?.toString().trim() ?? '' : '';
        if (name.isEmpty) continue;

        final address = row.length > 2 ? row[2]?.value?.toString().trim() ?? '' : '';
        final city = row.length > 3 ? row[3]?.value?.toString().trim() ?? '' : '';
        final postalCode = row.length > 4 ? row[4]?.value?.toString().trim() ?? '' : '';
        final contactPerson = row.length > 5 ? row[5]?.value?.toString().trim() ?? '' : '';
        final phone = row.length > 6 ? row[6]?.value?.toString().trim() ?? '' : '';

        clients.add(Client(
          name: name,
          address: address,
          city: city,
          postalCode: postalCode,
          contactPerson: contactPerson,
          phone: phone,
          email: '', // Not specified in mapping
        ));
      }
      return clients;
    } catch (e) {
      developer.log('Error parsing Clients Excel: $e', name: 'ExcelHelper', level: 1000);
      return [];
    }
  }

  static List<Product> parseGaganFoodsExcel(Uint8List bytes) {
    try {
      final excel = Excel.decodeBytes(bytes);
      final products = <Product>[];
      final priceMap = _buildPriceMap(excel);

      if (excel.tables.containsKey('DRY')) {
        products.addAll(_parseProductSheet(excel['DRY'], priceMap, 'Dry Grocery'));
      }
      if (excel.tables.containsKey('FROZEN')) {
        products.addAll(_parseProductSheet(excel['FROZEN'], priceMap, 'Frozen'));
      }
      return products;
    } catch (e) {
      return [];
    }
  }

  static Map<String, double> _buildPriceMap(Excel excel) {
    final map = <String, double>{};
    const sheetName = 'prices for Sobeys listed items';
    if (!excel.tables.containsKey(sheetName)) return map;
    final sheet = excel[sheetName];
    for (var i = 1; i < sheet.maxRows; i++) {
      final row = sheet.row(i);
      final article = row.isNotEmpty ? row[0]?.value?.toString().trim() : null;
      final price = row.length > 3 ? double.tryParse(row[3]?.value?.toString() ?? '') : null;
      if (article != null && price != null) map[article] = price;
    }
    return map;
  }

  static List<Product> _parseProductSheet(Sheet sheet, Map<String, double> priceMap, String defaultCategory) {
    final products = <Product>[];
    var currentCategory = defaultCategory;
    for (var i = 0; i < sheet.maxRows; i++) {
      final row = sheet.row(i);
      if (row.isEmpty) continue;
      final colA = row[0]?.value;
      final colB = row.length > 1 ? row[1]?.value : null;
      final colC = row.length > 2 ? row[2]?.value : null;
      if (colA != null && colB == null && colC == null) {
        currentCategory = colA.toString().trim();
        continue;
      }
      if (colC != null) {
        final article = colA.toString().trim();
        products.add(Product(
          name: colC.toString().trim(),
          description: colC.toString().trim(),
          price: priceMap[article] ?? 0.0,
          sku: article,
          category: currentCategory,
        ));
      }
    }
    return products;
  }
}
