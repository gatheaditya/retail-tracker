import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../utils/excel_helper.dart';
import 'dart:developer' as developer;

class ImportProductsScreen extends StatefulWidget {
  const ImportProductsScreen({super.key});

  @override
  State<ImportProductsScreen> createState() => _ImportProductsScreenState();
}

class _ImportProductsScreenState extends State<ImportProductsScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  bool _isLoading = false;
  String _statusMessage = 'Ready to import products';
  int _productCount = 0;

  @override
  void initState() {
    super.initState();
    _loadProductCount();
  }

  Future<void> _loadProductCount() async {
    final products = await _dbHelper.getAllProducts();
    if (mounted) {
      setState(() {
        _productCount = products.length;
        if (_productCount > 0) {
          _statusMessage = '$_productCount products in database';
        }
      });
    }
  }

  Future<void> _importFromBundledExcel() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Loading Gagan Foods catalog...';
    });

    try {
      final count = await ExcelHelper.seedProductsFromAsset();
      if (count > 0) {
        _statusMessage = 'Imported $count products successfully';
      } else {
        _statusMessage = 'Products already loaded ($_productCount in database)';
      }
      await _loadProductCount();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(count > 0
                ? '$count products imported successfully'
                : 'Products already loaded'),
          ),
        );
      }
    } catch (e) {
      developer.log('Error importing products: $e',
          name: 'ImportProductsScreen', level: 1000);
      if (mounted) {
        setState(() {
          _statusMessage = 'Error: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error importing products: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _reloadFromExcel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reload Products'),
        content: const Text(
          'This will delete all existing products and reload from the Gagan Foods catalog. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reload'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
      _statusMessage = 'Clearing existing products...';
    });

    try {
      // Delete all existing products
      final existing = await _dbHelper.getAllProducts();
      for (final product in existing) {
        if (product.id != null) {
          await _dbHelper.deleteProduct(product.id!);
        }
      }

      setState(() {
        _statusMessage = 'Reloading from Gagan Foods catalog...';
      });

      final count = await ExcelHelper.seedProductsFromAsset();
      _statusMessage = 'Reloaded $count products successfully';
      await _loadProductCount();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reloaded $count products')),
        );
      }
    } catch (e) {
      developer.log('Error reloading products: $e',
          name: 'ImportProductsScreen', level: 1000);
      if (mounted) {
        setState(() {
          _statusMessage = 'Error: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error reloading products: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Products'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Icon(Icons.import_export,
                        size: 64, color: Colors.blue),
                    const SizedBox(height: 16),
                    Text(
                      _statusMessage,
                      style: Theme.of(context).textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                    if (_productCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '$_productCount products in database',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    if (_isLoading)
                      const CircularProgressIndicator()
                    else
                      Column(
                        children: [
                          ElevatedButton.icon(
                            onPressed: _importFromBundledExcel,
                            icon: const Icon(Icons.inventory_2),
                            label: const Text('Import Gagan Foods Catalog'),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _reloadFromExcel,
                            icon: const Icon(Icons.refresh),
                            label:
                                const Text('Reload Catalog (Clear & Re-import)'),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gagan Foods Sobeys Catalog',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Products are loaded automatically on first launch from '
                      'the bundled Gagan Foods Sobeys catalog.\n\n'
                      'Categories include: Ashoka RTE Curries, Pickles, '
                      'Pastes & Chutneys, Bikano Snacks, Gagan Spices & Flours, '
                      'Dabur Products, MDH Spices, National Foods, '
                      'Hawkins, Vadilal Frozen, and more.\n\n'
                      'Use "Reload Catalog" to reset products to the original catalog.',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
