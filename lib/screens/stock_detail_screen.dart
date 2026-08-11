import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';

class StockDetailScreen extends StatefulWidget {
  final String stockId;
  const StockDetailScreen({super.key, required this.stockId});

  @override
  State<StockDetailScreen> createState() => _StockDetailScreenState();
}

class _StockDetailScreenState extends State<StockDetailScreen> {
  Map<String, dynamic>? _stock;
  Map<String, dynamic>? _history;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final stockRes = await apiService.getStock(widget.stockId);
      final histRes = await apiService.getStockHistory(widget.stockId);

      if (stockRes.statusCode == 200 && histRes.statusCode == 200) {
        if (mounted) {
          setState(() {
            _stock = jsonDecode(stockRes.body);
            _history = jsonDecode(histRes.body);
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _error = 'Failed to load stock data';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _changeQuantity() async {
    final qtyController = TextEditingController();
    final reasonController = TextEditingController();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Adjust Quantity'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current Quantity: ${_stock!['current_quantity']}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text('Enter adjustment (e.g. +5 or -3):'),
            TextField(
              controller: qtyController,
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              decoration: const InputDecoration(labelText: 'Change Amount'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(labelText: 'Reason (Required)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => context.pop(false), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () => context.pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC5A059)),
            child: const Text('SAVE'),
          ),
        ],
      )
    );

    if (result == true) {
      final changeStr = qtyController.text.trim();
      final reason = reasonController.text.trim();
      
      if (changeStr.isEmpty || reason.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Both change amount and reason are required.')));
        return;
      }

      final changeQty = int.tryParse(changeStr);
      if (changeQty != null) {
        setState(() => _isLoading = true);
        final response = await apiService.updateStockQuantity(widget.stockId, changeQty, reason: reason);
        if (response.statusCode != 200) {
          final error = jsonDecode(response.body)['detail'] ?? 'Failed to adjust quantity';
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
        }
        _loadData();
      }
    }
  }

  Future<void> _changePrice() async {
    final priceController = TextEditingController(text: _stock!['current_price_per_karat'].toString());
    final reasonController = TextEditingController();
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Price/Karat'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Current Price/Karat: ₹${_stock!['current_price_per_karat']}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'New Price/Karat'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(labelText: 'Reason (Required)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => context.pop(false), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () => context.pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC5A059)),
            child: const Text('SAVE'),
          ),
        ],
      )
    );

    if (result == true) {
      final newPrice = priceController.text.trim();
      final reason = reasonController.text.trim();
      if (newPrice.isNotEmpty && reason.isNotEmpty) {
        setState(() => _isLoading = true);
        final response = await apiService.updateStockPrice(widget.stockId, newPrice, reason: reason);
        if (response.statusCode != 200) {
          final error = jsonDecode(response.body)['detail'] ?? 'Failed to change price';
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
        }
        _loadData();
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Both new price and reason are required.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(backgroundColor: Colors.white, body: Center(child: CircularProgressIndicator(color: Color(0xFFC5A059))));
    }
    if (_error != null) {
      return Scaffold(backgroundColor: Colors.white, body: Center(child: Text(_error!, style: const TextStyle(color: Colors.red))));
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFFAFAF8),
        appBar: AppBar(
          title: const Text('Stock Detail', style: TextStyle(color: Colors.black)),
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black),
          bottom: const TabBar(
            labelColor: Color(0xFFC5A059),
            unselectedLabelColor: Colors.grey,
            indicatorColor: Color(0xFFC5A059),
            tabs: [
              Tab(text: 'DETAILS'),
              Tab(text: 'HISTORY'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildDetailsTab(),
            _buildHistoryTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          _buildSection('CURRENT', [
            _buildInfoRow('Current Quantity', '${_stock!['current_quantity']}', onEdit: _changeQuantity, isHighlight: true),
            _buildInfoRow('Current Price/Karat', '₹${_stock!['current_price_per_karat']}', onEdit: _changePrice, isHighlight: true),
            _buildInfoRow('Status', '${_stock!['status']}'),
          ]),
          _buildSection('BASE', [
            _buildInfoRow('Base Price/Karat', '₹${_stock!['current_price_per_karat']}'),
            _buildInfoRow('Base Total', '₹${_stock!['base_total_amount']}'),
          ]),
          _buildSection('LESS', [
            _buildInfoRow('Less %', '${_stock!['less_percentage']}%'),
            _buildInfoRow('Less Price/Karat', '₹${_stock!['less_price_per_karat']}'),
            _buildInfoRow('Less Total', '₹${_stock!['less_total_amount']}'),
          ]),
          _buildSection('BROKERAGE', [
            _buildInfoRow('Brokerage %', '${_stock!['brokerage_percentage']}%'),
            _buildInfoRow('Brok Price/Karat', '₹${_stock!['brokerage_price_per_karat']}'),
            _buildInfoRow('Brok Total', '₹${_stock!['brokerage_total_amount']}'),
          ]),
          _buildSection('FINAL', [
            _buildInfoRow('Final Price/Karat', '₹${_stock!['final_price_per_karat']}', isHighlight: true, highlightColor: const Color(0xFFC5A059)),
            _buildInfoRow('Final Total Amount', '₹${_stock!['final_total_amount']}', isHighlight: true, isLarge: true, highlightColor: const Color(0xFFC5A059)),
          ], isPremium: true),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _stock!['product_tag'],
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildTag('Karat: ${_stock!['karat']} Kt'),
            const SizedBox(width: 8),
            _buildTag('VVS: ${_stock!['vvs_white'] ?? 'N/A'}'),
            const SizedBox(width: 8),
            _buildTag('Hawai: ${_stock!['hawai_vvs'] ?? 'N/A'}'),
          ],
        ),
        if (_stock!['quality_cat_1'] != null || _stock!['quality_cat_2'] != null || _stock!['quality_cat_3'] != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              if (_stock!['quality_cat_1'] != null) _buildTag('C1: ${_stock!['quality_cat_1']}'),
              const SizedBox(width: 8),
              if (_stock!['quality_cat_2'] != null) _buildTag('C2: ${_stock!['quality_cat_2']}'),
              const SizedBox(width: 8),
              if (_stock!['quality_cat_3'] != null) _buildTag('C3: ${_stock!['quality_cat_3']}'),
            ],
          ),
        ]
      ],
    );
  }

  Widget _buildTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E5E5)),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12, color: Color(0xFF6B6B6B))),
    );
  }

  Widget _buildSection(String title, List<Widget> children, {bool isPremium = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: isPremium ? const Color(0xFFF9F6F0) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isPremium ? const Color(0xFFC5A059) : const Color(0xFFE5E5E5), width: isPremium ? 2 : 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isPremium ? const Color(0xFFC5A059).withValues(alpha: 0.1) : Colors.grey.shade50,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(10), topRight: Radius.circular(10)),
              border: Border(bottom: BorderSide(color: isPremium ? const Color(0xFFC5A059).withValues(alpha: 0.3) : const Color(0xFFE5E5E5))),
            ),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isPremium ? const Color(0xFFC5A059) : Colors.black87,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {VoidCallback? onEdit, bool isHighlight = false, Color highlightColor = Colors.black, bool isLarge = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
          Row(
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: isLarge ? 22 : (isHighlight ? 16 : 14),
                  fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
                  color: isHighlight ? highlightColor : Colors.black87,
                ),
              ),
              if (onEdit != null) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: onEdit,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF9E8),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.edit, size: 16, color: Color(0xFFC5A059)),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            child: const TabBar(
              labelColor: Colors.black,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.black,
              labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              tabs: [
                Tab(text: 'QUANTITY'),
                Tab(text: 'PRICE'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildQuantityHistory(),
                _buildPriceHistory(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityHistory() {
    final movements = _history!['movements'] as List<dynamic>;
    if (movements.isEmpty) return const Center(child: Text('No quantity movements.'));

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: movements.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        final m = movements[index];
        final isAdd = m['change_quantity'] > 0;
        final change = isAdd ? '+${m['change_quantity']}' : '${m['change_quantity']}';
        final color = isAdd ? Colors.green.shade600 : Colors.red.shade600;

        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Qty: ${m['previous_quantity']} → ${m['new_quantity']}', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(change, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Reason: ${m['reason']}'),
                const SizedBox(height: 4),
                Text('By: ${m['changed_by']} • ${DateTime.parse(m['changed_at']).toLocal().toString().split('.')[0]}', style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPriceHistory() {
    final prices = _history!['price_history'] as List<dynamic>;
    if (prices.isEmpty) return const Center(child: Text('No price changes.'));

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: prices.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        final p = prices[index];

        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Price: ₹${p['previous_price_per_karat']} → ₹${p['new_price_per_karat']}', style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Reason: ${p['reason']}'),
                const SizedBox(height: 4),
                Text('By: ${p['changed_by']} • ${DateTime.parse(p['changed_at']).toLocal().toString().split('.')[0]}', style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        );
      },
    );
  }
}
