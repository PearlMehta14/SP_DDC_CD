import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:decimal/decimal.dart';
import '../services/api_service.dart';
import 'stock_screen.dart';
import '../utils/date_formatter.dart';

class _DraftRejection {
  Map<String, dynamic>? stock;
  final date = TextEditingController();
  final buyer = TextEditingController();
  final soldValue = TextEditingController(); // Combines karat/cent entry as decimal e.g., 40.25
  final soldPrice = TextEditingController();
  final outRemark = TextEditingController();
}

class RejectionsScreen extends StatefulWidget {
  const RejectionsScreen({super.key});

  @override
  State<RejectionsScreen> createState() => _RejectionsScreenState();
}

class _RejectionsScreenState extends State<RejectionsScreen> {
  List<dynamic> _rejections = [];
  bool _isLoading = true;
  String? _error;

  bool _isAddingRejection = false;
  final _draft = _DraftRejection();
  bool _isSavingDraft = false;

  @override
  void initState() {
    super.initState();
    _loadRejections();
  }

  Future<void> _loadRejections({bool showLoader = true}) async {
    if (showLoader) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final response = await apiService.get('/api/v1/rejections/');
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            List<dynamic> fetchedRejections = jsonDecode(response.body);
            
            // Sort by default stock sequence
            fetchedRejections.sort((a, b) {
              final catA = a['stock_category']?.toString();
              final catB = b['stock_category']?.toString();
              
              int catOrder(String? c) => c == 'NEW' ? 0 : (c == 'OLD' ? 1 : (c == 'EXTRA' ? 2 : 3));
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
            
            _rejections = fetchedRejections;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _error = jsonDecode(response.body)['detail'] ?? 'Failed to load rejections';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted && showLoader) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      } else if (mounted) {
        _showError(e.toString());
      }
    }
  }

  Future<void> _showStockSelectionModal() async {
    setState(() => _isLoading = true);

    try {
      final response = await apiService.get('/api/v1/stock/?status=AVAILABLE');
      if (mounted) {
        setState(() => _isLoading = false);
      }
      
      if (response.statusCode == 200) {
        final List<dynamic> stocks = jsonDecode(response.body);
        if (stocks.isEmpty) {
          _showError('No available stocks to reject.');
          return;
        }
        
        if (mounted) {
          final selectedStock = await showModalBottomSheet<Map<String, dynamic>>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => _StockSelectionSheet(stocks: stocks),
          );
          
          if (selectedStock != null && mounted) {
            setState(() {
              _isAddingRejection = true;
              _draft.stock = selectedStock;
              _draft.date.text = AppDateFormatter.currentISTDateStr();
            });
          }
        }
      } else {
        _showError('Failed to load stocks');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError(e.toString());
      }
    }
  }

  Decimal _parse(String val) {
    if (val.trim().isEmpty) return Decimal.zero;
    try {
      return Decimal.parse(val.trim());
    } catch (_) {
      return Decimal.zero;
    }
  }

  String get _remainingStockDisplay {
    if (_draft.stock == null) return '';
    final stockKarat = _draft.stock!['karat'] ?? 0;
    final stockCent = _draft.stock!['cent'] ?? 0;
    final totalAvailable = Decimal.parse('$stockKarat.$stockCent');
    final sold = _parse(_draft.soldValue.text);
    
    if (sold > totalAvailable) {
      return 'EXCEEDS!';
    }
    
    final rem = totalAvailable - sold;
    return '${rem.toStringAsFixed(2)} KT';
  }

  Future<void> _saveDraft() async {
    if (_draft.stock == null) return;
    if (_draft.soldValue.text.trim().isEmpty || _draft.soldPrice.text.trim().isEmpty) {
      _showError("SOLD and SOLD PRICE are required");
      return;
    }

    final soldValStr = _draft.soldValue.text.trim();
    if (!soldValStr.contains('.')) {
      // automatically format to decimal if user types whole number
      _draft.soldValue.text = '$soldValStr.00';
    }
    
    final parts = _draft.soldValue.text.trim().split('.');
    int soldKarat = 0;
    int soldCent = 0;
    
    try {
      soldKarat = int.parse(parts[0]);
      if (parts.length > 1) {
        // Pad to ensure correct cent parsing (e.g. .5 -> .50)
        String centStr = parts[1];
        if (centStr.length == 1) centStr += '0';
        soldCent = int.parse(centStr.substring(0, 2));
      }
    } catch (e) {
      _showError("Invalid sold quantity format. Use format XX.XX");
      return;
    }
    
    setState(() => _isSavingDraft = true);

    final payload = {
      'stock_id': _draft.stock!['id'],
      'rejection_date': _draft.date.text.isNotEmpty ? _draft.date.text : AppDateFormatter.currentISTDateStr(),
      'sold_karat': soldKarat,
      'sold_cent': soldCent,
      'sold_price': _draft.soldPrice.text.trim(),
      'buyer': _draft.buyer.text.trim(),
      'out_remark': _draft.outRemark.text.trim(),
    };

    try {
      final response = await apiService.post('/api/v1/rejections/', payload);
      if (response.statusCode == 200 || response.statusCode == 201) {
        _draft.date.clear();
        _draft.buyer.clear();
        _draft.outRemark.clear();
        _draft.soldValue.clear();
        _draft.soldPrice.clear();
        
        setState(() {
          _isAddingRejection = false;
          _draft.stock = null;
        });
        
        await _loadRejections(showLoader: false);
      } else {
        _showError(jsonDecode(response.body)['detail'] ?? 'Failed to save rejection');
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isSavingDraft = false);
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
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_draft.date.text) ?? AppDateFormatter.nowIST(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFFC5A059)),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _draft.date.text = picked.toIso8601String().split('T')[0];
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

  Widget _buildActionCell(Widget child, {required double width, Color? bgColor, double scale = 1.0}) {
    return Container(
      width: width * scale,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bgColor ?? Colors.white,
        border: Border.all(color: const Color(0xFFE5E5E5), width: 0.5),
      ),
      child: child,
    );
  }

  static const colWidths = {
    'CATEGORY': 80.0,
    'TYPE': 50.0,
    'REFERENCE': 120.0,
    'DATE': 90.0,
    'OUT': 100.0,
    'BUYER': 100.0,
    'SOLD': 80.0,
    'SOLD PRICE': 100.0,
    'TOTAL PRIZE': 100.0,
    'ACTION': 100.0,
  };

  Widget _buildHeaderRow({double scale = 1.0}) {
    return Row(
      children: colWidths.keys.map((k) => _buildCell(k, width: colWidths[k]!, isHeader: true, scale: scale)).toList(),
    );
  }

  Widget _buildDraftRow({double scale = 1.0}) {
    final type = _draft.stock?['stock_type']?.toString();
    final typeDisplay = (type == '-2' || type == '+2') ? type : '';

    return Row(
      key: const ValueKey('draft_row'),
      children: [
        _buildCell(_draft.stock?['stock_category'] ?? '', width: colWidths['CATEGORY']!, bgColor: const Color(0xFFF0F0F0), scale: scale),
        _buildCell(typeDisplay!, width: colWidths['TYPE']!, bgColor: const Color(0xFFF0F0F0), scale: scale),
        _buildCell(_draft.stock?['product_tag'] ?? 'Select...', width: colWidths['REFERENCE']!, isEditable: true, onTap: _showStockSelectionModal, scale: scale),
        _buildCell(_draft.date.text, width: colWidths['DATE']!, isEditable: true, onTap: _selectDate, scale: scale),
        _buildCell(_draft.outRemark.text, width: colWidths['OUT']!, isEditable: true, onTap: () => _showInputDialog('OUT', _draft.outRemark), scale: scale),
        _buildCell(_draft.buyer.text, width: colWidths['BUYER']!, isEditable: true, onTap: () => _showInputDialog('BUYER', _draft.buyer), scale: scale),
        _buildCell(_draft.soldValue.text.isNotEmpty ? '${_draft.soldValue.text} KT' : '', width: colWidths['SOLD']!, isEditable: true, onTap: () => _showInputDialog('SOLD', _draft.soldValue, isNumber: true), scale: scale),
        _buildCell(_draft.soldPrice.text, width: colWidths['SOLD PRICE']!, isEditable: true, onTap: () => _showInputDialog('SOLD PRICE', _draft.soldPrice, isNumber: true), scale: scale),
        _buildCell('', width: colWidths['TOTAL PRIZE']!, bgColor: const Color(0xFFFFF9E8), scale: scale),
        _buildActionCell(
          _isSavingDraft 
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) 
            : TextButton(
                onPressed: _saveDraft,
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(60, 30)),
                child: const Text('SAVE ROW', style: TextStyle(color: Color(0xFFC5A059), fontWeight: FontWeight.bold, fontSize: 11)),
              ),
          width: colWidths['ACTION']!,
          bgColor: Colors.white,
          scale: scale,
        ),
      ],
    );
  }

  Widget _buildRejectionRow(Map<String, dynamic> rej, {double scale = 1.0}) {
    final dateStr = AppDateFormatter.formatDateOnly(rej['rejection_date']);
        
    final soldKarat = rej['sold_karat'] ?? 0;
    final soldCent = rej['sold_cent'] ?? 0;
    final soldStr = '$soldKarat.${soldCent.toString().padLeft(2, '0')} KT';

    final type = rej['stock_type']?.toString();
    final typeDisplay = (type == '-2' || type == '+2') ? type : '';

    return Row(
      key: ValueKey(rej['id'] ?? UniqueKey().toString()),
      children: [
        _buildCell(rej['stock_category'] ?? '', width: colWidths['CATEGORY']!, scale: scale),
        _buildCell(typeDisplay!, width: colWidths['TYPE']!, scale: scale),
        _buildCell(rej['product_tag'] ?? '', width: colWidths['REFERENCE']!, scale: scale),
        _buildCell(dateStr, width: colWidths['DATE']!, scale: scale),
        _buildCell(rej['out_remark'] ?? '', width: colWidths['OUT']!, scale: scale),
        _buildCell(rej['buyer'] ?? '', width: colWidths['BUYER']!, scale: scale),
        _buildCell(soldStr, width: colWidths['SOLD']!, scale: scale),
        _buildCell(rej['sold_price']?.toString() ?? '', width: colWidths['SOLD PRICE']!, scale: scale),
        _buildCell(rej['total_price']?.toString() ?? '', width: colWidths['TOTAL PRIZE']!, bgColor: const Color(0xFFFFF9E8), textColor: const Color(0xFFB8860B), scale: scale),
        _buildCell('', width: colWidths['ACTION']!, scale: scale),
      ],
    );
  }

  Widget _buildRejectionsFooter({double scale = 1.0}) {
    double totalKt = 0;
    double totalPrize = 0;
    for (var i in _rejections) {
       final kt = double.tryParse('${i['sold_karat']}.${i['sold_cent']?.toString().padLeft(2, '0') ?? '00'}') ?? 0.0;
       totalKt += kt;
       totalPrize += double.tryParse(i['total_price']?.toString() ?? '0') ?? 0.0;
    }
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF9F9F9),
        border: Border(top: BorderSide(color: Color(0xFFC5A059), width: 1.5)),
      ),
      child: Row(
        children: [
          _buildCell('TOTAL', width: colWidths['CATEGORY']! + colWidths['TYPE']! + colWidths['REFERENCE']! + colWidths['DATE']! + colWidths['OUT']! + colWidths['BUYER']!, isHeader: true, scale: scale),
          _buildCell('${totalKt.toStringAsFixed(2)} KT', width: colWidths['SOLD']!, isHeader: true, textColor: const Color(0xFFC5A059), scale: scale),
          _buildCell('', width: colWidths['SOLD PRICE']!, scale: scale),
          _buildCell(totalPrize.toStringAsFixed(2), width: colWidths['TOTAL PRIZE']!, isHeader: true, textColor: const Color(0xFFC5A059), scale: scale),
          _buildCell('', width: colWidths['ACTION']!, scale: scale),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('REJECTIONS', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    if (!_isAddingRejection) {
                      _showStockSelectionModal();
                    }
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('ADD REJECTION'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A1A1A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
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
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final minWidth = colWidths.values.reduce((a, b) => a + b);
                          final scale = constraints.maxWidth > minWidth ? constraints.maxWidth / minWidth : 1.0;
                          return SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SizedBox(
                                width: minWidth * scale,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildHeaderRow(scale: scale),
                                    if (_isAddingRejection) _buildDraftRow(scale: scale),
                                    ..._rejections.map((rej) => _buildRejectionRow(rej, scale: scale)),
                                    if (_rejections.isNotEmpty) _buildRejectionsFooter(scale: scale),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }
                      ),
          ),
        ],
      ),
    );
  }
}

class _StockSelectionSheet extends StatefulWidget {
  final List<dynamic> stocks;
  const _StockSelectionSheet({required this.stocks});

  @override
  State<_StockSelectionSheet> createState() => _StockSelectionSheetState();
}

class _StockSelectionSheetState extends State<_StockSelectionSheet> {
  Map<String, dynamic>? _selectedStock;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE5E5E5))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Select Stock Packet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: widget.stocks.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final stock = widget.stocks[index];
                final karatStr = '${stock['karat']}.${stock['cent']?.toString().padLeft(2, '0') ?? '00'} KT';
                final category = stock['stock_category'] ?? 'EXTRA';
                final type = stock['stock_type'] ?? '';
                final product = stock['product_tag'] ?? 'N/A';

                return RadioListTile<Map<String, dynamic>>(
                  value: stock,
                  groupValue: _selectedStock,
                  onChanged: (val) {
                    setState(() {
                      _selectedStock = val;
                    });
                  },
                  title: Text('$category | $type | $product', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    'Available: $karatStr',
                    style: const TextStyle(fontSize: 14, color: Colors.green),
                  ),
                  activeColor: const Color(0xFFC5A059),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedStock == null ? null : () => Navigator.pop(context, _selectedStock),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A1A1A),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  disabledBackgroundColor: Colors.grey.shade300,
                ),
                child: const Text('CONTINUE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          )
        ],
      ),
    );
  }
}
