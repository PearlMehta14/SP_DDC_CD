import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';

import '../utils/date_formatter.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  List<dynamic> _logs = [];
  bool _isLoading = true;
  String? _error;
  String _filterType = 'ALL';

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final res = await apiService.getLogs();
      if (res.statusCode == 200) {
        setState(() => _logs = jsonDecode(res.body) as List);
      } else {
        setState(() => _error = 'Failed to load (${res.statusCode})');
      }
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _formatKarat(int? karat, int? cent) {
    if (karat == null) return '--';
    return '$karat.${(cent ?? 0).toString().padLeft(2, '0')}';
  }

  String _formatDate(String? iso) {
    return AppDateFormatter.formatDateTime(iso);
  }

  List<dynamic> get _filtered {
    if (_filterType == 'ALL') return _logs;
    return _logs.where((l) => l['movement_type'] == _filterType).toList();
  }

  @override
  Widget build(BuildContext context) {
    final logs = _filtered;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('ACTIVITY LOGS',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFE5E5E5)),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.black87), onPressed: _loadLogs),
        ],
      ),
      body: Column(
        children: [
          // Filter row
          Container(
            color: const Color(0xFFFAFAFA),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _chip('ALL'),
                const SizedBox(width: 8),
                _chip('+'),
                const SizedBox(width: 8),
                _chip('-'),
                const Spacer(),
                Text('${logs.length}', style: const TextStyle(fontSize: 12, color: Colors.black45)),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE5E5E5)),

          // Header row
          _headerRow(),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.black54, strokeWidth: 2))
                : _error != null
                    ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                    : logs.isEmpty
                        ? const Center(child: Text('No logs.', style: TextStyle(color: Colors.black38)))
                        : RefreshIndicator(
                            onRefresh: _loadLogs,
                            color: Colors.black,
                            child: ListView.separated(
                              itemCount: logs.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1, color: Color(0xFFEEEEEE)),
                              itemBuilder: (context, i) {
                                final log = logs[i];
                                final isAdd = log['movement_type'] == 'ADDED';
                                final sign = isAdd ? '+' : '−';
                                final changeKt = _formatKarat(log['change_karat'], log['change_cent']);
                                final prevKt = _formatKarat(log['previous_karat'], log['previous_cent']);
                                final newKt = _formatKarat(log['new_karat'], log['new_cent']);
                                final cat = log['stock_category'] ?? '';
                                final type = (cat == 'EXTRA') ? '' : (log['stock_type'] ?? '');
                                final product = log['product_tag'] ?? '';
                                final user = log['changed_by_name'] ?? '';
                                final date = _formatDate(log['changed_at']?.toString());

                                return Container(
                                  color: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      // Sign
                                      SizedBox(
                                        width: 24,
                                        child: Text(
                                          sign,
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      // Main info
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // Product line
                                            Text(
                                              [cat, type, product].where((s) => s.isNotEmpty).join('  '),
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.black87,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            // Karat change
                                            Text(
                                              '$prevKt  →  $newKt  ($sign$changeKt KT)',
                                              style: const TextStyle(fontSize: 12, color: Colors.black54),
                                            ),
                                            const SizedBox(height: 2),
                                            // User + date
                                            Text(
                                              '$user  •  $date',
                                              style: const TextStyle(fontSize: 11, color: Colors.black38),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _headerRow() {
    return Container(
      color: const Color(0xFFF9F9F9),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: const Row(
        children: [
          SizedBox(width: 34),
          Text('PRODUCT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54, letterSpacing: 0.5)),
          Spacer(),
          Text('BY  •  DATE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _chip(String label) {
    String apiVal;
    if (label == '+') apiVal = 'ADDED';
    else if (label == '-') apiVal = 'REMOVED';
    else apiVal = 'ALL';

    final selected = _filterType == apiVal;
    return GestureDetector(
      onTap: () => setState(() => _filterType = apiVal),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? Colors.black : const Color(0xFFDDDDDD)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: selected ? Colors.white : Colors.black54,
          ),
        ),
      ),
    );
  }
}
