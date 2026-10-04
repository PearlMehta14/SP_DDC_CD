import 'package:flutter/material.dart';
import '../services/product_order_service.dart';

class ReorderScreen extends StatefulWidget {
  const ReorderScreen({super.key});

  @override
  State<ReorderScreen> createState() => _ReorderScreenState();
}

class _ReorderScreenState extends State<ReorderScreen> {
  String _selectedCategory = 'NEW';
  String _selectedType = '-2';
  List<String> _currentList = [];

  @override
  void initState() {
    super.initState();
    _loadList();
  }

  void _loadList() {
    setState(() {
      if (_selectedCategory == 'NEW') {
        _currentList = List.from(_selectedType == '-2' ? productOrderService.minus2Products : productOrderService.plus2Products);
      } else if (_selectedCategory == 'OLD') {
        _currentList = List.from(_selectedType == '-2' ? productOrderService.oldMinus2Products : productOrderService.oldPlus2Products);
      } else if (_selectedCategory == 'EXTRA') {
        _currentList = List.from(productOrderService.extraProducts);
      }
    });
  }

  Future<void> _saveList() async {
    if (_selectedCategory == 'NEW') {
      if (_selectedType == '-2') {
        await productOrderService.saveMinus2(_currentList);
      } else {
        await productOrderService.savePlus2(_currentList);
      }
    } else if (_selectedCategory == 'OLD') {
      if (_selectedType == '-2') {
        await productOrderService.saveOldMinus2(_currentList);
      } else {
        await productOrderService.saveOldPlus2(_currentList);
      }
    } else if (_selectedCategory == 'EXTRA') {
      await productOrderService.saveExtra(_currentList);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order saved successfully')));
    }
  }

  void _addNewProduct() {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Product'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Product Name'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                setState(() {
                  _currentList.add(controller.text.trim());
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reorder Products', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.white,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.save, color: Color(0xFFC5A059)),
            onPressed: _saveList,
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Category: ', style: TextStyle(fontWeight: FontWeight.bold)),
                    ToggleButtons(
                      isSelected: [_selectedCategory == 'NEW', _selectedCategory == 'OLD', _selectedCategory == 'EXTRA'],
                      onPressed: (index) {
                        setState(() {
                          _selectedCategory = index == 0 ? 'NEW' : (index == 1 ? 'OLD' : 'EXTRA');
                          _loadList();
                        });
                      },
                      children: const [
                        Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('NEW')),
                        Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('OLD')),
                        Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('EXTRA')),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_selectedCategory != 'EXTRA')
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Type: ', style: TextStyle(fontWeight: FontWeight.bold)),
                      ToggleButtons(
                        isSelected: [_selectedType == '-2', _selectedType == '+2'],
                        onPressed: (index) {
                          setState(() {
                            _selectedType = index == 0 ? '-2' : '+2';
                            _loadList();
                          });
                        },
                        children: const [
                          Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('-2')),
                          Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('+2')),
                        ],
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Expanded(
            child: ReorderableListView(
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (oldIndex < newIndex) {
                    newIndex -= 1;
                  }
                  final item = _currentList.removeAt(oldIndex);
                  _currentList.insert(newIndex, item);
                });
              },
              children: [
                for (int i = 0; i < _currentList.length; i++)
                  ListTile(
                    key: ValueKey('$_selectedCategory-$_selectedType-${_currentList[i]}'),
                    title: Text(_currentList[i]),
                    trailing: const Icon(Icons.drag_handle),
                  ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewProduct,
        backgroundColor: const Color(0xFFC5A059),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
