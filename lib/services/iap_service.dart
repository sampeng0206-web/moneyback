import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'dart:io';

class IapService {
  // RevenueCat IAP Product IDs
  static const String protectionPackId = 'moneyback.protection.pack.190';
  static const String actionPackId = 'moneyback.action.pack.190';
  static const String yearlyId = 'moneyback.yearly.490';

  // API Keys (Placeholder: User should insert their actual RevenueCat keys here)
  static const String _appleApiKey = 'rc_apple_placeholder_key';
  static const String _googleApiKey = 'rc_google_placeholder_key';

  static bool _initialized = false;

  // Initialize RevenueCat SDK
  static Future<void> initialize() async {
    if (_initialized) return;

    if (kIsWeb) {
      debugPrint("RevenueCat is not supported on Web. Running in mock mode.");
      return;
    }

    try {
      // Configure RevenueCat settings
      await Purchases.setLogLevel(LogLevel.debug);

      PurchasesConfiguration? configuration;

      if (Platform.isAndroid) {
        configuration = PurchasesConfiguration(_googleApiKey);
      } else if (Platform.isIOS) {
        configuration = PurchasesConfiguration(_appleApiKey);
      }

      if (configuration != null) {
        await Purchases.configure(configuration);
        _initialized = true;
        debugPrint("RevenueCat initialized successfully.");
      }
    } catch (e) {
      debugPrint("RevenueCat initialization failed: $e. Mock mode will be used.");
    }
  }

  // Purchase a product
  static Future<bool> purchaseProduct(String productId) async {
    if (!_initialized) {
      debugPrint("RevenueCat not initialized. Simulating purchase for $productId...");
      // Simulate network delay and return success for mock testing
      await Future.delayed(const Duration(milliseconds: 500));
      return true;
    }

    try {
      CustomerInfo customerInfo = await Purchases.purchaseProduct(productId);
      return _hasActiveEntitlement(customerInfo, productId);
    } catch (e) {
      debugPrint("RevenueCat purchase error: $e");
      // For testing, if it's a dev build/simulator, we can fail or fallback
      // We return false here to indicate actual payment failed.
      return false;
    }
  }

  // Restore Purchases
  static Future<List<String>> restorePurchases() async {
    if (!_initialized) {
      debugPrint("RevenueCat not initialized. Restoring mock purchases...");
      return [];
    }

    try {
      CustomerInfo customerInfo = await Purchases.restorePurchases();
      return _getActiveEntitlementsFromInfo(customerInfo);
    } catch (e) {
      debugPrint("RevenueCat restore error: $e");
      return [];
    }
  }

  // Get active entitlements
  static Future<List<String>> getActiveEntitlements() async {
    if (!_initialized) {
      return [];
    }

    try {
      CustomerInfo customerInfo = await Purchases.getCustomerInfo();
      return _getActiveEntitlementsFromInfo(customerInfo);
    } catch (e) {
      debugPrint("RevenueCat getCustomerInfo error: $e");
      return [];
    }
  }

  // Helper to extract active entitlements
  static List<String> _getActiveEntitlementsFromInfo(CustomerInfo customerInfo) {
    List<String> entitlements = [];
    
    // Check which entitlements are active in RevenueCat
    // In RevenueCat, entitlements are typically configured to map to products.
    // We assume the entitlement ID matches the product ID or is mapped.
    if (customerInfo.entitlements.all[protectionPackId]?.isActive ?? false) {
      entitlements.add(protectionPackId);
    }
    if (customerInfo.entitlements.all[actionPackId]?.isActive ?? false) {
      entitlements.add(actionPackId);
    }
    if (customerInfo.entitlements.all[yearlyId]?.isActive ?? false) {
      entitlements.add(yearlyId);
      entitlements.add(protectionPackId);
      entitlements.add(actionPackId);
    }

    return entitlements;
  }

  // Helper to check if customer has a specific entitlement active
  static bool _hasActiveEntitlement(CustomerInfo customerInfo, String productId) {
    if (productId == yearlyId) {
      return customerInfo.entitlements.all[yearlyId]?.isActive ?? false;
    }
    
    // If buying protection pack, it is active if directly bought or if yearly is active
    if (productId == protectionPackId) {
      return (customerInfo.entitlements.all[protectionPackId]?.isActive ?? false) ||
             (customerInfo.entitlements.all[yearlyId]?.isActive ?? false);
    }

    // If buying action pack, it is active if directly bought or if yearly is active
    if (productId == actionPackId) {
      return (customerInfo.entitlements.all[actionPackId]?.isActive ?? false) ||
             (customerInfo.entitlements.all[yearlyId]?.isActive ?? false);
    }

    return false;
  }
}
