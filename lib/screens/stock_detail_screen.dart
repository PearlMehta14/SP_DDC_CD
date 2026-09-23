import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/date_formatter.dart';

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
          _buildSection('CURRENT STOCK', [
            _buildInfoRow('Stock Amount', '${(_stock!['karat'] + _stock!['cent'] / 100.0).toStringAsFixed(2)} KT', isHighlight: true),
            _buildInfoRow('Current Price/Karat', '₹${_stock!['current_price_per_karat']}', isHighlight: true),
            _buildInfoRow('Status', '${_stock!['status']}'),
          ]),
          _buildSection('PRICING', [
            _buildInfoRow('Base Total', '₹${_stock!['base_total_amount']}'),
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
            _buildTag('Stock: ${(_stock!['karat'] + _stock!['cent'] / 100.0).toStringAsFixed(2)} KT'),
            const SizedBox(width: 8),
            if (_stock!['vvs_white'] != null && _stock!['vvs_white'].toString().isNotEmpty) _buildTag('HAWA: ${_stock!['vvs_white']}'),
            const SizedBox(width: 8),
            if (_stock!['hawai_vvs'] != null && _stock!['hawai_vvs'].toString().isNotEmpty) _buildTag('AIR: ${_stock!['hawai_vvs']}'),
          ],
        ),
        if ((_stock!['quality_cat_1'] != null && _stock!['quality_cat_1'].toString().isNotEmpty) || 
            (_stock!['quality_cat_2'] != null && _stock!['quality_cat_2'].toString().isNotEmpty) || 
            (_stock!['quality_cat_3'] != null && _stock!['quality_cat_3'].toString().isNotEmpty)) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              if (_stock!['quality_cat_1'] != null && _stock!['quality_cat_1'].toString().isNotEmpty) _buildTag('ORN: ${_stock!['quality_cat_1']}'),
              const SizedBox(width: 8),
              if (_stock!['quality_cat_2'] != null && _stock!['quality_cat_2'].toString().isNotEmpty) _buildTag('COLL: ${_stock!['quality_cat_2']}'),
              const SizedBox(width: 8),
              if (_stock!['quality_cat_3'] != null && _stock!['quality_cat_3'].toString().isNotEmpty) _buildTag('Q1: ${_stock!['quality_cat_3']}'),
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

  Widget _buildInfoRow(String label, String value, {bool isHighlight = false, Color highlightColor = Colors.black, bool isLarge = false, VoidCallback? onTap}) {
    Widget row = Padding(
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
              if (onTap != null) ...[
                const SizedBox(width: 8),
                const Icon(Icons.edit, size: 16, color: Color(0xFFC5A059)),
              ]
            ],
          ),
        ],
      ),
    );
    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: row,
        ),
      );
    }
    return row;
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
                Tab(text: 'STOCK'),
                Tab(text: 'PRICE'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildKaratHistory(),
                _buildPriceHistory(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKaratHistory() {
    final movements = _history!['movements'] as List<dynamic>;
    if (movements.isEmpty) return const Center(child: Text('No stock movements.'));

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: movements.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        final m = movements[index];
        final isAdd = m['movement_type'] == 'ADDED';
        final effectiveChange = (m['change_karat'] + m['change_cent'] / 100.0).toStringAsFixed(2);
        final changeStr = (isAdd ? '+' : '-') + '$effectiveChange KT';

        final prevVal = (m['previous_karat'] + m['previous_cent'] / 100.0).toStringAsFixed(2);
        final newVal = (m['new_karat'] + m['new_cent'] / 100.0).toStringAsFixed(2);

        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(backgroundColor: isAdd ? Colors.green.shade50 : Colors.red.shade50, child: Icon(isAdd ? Icons.arrow_upward : Icons.arrow_downward, color: isAdd ? Colors.green : Colors.red)),
          title: Text('$prevVal KT → $newVal KT', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          trailing: Text(changeStr, style: TextStyle(color: isAdd ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 14)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Reason: ${m['reason']}'),
                const SizedBox(height: 4),
                Text('By: ${m['changed_by']} • ${AppDateFormatter.formatDateTime(m['changed_at'])}', style: const TextStyle(fontSize: 12)),
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
                Text('By: ${p['changed_by']} • ${AppDateFormatter.formatDateTime(p['changed_at'])}', style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        );
      },
    );
  }
}
