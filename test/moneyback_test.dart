import 'package:flutter_test/flutter_test.dart';
import 'package:moneyback/models/case_model.dart';
import 'package:moneyback/providers/case_state.dart';

import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CaseModel Tests', () {
    test('Should serialize and deserialize correctly', () {
      final now = DateTime(2026, 6, 16);
      final model = CaseModel(
        situation: "對方不還錢",
        amount: 50000.0,
        borrowDate: DateTime(2026, 1, 1),
        repayDate: DateTime(2026, 5, 1),
        sendDate: now,
        hasTransferRecord: true,
        transferDate: DateTime(2026, 1, 2),
        senderName: "王大明",
        senderAddress: "台北市信義路1號",
        recipientName: "李小華",
        recipientAddress: "新北市板橋路2號",
        chatAppName: "LINE",
        evidenceTypes: "對話截圖與匯款單",
        debtType: "commercial",
        serviceDescription: "網頁設計服務",
        rentalObject: "租用相機",
      );

      final jsonMap = model.toJson();
      final decodedModel = CaseModel.fromJson(jsonMap);

      expect(decodedModel.situation, "對方不還錢");
      expect(decodedModel.amount, 50000.0);
      expect(decodedModel.borrowDate, DateTime(2026, 1, 1));
      expect(decodedModel.repayDate, DateTime(2026, 5, 1));
      expect(decodedModel.hasTransferRecord, true);
      expect(decodedModel.transferDate, DateTime(2026, 1, 2));
      expect(decodedModel.senderName, "王大明");
      expect(decodedModel.recipientName, "李小華");
      expect(decodedModel.chatAppName, "LINE");
      expect(decodedModel.debtType, "commercial");
      expect(decodedModel.serviceDescription, "網頁設計服務");
      expect(decodedModel.rentalObject, "租用相機");
    });
  });

  group('CaseState Utility Calculations', () {
    test('ROC Year Conversion should calculate correctly', () {
      final date = DateTime(2026, 6, 16);
      final parts = CaseState.getRocDateParts(date);
      
      // 2026 - 1911 = 115 (Republic of China Year)
      expect(parts['year'], '115');
      expect(parts['month'], '6');
      expect(parts['day'], '16');

      final formattedStr = CaseState.formatToRocString(date);
      expect(formattedStr, "中華民國 115 年 6 月 16 日");
    });

    test('Overdue Days should calculate correctly', () {
      // Setup a CaseState with a mock repayDate in the past
      final state = CaseState();
      
      final today = DateTime.now();
      final repayDate = today.subtract(const Duration(days: 10));
      
      final mockCase = CaseModel(
        amount: 20000,
        borrowDate: today.subtract(const Duration(days: 40)),
        repayDate: repayDate,
      );

      state.updateCase(mockCase);

      // Overdue days should be exactly 10 days
      expect(state.overdueDays, 10);
    });

    test('Overdue Days should be 0 if repayDate is in the future', () {
      final state = CaseState();
      final today = DateTime.now();
      final repayDate = today.add(const Duration(days: 10));
      
      final mockCase = CaseModel(
        amount: 20000,
        borrowDate: today,
        repayDate: repayDate,
      );

      state.updateCase(mockCase);

      // Overdue days should be 0 because repayDate has not passed
      expect(state.overdueDays, 0);
    });

    test('Completeness progress should reflect entered data', () {
      final state = CaseState();
      
      // Default case model should have low completeness
      expect(state.evidenceCompleteness, lessThan(0.5));

      // Fill basic details
      final completedCase = CaseModel(
        situation: "對方不還錢",
        amount: 15000.0,
        borrowDate: DateTime(2026, 1, 1),
        repayDate: DateTime(2026, 2, 1),
        hasTransferRecord: true,
        transferDate: DateTime(2026, 1, 1),
        hasLineScreenshots: true,
        chatAppName: "LINE",
        senderName: "王大明",
        senderAddress: "台北市信義路1號",
        recipientName: "李小華",
        recipientAddress: "新北市板橋路2號",
        hasCosigner: false, // If no cosigner, this part is auto-completed
      );

      state.updateCase(completedCase);

      // A fully filled case should have 100% completeness
      expect(state.evidenceCompleteness, 1.0);
    });

    test('situationStatusText and situationDescription should dynamically adjust based on debtType', () {
      final state = CaseState();

      // Test default/loan
      final loanCase = CaseModel(
        debtType: 'loan',
        situation: "對方不還錢",
      );
      state.updateCase(loanCase);
      expect(state.situationStatusText, "你有基本的證據條件，目前處於正式催收準備階段。");
      expect(state.situationDescription, "你有基本的證據條件，目前處於正式催收準備階段。");

      // Test advance
      final advanceCase = CaseModel(
        debtType: 'advance',
        situation: "對方一直拖",
      );
      state.updateCase(advanceCase);
      expect(state.situationStatusText, "對方的拖延代墊款行為已構成遲延責任，你有權要求立即清償。");
      expect(state.situationDescription, "你的代墊款屬於不當得利返還請求權，具備完整的法律依據。");

      // Test commercial
      final commercialCase = CaseModel(
        debtType: 'commercial',
        situation: "對方已失聯",
      );
      state.updateCase(commercialCase);
      expect(state.situationStatusText, "商業債務人失聯不影響存證信函催告效力，若為公司可寄至登記地址。");
      expect(state.situationDescription, "商業款項糾紛屬於契約債務不履行，你有權要求對方履行付款義務。");

      // Test rental
      final rentalCase = CaseModel(
        debtType: 'rental',
        situation: "對方一直拖",
      );
      state.updateCase(rentalCase);
      expect(state.situationStatusText, "對方的拖延欠租已構成遲延責任，累積達兩期租額可依法終止租約。");
      expect(state.situationDescription, "租金或押金糾紛屬於租賃契約請求權，存證信函是最有效的第一步。");

      // Test online_shopping
      final shoppingCase = CaseModel(
        debtType: 'online_shopping',
        situation: "對方不還錢",
      );
      state.updateCase(shoppingCase);
      expect(state.situationStatusText, "你有交易或代購合意憑證，目前處於商品或退款給付請求準備階段。");
      expect(state.situationDescription, "代購款項屬於委任或消費寄託關係，你有權要求對方返還款項。");
    });
  });
}
