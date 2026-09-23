import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:excel/excel.dart' as ex;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/api_service.dart';
import 'stock_screen.dart';
import '../utils/date_formatter.dart';
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _reportType = 'STOCK'; // STOCK or REJECTION
  String _selectedCategory = 'ALL';
  String _selectedStockType = 'ALL';
  String _selectedProduct = 'ALL';
  
  bool _isLoading = false;
  String? _error;
  
  Map<String, dynamic>? _summary;
  List<dynamic> _records = [];
  
  final List<String> _products = ['ALL', 'Hava VVS', 'Air VVS', 'Orn VVS', 'Coll VVS', 'Q1', 'Q2', 'Q3'];
  final List<String> _categories = ['ALL', 'NEW', 'OLD', 'EXTRA'];
  final List<String> _stockTypes = ['ALL', '-2', '+2'];

  @override
  void initState() {
    super.initState();
    _loadReports();
  }
  
  Future<void> _loadReports() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = _reportType == 'STOCK' 
          ? await apiService.getStockReport(
              stockCategory: _selectedCategory,
              stockType: _selectedStockType,
              productTag: _selectedProduct,
            )
          : await apiService.getRejectionReport(
              stockCategory: _selectedCategory,
              stockType: _selectedStockType,
              productTag: _selectedProduct,
            );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _summary = data['summary'];
            List<dynamic> fetchedRecords = data['records'];
            
            // Sort by default stock sequence
            fetchedRecords.sort((a, b) {
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
            
            _records = fetchedRecords;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _error = jsonDecode(response.body)['detail'] ?? 'Failed to load reports';
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

  String _formatKarat(int? karat, int? cent) {
    if (karat == null || cent == null) return '-';
    return '$karat.${cent.toString().padLeft(2, '0')} KT';
  }
  
  double? _parseKarat(int? k, int? c) {
    if (k == null || c == null) return null;
    return k.toDouble() + c.toDouble() / 100.0;
  }
  
  String _getFileName(String ext) {
    final prefix = _reportType == 'STOCK' ? 'DDC_Stock_Report' : 'DDC_Rejection_Report';
    final timestamp = DateFormat('yyyy-MM-dd_HH-mm').format(AppDateFormatter.nowIST());
    return '${prefix}_$timestamp.$ext';
  }

  Future<void> _exportToExcel() async {
    if (_records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No records to export.")));
      return;
    }
    
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Report'];
      excel.setDefaultSheet('Report');
      
      final headerStyle = CellStyle(
        bold: true,
        backgroundColorHex: ex.ExcelColor.fromHexString('#C5A059'),
        fontColorHex: ex.ExcelColor.fromHexString('#FFFFFF'),
      );
      
      final numberFormat = NumFormat.custom(formatCode: '0.00');
      final karatStyle = CellStyle(numberFormat: numberFormat);
      
      final List<String> headers = _reportType == 'STOCK' 
          ? ['CATEGORY', 'TYPE', 'PRODUCT TAG', 'STOCK TAG', 'VERSION', 'KARAT', 'PRICE/KT', 'FINAL TOTAL', 'STATUS']
          : ['CATEGORY', 'TYPE', 'PRODUCT TAG', 'SOLD', 'SOLD PRICE', 'REMAINING STOCK', 'BUYER', 'DATE'];
          
      sheet.appendRow(headers.map((e) => TextCellValue(e)).toList());
      
      for (int i = 0; i < headers.length; i++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0)).cellStyle = headerStyle;
      }
      
      for (int rowIndex = 0; rowIndex < _records.length; rowIndex++) {
        final r = _records[rowIndex];
        final actualRow = rowIndex + 1;
        
        if (_reportType == 'STOCK') {
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: actualRow)).value = TextCellValue(r['stock_category'] ?? '');
          
          final typeStr = r['stock_type'];
          if (typeStr == '-2') {
            sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: actualRow)).value = IntCellValue(-2);
          } else if (typeStr == '+2') {
            sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: actualRow)).value = IntCellValue(2);
          } else {
            sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: actualRow)).value = TextCellValue(typeStr ?? '');
          }
          
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: actualRow)).value = TextCellValue(r['product_tag']);
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: actualRow)).value = TextCellValue(r['stock_tag']);
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: actualRow)).value = IntCellValue(r['version_no'] ?? 0);
          
          final karatVal = _parseKarat(r['karat'], r['cent']);
          final cellKarat = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: actualRow));
          if (karatVal != null) {
            cellKarat.value = DoubleCellValue(karatVal);
            cellKarat.cellStyle = karatStyle;
          }
          
          final priceStr = r['current_price_per_karat'];
          if (priceStr != null) {
            sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: actualRow)).value = DoubleCellValue(double.tryParse(priceStr.toString()) ?? 0.0);
          }
          
          final totalStr = r['base_total_amount'];
          if (totalStr != null) {
            sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: actualRow)).value = DoubleCellValue(double.tryParse(totalStr.toString()) ?? 0.0);
          }
          
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: actualRow)).value = TextCellValue(r['status'] ?? '');
          
        } else {
          // REJECTION REPORT
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: actualRow)).value = TextCellValue(r['stock_category'] ?? '');
          
          final typeStr = r['stock_type'];
          if (typeStr == '-2') {
            sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: actualRow)).value = IntCellValue(-2);
          } else if (typeStr == '+2') {
            sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: actualRow)).value = IntCellValue(2);
          } else {
            sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: actualRow)).value = TextCellValue(typeStr ?? '');
          }
          
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: actualRow)).value = TextCellValue(r['product_tag']);
          
          final soldVal = _parseKarat(r['sold_karat'], r['sold_cent']);
          final cellSold = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: actualRow));
          if (soldVal != null) {
            cellSold.value = DoubleCellValue(soldVal);
            cellSold.cellStyle = karatStyle;
          }
          
          final soldPrice = r['sold_price'];
          if (soldPrice != null) {
            sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: actualRow)).value = DoubleCellValue(double.tryParse(soldPrice.toString()) ?? 0.0);
          }
          
          final remVal = _parseKarat(r['remaining_karat'], r['remaining_cent']);
          final cellRem = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: actualRow));
          if (remVal != null) {
            cellRem.value = DoubleCellValue(remVal);
            cellRem.cellStyle = karatStyle;
          }
          
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: actualRow)).value = TextCellValue(r['buyer'] ?? '');
          
          final dateStr = r['rejection_date'];
          if (dateStr != null) {
             sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: actualRow)).value = TextCellValue(AppDateFormatter.formatDateOnly(dateStr));
          }
        }
      }
      
      final bytes = excel.encode();
      if (bytes != null) {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/${_getFileName('xlsx')}');
        await file.writeAsBytes(bytes);
        
        // ignore: deprecated_member_use
        await Share.shareXFiles([XFile(file.path, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')]);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Excel export failed: $e")));
      }
    }
  }

  Future<void> _exportToPDF() async {
    if (_records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No records to export.")));
      return;
    }
    
    try {
      String asciiOnly(String input) {
        return input.replaceAll(RegExp(r'[^\x00-\x7F]'), '');
      }
      
      final pdf = pw.Document();
      
      // Load logo
      pw.MemoryImage? logoImage;
      try {
        final ByteData bytes = await rootBundle.load('assets/images/logo_bgremoved.png');
        logoImage = pw.MemoryImage(bytes.buffer.asUint8List());
      } catch (e) {
        debugPrint("Could not load logo: $e");
      }
      
      final reportTitle = _reportType == 'STOCK' ? 'STOCK REPORT' : 'REJECTION REPORT';
      
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(24),
          header: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('DDC DIAMONDS', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.amber800)),
                        pw.Text(reportTitle, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 8),
                        pw.Text(asciiOnly('Filters - Category: $_selectedCategory | Type: ${_selectedCategory == 'EXTRA' ? 'N/A' : _selectedStockType} | Product: $_selectedProduct')),
                      ]
                    ),
                    if (logoImage != null)
                      pw.Container(
                        height: 50,
                        child: pw.Image(logoImage),
                      )
                  ]
                ),
                pw.SizedBox(height: 16),
              ]
            );
          },
          footer: (pw.Context context) {
            final now = AppDateFormatter.formatDateTime(DateTime.now());
            return pw.Container(
              alignment: pw.Alignment.centerRight,
              margin: const pw.EdgeInsets.only(top: 10),
              child: pw.Text('Generated At: $now  |  Page ${context.pageNumber} of ${context.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
            );
          },
          build: (pw.Context context) {
            final tableHeaders = _reportType == 'STOCK'
                ? ['CATEGORY', 'TYPE', 'PRODUCT TAG', 'STOCK TAG', 'VERSION', 'KARAT', 'PRICE/KT', 'FINAL TOTAL', 'STATUS']
                : ['CATEGORY', 'TYPE', 'PRODUCT TAG', 'SOLD', 'SOLD PRICE', 'REMAINING', 'BUYER', 'DATE'];
            
            final tableData = _records.map((r) {
              if (_reportType == 'STOCK') {
                return [
                  asciiOnly(r['stock_category'] ?? ''),
                  asciiOnly(r['stock_type'] ?? ''),
                  asciiOnly(r['product_tag'] ?? ''),
                  asciiOnly(r['stock_tag'].toString().substring(0, 8) + '...'),
                  asciiOnly('v${r['version_no']}'),
                  asciiOnly(_formatKarat(r['karat'], r['cent'])),
                  asciiOnly(r['current_price_per_karat']?.toString() ?? ''),
                  asciiOnly(r['base_total_amount']?.toString() ?? ''),
                  asciiOnly(r['status'] ?? ''),
                ];
              } else {
                final dateStr = r['rejection_date'] != null ? AppDateFormatter.formatDateOnly(r['rejection_date']) : '';
                return [
                  asciiOnly(r['stock_category'] ?? ''),
                  asciiOnly(r['stock_type'] ?? ''),
                  asciiOnly(r['product_tag'] ?? ''),
                  asciiOnly(_formatKarat(r['sold_karat'], r['sold_cent'])),
                  asciiOnly(r['sold_price']?.toString() ?? ''),
                  asciiOnly(_formatKarat(r['remaining_karat'], r['remaining_cent'])),
                  asciiOnly(r['buyer'] ?? ''),
                  asciiOnly(dateStr),
                ];
              }
            }).toList();

            return [
              pw.TableHelper.fromTextArray(
                headers: tableHeaders,
                data: tableData,
                border: pw.TableBorder.all(color: PdfColors.grey300),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.amber800),
                cellStyle: const pw.TextStyle(fontSize: 9),
                cellAlignment: pw.Alignment.centerLeft,
              ),
              pw.SizedBox(height: 20),
              
              // Final Totals section
              if (_summary != null)
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    border: pw.Border.all(color: PdfColors.grey400)
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('REPORT TOTALS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
                      pw.SizedBox(height: 8),
                      pw.Text('TOTAL RECORDS: ${_summary!['total_records']}', style: const pw.TextStyle(fontSize: 10)),
                      pw.SizedBox(height: 4),
                      if (_reportType == 'STOCK') ...[
                        pw.Text('TOTAL KARAT: ${_summary!['total_karat']} KT', style: const pw.TextStyle(fontSize: 10)),
                        pw.SizedBox(height: 4),
                        pw.Text('TOTAL VALUE: Rs ${_summary!['total_value']}', style: const pw.TextStyle(fontSize: 10)),
                      ] else ...[
                        pw.Text('TOTAL SOLD: ${_summary!['total_sold_karat']} KT', style: const pw.TextStyle(fontSize: 10)),
                        pw.SizedBox(height: 4),
                        pw.Text('TOTAL SOLD VALUE: Rs ${_summary!['total_sold_value']}', style: const pw.TextStyle(fontSize: 10)),
                      ]
                    ]
                  )
                )
            ];
          },
        )
      );

      final bytes = await pdf.save();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${_getFileName('pdf')}');
      await file.writeAsBytes(bytes);
      // ignore: deprecated_member_use
      await Share.shareXFiles([XFile(file.path, mimeType: 'application/pdf')]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("PDF export failed: $e")));
      }
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
          // Toggle Report Type
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      if (_reportType != 'STOCK') {
                        setState(() => _reportType = 'STOCK');
                        _loadReports();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _reportType == 'STOCK' ? const Color(0xFF1A1A1A) : Colors.grey.shade200,
                        borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                      ),
                      alignment: Alignment.center,
                      child: Text('STOCK REPORT', style: TextStyle(fontWeight: FontWeight.bold, color: _reportType == 'STOCK' ? Colors.white : Colors.black54)),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      if (_reportType != 'REJECTION') {
                        setState(() => _reportType = 'REJECTION');
                        _loadReports();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _reportType == 'REJECTION' ? const Color(0xFF1A1A1A) : Colors.grey.shade200,
                        borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                      ),
                      alignment: Alignment.center,
                      child: Text('REJECTION REPORT', style: TextStyle(fontWeight: FontWeight.bold, color: _reportType == 'REJECTION' ? Colors.white : Colors.black54)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Filters
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    decoration: InputDecoration(isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12), labelText: 'Category', labelStyle: const TextStyle(fontSize: 12)),
                    value: _selectedCategory,
                    items: _categories.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (v) { 
                      setState(() {
                        _selectedCategory = v!;
                      });
                      _loadReports();
                    },
                  )
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    decoration: InputDecoration(isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12), labelText: 'Type', labelStyle: const TextStyle(fontSize: 12)),
                    value: _selectedCategory == 'EXTRA' ? 'ALL' : _selectedStockType, // Force ALL if EXTRA
                    items: _stockTypes.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: _selectedCategory == 'EXTRA' ? null : (v) { 
                      setState(() => _selectedStockType = v!); 
                      _loadReports(); 
                    },
                  )
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    decoration: InputDecoration(isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12), labelText: 'Product Tag', labelStyle: const TextStyle(fontSize: 12)),
                    value: _selectedProduct,
                    items: _products.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (v) { 
                      setState(() => _selectedProduct = v!); 
                      _loadReports(); 
                    },
                  )
                ),
              ],
            ),
          ),
          
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedCategory = 'ALL';
                      _selectedStockType = 'ALL';
                      _selectedProduct = 'ALL';
                    });
                    _loadReports();
                  },
                  icon: const Icon(Icons.refresh, size: 16, color: Colors.grey),
                  label: const Text('RESET FILTERS', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                ),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _records.isEmpty ? null : _exportToPDF,
                      icon: const Icon(Icons.picture_as_pdf, size: 14),
                      label: const Text('PDF', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600, 
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _records.isEmpty ? null : _exportToExcel,
                      icon: const Icon(Icons.table_chart, size: 14),
                      label: const Text('EXCEL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600, 
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
          
          // Summary KPIs
          if (_summary != null)
            Container(
              color: Colors.white,
              width: double.infinity,
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9F9F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE5E5E5))
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSummaryItem('TOTAL RECORDS', _summary!['total_records'].toString()),
                    if (_reportType == 'STOCK') ...[
                      _buildSummaryItem('TOTAL KARAT', '${_summary!['total_karat']} KT'),
                      _buildSummaryItem('TOTAL VALUE', 'Rs ${_summary!['total_value']}'),
                    ] else ...[
                      _buildSummaryItem('TOTAL SOLD', '${_summary!['total_sold_karat']} KT'),
                      _buildSummaryItem('TOTAL SOLD VALUE', 'Rs ${_summary!['total_sold_value']}'),
                    ]
                  ],
                ),
              ),
            ),
            
          // Table
          Expanded(
            child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFC5A059)))
              : _error != null
                ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                : _records.isEmpty
                  ? Center(child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.insert_chart_outlined, size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text('No records found.', style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
                      ],
                    ))
                  : Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(top: BorderSide(color: Color(0xFFE5E5E5)))
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                                child: DataTable(
                            headingRowColor: WidgetStateProperty.all(const Color(0xFFF5F5F5)),
                            headingTextStyle: const TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5),
                            dataTextStyle: const TextStyle(fontSize: 12, color: Colors.black87),
                            columnSpacing: 24,
                            horizontalMargin: 16,
                            columns: _reportType == 'STOCK'
                                ? const [
                                    DataColumn(label: Text('CATEGORY')),
                                    DataColumn(label: Text('TYPE')),
                                    DataColumn(label: Text('PRODUCT TAG')),
                                    DataColumn(label: Text('STOCK TAG')),
                                    DataColumn(label: Text('VER')),
                                    DataColumn(label: Text('KARAT')),
                                    DataColumn(label: Text('PRICE/KT')),
                                    DataColumn(label: Text('FINAL TOTAL')),
                                    DataColumn(label: Text('STATUS')),
                                  ]
                                : const [
                                    DataColumn(label: Text('CATEGORY')),
                                    DataColumn(label: Text('TYPE')),
                                    DataColumn(label: Text('PRODUCT TAG')),
                                    DataColumn(label: Text('SOLD KT')),
                                    DataColumn(label: Text('SOLD PRICE')),
                                    DataColumn(label: Text('REMAINING')),
                                    DataColumn(label: Text('BUYER')),
                                    DataColumn(label: Text('DATE')),
                                  ],
                            rows: _records.map((r) {
                              if (_reportType == 'STOCK') {
                                return DataRow(
                                  cells: [
                                    DataCell(Text(r['stock_category'] ?? '')),
                                    DataCell(Text(r['stock_type'] ?? '')),
                                    DataCell(Text(r['product_tag'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold))),
                                    DataCell(Text(r['stock_tag'].toString().substring(0, 8) + '...', style: const TextStyle(color: Colors.grey))),
                                    DataCell(Text('v${r['version_no']}', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
                                    DataCell(Text(_formatKarat(r['karat'], r['cent']))),
                                    DataCell(Text(r['current_price_per_karat'] ?? '')),
                                    DataCell(Text(r['base_total_amount'] ?? '')),
                                    DataCell(Text(r['status'] ?? '', style: TextStyle(color: r['status'] == 'AVAILABLE' ? Colors.green : Colors.red, fontWeight: FontWeight.bold))),
                                  ]
                                );
                              } else {
                                final dateStr = r['rejection_date'] != null ? AppDateFormatter.formatDateOnly(r['rejection_date']) : '';
                                return DataRow(
                                  cells: [
                                    DataCell(Text(r['stock_category'] ?? '')),
                                    DataCell(Text(r['stock_type'] ?? '')),
                                    DataCell(Text(r['product_tag'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold))),
                                    DataCell(Text(_formatKarat(r['sold_karat'], r['sold_cent']))),
                                    DataCell(Text(r['sold_price'] ?? '')),
                                    DataCell(Text(_formatKarat(r['remaining_karat'], r['remaining_cent']))),
                                    DataCell(Text(r['buyer'] ?? '')),
                                    DataCell(Text(dateStr, style: const TextStyle(color: Colors.grey))),
                                  ]
                                );
                              }
                            }).toList(),
                            ),
                          ),
                        );
                      }
                    ),
                  ),
                ),
      )
        ],
      ),
    );
  }
  
  Widget _buildSummaryItem(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFC5A059))),
      ],
    );
  }
}
