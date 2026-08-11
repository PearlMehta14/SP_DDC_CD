import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  List<dynamic> _stocks = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  String? _selectedQuality;
  String? _selectedKarat;
  String _selectedStatus = 'AVAILABLE';

  @override
  void initState() {
    super.initState();
    _loadStocks();
  }

  Future<void> _loadStocks() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await apiService.get('/api/v1/stock/', queryParameters: {
        if (_searchQuery.isNotEmpty) 'q': _searchQuery,
        if (_selectedQuality != null && _selectedQuality!.isNotEmpty) 'quality': _selectedQuality!,
        if (_selectedKarat != null && _selectedKarat!.isNotEmpty) 'karat': _selectedKarat!,
        'status': _selectedStatus,
      });

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _stocks = jsonDecode(response.body);
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _error = jsonDecode(response.body)['detail'] ?? 'Failed to load stock';
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('AVAILABLE STOCK', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 16)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search Product Tag...',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (value) {
                _searchQuery = value;
                _loadStocks();
              },
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Row(
              children: [
                DropdownButton<String>(
                  value: _selectedStatus,
                  hint: const Text('Status'),
                  items: const [
                    DropdownMenuItem(value: 'AVAILABLE', child: Text('Available')),
                    DropdownMenuItem(value: 'SOLD', child: Text('Sold')),
                    DropdownMenuItem(value: 'REMOVED', child: Text('Removed')),
                    DropdownMenuItem(value: 'ALL', child: Text('All')),
                  ],
                  onChanged: (val) {
                    setState(() => _selectedStatus = val!);
                    _loadStocks();
                  },
                ),
                const SizedBox(width: 16),
                DropdownButton<String>(
                  value: _selectedQuality,
                  hint: const Text('Quality'),
                  items: ['1','2','3','4','5'].map((e) => DropdownMenuItem(value: e, child: Text('Quality $e'))).toList()
                    ..insert(0, const DropdownMenuItem(value: null, child: Text('Any Quality'))),
                  onChanged: (val) {
                    setState(() => _selectedQuality = val);
                    _loadStocks();
                  },
                ),
                const SizedBox(width: 16),
                DropdownButton<String>(
                  value: _selectedKarat,
                  hint: const Text('Karat'),
                  items: ['1','2','3'].map((e) => DropdownMenuItem(value: e, child: Text('$e Kt'))).toList()
                    ..insert(0, const DropdownMenuItem(value: null, child: Text('Any Karat'))),
                  onChanged: (val) {
                    setState(() => _selectedKarat = val);
                    _loadStocks();
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFC5A059)))
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red, size: 48),
                            const SizedBox(height: 16),
                            Text(_error!, style: const TextStyle(color: Colors.red)),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadStocks,
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC5A059)),
                              child: const Text('RETRY'),
                            ),
                          ],
                        ),
                      )
                    : _stocks.isEmpty
                        ? const Center(
                            child: Text(
                              'No stock available',
                              style: TextStyle(color: Colors.grey, fontSize: 16),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadStocks,
                            color: const Color(0xFFC5A059),
                            child: ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: _stocks.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final stock = _stocks[index];
                                return InkWell(
                                  onTap: () {
                                    context.push('/stock/${stock['id']}').then((_) => _loadStocks());
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFE5E5E5)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              stock['product_tag'] ?? 'N/A',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1A1A1A)),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFFF9E8),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                stock['status'] ?? 'UNKNOWN',
                                                style: const TextStyle(color: Color(0xFFB8860B), fontSize: 12, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          'Quality: ${stock['vvs_white'] ?? ''} | ${stock['hawai_vvs'] ?? ''}',
                                          style: const TextStyle(color: Color(0xFF6B6B6B), fontSize: 14),
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text('KARAT & QTY', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                                                const SizedBox(height: 4),
                                                Text('${stock['karat']} Kt  |  ${stock['current_quantity']} items', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                              ],
                                            ),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                const Text('FINAL VALUE', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                                                const SizedBox(height: 4),
                                                Text('₹${stock['final_total_amount']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFC5A059))),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await context.push('/stock/add');
          if (result == true) {
            _loadStocks();
          }
        },
        backgroundColor: const Color(0xFF1A1A1A),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('ADD STOCK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
