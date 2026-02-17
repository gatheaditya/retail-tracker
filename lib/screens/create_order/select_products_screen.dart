import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../database/database_helper.dart';
import '../../models/client.dart';
import '../../models/product.dart';
import 'cart_item.dart';
import 'order_summary_screen.dart';

class SelectProductsScreen extends StatefulWidget {
  final Client client;

  const SelectProductsScreen({
    super.key,
    required this.client,
  });

  @override
  State<SelectProductsScreen> createState() => _SelectProductsScreenState();
}

class _SelectProductsScreenState extends State<SelectProductsScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  List<String> _categories = [];
  String? _selectedCategory;
  final TextEditingController _searchController = TextEditingController();
  final Map<String, CartItem> _cart = {};

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _searchController.addListener(_filterProducts);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    final products = await _dbHelper.getAllProducts();
    final categories = await _dbHelper.getDistinctCategories();
    setState(() {
      _products = products;
      _categories = categories;
      _filterProducts();
    });
  }

  void _filterProducts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      var filtered = _products.toList();

      // Filter by selected category
      if (_selectedCategory != null) {
        filtered = filtered
            .where((product) => product.category == _selectedCategory)
            .toList();
      }

      // Filter by search query
      if (query.isNotEmpty) {
        filtered = filtered
            .where((product) =>
                product.name.toLowerCase().contains(query) ||
                (product.description.isNotEmpty &&
                    product.description.toLowerCase().contains(query)) ||
                (product.sku.isNotEmpty &&
                    product.sku.toLowerCase().contains(query)))
            .toList();
      }

      _filteredProducts = filtered;
    });
  }

  void _addToCart(Product product) {
    setState(() {
      if (_cart.containsKey(product.id)) {
        _cart[product.id!]!.quantity++;
      } else {
        _cart[product.id!] = CartItem(product: product, quantity: 1);
      }
    });
  }

  void _updateQuantity(Product product, int quantity) {
    setState(() {
      if (quantity <= 0) {
        _cart.remove(product.id);
      } else {
        _cart[product.id!] = _cart[product.id!]!.copyWith(quantity: quantity);
      }
    });
  }

  void _removeFromCart(Product product) {
    setState(() {
      _cart.remove(product.id);
    });
  }

  int get _cartItemCount => _cart.values.fold(0, (sum, item) => sum + item.quantity);

  double get _cartTotal =>
      _cart.values.fold(0, (sum, item) => sum + item.totalPrice);

  String _formatPrice(double price) {
    return NumberFormat.currency(symbol: '\$').format(price);
  }

  Map<String, List<Product>> _groupByCategory() {
    final grouped = <String, List<Product>>{};
    for (final product in _filteredProducts) {
      final category = product.category.isEmpty ? 'General' : product.category;
      grouped.putIfAbsent(category, () => []).add(product);
    }
    // Sort categories alphabetically, but put "General" last
    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) {
        if (a == 'General') return 1;
        if (b == 'General') return -1;
        return a.compareTo(b);
      });
    return {for (final key in sortedKeys) key: grouped[key]!};
  }

  Widget _buildGroupedProductList() {
    final grouped = _groupByCategory();
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: grouped.entries.fold<int>(0, (sum, entry) => sum + 1 + entry.value.length),
      itemBuilder: (context, index) {
        int currentIndex = 0;
        for (final entry in grouped.entries) {
          if (index == currentIndex) {
            // Category header
            return Padding(
              padding: EdgeInsets.only(
                top: currentIndex == 0 ? 0 : 16,
                bottom: 8,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.category,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    entry.key,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Divider(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                    ),
                  ),
                ],
              ),
            );
          }
          currentIndex++;
          if (index < currentIndex + entry.value.length) {
            final product = entry.value[index - currentIndex];
            return _buildProductCard(product);
          }
          currentIndex += entry.value.length;
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildProductCard(Product product) {
    final cartItem = _cart[product.id];
    final isInCart = cartItem != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  if (product.description.isNotEmpty)
                    Text(
                      product.description,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (product.sku.isNotEmpty)
                    Text(
                      'SKU: ${product.sku}',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                  Text(
                    _formatPrice(product.price),
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .primary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (!isInCart)
              ElevatedButton.icon(
                onPressed: () => _addToCart(product),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove, size: 18),
                      onPressed: () => _updateQuantity(
                        product,
                        cartItem.quantity - 1,
                      ),
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                    ),
                    Text(
                      '${cartItem.quantity}',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, size: 18),
                      onPressed: () => _updateQuantity(
                        product,
                        cartItem.quantity + 1,
                      ),
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _proceedToSummary() {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one product')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderSummaryScreen(
          client: widget.client,
          cartItems: _cart.values.toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Products'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search products...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Client info header
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
            child: Row(
              children: [
                Icon(
                  Icons.person,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Client:',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                      Text(
                        widget.client.name,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Cart summary
          if (_cart.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.3),
              child: Row(
                children: [
                  Icon(
                    Icons.shopping_cart,
                    size: 20,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$_cartItemCount items',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const Spacer(),
                  Text(
                    'Total: ${_formatPrice(_cartTotal)}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                  ),
                ],
              ),
            ),
          // Category filter chips
          if (_categories.isNotEmpty)
            Container(
              height: 50,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _categories.length + 1, // +1 for "All" chip
                itemBuilder: (context, index) {
                  if (index == 0) {
                    final isSelected = _selectedCategory == null;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text('All (${_products.length})'),
                        selected: isSelected,
                        onSelected: (_) {
                          setState(() {
                            _selectedCategory = null;
                            _filterProducts();
                          });
                        },
                      ),
                    );
                  }
                  final category = _categories[index - 1];
                  final isSelected = _selectedCategory == category;
                  final count = _products
                      .where((p) => p.category == category)
                      .length;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text('$category ($count)'),
                      selected: isSelected,
                      onSelected: (_) {
                        setState(() {
                          _selectedCategory = isSelected ? null : category;
                          _filterProducts();
                        });
                      },
                    ),
                  );
                },
              ),
            ),
          // Product list grouped by category
          Expanded(
            child: _filteredProducts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 64,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchController.text.isEmpty
                              ? 'No products yet'
                              : 'No matching products',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        if (_searchController.text.isEmpty)
                          const SizedBox(height: 8),
                        if (_searchController.text.isEmpty)
                          Text(
                            'Add products from the Products section',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                      ],
                    ),
                  )
                : _buildGroupedProductList(),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$_cartItemCount items',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      _formatPrice(_cartTotal),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: _cart.isNotEmpty ? _proceedToSummary : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                child: const Row(
                  children: [
                    Text('Review Order'),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
