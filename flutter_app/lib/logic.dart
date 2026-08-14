import 'dart:collection';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'logic.g.dart';

// -------------------- Utility Calculator --------------------
class Calculator {
  static int daysBetween(DateTime from, DateTime to) {
    final f = DateTime.utc(from.year, from.month, from.day);
    final t = DateTime.utc(to.year, to.month, to.day);
    return t.difference(f).inDays;
  }

  static double dailyBankProfit({
    required double paidAmount,
    required double interestRate,
    required int days,
  }) {
    if (days <= 0 || paidAmount <= 0) return 0;
    final dailyRate = interestRate / 100 / 365;
    return (paidAmount * (pow(1 + dailyRate, days) - 1)).toDouble();
  }

  static double assetProfit({
    required double currentPrice,
    required double quantity,
    required double paidAmount,
  }) {
    return currentPrice * quantity - paidAmount;
  }

  static double calculateProfit({
    required double currentPrice,
    required double purchasePrice,
    required double quantity,
    required double paidAmount,
    required double interestRate,
    required int days,
  }) {
    final currentValue = currentPrice * quantity;
    final purchaseProfit = currentValue - paidAmount;
    final bankProfit = dailyBankProfit(
      paidAmount: paidAmount,
      interestRate: interestRate,
      days: days,
    );
    return purchaseProfit - bankProfit;
  }
}

// -------------------- Models --------------------
@HiveType(typeId: 0)
class GoldTransaction extends HiveObject {
  @HiveField(0) String id;
  @HiveField(1) String type;
  @HiveField(2) DateTime purchaseDate;
  @HiveField(3) double purchasePricePerUnit;
  @HiveField(4) double quantity;
  @HiveField(5) String description;
  @HiveField(6) double remainingQuantity;

  GoldTransaction({
    required this.id,
    required this.type,
    required this.purchaseDate,
    required this.purchasePricePerUnit,
    required this.quantity,
    required this.description,
    double? remainingQuantity,
  }) : remainingQuantity = remainingQuantity ?? quantity;
}

@HiveType(typeId: 1)
class CoinTransaction extends HiveObject {
  @HiveField(0) String id;
  @HiveField(1) String coinType;
  @HiveField(2) DateTime purchaseDate;
  @HiveField(3) double purchasePricePerUnit;
  @HiveField(4) int count;
  @HiveField(5) String description;
  @HiveField(6) int remainingCount;

  CoinTransaction({
    required this.id,
    required this.coinType,
    required this.purchaseDate,
    required this.purchasePricePerUnit,
    required this.count,
    required this.description,
    int? remainingCount,
  }) : remainingCount = remainingCount ?? count;
}

@HiveType(typeId: 2)
class SaleTransaction extends HiveObject {
  @HiveField(0) String id;
  @HiveField(1) String lotId;
  @HiveField(2) DateTime saleDate;
  @HiveField(3) double salePricePerUnit;
  @HiveField(4) double quantity;
  @HiveField(5) bool isGold;
  @HiveField(6) String? coinType;
  @HiveField(7) double purchasePricePerUnit;
  @HiveField(8) DateTime purchaseDate;

  SaleTransaction({
    required this.id,
    required this.lotId,
    required this.saleDate,
    required this.salePricePerUnit,
    required this.quantity,
    required this.isGold,
    this.coinType,
    required this.purchasePricePerUnit,
    required this.purchaseDate,
  });
}

// -------------------- Price Models --------------------
class PriceResponse {
  final String name;
  final double? currentPrice;
  final double? high;
  final double? low;
  final double? yesterdayAvg;
  final Change? change;

  PriceResponse({
    required this.name,
    this.currentPrice,
    this.high,
    this.low,
    this.yesterdayAvg,
    this.change,
  });

  factory PriceResponse.fromJson(Map<String, dynamic> json) => PriceResponse(
        name: json['name'] ?? '',
        currentPrice: json['current_price'] != null
            ? (json['current_price'] as num).toDouble()
            : null,
        high: json['high'] != null ? (json['high'] as num).toDouble() : null,
        low: json['low'] != null ? (json['low'] as num).toDouble() : null,
        yesterdayAvg: json['yesterday_avg'] != null
            ? (json['yesterday_avg'] as num).toDouble()
            : null,
        change: json['change'] != null ? Change.fromJson(json['change']) : null,
      );
}

class Change {
  final double? value;
  final double? percent;
  final String? direction;

  Change({this.value, this.percent, this.direction});

  factory Change.fromJson(Map<String, dynamic> json) => Change(
        value: json['value'] != null ? (json['value'] as num).toDouble() : null,
        percent:
            json['percent'] != null ? (json['percent'] as num).toDouble() : null,
        direction: json['direction'],
      );
}

// -------------------- Providers --------------------
class SettingsProvider extends ChangeNotifier {
  double _bankInterestRate = 26.0;
  int _autoUpdateInterval = 300;
  Color _secondaryColor = Colors.amber;
  Color _menuColor = const Color(0xFF111111);
  double _menuBottomPadding = 12.0;
  double _menuWidthPercent = 95.0;

  double get bankInterestRate => _bankInterestRate;
  int get autoUpdateInterval => _autoUpdateInterval;
  Color get secondaryColor => _secondaryColor;
  Color get menuColor => _menuColor;
  double get menuBottomPadding => _menuBottomPadding;
  double get menuWidthPercent => _menuWidthPercent;

  final SharedPreferences _prefs;

  SettingsProvider(this._prefs) {
    _loadSettings();
  }

  void _loadSettings() {
    _bankInterestRate = _prefs.getDouble('bankInterestRate') ?? 26.0;
    _autoUpdateInterval = _prefs.getInt('autoUpdateInterval') ?? 300;
    _menuBottomPadding = _prefs.getDouble('menuBottomPadding') ?? 12.0;
    _menuWidthPercent = _prefs.getDouble('menuWidthPercent') ?? 95.0;

    final colorStr = _prefs.getString('secondaryColor');
    if (colorStr != null) {
      try {
        _secondaryColor = _parseColor(colorStr);
      } catch (_) {}
    }
    final menuColorStr = _prefs.getString('menuColor');
    if (menuColorStr != null) {
      try {
        _menuColor = _parseColor(menuColorStr);
      } catch (_) {}
    }
  }

  Color _parseColor(String s) {
    if (s.startsWith('#')) {
      return Color(int.parse(s.substring(1), radix: 16));
    }
    return Color(int.parse(s));
  }

  String _colorToString(Color c) =>
      '#${c.value.toRadixString(16).padLeft(8, '0')}';

  Future<void> setBankInterestRate(double v) async {
    _bankInterestRate = v;
    await _prefs.setDouble('bankInterestRate', v);
    notifyListeners();
  }

  Future<void> setAutoUpdateInterval(int s) async {
    _autoUpdateInterval = s;
    await _prefs.setInt('autoUpdateInterval', s);
    notifyListeners();
  }

  Future<void> setSecondaryColor(Color c) async {
    _secondaryColor = c;
    await _prefs.setString('secondaryColor', _colorToString(c));
    notifyListeners();
  }

  Future<void> setMenuColor(Color c) async {
    _menuColor = c;
    await _prefs.setString('menuColor', _colorToString(c));
    notifyListeners();
  }

  Future<void> setMenuBottomPadding(double v) async {
    _menuBottomPadding = v;
    await _prefs.setDouble('menuBottomPadding', v);
    notifyListeners();
  }

  Future<void> setMenuWidthPercent(double v) async {
    _menuWidthPercent = v;
    await _prefs.setDouble('menuWidthPercent', v);
    notifyListeners();
  }
}

class BasePriceProvider extends ChangeNotifier {
  Map<String, double> _basePrices = {};
  final SharedPreferences _prefs;

  BasePriceProvider(this._prefs) {
    _loadBasePrices();
  }

  Map<String, double> get basePrices => UnmodifiableMapView(_basePrices);

  void _loadBasePrices() {
    final jsonStr = _prefs.getString('basePrices');
    if (jsonStr != null) {
      try {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        _basePrices = map.map((k, v) => MapEntry(k, (v as num).toDouble()));
      } catch (_) {
        _setDefaultBasePrices();
      }
    } else {
      _setDefaultBasePrices();
    }
    notifyListeners();
  }

  void _setDefaultBasePrices() {
    _basePrices = {
      'gold_18': 201226000.0,
      'gold_24': 268301333.0,
      'gold_ons': 0,
      'gold_mazneh': 20122600.0,
      'coin_old': 2089850000.0,
      'coin_new': 2089850000.0,
      'coin_half': 1081900000.0,
      'coin_quarter': 595200000.0,
      'coin_1g': 185000000.0,
    };
    _saveBasePrices();
  }

  Future<void> _saveBasePrices() async {
    await _prefs.setString('basePrices', jsonEncode(_basePrices));
  }

  Future<void> setBasePrice(String key, double value) async {
    _basePrices[key] = value;
    await _saveBasePrices();
    notifyListeners();
  }
}

class DataProvider extends ChangeNotifier {
  final Box<GoldTransaction> goldBox;
  final Box<CoinTransaction> coinBox;
  final Box<SaleTransaction> saleBox;

  DataProvider({
    required this.goldBox,
    required this.coinBox,
    required this.saleBox,
  }) {
    if (goldBox.isEmpty && coinBox.isEmpty) _addDefaultData();
  }

  void _addDefaultData() {
    goldBox.addAll([
      GoldTransaction(id: '1', type: 'gold_18', purchaseDate: DateTime(2025, 1, 2), purchasePricePerUnit: 52518583, quantity: 100, description: ''),
      GoldTransaction(id: '2', type: 'gold_18', purchaseDate: DateTime(2025, 2, 9), purchasePricePerUnit: 65792511, quantity: 61.195, description: ''),
      GoldTransaction(id: '3', type: 'gold_18', purchaseDate: DateTime(2025, 4, 13), purchasePricePerUnit: 76180802, quantity: 50, description: ''),
      GoldTransaction(id: '4', type: 'gold_18', purchaseDate: DateTime(2025, 10, 6), purchasePricePerUnit: 105960571, quantity: 100, description: ''),
      GoldTransaction(id: '5', type: 'gold_18', purchaseDate: DateTime(2025, 11, 10), purchasePricePerUnit: 105730000, quantity: 60, description: ''),
      GoldTransaction(id: '6', type: 'gold_18', purchaseDate: DateTime(2025, 12, 14), purchasePricePerUnit: 138048000, quantity: 15, description: ''),
    ]);

    coinBox.addAll([
      CoinTransaction(id: 'c1', coinType: 'coin_quarter', purchaseDate: DateTime(2023, 1, 17), purchasePricePerUnit: 70500000, count: 3, description: 'خرید از بورس کالای کارگزاری آگاه'),
      CoinTransaction(id: 'c2', coinType: 'coin_new', purchaseDate: DateTime(2025, 1, 1), purchasePricePerUnit: 560000000, count: 2, description: 'خرید از زهرا'),
      CoinTransaction(id: 'c3', coinType: 'coin_quarter', purchaseDate: DateTime(2025, 1, 1), purchasePricePerUnit: 174000000, count: 1, description: 'خرید از زهرا'),
      CoinTransaction(id: 'c4', coinType: 'coin_new', purchaseDate: DateTime(2025, 9, 8), purchasePricePerUnit: 832224932, count: 6, description: 'خرید از مرکز مبادلات سکه و ارز'),
      CoinTransaction(id: 'c5', coinType: 'coin_half', purchaseDate: DateTime(2025, 9, 8), purchasePricePerUnit: 441195425, count: 10, description: 'خرید از مرکز مبادلات سکه و ارز'),
      CoinTransaction(id: 'c6', coinType: 'coin_quarter', purchaseDate: DateTime(2025, 9, 8), purchasePricePerUnit: 257758617, count: 14, description: 'خرید از مرکز مبادلات سکه و ارز'),
      CoinTransaction(id: 'c7', coinType: 'coin_half', purchaseDate: DateTime(2025, 11, 12), purchasePricePerUnit: 575585000, count: 1, description: 'خرید از مرکز مبادلات کاربری مریم'),
      CoinTransaction(id: 'c8', coinType: 'coin_quarter', purchaseDate: DateTime(2025, 11, 12), purchasePricePerUnit: 327850000, count: 2, description: 'خرید از مرکز مبادلات کابری مریم'),
      CoinTransaction(id: 'c9', coinType: 'coin_new', purchaseDate: DateTime(2026, 2, 15), purchasePricePerUnit: 1930000000, count: 4, description: 'خرید از علی بابت پول ماشین'),
      CoinTransaction(id: 'c10', coinType: 'coin_quarter', purchaseDate: DateTime(2026, 2, 15), purchasePricePerUnit: 525000000, count: 6, description: 'خرید از علی بابت پول ماشین'),
      CoinTransaction(id: 'c11', coinType: 'coin_half', purchaseDate: DateTime(2026, 2, 15), purchasePricePerUnit: 970000000, count: 3, description: 'خرید از علی بابت پول ماشین'),
    ]);
  }

  List<GoldTransaction> get activeGold =>
      goldBox.values.where((g) => g.remainingQuantity > 0.0001).toList();

  List<CoinTransaction> get activeCoins =>
      coinBox.values.where((c) => c.remainingCount > 0).toList();

  Future<void> addGold(GoldTransaction t) async {
    await goldBox.add(t);
    notifyListeners();
  }

  Future<void> updateGold(GoldTransaction t) async {
    await t.save();
    notifyListeners();
  }

  Future<void> deleteGold(GoldTransaction t) async {
    final salesToDelete =
        saleBox.values.where((s) => s.lotId == t.id && s.isGold).toList();
    for (var s in salesToDelete) await s.delete();
    await t.delete();
    notifyListeners();
  }

  Future<void> addCoin(CoinTransaction t) async {
    await coinBox.add(t);
    notifyListeners();
  }

  Future<void> updateCoin(CoinTransaction t) async {
    await t.save();
    notifyListeners();
  }

  Future<void> deleteCoin(CoinTransaction t) async {
    final salesToDelete =
        saleBox.values.where((s) => s.lotId == t.id && !s.isGold).toList();
    for (var s in salesToDelete) await s.delete();
    await t.delete();
    notifyListeners();
  }

  // -------------------- Sell (منطق اصلی و درست) --------------------
  Future<void> sellGold(
    GoldTransaction lot,
    double quantity,
    double pricePerUnit,
    DateTime saleDate,
  ) async {
    if (quantity <= 0 || quantity > lot.remainingQuantity) return;

    final sale = SaleTransaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      lotId: lot.id,
      saleDate: saleDate,
      salePricePerUnit: pricePerUnit,
      quantity: quantity,
      isGold: true,
      purchasePricePerUnit: lot.purchasePricePerUnit,
      purchaseDate: lot.purchaseDate,
    );

    lot.remainingQuantity -= quantity;
    if (lot.remainingQuantity <= 0.0001) lot.remainingQuantity = 0;

    await saleBox.add(sale);
    await lot.save();
    notifyListeners();
  }

  Future<void> sellCoin(
    CoinTransaction lot,
    int count,
    double pricePerUnit,
    DateTime saleDate,
  ) async {
    if (count <= 0 || count > lot.remainingCount) return;

    final sale = SaleTransaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      lotId: lot.id,
      saleDate: saleDate,
      salePricePerUnit: pricePerUnit,
      quantity: count.toDouble(),
      isGold: false,
      coinType: lot.coinType,
      purchasePricePerUnit: lot.purchasePricePerUnit,
      purchaseDate: lot.purchaseDate,
    );

    lot.remainingCount -= count;
    if (lot.remainingCount == 0) lot.remainingCount = 0;

    await saleBox.add(sale);
    await lot.save();
    notifyListeners();
  }

  // -------------------- Delete Sale (برگشت مقدار به دارایی) --------------------
  Future<void> deleteSale(SaleTransaction sale) async {
    if (sale.isGold) {
      final lot = goldBox.get(sale.lotId);
      if (lot != null) {
        lot.remainingQuantity = lot.remainingQuantity + sale.quantity;
        if (lot.remainingQuantity > lot.quantity) {
          lot.remainingQuantity = lot.quantity;
        }
        if (lot.remainingQuantity < 0) lot.remainingQuantity = 0;
        await lot.save();
      }
    } else {
      final lot = coinBox.get(sale.lotId);
      if (lot != null) {
        lot.remainingCount = lot.remainingCount + sale.quantity.toInt();
        if (lot.remainingCount > lot.count) lot.remainingCount = lot.count;
        if (lot.remainingCount < 0) lot.remainingCount = 0;
        await lot.save();
      }
    }

    await sale.delete();
    notifyListeners();
  }

  // -------------------- Update Sale (تنظیم دقیق باقی‌مانده) --------------------
  Future<void> updateSale(
    SaleTransaction sale, {
    required double newQuantity,
    required double newPrice,
    required DateTime newDate,
  }) async {
    if (newQuantity <= 0 || newPrice <= 0) return;

    final oldQuantity = sale.quantity;

    if (sale.isGold) {
      final lot = goldBox.get(sale.lotId);
      if (lot != null) {
        // مقدار فروخته‌شدهٔ قبلی را برمی‌گردانیم و مقدار جدید را کم می‌کنیم
        lot.remainingQuantity = lot.remainingQuantity + oldQuantity - newQuantity;
        if (lot.remainingQuantity > lot.quantity) {
          lot.remainingQuantity = lot.quantity;
        }
        if (lot.remainingQuantity < 0) lot.remainingQuantity = 0;
        await lot.save();
      }
    } else {
      final lot = coinBox.get(sale.lotId);
      if (lot != null) {
        lot.remainingCount =
            lot.remainingCount + oldQuantity.toInt() - newQuantity.toInt();
        if (lot.remainingCount > lot.count) lot.remainingCount = lot.count;
        if (lot.remainingCount < 0) lot.remainingCount = 0;
        await lot.save();
      }
    }

    sale.quantity = newQuantity;
    sale.salePricePerUnit = newPrice;
    sale.saleDate = newDate;
    await sale.save();
    notifyListeners();
  }

  double get totalRealizedProfit {
    double profit = 0;
    for (var sale in saleBox.values) {
      profit +=
          (sale.salePricePerUnit - sale.purchasePricePerUnit) * sale.quantity;
    }
    return profit;
  }

  double getSaleProfit(SaleTransaction sale) {
    return (sale.salePricePerUnit - sale.purchasePricePerUnit) * sale.quantity;
  }

  double getRealizedProfitUntil(DateTime date) {
    double profit = 0;
    final endOfDay = date.add(const Duration(days: 1));
    for (var sale in saleBox.values) {
      if (sale.saleDate.isBefore(endOfDay)) {
        profit +=
            (sale.salePricePerUnit - sale.purchasePricePerUnit) * sale.quantity;
      }
    }
    return profit;
  }

  double getUnrealizedProfit(
    Map<String, double> currentPrices,
    double interestRate, {
    DateTime? asOf,
    bool deductBankInterest = true,
  }) {
    final endDate = asOf ?? DateTime.now();
    double profit = 0;

    for (var g in activeGold) {
      final cp = currentPrices[g.type] ?? 0;
      final paid = g.purchasePricePerUnit * g.remainingQuantity;
      final days = Calculator.daysBetween(g.purchaseDate, endDate);
      if (deductBankInterest) {
        profit += Calculator.calculateProfit(
          currentPrice: cp,
          purchasePrice: g.purchasePricePerUnit,
          quantity: g.remainingQuantity,
          paidAmount: paid,
          interestRate: interestRate,
          days: days,
        );
      } else {
        profit += Calculator.assetProfit(
          currentPrice: cp,
          quantity: g.remainingQuantity,
          paidAmount: paid,
        );
      }
    }

    for (var c in activeCoins) {
      final cp = currentPrices[c.coinType] ?? 0;
      final paid = c.purchasePricePerUnit * c.remainingCount;
      final days = Calculator.daysBetween(c.purchaseDate, endDate);
      if (deductBankInterest) {
        profit += Calculator.calculateProfit(
          currentPrice: cp,
          purchasePrice: c.purchasePricePerUnit,
          quantity: c.remainingCount.toDouble(),
          paidAmount: paid,
          interestRate: interestRate,
          days: days,
        );
      } else {
        profit += Calculator.assetProfit(
          currentPrice: cp,
          quantity: c.remainingCount.toDouble(),
          paidAmount: paid,
        );
      }
    }

    return profit;
  }

  Future<Map<String, dynamic>> exportAllData() async {
    final goldData = goldBox.values.map((g) => {
          'id': g.id,
          'type': g.type,
          'purchaseDate': g.purchaseDate.toIso8601String(),
          'purchasePricePerUnit': g.purchasePricePerUnit,
          'quantity': g.quantity,
          'description': g.description,
          'remainingQuantity': g.remainingQuantity,
        }).toList();

    final coinData = coinBox.values.map((c) => {
          'id': c.id,
          'coinType': c.coinType,
          'purchaseDate': c.purchaseDate.toIso8601String(),
          'purchasePricePerUnit': c.purchasePricePerUnit,
          'count': c.count,
          'description': c.description,
          'remainingCount': c.remainingCount,
        }).toList();

    final saleData = saleBox.values.map((s) => {
          'id': s.id,
          'lotId': s.lotId,
          'saleDate': s.saleDate.toIso8601String(),
          'salePricePerUnit': s.salePricePerUnit,
          'quantity': s.quantity,
          'isGold': s.isGold,
          'coinType': s.coinType,
          'purchasePricePerUnit': s.purchasePricePerUnit,
          'purchaseDate': s.purchaseDate.toIso8601String(),
        }).toList();

    return {
      'goldTransactions': goldData,
      'coinTransactions': coinData,
      'saleTransactions': saleData,
      'exportDate': DateTime.now().toIso8601String(),
    };
  }

  Future<void> importData(Map<String, dynamic> data) async {
    await goldBox.clear();
    await coinBox.clear();
    await saleBox.clear();

    final goldList = data['goldTransactions'] as List? ?? [];
    for (var item in goldList) {
      final g = GoldTransaction(
        id: item['id'],
        type: item['type'],
        purchaseDate: DateTime.parse(item['purchaseDate']),
        purchasePricePerUnit: (item['purchasePricePerUnit'] as num).toDouble(),
        quantity: (item['quantity'] as num).toDouble(),
        description: item['description'] ?? '',
        remainingQuantity: (item['remainingQuantity'] as num).toDouble(),
      );
      await goldBox.add(g);
    }

    final coinList = data['coinTransactions'] as List? ?? [];
    for (var item in coinList) {
      final c = CoinTransaction(
        id: item['id'],
        coinType: item['coinType'],
        purchaseDate: DateTime.parse(item['purchaseDate']),
        purchasePricePerUnit: (item['purchasePricePerUnit'] as num).toDouble(),
        count: item['count'],
        description: item['description'] ?? '',
        remainingCount: item['remainingCount'],
      );
      await coinBox.add(c);
    }

    final saleList = data['saleTransactions'] as List? ?? [];
    for (var item in saleList) {
      final s = SaleTransaction(
        id: item['id'],
        lotId: item['lotId'],
        saleDate: DateTime.parse(item['saleDate']),
        salePricePerUnit: (item['salePricePerUnit'] as num).toDouble(),
        quantity: (item['quantity'] as num).toDouble(),
        isGold: item['isGold'],
        coinType: item['coinType'],
        purchasePricePerUnit: (item['purchasePricePerUnit'] as num).toDouble(),
        purchaseDate: DateTime.parse(item['purchaseDate']),
      );
      await saleBox.add(s);
    }

    notifyListeners();
  }
}