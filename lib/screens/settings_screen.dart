import 'package:flutter/material.dart';
import '../services/config_service.dart';
import '../data/seed_data.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final email = await ConfigService.instance.getRecipientEmail();
    setState(() {
      _emailController.text = email;
      _isLoading = false;
    });
  }

  Future<void> _seedProducts({required bool clearExisting}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(clearExisting ? 'Replace All Products?' : 'Add Products?'),
        content: Text(clearExisting
            ? 'This will delete all existing products and replace them with the Gagan Foods catalog.'
            : 'This will add ${SeedData.gaganFoodsProducts.length} Gagan Foods products to your catalog.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final count = await SeedData.seedProducts(clearExisting: clearExisting);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$count products loaded successfully')),
      );
    }
  }

  Future<void> _saveSettings() async {
    await ConfigService.instance.setRecipientEmail(_emailController.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveSettings,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Email Configuration',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This email will be used as the default recipient when sending orders.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Recipient Email',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _saveSettings,
                  child: const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('Save Settings'),
                  ),
                ),
                const Divider(height: 48),
                const Text(
                  'Product Data',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Load Gagan Foods product catalog (13 categories, 90+ products). This will add products without removing existing ones.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => _seedProducts(clearExisting: false),
                  icon: const Icon(Icons.add_shopping_cart),
                  label: const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('Add Gagan Foods Products'),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _seedProducts(clearExisting: true),
                  icon: const Icon(Icons.refresh),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.orange),
                  label: const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('Replace All with Gagan Foods'),
                  ),
                ),
              ],
            ),
    );
  }
}
