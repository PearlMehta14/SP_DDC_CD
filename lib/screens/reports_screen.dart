import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _historyData;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final response = await apiService.getDailyHistory(dateStr);

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _historyData = jsonDecode(response.body);
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _error = jsonDecode(response.body)['detail'] ?? 'Failed to load history';
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

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFC5A059),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAF8),
      appBar: AppBar(
        title: const Text('REPORTS', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: const Color(0xFFE5E5E5), height: 1.0),
        ),
      ),
      body: Column(
        children: [
          // Date Picker Header
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Date-wise History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                InkWell(
                  onTap: () => _selectDate(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF9E8),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFC5A059).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 16, color: Color(0xFFC5A059)),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('dd MMM yyyy').format(_selectedDate),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFB8860B)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFC5A059)))
                : _error != null
                    ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                    : _buildHistoryContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryContent() {
    final movements = _historyData!['quantity_movements'] as List<dynamic>;
    final priceChanges = _historyData!['price_changes'] as List<dynamic>;

    final added = movements.where((m) => m['change_quantity'] > 0).toList();
    final reduced = movements.where((m) => m['change_quantity'] < 0).toList();

    if (added.isEmpty && reduced.isEmpty && priceChanges.isEmpty) {
      return const Center(
        child: Text('No stock activity on this date.', style: TextStyle(color: Colors.grey, fontSize: 16)),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary Cards
        Row(
          children: [
            Expanded(child: _buildSummaryCard('Added Qty', '${_historyData!['added_quantity']}', Colors.green)),
            const SizedBox(width: 12),
            Expanded(child: _buildSummaryCard('Reduced Qty', '${_historyData!['removed_quantity']}', Colors.red)),
            const SizedBox(width: 12),
            Expanded(child: _buildSummaryCard('Price Edits', '${priceChanges.length}', Colors.blue)),
          ],
        ),
        const SizedBox(height: 24),

        if (added.isNotEmpty) _buildSection('STOCK ADDED', added, true),
        if (reduced.isNotEmpty) _buildSection('STOCK REDUCED', reduced, true),
        if (priceChanges.isNotEmpty) _buildSection('PRICE CHANGES', priceChanges, false),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E5E5)),
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<dynamic> items, bool isQuantity) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54, letterSpacing: 1.2),
          ),
        ),
        ...items.map((item) => isQuantity ? _buildQuantityItem(item) : _buildPriceItem(item)),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildQuantityItem(dynamic m) {
    final isAdd = m['change_quantity'] > 0;
    final change = isAdd ? '+${m['change_quantity']}' : '${m['change_quantity']}';
    final color = isAdd ? Colors.green.shade600 : Colors.red.shade600;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFE5E5E5)),
      ),
      child: ListTile(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(m['product_tag'], style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(change, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${m['previous_quantity']} → ${m['new_quantity']}', style: const TextStyle(color: Colors.black87)),
              const SizedBox(height: 4),
              Text('Reason: ${m['reason']}'),
              const SizedBox(height: 4),
              Text('By: ${m['changed_by']} • ${DateTime.parse(m['changed_at']).toLocal().toString().split('.')[0]}', style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriceItem(dynamic p) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFE5E5E5)),
      ),
      child: ListTile(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(p['product_tag'], style: const TextStyle(fontWeight: FontWeight.bold)),
            const Icon(Icons.currency_rupee, size: 16, color: Colors.blue),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('₹${p['previous_price_per_karat']} → ₹${p['new_price_per_karat']}', style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Reason: ${p['reason']}'),
              const SizedBox(height: 4),
              Text('By: ${p['changed_by']} • ${DateTime.parse(p['changed_at']).toLocal().toString().split('.')[0]}', style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
