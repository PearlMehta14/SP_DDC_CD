import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:decimal/decimal.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _metrics;

  @override
  void initState() {
    super.initState();
    _fetchDashboard();
  }

  Future<void> _fetchDashboard() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      
      final endpoint = dateStr == todayStr 
          ? '/api/v1/dashboard/today' 
          : '/api/v1/dashboard/?date=$dateStr';
          
      final response = await apiService.get(endpoint);
      
      if (response.statusCode == 200) {
        setState(() {
          _metrics = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        throw Exception(jsonDecode(response.body)['detail'] ?? 'Failed to load dashboard');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFD4AF37),
              onPrimary: Colors.white,
              onSurface: Color(0xFF1A1A1A),
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
      _fetchDashboard();
    }
  }

  String _formatKarat(String val) {
    try {
      final d = Decimal.parse(val);
      return d.toStringAsFixed(2);
    } catch (_) {
      return '0.00';
    }
  }

  String _formatCurrency(String val) {
    try {
      final d = Decimal.parse(val);
      final formatter = NumberFormat.currency(
        locale: 'en_IN',
        symbol: '₹ ',
        decimalDigits: 2,
      );
      // We parse it as a double just for the NumberFormat, but we can also use custom string manipulation if double precision loss is unacceptable for display.
      // Since it's for display format, double is usually okay, but for exact string formatting it's better to avoid double.
      // Using intl package format on double is okay for display.
      return formatter.format(d.toDouble());
    } catch (_) {
      return '₹ 0.00';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final isToday = DateFormat('yyyy-MM-dd').format(_selectedDate) == DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAF8),
      appBar: AppBar(
        title: const Text(
          'DDC DIAMONDS',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: const Color(0xFFE5E5E5),
            height: 1.0,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchDashboard,
        color: const Color(0xFFD4AF37),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome, ${user?['name'] ?? 'User'}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: () => _selectDate(context),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                isToday ? 'Today' : DateFormat('dd MMM yyyy').format(_selectedDate),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFD4AF37),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.calendar_today, size: 14, color: Color(0xFFD4AF37)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Image.asset(
                    'assets/images/logo.jpeg',
                    width: 100,
                    height: 100,
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Dashboard Content
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(color: Color(0xFFD4AF37)),
                  ),
                )
              else if (_error != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF9E8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFD4AF37)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Color(0xFFB8860B)),
                      const SizedBox(width: 12),
                      Expanded(child: Text(_error!, style: const TextStyle(color: Color(0xFFB8860B)))),
                    ],
                  ),
                )
              else if (_metrics != null && _metrics!['available_stock_count'] == 0 && _metrics!['stock_added_today'] == 0 && _metrics!['stock_removed_today'] == 0)
                // Empty State
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 64, horizontal: 32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5E5E5)),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 48, color: Color(0xFFE5E5E5)),
                      SizedBox(height: 16),
                      Text(
                        'No stock recorded',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'No stock has been added for this date.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF6B6B6B)),
                      ),
                    ],
                  ),
                )
              else
                // Metrics
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Main Value Card
                    _buildValueCard(
                      'TOTAL STOCK VALUE',
                      _formatCurrency(_metrics!['total_value'] ?? '0'),
                    ),
                    const SizedBox(height: 16),
                    
                    // Grid Metrics
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            'AVAILABLE STOCK',
                            '${_metrics!['available_stock_count'] ?? 0}',
                            'Items',
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildMetricCard(
                            'TOTAL KARAT',
                            _formatKarat(_metrics!['total_karat'] ?? '0'),
                            'Ct',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildMetricCard(
                      'TOTAL QUANTITY',
                      '${_metrics!['total_quantity'] ?? 0}',
                      'Pcs',
                    ),
                    const SizedBox(height: 32),

                    // Today's Movement
                    const Text(
                      "TODAY'S STOCK",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        color: Color(0xFF6B6B6B),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE5E5E5)),
                      ),
                      child: Column(
                        children: [
                          _buildMovementRow(
                            'Added Today', 
                            '+ ${_metrics!['stock_added_today'] ?? 0}',
                            const Color(0xFFD4AF37)
                          ),
                          const Divider(height: 24, color: Color(0xFFE5E5E5)),
                          _buildMovementRow(
                            'Removed Today', 
                            '- ${_metrics!['stock_removed_today'] ?? 0}',
                            Colors.red.shade400
                          ),
                          const Divider(height: 24, color: Color(0xFFE5E5E5)),
                          _buildMovementRow(
                            'Price Changes Today', 
                            '${_metrics!['price_changes_today'] ?? 0}',
                            Colors.blue.shade600
                          ),
                          const Divider(height: 24, color: Color(0xFFE5E5E5)),
                          _buildMovementRow(
                            'Current Available', 
                            '${_metrics!['available_stock_count'] ?? 0}',
                            const Color(0xFF1A1A1A)
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildValueCard(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFD4AF37),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, String unit) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E5E5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
              color: Color(0xFF6B6B6B),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  unit,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFB8860B),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMovementRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            color: Color(0xFF6B6B6B),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
