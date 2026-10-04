import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ProductOrderService {
  static const String _keyMinus2 = 'order_minus2';
  static const String _keyPlus2 = 'order_plus2';
  static const String _keyOldMinus2 = 'order_old_minus2';
  static const String _keyOldPlus2 = 'order_old_plus2';
  static const String _keyExtra = 'order_extra';

  List<String> minus2Products = [
    'Hava VVS', 'Hava Dagina', 'Hava Jew', 'Hava S Dlx', 'Hava Dlx',
    'Air VVS', 'Air Dagina', 'Air Jew', 'Air S Dlx', 'Air Dlx',
    'Coll VVS', 'Coll Dagina', 'Coll Jew', 'Coll S Dlx', 'Coll Dlx',
    'Orn VVS', 'Orn Dagina', 'Orn Jew', 'Orn S Dlx', 'Orn Dlx',
    'Super VVS', 'Super Dagina', 'Super Jew', 'Super S Dlx', 'Super Dlx',
    'White VVS', 'White Dagina', 'White Jew'
  ];

  List<String> plus2Products = [
    'Hava VVS', 'Hava Dagina', 'Hava Jew', 'Hava S Dlx', 'Hava Dlx',
    'Air VVS', 'Air Dagina', 'Air Jew', 'Air S Dlx', 'Air Dlx',
    'Coll VVS', 'Coll Dagina', 'Coll Jew', 'Coll S Dlx', 'Coll Dlx',
    'Orn VVS', 'Orn Dagina', 'Orn Jew', 'Orn S Dlx', 'Orn Dlx',
    'White VVS', 'White Dagina', 'White Jew'
  ];

  List<String> oldMinus2Products = [
    'Hava 3', 'hava 4', 'hava 5', 'air 3', 'air 4', 'air 5', 'col 2', 'col 3', 'col 4', 'col 5', 'Ex 3', 'Ex 4'
  ];

  List<String> oldPlus2Products = [
    'air 2', 'air 3', 'air 5', 'col 2', 'col 3', 'col 4', 'Ex 1', 'Ex 2', 'Ex 3', 'Ex 4', 'Ex 5'
  ];

  List<String> extraProducts = [
    'Mix', 'Natts', 'LC 1', 'LC 2', 'LC 3', 'Bud', 'Weak', 'ws -2'
  ];

  static final ProductOrderService _instance = ProductOrderService._internal();

  factory ProductOrderService() {
    return _instance;
  }

  ProductOrderService._internal();

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    
    minus2Products = _loadList(prefs, _keyMinus2, minus2Products);
    plus2Products = _loadList(prefs, _keyPlus2, plus2Products);
    oldMinus2Products = _loadList(prefs, _keyOldMinus2, oldMinus2Products);
    oldPlus2Products = _loadList(prefs, _keyOldPlus2, oldPlus2Products);
    extraProducts = _loadList(prefs, _keyExtra, extraProducts);
  }

  List<String> _loadList(SharedPreferences prefs, String key, List<String> defaultList) {
    final saved = prefs.getString(key);
    if (saved != null) {
      try {
        final List<dynamic> decoded = jsonDecode(saved);
        return decoded.cast<String>();
      } catch (e) {
        return List.from(defaultList);
      }
    }
    return List.from(defaultList);
  }

  Future<void> saveMinus2(List<String> list) async {
    minus2Products = list;
    await _saveList(_keyMinus2, list);
  }

  Future<void> savePlus2(List<String> list) async {
    plus2Products = list;
    await _saveList(_keyPlus2, list);
  }

  Future<void> saveOldMinus2(List<String> list) async {
    oldMinus2Products = list;
    await _saveList(_keyOldMinus2, list);
  }

  Future<void> saveOldPlus2(List<String> list) async {
    oldPlus2Products = list;
    await _saveList(_keyOldPlus2, list);
  }

  Future<void> saveExtra(List<String> list) async {
    extraProducts = list;
    await _saveList(_keyExtra, list);
  }

  Future<void> _saveList(String key, List<String> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(list));
  }
}

final productOrderService = ProductOrderService();
