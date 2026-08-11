import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:decimal/decimal.dart';
import '../services/api_service.dart';

class AddStockScreen extends StatefulWidget {
  const AddStockScreen({super.key});

  @override
  State<AddStockScreen> createState() => _AddStockScreenState();
}

class _AddStockScreenState extends State<AddStockScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _productTagController = TextEditingController();
  final _karatController = TextEditingController();
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _lessPctController = TextEditingController(text: '5');
  final _brokeragePctController = TextEditingController(text: '1');

  String? _vvsWhite = '1';
  String? _hawaiVvs = '1';
  String? _cat1 = 'A';
  String? _cat2 = 'A';
  String? _cat3 = 'A';

  bool _isLoading = false;
  String? _error;

  void _calculate() {
    setState(() {}); // Rebuilds UI to show recalculated values
  }

  Decimal _parse(TextEditingController controller) {
    if (controller.text.isEmpty) return Decimal.zero;
    try {
      return Decimal.parse(controller.text);
    } catch (_) {
      return Decimal.zero;
    }
  }

  // Current inputs
  Decimal get _karat => _parse(_karatController);
  Decimal get _qty => _parse(_quantityController);
  Decimal get _price => _parse(_priceController);
  Decimal get _lessPct => _parse(_lessPctController);
  Decimal get _brokPct => _parse(_brokeragePctController);

  // BASE
  Decimal get _baseTotal => _price * _karat * _qty;

  // LESS
  Decimal get _lessPrice {
    if (_price == Decimal.zero) return Decimal.zero;
    final pctMultiplier = ((Decimal.fromInt(100) - _lessPct) / Decimal.fromInt(100)).toDecimal(scaleOnInfinitePrecision: 4);
    return _price * pctMultiplier;
  }
  Decimal get _lessTotal => _lessPrice * _karat * _qty;

  // BROKERAGE
  Decimal get _brokPrice {
    if (_lessPrice == Decimal.zero) return Decimal.zero;
    final pctMultiplier = ((Decimal.fromInt(100) - _brokPct) / Decimal.fromInt(100)).toDecimal(scaleOnInfinitePrecision: 4);
    return _lessPrice * pctMultiplier;
  }
  Decimal get _brokTotal => _brokPrice * _karat * _qty;

  // FINAL
  Decimal get _finalPrice => _brokPrice;
  Decimal get _finalTotal => _finalPrice * _karat * _qty;


  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final body = {
      'product_tag': _productTagController.text.trim(),
      'vvs_white': _vvsWhite,
      'hawai_vvs': _hawaiVvs,
      'quality_cat_1': _cat1,
      'quality_cat_2': _cat2,
      'quality_cat_3': _cat3,
      'karat': _karatController.text.trim(),
      'quantity': int.parse(_quantityController.text.trim()),
      'price_per_karat': _priceController.text.trim(),
      'less_percentage': _lessPctController.text.trim(),
      'brokerage_percentage': _brokeragePctController.text.trim(),
    };

    try {
      final response = await apiService.post('/api/v1/stock/', body);
      if (response.statusCode == 200) {
        if (mounted) {
          context.pop(true);
        }
      } else {
        setState(() {
          _error = jsonDecode(response.body)['detail'] ?? 'Failed to add stock';
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Add Stock', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 20),
                  color: Colors.red.shade50,
                  child: Text(_error!, style: TextStyle(color: Colors.red.shade900)),
                ),

              _buildSectionTitle('IDENTIFICATION'),
              _buildTextField('Product Tag', _productTagController, true),
              const SizedBox(height: 16),
              
              _buildSectionTitle('QUALITY'),
              Row(
                children: [
                  Expanded(child: _buildDropdown('VVS White', ['1','2','3'], _vvsWhite, (v) => setState(() => _vvsWhite = v))),
                  const SizedBox(width: 16),
                  Expanded(child: _buildDropdown('Hawai VVS', ['1','2','3','4','5'], _hawaiVvs, (v) => setState(() => _hawaiVvs = v))),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildDropdown('Category 1', ['A','B','C'], _cat1, (v) => setState(() => _cat1 = v))),
                  const SizedBox(width: 16),
                  Expanded(child: _buildDropdown('Category 2', ['A','B','C'], _cat2, (v) => setState(() => _cat2 = v))),
                  const SizedBox(width: 16),
                  Expanded(child: _buildDropdown('Category 3', ['A','B','C'], _cat3, (v) => setState(() => _cat3 = v))),
                ],
              ),
              const SizedBox(height: 32),

              _buildSectionTitle('BASE'),
              Row(
                children: [
                  Expanded(child: _buildTextField('Karat', _karatController, true, isNumber: true)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildTextField('Quantity', _quantityController, true, isNumber: true)),
                ],
              ),
              const SizedBox(height: 16),
              _buildTextField('Price / Karat', _priceController, true, isNumber: true),
              const SizedBox(height: 16),
              _buildDisplayField('Base Total Amount', _baseTotal.toStringAsFixed(2)),
              const SizedBox(height: 32),

              _buildSectionTitle('LESS'),
              _buildTextField('Less %', _lessPctController, false, isNumber: true),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildDisplayField('Less Price/Karat', _lessPrice.toStringAsFixed(2))),
                  const SizedBox(width: 16),
                  Expanded(child: _buildDisplayField('Less Total', _lessTotal.toStringAsFixed(2))),
                ],
              ),
              const SizedBox(height: 32),

              _buildSectionTitle('BROKERAGE'),
              _buildTextField('Brokerage %', _brokeragePctController, false, isNumber: true),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildDisplayField('Brok Price/Karat', _brokPrice.toStringAsFixed(2))),
                  const SizedBox(width: 16),
                  Expanded(child: _buildDisplayField('Brok Total', _brokTotal.toStringAsFixed(2))),
                ],
              ),
              const SizedBox(height: 32),

              _buildSectionTitle('FINAL', color: const Color(0xFFC5A059)),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9F6F0),
                  border: Border.all(color: const Color(0xFFC5A059), width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildFinalValue('Final Price/Karat', _finalPrice.toStringAsFixed(2)),
                    const Divider(height: 24, color: Color(0xFFC5A059)),
                    _buildFinalValue('Final Total Amount', _finalTotal.toStringAsFixed(2), isLarge: true),
                  ],
                ),
              ),

              const SizedBox(height: 40),
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC5A059),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('SAVE STOCK', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, {Color color = Colors.black87}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: color,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, bool required, {bool isNumber = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFC5A059), width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      onChanged: (val) {
        if (isNumber) _calculate();
      },
      validator: (value) {
        if (required && (value == null || value.trim().isEmpty)) {
          return 'Required';
        }
        if (isNumber && value != null && value.isNotEmpty) {
          if (Decimal.tryParse(value) == null) {
            return 'Invalid number';
          }
        }
        return null;
      },
    );
  }

  Widget _buildDropdown(String label, List<String> options, String? value, Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      // ignore: deprecated_member_use
      value: value,
      items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFC5A059), width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
    );
  }

  Widget _buildDisplayField(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildFinalValue(String label, String value, {bool isLarge = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isLarge ? 16 : 14,
            fontWeight: FontWeight.bold,
            color: const Color(0xFFC5A059),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isLarge ? 24 : 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ],
    );
  }
}
