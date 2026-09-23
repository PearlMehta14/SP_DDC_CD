import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:decimal/decimal.dart';
import '../services/api_service.dart';

class _BatchRowData {
  final TextEditingController productName = TextEditingController();
  final TextEditingController karat = TextEditingController();
  final TextEditingController price = TextEditingController();
  String? rowError;
  bool isSuccess = false;

  _BatchRowData(String pName) {
    productName.text = pName;
  }

  void dispose() {
    productName.dispose();
    karat.dispose();
    price.dispose();
  }

  bool get hasData => productName.text.trim().isNotEmpty && (karat.text.trim().isNotEmpty || price.text.trim().isNotEmpty);
}

const List<String> minus2Products = [
  'Hava VVS', 'Hava Dagina', 'Hava Jew', 'Hava S Dlx', 'Hava Dlx',
  'Air VVS', 'Air Dagina', 'Air Jew', 'Air S Dlx', 'Air Dlx',
  'Coll VVS', 'Coll Dagina', 'Coll Jew', 'Coll S Dlx', 'Coll Dlx',
  'Orn VVS', 'Orn Dagina', 'Orn Jew', 'Orn S Dlx', 'Orn Dlx',
  'Super VVS', 'Super Dagina', 'Super Jew', 'Super S Dlx', 'Super Dlx',
  'White VVS', 'White Dagina', 'White Jew'
];

const List<String> plus2Products = [
  'Hava VVS', 'Hava Dagina', 'Hava Jew', 'Hava S Dlx', 'Hava Dlx',
  'Air VVS', 'Air Dagina', 'Air Jew', 'Air S Dlx', 'Air Dlx',
  'Coll VVS', 'Coll Dagina', 'Coll Jew', 'Coll S Dlx', 'Coll Dlx',
  'Orn VVS', 'Orn Dagina', 'Orn Jew', 'Orn S Dlx', 'Orn Dlx',
  'White VVS', 'White Dagina', 'White Jew'
];

const List<String> oldMinus2Products = [
  'Hava 3', 'hava 4', 'hava 5', 'air 3', 'air 4', 'air 5', 'col 2', 'col 3', 'col 4', 'col 5', 'Ex 3', 'Ex 4'
];

const List<String> oldPlus2Products = [
  'air 2', 'air 3', 'air 5', 'col 2', 'col 3', 'col 4', 'Ex 1', 'Ex 2', 'Ex 3', 'Ex 4', 'Ex 5'
];

const List<String> extraProducts = [
  'Mix', 'Natts', 'LC 1', 'LC 2', 'LC 3', 'Bud', 'Weak', 'ws -2'
];


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
  String _selectedStatus = 'ALL';
  
  String _selectedCategory = 'ALL';
  String _selectedType = 'ALL';

  bool _isAddingStock = false;
  String _batchCategory = 'NEW';
  String _batchType = '-2';
  List<_BatchRowData> _batchRows = [];
  bool _isSavingBatch = false;
  
  final TextEditingController _batchLess = TextEditingController(text: '5');
  final TextEditingController _batchBrokerage = TextEditingController(text: '1');

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
        if (_selectedCategory != 'ALL') 'category': _selectedCategory,
        if (_selectedStatus != 'ALL') 'status': _selectedStatus,
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

  void _initBatchRows() {
    for (var r in _batchRows) {
      r.dispose();
    }

    List<String> products;
    if (_batchCategory == 'EXTRA') {
      products = extraProducts;
    } else if (_batchCategory == 'OLD') {
      products = _batchType == '-2' ? oldMinus2Products : oldPlus2Products;
    } else {
      products = _batchType == '-2' ? minus2Products : plus2Products;
    }

    _batchRows = products.map((p) {
      final row = _BatchRowData(p);
      // Pre-fill from existing stock if available
      final existing = _stocks.where((s) {
        if (s['stock_category'] != _batchCategory) return false;
        if (_batchCategory != 'EXTRA' && s['stock_type'] != _batchType) return false;
        return s['product_tag'] == p;
      });
      if (existing.isNotEmpty) {
        final s = existing.first;
        final kt = '${s['karat']}.${(s['cent'] ?? 0).toString().padLeft(2, '0')}';
        row.karat.text = kt;
        row.price.text = s['current_price_per_karat']?.toString() ?? '';
      }
      return row;
    }).toList();

    if (mounted) setState(() {});
  }
  
  void _addExtraRow() {
    setState(() {
      _batchRows.add(_BatchRowData(''));
    });
  }

  Decimal _parse(TextEditingController controller) {
    if (controller.text.isEmpty) return Decimal.zero;
    try {
      return Decimal.parse(controller.text);
    } catch (_) {
      return Decimal.zero;
    }
  }

  Future<void> _saveBatch() async {
    final rowsToSave = _batchRows.where((r) => r.hasData).toList();
    if (rowsToSave.isEmpty) {
      _showError("No valid rows to save.");
      return;
    }

    setState(() => _isSavingBatch = true);
    
    int successCount = 0;
    
    for (final row in rowsToSave) {
      if (row.productName.text.trim().isEmpty) {
        setState(() => row.rowError = "NAME required");
        continue;
      }
      if (row.karat.text.trim().isEmpty || row.price.text.trim().isEmpty) {
        setState(() => row.rowError = "KARAT & PRICE required");
        continue;
      }
      
      final karatVal = double.tryParse(row.karat.text.trim());
      if (karatVal == null) {
        setState(() => row.rowError = "Invalid KARAT");
        continue;
      }
      
      final karatInt = karatVal.truncate();
      final centInt = ((karatVal - karatInt) * 100).round();
      
      final body = {
        'stock_category': _batchCategory,
        'stock_type': _batchCategory == 'EXTRA' ? null : _batchType,
        'product_tag': row.productName.text.trim(),
        'karat': karatInt,
        'cent': centInt,
        'price_per_karat': row.price.text.trim(),
      };
      
      try {
        final response = await apiService.post('/api/v1/stock/', body);
        if (response.statusCode == 200) {
          setState(() {
            row.isSuccess = true;
            row.rowError = null;
          });
          successCount++;
        } else {
          setState(() => row.rowError = jsonDecode(response.body)['detail'] ?? 'Failed');
        }
      } catch (e) {
        setState(() => row.rowError = e.toString());
      }
    }
    
    setState(() => _isSavingBatch = false);
    _loadStocks();
    
    if (successCount == rowsToSave.length) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All rows saved successfully!'), backgroundColor: Colors.green));
      setState(() {
        _isAddingStock = false;
        _batchRows.clear();
      });
    } else {
      _showError("Some rows failed to save. Please check errors.");
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  Future<void> _showInputDialog(String title, TextEditingController controller, {bool isNumber = false}) async {
    final tempController = TextEditingController(text: controller.text);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: tempController,
          keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
          autofocus: true,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A1A1A)),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (result == true) {
      setState(() {
        controller.text = tempController.text.trim();
      });
    }
  }


  // --- UI Builders ---

  Widget _buildCell(String text, {required double width, bool isHeader = false, bool isEditable = false, VoidCallback? onTap, Color? bgColor, Color? textColor, double scale = 1.0}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: width * scale,
        height: isHeader ? 36 : 42,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: bgColor ?? (isHeader ? const Color(0xFFF9F9F9) : Colors.white),
          border: Border.all(color: const Color(0xFFE5E5E5), width: 0.5),
        ),
        child: Text(
          text.isEmpty ? '' : text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: isHeader ? 11 : 12,
            fontWeight: isHeader ? FontWeight.bold : FontWeight.w500,
            color: textColor ?? (isEditable ? const Color(0xFFC5A059) : Colors.black87),
          ),
        ),
      ),
    );
  }

  static const colWidths = {
    'CATEGORY': 80.0,
    'TYPE': 60.0,
    'NAME': 120.0,
    'KARAT': 80.0,
    'PRICE/KT': 80.0,
    'BASE TOTAL': 90.0,
    'STATUS': 90.0,
  };

  Widget _buildHeaderRow({double scale = 1.0}) {
    return Row(
      children: colWidths.keys.map((k) => _buildCell(k, width: colWidths[k]!, isHeader: true, scale: scale)).toList(),
    );
  }

  static const batchColWidths = {
    'NAME': 150.0,
    'KARAT': 100.0,
    'PRICE/KT': 100.0,
    'BASE TOTAL': 120.0,
    'STATUS': 150.0,
    'ACTION': 60.0,
  };

  Widget _buildBatchHeaderRow({double scale = 1.0}) {
    return Row(
      children: batchColWidths.keys.map((k) => _buildCell(k, width: batchColWidths[k]!, isHeader: true, scale: scale)).toList(),
    );
  }

  Widget _buildBatchRow(_BatchRowData row, {double scale = 1.0}) {
    return AnimatedBuilder(
      animation: Listenable.merge([row.productName, row.karat, row.price]),
      builder: (context, child) {
        final bTotal = _parse(row.price) * _parse(row.karat);
        
        return Row(
          children: [
            _buildCell(row.productName.text, width: batchColWidths['NAME']!, isEditable: true, bgColor: Colors.white, scale: scale, onTap: () => _showInputDialog('PRODUCT NAME', row.productName)),
            _buildCell(row.karat.text, width: batchColWidths['KARAT']!, isEditable: true, scale: scale, onTap: () => _showInputDialog('KARAT', row.karat, isNumber: true)),
            _buildCell(row.price.text, width: batchColWidths['PRICE/KT']!, isEditable: true, scale: scale, onTap: () => _showInputDialog('PRICE/KT', row.price, isNumber: true)),
            _buildCell(bTotal.toStringAsFixed(2), width: batchColWidths['BASE TOTAL']!, bgColor: Colors.grey.shade50, scale: scale),
            _buildCell(row.isSuccess ? 'Saved' : (row.rowError ?? ''), width: batchColWidths['STATUS']!, textColor: row.isSuccess ? Colors.green : (row.rowError != null ? Colors.red : Colors.black87), scale: scale),
            InkWell(
              onTap: () {
                setState(() => _batchRows.remove(row));
              },
              child: Container(
                width: batchColWidths['ACTION']! * scale,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE5E5E5), width: 0.5)),
                child: const Icon(Icons.delete, color: Colors.red, size: 18),
              ),
            ),
          ],
        );
      }
    );
  }

  Widget _buildBatchCalculationSummary() {
    return AnimatedBuilder(
      animation: Listenable.merge([..._batchRows.map((r) => r.karat), ..._batchRows.map((r) => r.price)]),
      builder: (context, child) {
        Decimal totalBase = Decimal.zero;
        for (var row in _batchRows) {
          totalBase += _parse(row.price) * _parse(row.karat);
        }

        Widget summaryRow(String label, String value, {bool isBold = false, Color? color, Widget? trailing}) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: isBold ? 14 : 12)),
                Row(
                  children: [
                    if (trailing != null) trailing,
                    const SizedBox(width: 8),
                    Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: isBold ? 14 : 13, color: color)),
                  ],
                ),
              ],
            ),
          );
        }

        return Container(
          width: 350,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('BATCH SUMMARY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
              const Divider(),
              summaryRow('TOTAL BASE VALUE', '₹ ${totalBase.toStringAsFixed(2)}', isBold: true),
            ],
          ),
        );
      }
    );
  }

  Widget _buildBatchEntryUI() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('CATEGORY: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ToggleButtons(
                  isSelected: [_batchCategory == 'NEW', _batchCategory == 'OLD', _batchCategory == 'EXTRA'],
                  onPressed: (index) {
                    setState(() {
                      if (index == 0) _batchCategory = 'NEW';
                      else if (index == 1) _batchCategory = 'OLD';
                      else _batchCategory = 'EXTRA';
                      _initBatchRows();
                    });
                  },
                  constraints: const BoxConstraints(minHeight: 32, minWidth: 60),
                  borderRadius: BorderRadius.circular(4),
                  borderColor: Colors.grey.shade300,
                  selectedBorderColor: const Color(0xFFC5A059),
                  selectedColor: Colors.white,
                  fillColor: const Color(0xFFC5A059),
                  color: Colors.black87,
                  children: const [
                    Text('NEW', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    Text('OLD', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    Text('EXTRA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
                
                if (_batchCategory != 'EXTRA') ...[
                  const SizedBox(width: 8),
                  const Text('TYPE: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ToggleButtons(
                    isSelected: [_batchType == '-2', _batchType == '+2'],
                    onPressed: (index) {
                      setState(() {
                        _batchType = index == 0 ? '-2' : '+2';
                        _initBatchRows();
                      });
                    },
                    constraints: const BoxConstraints(minHeight: 32, minWidth: 50),
                    borderRadius: BorderRadius.circular(4),
                    borderColor: Colors.grey.shade300,
                    selectedBorderColor: const Color(0xFFC5A059),
                    selectedColor: Colors.white,
                    fillColor: const Color(0xFFC5A059),
                    color: Colors.black87,
                    children: const [
                      Text('-2', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      Text('+2', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
                
                  ElevatedButton.icon(
                    onPressed: _addExtraRow,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Row'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade200, foregroundColor: Colors.black),
                  ),

                  // SAVE BATCH moved here — next to Add Row
                  if (_isSavingBatch)
                    const SizedBox(
                      width: 28, height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFC5A059)),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: _saveBatch,
                      icon: const Icon(Icons.save, size: 16),
                      label: const Text('Save'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC5A059),
                        foregroundColor: Colors.white,
                      ),
                    ),

                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _isAddingStock = false),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final minWidth = batchColWidths.values.reduce((a, b) => a + b);
                      final scale = constraints.maxWidth > minWidth ? constraints.maxWidth / minWidth : 1.0;
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: minWidth * scale,
                          child: Column(
                            children: [
                              _buildBatchHeaderRow(scale: scale),
                              ..._batchRows.map((r) => _buildBatchRow(r, scale: scale)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildBatchCalculationSummary(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }


  Future<void> _showUpdateDialog(Map<String, dynamic> stock) async {
    final karatStr = '${stock['karat']}.${stock['cent']?.toString().padLeft(2, '0') ?? '00'}';
    final priceStr = stock['current_price_per_karat']?.toString() ?? '';
    final karatCtrl = TextEditingController(text: karatStr);
    final priceCtrl = TextEditingController(text: priceStr);

    // Let user pick what to update
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('UPDATE STOCK', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${stock['stock_category'] ?? ''} ${stock['stock_type'] ?? ''}  •  ${stock['product_tag'] ?? ''}',
                    style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.normal)),
              ],
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('CURRENT KARAT:', style: TextStyle(fontSize: 12, color: Colors.black54)),
                Text('$karatStr KT', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('CURRENT PRICE/KT:', style: TextStyle(fontSize: 12, color: Colors.black54)),
                Text(priceStr, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 20),
            const Text('What do you want to update?', style: TextStyle(fontSize: 13, color: Colors.black87)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(ctx, 'karat'),
                    icon: const Icon(Icons.scale_outlined, size: 16),
                    label: const Text('KARAT', style: TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFC5A059),
                      side: const BorderSide(color: Color(0xFFC5A059)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(ctx, 'price'),
                    icon: const Icon(Icons.currency_rupee, size: 16),
                    label: const Text('PRICE/KT', style: TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1A1A1A),
                      side: const BorderSide(color: Color(0xFF1A1A1A)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('CANCEL', style: TextStyle(color: Colors.black45))),
        ],
      ),
    );

    if (choice == null || !mounted) return;

    if (choice == 'karat') {
      await _showKaratUpdateDialog(stock, karatStr, karatCtrl);
    } else if (choice == 'price') {
      await _showPriceUpdateDialog(stock, priceStr, priceCtrl);
    }
  }

  Future<void> _showKaratUpdateDialog(Map<String, dynamic> stock, String karatStr, TextEditingController controller) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('UPDATE KARAT', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('PRODUCT:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                Text('${stock['product_tag']}', style: const TextStyle(fontSize: 12)),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'NEW KARAT (e.g. 42.50)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC5A059), foregroundColor: Colors.white),
            child: const Text('SAVE VERSION'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      final newKarat = controller.text.trim();
      if (newKarat.isEmpty) return;
      try {
        final parsed = double.tryParse(newKarat);
        if (parsed == null) { _showError('Invalid Karat value'); return; }
        final oldParsed = double.tryParse(karatStr);
        if (parsed == oldParsed) { _showError('No changes to save.'); return; }
        final response = await apiService.updateStockVersion(stock['id'], newKarat);
        if (response.statusCode == 200) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Karat updated successfully'), backgroundColor: Colors.green));
          _loadStocks();
        } else {
          _showError(jsonDecode(response.body)['detail'] ?? 'Update failed');
        }
      } catch (e) {
        _showError(e.toString());
      }
    }
  }

  Future<void> _showPriceUpdateDialog(Map<String, dynamic> stock, String priceStr, TextEditingController controller) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('UPDATE PRICE / KT', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('PRODUCT:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                Text('${stock['product_tag']}', style: const TextStyle(fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('CURRENT PRICE/KT:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                Text(priceStr, style: const TextStyle(fontSize: 12, color: Color(0xFFC5A059))),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'NEW PRICE / KT',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                prefixIcon: Icon(Icons.currency_rupee, size: 18),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A1A1A), foregroundColor: Colors.white),
            child: const Text('UPDATE PRICE'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      final newPrice = controller.text.trim();
      if (newPrice.isEmpty) return;
      try {
        final parsed = double.tryParse(newPrice);
        if (parsed == null || parsed <= 0) { _showError('Invalid price value'); return; }
        final oldParsed = double.tryParse(priceStr);
        if (parsed == oldParsed) { _showError('No changes to save.'); return; }
        final response = await apiService.updateStockPrice(stock['id'], newPrice);
        if (response.statusCode == 200) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Price updated successfully'), backgroundColor: Colors.green));
          _loadStocks();
        } else {
          _showError(jsonDecode(response.body)['detail'] ?? 'Update failed');
        }
      } catch (e) {
        _showError(e.toString());
      }
    }
  }


  Widget _buildFooterRow(List<dynamic> items, {double scale = 1.0}) {
    double totalKt = 0;
    double totalPrize = 0;
    for (var s in items) {
       if (s['status'] != 'AVAILABLE') continue;
       final kt = double.tryParse('${s['karat']}.${s['cent']?.toString().padLeft(2, '0') ?? '00'}') ?? 0.0;
       totalKt += kt;
       totalPrize += double.tryParse(s['base_total_amount']?.toString() ?? '0') ?? 0.0;
    }
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF9F9F9),
        border: Border(top: BorderSide(color: Color(0xFFC5A059), width: 1.5)),
      ),
      child: Row(
        children: [
          _buildCell('TOTAL', width: colWidths['CATEGORY']! + colWidths['TYPE']! + colWidths['NAME']!, isHeader: true, scale: scale),
          _buildCell('${totalKt.toStringAsFixed(2)} KT', width: colWidths['KARAT']!, isHeader: true, textColor: const Color(0xFFC5A059), scale: scale),
          _buildCell('', width: colWidths['PRICE/KT']!, scale: scale),
          _buildCell(totalPrize.toStringAsFixed(2), width: colWidths['BASE TOTAL']!, isHeader: true, textColor: const Color(0xFFC5A059), scale: scale),
          _buildCell('', width: colWidths['STATUS']!, scale: scale),
        ],
      ),
    );
  }

  Widget _buildStockRow(Map<String, dynamic> stock, {double scale = 1.0}) {
    final karatStr = '${stock['karat']}.${stock['cent']?.toString().padLeft(2, '0') ?? '00'} KT';
    final priceStr = stock['current_price_per_karat']?.toString() ?? '';
    
    final displayCat = stock['stock_category']?.toString().trim() ?? '';
    final displayType = stock['stock_type']?.toString().trim();
    final typeStr = (displayCat == 'EXTRA') ? '--' : (displayType ?? '--');
    
    final displayName = stock['product_tag'] ?? '';
    final karatRaw = '${stock['karat']}.${stock['cent']?.toString().padLeft(2, '0') ?? '00'}';
    
    return Row(
      children: [
        _buildCell(displayCat, width: colWidths['CATEGORY']!, textColor: Colors.black87, scale: scale),
        _buildCell(typeStr, width: colWidths['TYPE']!, scale: scale),
        _buildCell(displayName, width: colWidths['NAME']!, scale: scale),
        // Double-tap karat → update karat
        GestureDetector(
          onDoubleTap: () => _showKaratUpdateDialog(stock, karatRaw, TextEditingController(text: karatRaw)),
          child: _buildCell(karatStr, width: colWidths['KARAT']!, scale: scale),
        ),
        // Double-tap price → update price
        GestureDetector(
          onDoubleTap: () => _showPriceUpdateDialog(stock, priceStr, TextEditingController(text: priceStr)),
          child: _buildCell(priceStr, width: colWidths['PRICE/KT']!, scale: scale),
        ),
        _buildCell(stock['base_total_amount']?.toString() ?? '', width: colWidths['BASE TOTAL']!, bgColor: Colors.grey.shade50, scale: scale),
        _buildCell(stock['status'] ?? '', width: colWidths['STATUS']!, scale: scale),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('STOCK', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ToggleButtons(
                      isSelected: [_selectedCategory == 'ALL', _selectedCategory == 'NEW', _selectedCategory == 'OLD', _selectedCategory == 'EXTRA'],
                      onPressed: (index) {
                        setState(() {
                          if (index == 0) _selectedCategory = 'ALL';
                          else if (index == 1) _selectedCategory = 'NEW';
                          else if (index == 2) _selectedCategory = 'OLD';
                          else _selectedCategory = 'EXTRA';
                          _selectedType = 'ALL';
                          _loadStocks();
                        });
                      },
                      constraints: const BoxConstraints(minHeight: 36, minWidth: 60),
                      borderRadius: BorderRadius.circular(4),
                      borderColor: Colors.grey.shade300,
                      selectedBorderColor: const Color(0xFFC5A059),
                      selectedColor: Colors.white,
                      fillColor: const Color(0xFFC5A059),
                      color: Colors.black87,
                      children: const [
                        Text('ALL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        Text('NEW', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        Text('OLD', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        Text('EXTRA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        if (!_isAddingStock) {
                          setState(() {
                            _isAddingStock = true;
                            _initBatchRows();
                          });
                        }
                      },
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC5A059),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                      ),
                    ),
                  ],
                ),
                if (_selectedCategory != 'EXTRA') ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ToggleButtons(
                        isSelected: [_selectedType == 'ALL', _selectedType == '-2', _selectedType == '+2'],
                        onPressed: (index) {
                          setState(() {
                            if (index == 0) _selectedType = 'ALL';
                            else if (index == 1) _selectedType = '-2';
                            else _selectedType = '+2';
                          });
                        },
                        constraints: const BoxConstraints(minHeight: 32, minWidth: 40),
                        borderRadius: BorderRadius.circular(4),
                        borderColor: Colors.grey.shade300,
                        selectedBorderColor: const Color(0xFFC5A059),
                        selectedColor: Colors.white,
                        fillColor: const Color(0xFFC5A059),
                        color: Colors.black87,
                        children: const [
                          Text('ALL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          Text('-2', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          Text('+2', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const Spacer(),
                      Builder(
                        builder: (context) {
                          double total = 0;
                          for (final s in _stocks) {
                            if (s['status'] != 'AVAILABLE') continue;
                            final type = s['stock_type']?.toString().trim() ?? '';
                            if (_selectedType != 'ALL' && type != _selectedType) continue;
                            final kt = double.tryParse('${s['karat']}.${s['cent']?.toString().padLeft(2, '0') ?? '00'}') ?? 0.0;
                            total += kt;
                          }
                          return Text(
                            'TOTAL STOCK: ${total.toStringAsFixed(2)} KT',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFFC5A059)),
                          );
                        }
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (!_isAddingStock) Padding(
            padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search Product Tag...',
                      prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 20),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                    onChanged: (value) {
                      _searchQuery = value;
                      _loadStocks();
                    },
                  ),
                ),
                const SizedBox(width: 16),
                DropdownButton<String>(
                  value: _selectedStatus,
                  hint: const Text('Status'),
                  isDense: true,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 'AVAILABLE', child: Text('Available', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'SOLD', child: Text('Sold', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'REMOVED', child: Text('Removed', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'ALL', child: Text('All', style: TextStyle(fontSize: 12))),
                  ],
                  onChanged: (val) {
                    setState(() => _selectedStatus = val!);
                    _loadStocks();
                  },
                ),
              ],
            ),
          ),
          if (_isAddingStock) 
            Expanded(child: _buildBatchEntryUI())
          else
            Expanded(
              child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFC5A059)))
                : _error != null
                    ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                    : SingleChildScrollView(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final minWidth = colWidths.values.reduce((a, b) => a + b);
                            final scale = constraints.maxWidth > minWidth ? constraints.maxWidth / minWidth : 1.0;
                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SizedBox(
                                width: minWidth * scale,
                                child: Builder(
                                  builder: (context) {
                                    final searchLower = _searchQuery.toLowerCase();
                                    final allFiltered = _stocks.where((s) {
                                      if (_selectedStatus != 'ALL' && s['status'] != _selectedStatus) return false;
                                      if (searchLower.isNotEmpty && !(s['product_tag']?.toString().toLowerCase().contains(searchLower) ?? false)) return false;
                                      if (_selectedType != 'ALL' && s['stock_type'] != _selectedType) return false;
                                      return true;
                                    }).toList();

                                    allFiltered.sort((a, b) {
                                      final catA = a['stock_category']?.toString();
                                      final catB = b['stock_category']?.toString();
                                      
                                      int catOrder(String? c) => c == 'OLD' ? 0 : (c == 'NEW' ? 1 : (c == 'EXTRA' ? 2 : 3));
                                      final catCmp = catOrder(catA).compareTo(catOrder(catB));
                                      if (catCmp != 0) return catCmp;
                                      
                                      final typeA = a['stock_type']?.toString();
                                      final typeB = b['stock_type']?.toString();
                                      int typeOrder(String? t) => t == '-2' ? 0 : (t == '+2' ? 1 : 2);
                                      final typeCmp = typeOrder(typeA).compareTo(typeOrder(typeB));
                                      if (typeCmp != 0) return typeCmp;
                                      
                                      int tagOrder(String? cat, String? type, String? tag) {
                                        if (tag == null) return 999;
                                        if (cat == 'NEW') {
                                          if (type == '-2') return minus2Products.indexOf(tag) != -1 ? minus2Products.indexOf(tag) : 999;
                                          if (type == '+2') return plus2Products.indexOf(tag) != -1 ? plus2Products.indexOf(tag) : 999;
                                        } else if (cat == 'OLD') {
                                          if (type == '-2') return oldMinus2Products.indexOf(tag) != -1 ? oldMinus2Products.indexOf(tag) : 999;
                                          if (type == '+2') return oldPlus2Products.indexOf(tag) != -1 ? oldPlus2Products.indexOf(tag) : 999;
                                        } else if (cat == 'EXTRA') {
                                          return extraProducts.indexOf(tag) != -1 ? extraProducts.indexOf(tag) : 999;
                                        }
                                        return 999;
                                      }
                                      
                                      final tagA = a['product_tag']?.toString();
                                      final tagB = b['product_tag']?.toString();
                                      
                                      final tagIdxA = tagOrder(catA, typeA, tagA);
                                      final tagIdxB = tagOrder(catB, typeB, tagB);
                                      
                                      if (tagIdxA != tagIdxB) return tagIdxA.compareTo(tagIdxB);
                                      
                                      return (tagA ?? '').compareTo(tagB ?? '');
                                    });

                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 8),
                                        _buildHeaderRow(scale: scale),
                                        ...allFiltered.map((s) => _buildStockRow(s, scale: scale)),
                                        if (allFiltered.isNotEmpty) _buildFooterRow(allFiltered, scale: scale),
                                        const SizedBox(height: 32),
                                        if (allFiltered.isEmpty)
                                          const Padding(
                                            padding: EdgeInsets.all(32.0),
                                            child: Text('No stock items found.', style: TextStyle(color: Colors.grey)),
                                          ),
                                      ],
                                    );
                                  }
                                ),
                              ),
                            );
                          }
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
