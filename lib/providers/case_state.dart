import 'package:flutter/material.dart';
import '../models/case_model.dart';
import '../services/storage_service.dart';
import '../services/iap_service.dart';
import 'package:intl/intl.dart';

class CaseState extends ChangeNotifier {
  CaseModel _currentCase = CaseModel();
  bool _isLoading = false;

  // IAP Entitlements
  bool _isPurchasedProtection = false;
  bool _isPurchasedAction = false;
  bool _isPurchasedYearly = false;

  // Notification states
  int _alertDays = 7;
  bool _isAlertEnabled = false;

  CaseModel get currentCase => _currentCase;
  bool get isLoading => _isLoading;

  bool get isPurchasedProtection => _isPurchasedProtection || _isPurchasedYearly;
  bool get isPurchasedAction => _isPurchasedAction || _isPurchasedYearly;
  bool get isPurchasedYearly => _isPurchasedYearly;
  bool get isPremium => isPurchasedProtection || isPurchasedAction || isPurchasedYearly;

  int get alertDays => _alertDays;
  bool get isAlertEnabled => _isAlertEnabled;

  CaseState() {
    _loadState();
  }

  // Load from local storage
  Future<void> _loadState() async {
    _isLoading = true;
    notifyListeners();

    try {
      _currentCase = await StorageService.loadCase();
      _isPurchasedProtection = await StorageService.getBool('purchased_protection', defaultValue: false);
      _isPurchasedAction = await StorageService.getBool('purchased_action', defaultValue: false);
      _isPurchasedYearly = await StorageService.getBool('purchased_yearly', defaultValue: false);
      
      _alertDays = await StorageService.getInt('alert_days', defaultValue: 7);
      _isAlertEnabled = await StorageService.getBool('alert_enabled', defaultValue: false);
      
      // Update from RevenueCat if configured
      await syncWithRevenueCat();
    } catch (e) {
      debugPrint("Error loading state: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Save Case data
  Future<void> updateCase(CaseModel updatedCase) async {
    _currentCase = updatedCase;
    await StorageService.saveCase(_currentCase);
    notifyListeners();
  }

  // Purchase Protection Pack
  Future<bool> buyProtectionPack() async {
    bool success = await IapService.purchaseProduct(IapService.protectionPackId);
    if (success) {
      _isPurchasedProtection = true;
      await StorageService.setBool('purchased_protection', true);
      notifyListeners();
    }
    return success;
  }

  // Purchase Action Pack
  Future<bool> buyActionPack() async {
    bool success = await IapService.purchaseProduct(IapService.actionPackId);
    if (success) {
      _isPurchasedAction = true;
      await StorageService.setBool('purchased_action', true);
      notifyListeners();
    }
    return success;
  }

  // Purchase Yearly Subscription
  Future<bool> buyYearlySubscription() async {
    bool success = await IapService.purchaseProduct(IapService.yearlyId);
    if (success) {
      _isPurchasedYearly = true;
      _isPurchasedProtection = true;
      _isPurchasedAction = true;
      await StorageService.setBool('purchased_yearly', true);
      await StorageService.setBool('purchased_protection', true);
      await StorageService.setBool('purchased_action', true);
      notifyListeners();
    }
    return success;
  }

  // Restore purchases
  Future<void> restorePurchases() async {
    _isLoading = true;
    notifyListeners();
    try {
      final activeEntitlements = await IapService.restorePurchases();
      final hasPro = activeEntitlements.contains('moneyback-pro');
      _isPurchasedProtection = activeEntitlements.contains(IapService.protectionPackId) || hasPro;
      _isPurchasedAction = activeEntitlements.contains(IapService.actionPackId) || hasPro;
      _isPurchasedYearly = activeEntitlements.contains(IapService.yearlyId) || hasPro;

      if (_isPurchasedYearly) {
        _isPurchasedProtection = true;
        _isPurchasedAction = true;
      }

      await StorageService.setBool('purchased_protection', _isPurchasedProtection);
      await StorageService.setBool('purchased_action', _isPurchasedAction);
      await StorageService.setBool('purchased_yearly', _isPurchasedYearly);
    } catch (e) {
      debugPrint("Error restoring purchases: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Sync RevenueCat entitlements
  Future<void> syncWithRevenueCat() async {
    try {
      final activeEntitlements = await IapService.getActiveEntitlements();
      if (activeEntitlements.isNotEmpty) {
        final hasPro = activeEntitlements.contains('moneyback-pro');
        _isPurchasedProtection = activeEntitlements.contains(IapService.protectionPackId) || hasPro;
        _isPurchasedAction = activeEntitlements.contains(IapService.actionPackId) || hasPro;
        _isPurchasedYearly = activeEntitlements.contains(IapService.yearlyId) || hasPro;

        if (_isPurchasedYearly) {
          _isPurchasedProtection = true;
          _isPurchasedAction = true;
        }

        await StorageService.setBool('purchased_protection', _isPurchasedProtection);
        await StorageService.setBool('purchased_action', _isPurchasedAction);
        await StorageService.setBool('purchased_yearly', _isPurchasedYearly);
      }
    } catch (e) {
      debugPrint("Failed to sync with RevenueCat: $e");
    }
  }

  // Update alert preferences
  Future<void> setAlertPreferences(int days, bool enabled) async {
    _alertDays = days;
    _isAlertEnabled = enabled;
    await StorageService.setInt('alert_days', days);
    await StorageService.setBool('alert_enabled', enabled);
    notifyListeners();
  }

  // Calculations
  double get evidenceCompleteness {
    double progress = 0.0;
    
    // 1. Amount filled (15%)
    if (_currentCase.amount > 0) progress += 0.15;
    
    // 2. Dates filled (15%)
    if (_currentCase.borrowDate != null && _currentCase.repayDate != null) progress += 0.15;

    // 3. 金流證明 (25%)
    if (_currentCase.hasTransferRecord) {
      progress += 0.15;
      if (_currentCase.transferDate != null) progress += 0.10;
    } else if (_currentCase.hasCash) {
      progress += 0.15; // cash has lower completeness since no paper trail
    } else if (_currentCase.isUnprovable) {
      progress += 0.05;
    }

    // 4. 對話紀錄 (25%)
    if (_currentCase.hasLineScreenshots) {
      progress += 0.25;
    } else if (_currentCase.hasVerbalPromise) {
      progress += 0.15;
    } else if (_currentCase.hasNoResponse) {
      progress += 0.10;
    }

    // 5. 連帶保證人 (10%)
    if (!_currentCase.hasCosigner) {
      progress += 0.10; // If no cosigner, this part is not required, auto-complete
    } else {
      if (_currentCase.cosignerName.isNotEmpty && _currentCase.cosignerAddress.isNotEmpty) {
        progress += 0.10;
      }
    }

    // 6. User and recipient details (10%)
    double detailsProgress = 0.0;
    if (_currentCase.senderName.isNotEmpty) detailsProgress += 0.025;
    if (_currentCase.senderAddress.isNotEmpty) detailsProgress += 0.025;
    if (_currentCase.recipientName.isNotEmpty) detailsProgress += 0.025;
    if (_currentCase.recipientAddress.isNotEmpty) detailsProgress += 0.025;
    progress += detailsProgress;

    // Round to avoid floating point precision issues
    final roundedProgress = double.parse(progress.toStringAsFixed(4));
    return roundedProgress.clamp(0.0, 1.0);
  }

  List<String> get completedItems {
    List<String> items = [];
    if (_currentCase.hasTransferRecord) {
      items.add("金流證明（有轉帳紀錄）");
    }
    if (_currentCase.hasLineScreenshots) {
      items.add("借貸合意（對話內對方未否認欠款）");
    }
    if (_currentCase.hasCosigner && 
        _currentCase.cosignerName.isNotEmpty && 
        _currentCase.cosignerAddress.isNotEmpty) {
      items.add("連帶保證人資料已取得");
    }
    return items;
  }

  List<String> get missingItems {
    List<String> items = [];
    // ⚠️ 缺少正式催告紀錄（無明確限期還款字眼）— 預設顯示
    items.add("缺少正式催告紀錄（無明確限期還款字眼）");
    
    // ⚠️ 缺少對方明確身分資料 — 僅當對方地址欄位為空時顯示
    if (_currentCase.recipientAddress.isEmpty) {
      items.add("缺少對方明確身分資料");
    }
    
    // ⚠ 缺少書面/金流證明 — 僅當用戶未勾選「有銀行匯款」時顯示，文字依債務類型動態調整
    if (!_currentCase.hasTransferRecord) {
      final isNonCashType = ['commercial', 'rental', 'online_shopping'].contains(_currentCase.debtType);
      items.add(isNonCashType ? "無交付／履行證明，僅有口頭約定" : "無金流證明，僅有口頭或對話紀錄");
    }
    return items;
  }

  String get situationStatusText {
    switch (_currentCase.debtType) {
      case 'advance':
        switch (_currentCase.situation) {
          case "對方不還錢":
            return "你有基本的代墊憑證，目前處於代墊款催收準備階段。";
          case "對方一直拖":
            return "對方的拖延代墊款行為已構成遲延責任，你有權要求立即清償。";
          case "對方已失聯":
            return "代墊債務人失聯不影響你的催告效力，存證信函仍可依戶籍地寄送。";
          default:
            return "先搞清楚狀況，才能做對下一步。";
        }
      case 'commercial':
        switch (_currentCase.situation) {
          case "對方不還錢":
            return "你有服務或交貨憑證，目前處於契約給付請求準備階段。";
          case "對方一直拖":
            return "對方的給付遲延已構成契約違約，你有權要求依約付款及遲延利息。";
          case "對方已失聯":
            return "商業債務人失聯不影響存證信函催告效力，若為公司可寄至登記地址。";
          default:
            return "先搞清楚狀況，才能做對下一步。";
        }
      case 'rental':
        switch (_currentCase.situation) {
          case "對方不還錢":
            return "你有租賃契約憑證，目前處於催告租金或押金給付準備階段。";
          case "對方一直拖":
            return "對方的拖延欠租已構成遲延責任，累積達兩期租額可依法終止租約。";
          case "對方已失聯":
            return "承租人或出租人失聯不影響催告效力，存證信函可寄至契約或戶籍地址。";
          default:
            return "先搞清楚狀況，才能做對下一步。";
        }
      case 'online_shopping':
        switch (_currentCase.situation) {
          case "對方不還錢":
            return "你有交易或代購合意憑證，目前處於商品或退款給付請求準備階段。";
          case "對方一直拖":
            return "對方的遲延給付或出貨已構成違約，你有權催告限期履行或解除契約。";
          case "對方已失聯":
            return "交易對象失聯不影響催告效力，存證信函可寄至對方登記或留存地址。";
          default:
            return "先搞清楚狀況，才能做對下一步。";
        }
      case 'loan':
      default:
        switch (_currentCase.situation) {
          case "對方不還錢":
            return "你有基本的證據條件，目前處於正式催收準備階段。";
          case "對方一直拖":
            return "對方的拖延行為已構成遲延責任，你有權要求限期清償。";
          case "對方已失聯":
            return "對方失聯不影響你的催告效力，存證信函仍可依戶籍地寄送。";
          default:
            return "先搞清楚狀況，才能做對下一步。";
        }
    }
  }

  String get situationDescription {
    switch (_currentCase.debtType) {
      case 'advance':
        return "你的代墊款屬於不當得利返還請求權，具備完整的法律依據。";
      case 'commercial':
        return "商業款項糾紛屬於契約債務不履行，你有權要求對方履行付款義務。";
      case 'rental':
        return "租金或押金糾紛屬於租賃契約請求權，存證信函是最有效的第一步。";
      case 'online_shopping':
        return "代購款項屬於委任或消費寄託關係，你有權要求對方返還款項。";
      case 'loan':
      default:
        return situationStatusText;
    }
  }

  String get situationWarningText {
    switch (_currentCase.situation) {
      case "對方不還錢":
        return "不要繼續傳情緒性訊息給對方。這會讓你的催告紀錄出現對自己不利的字眼。";
      case "對方一直拖":
        return "不要接受對方新的口頭承諾而不要求書面紀錄。每一次口頭承諾都是新的拖延工具。";
      case "對方已失聯":
        return "不要只靠私訊聯繫。對方封鎖你後私訊無催告效力，存證信函才是唯一有效的催告方式。";
      default:
        return "";
    }
  }

  int get overdueDays {
    if (_currentCase.repayDate == null) return 0;
    final today = DateTime.now();
    final cleanToday = DateTime(today.year, today.month, today.day);
    final cleanRepay = DateTime(_currentCase.repayDate!.year, _currentCase.repayDate!.month, _currentCase.repayDate!.day);
    final diff = cleanToday.difference(cleanRepay).inDays;
    return diff > 0 ? diff : 0;
  }

  // Format AD to ROC year string (e.g. 2026/06/16 -> 中華民國 115 年 6 月 16 日)
  static String formatToRocString(DateTime? date) {
    if (date == null) return "[日期]";
    final rocYear = date.year - 1911;
    return "中華民國 $rocYear 年 ${date.month} 月 ${date.day} 日";
  }

  // Return separate parts of ROC year
  static Map<String, String> getRocDateParts(DateTime? date) {
    if (date == null) {
      return {
        'year': '[年]',
        'month': '[月]',
        'day': '[日]',
      };
    }
    return {
      'year': '${date.year - 1911}',
      'month': '${date.month}',
      'day': '${date.day}',
    };
  }

  // Helper method to simulate a mock payment for testing
  Future<void> simulatePurchaseMock(String productId) async {
    _isLoading = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 800));
    
    if (productId == IapService.protectionPackId) {
      _isPurchasedProtection = true;
      await StorageService.setBool('purchased_protection', true);
    } else if (productId == IapService.actionPackId) {
      _isPurchasedAction = true;
      await StorageService.setBool('purchased_action', true);
    } else if (productId == IapService.yearlyId) {
      _isPurchasedYearly = true;
      _isPurchasedProtection = true;
      _isPurchasedAction = true;
      await StorageService.setBool('purchased_yearly', true);
      await StorageService.setBool('purchased_protection', true);
      await StorageService.setBool('purchased_action', true);
    }
    
    _isLoading = false;
    notifyListeners();
  }

  // Reset all purchase statuses
  Future<void> resetPurchases() async {
    _isPurchasedProtection = false;
    _isPurchasedAction = false;
    _isPurchasedYearly = false;
    await StorageService.setBool('purchased_protection', false);
    await StorageService.setBool('purchased_action', false);
    await StorageService.setBool('purchased_yearly', false);
    notifyListeners();
  }
}
