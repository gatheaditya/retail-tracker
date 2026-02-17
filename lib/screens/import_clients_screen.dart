import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../utils/excel_helper.dart';
import 'dart:developer' as developer;

class ImportClientsScreen extends StatefulWidget {
  const ImportClientsScreen({super.key});

  @override
  State<ImportClientsScreen> createState() => _ImportClientsScreenState();
}

class _ImportClientsScreenState extends State<ImportClientsScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  bool _isLoading = false;
  String _statusMessage = 'Ready to import clients';
  int _clientCount = 0;

  @override
  void initState() {
    super.initState();
    _loadClientCount();
  }

  Future<void> _loadClientCount() async {
    final clients = await _dbHelper.getAllClients();
    if (mounted) {
      setState(() {
        _clientCount = clients.length;
        if (_clientCount > 0) {
          _statusMessage = '$_clientCount clients in database';
        }
      });
    }
  }

  Future<void> _importFromBundledExcel() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Loading clients catalog...';
    });

    try {
      final count = await ExcelHelper.seedClientsFromAsset();
      if (count > 0) {
        _statusMessage = 'Imported $count clients successfully';
      } else {
        _statusMessage = 'Clients already loaded ($_clientCount in database)';
      }
      await _loadClientCount();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(count > 0
                ? '$count clients imported successfully'
                : 'Clients already loaded'),
          ),
        );
      }
    } catch (e) {
      developer.log('Error importing clients: $e',
          name: 'ImportClientsScreen', level: 1000);
      if (mounted) {
        setState(() {
          _statusMessage = 'Error: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error importing clients: $e')),
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
        title: const Text('Reload Clients'),
        content: const Text(
          'This will delete all existing clients and reload from the Excel catalog. Continue?',
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
      _statusMessage = 'Clearing existing clients...';
    });

    try {
      // Delete all existing clients
      final existing = await _dbHelper.getAllClients();
      for (final client in existing) {
        if (client.id != null) {
          await _dbHelper.deleteClient(client.id!);
        }
      }

      setState(() {
        _statusMessage = 'Reloading from Excel catalog...';
      });

      final count = await ExcelHelper.seedClientsFromAsset();
      _statusMessage = 'Reloaded $count clients successfully';
      await _loadClientCount();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reloaded $count clients')),
        );
      }
    } catch (e) {
      developer.log('Error reloading clients: $e',
          name: 'ImportClientsScreen', level: 1000);
      if (mounted) {
        setState(() {
          _statusMessage = 'Error: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error reloading clients: $e')),
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
        title: const Text('Import Clients'),
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
                    const Icon(Icons.people_alt,
                        size: 64, color: Colors.blue),
                    const SizedBox(height: 16),
                    Text(
                      _statusMessage,
                      style: Theme.of(context).textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                    if (_clientCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '$_clientCount clients in database',
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
                            icon: const Icon(Icons.file_download),
                            label: const Text('Import Clients from Excel'),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _reloadFromExcel,
                            icon: const Icon(Icons.refresh),
                            label:
                                const Text('Reload Clients (Clear & Re-import)'),
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
                      'Clients Excel Format',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'The Excel file should have the following columns:\n'
                      'Column A: Name\n'
                      'Column B: Phone\n'
                      'Column C: Email\n'
                      'Column D: Address\n\n'
                      'The first row is assumed to be a header and is skipped.',
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
