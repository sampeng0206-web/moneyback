import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/case_model.dart';
import '../providers/case_state.dart';

class PdfService {
  // Generate the PDF document based on Case data and template index
  static Future<Uint8List> generatePdf(CaseModel caseModel, int templateIndex) async {
    final pdf = pw.Document();
    
    // Resolve Chinese Font (Noto Sans TC)
    pw.Font chineseFont;
    try {
      chineseFont = await PdfGoogleFonts.notoSansTCRegular();
    } catch (e) {
      // Fallback to standard Helvetica if offline or failed, 
      // though Helvetica won't render Chinese characters.
      chineseFont = pw.Font.helvetica();
    }

    final String title = "存  證  信  函";
    final String subjectText = _getSubject(caseModel, templateIndex);
    final List<String> explanations = _getExplanations(caseModel, templateIndex);
    
    // Formatting variables
    final sendRocDate = CaseState.getRocDateParts(caseModel.sendDate);
    final String sendDateStr = "中華民國 ${sendRocDate['year']} 年 ${sendRocDate['month']} 月 ${sendRocDate['day']} 日";

    // Recipient & Sender details
    final String recipientName = caseModel.recipientName.isNotEmpty ? caseModel.recipientName : "[對方姓名]";
    final String recipientAddr = caseModel.recipientAddress.isNotEmpty ? caseModel.recipientAddress : "[對方地址]";
    final String senderName = caseModel.senderName.isNotEmpty ? caseModel.senderName : "[您的姓名]";
    final String senderAddr = caseModel.senderAddress.isNotEmpty ? caseModel.senderAddress : "[您的地址]";
    
    // Add page to PDF
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.copyWith(
          marginTop: 2.5 * PdfPageFormat.cm,
          marginBottom: 2.5 * PdfPageFormat.cm,
          marginLeft: 2.5 * PdfPageFormat.cm,
          marginRight: 2.5 * PdfPageFormat.cm,
        ),
        theme: pw.ThemeData.withFont(
          base: chineseFont,
          bold: chineseFont,
        ),
        header: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(bottom: 20),
            child: pw.Text(
              "郵局存證信函格式",
              style: pw.TextStyle(font: chineseFont, fontSize: 10, color: PdfColors.grey),
            ),
          );
        },
        footer: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Divider(thickness: 0.5, color: PdfColors.grey),
              pw.SizedBox(height: 5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      "本文件由 MoneyBack 還我錢來 App 自動生成，內容由用戶自行填寫確認，不構成法律意見。",
                      style: pw.TextStyle(font: chineseFont, fontSize: 8, color: PdfColors.grey700),
                    ),
                  ),
                  pw.Text(
                    "頁碼 ${context.pageNumber} / ${context.pagesCount}",
                    style: pw.TextStyle(font: chineseFont, fontSize: 8, color: PdfColors.grey700),
                  ),
                ],
              ),
            ],
          );
        },
        build: (pw.Context context) {
          return [
            // Title
            pw.Center(
              child: pw.Text(
                title,
                style: pw.TextStyle(
                  font: chineseFont,
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 30),

            // Receiver & Sender details
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("受文者：", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text("$recipientName 先生/小姐/公司", style: const pw.TextStyle(fontSize: 14)),
                          pw.Text(recipientAddr, style: const pw.TextStyle(fontSize: 14)),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 15),
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("發文者：", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text("$senderName 先生/小姐", style: const pw.TextStyle(fontSize: 14)),
                          pw.Text(senderAddr, style: const pw.TextStyle(fontSize: 14)),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 15),
                pw.Row(
                  children: [
                    pw.Text("發文日期：", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                    pw.Text(sendDateStr, style: const pw.TextStyle(fontSize: 14)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 25),
            pw.Divider(thickness: 1, color: PdfColors.black),
            pw.SizedBox(height: 15),

            // Subject
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text("主旨：", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                pw.Expanded(
                  child: pw.Text(
                    subjectText,
                    style: const pw.TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 15),

            // Explanations
            pw.Text("說明：", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
            pw.SizedBox(height: 5),
            pw.ListView.builder(
              itemCount: explanations.length,
              itemBuilder: (pw.Context context, int index) {
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 10),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        _getChineseNumber(index + 1) + "、",
                        style: const pw.TextStyle(fontSize: 14),
                      ),
                      pw.Expanded(
                        child: pw.Text(
                          explanations[index],
                          style: const pw.TextStyle(fontSize: 14)
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            
            pw.SizedBox(height: 30),
            pw.Divider(thickness: 0.5, color: PdfColors.black),
            pw.SizedBox(height: 15),

            // Sincerely
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("此致\n$recipientName 先生/小姐/公司", style: const pw.TextStyle(fontSize: 14)),
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 20, right: 30),
                  child: pw.Text(
                    "$senderName （簽章）",
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  // Helper: Get subject based on template index
  static String _getSubject(CaseModel caseModel, int templateIndex) {
    final amountText = caseModel.amount.toStringAsFixed(0);
    switch (templateIndex) {
      case 0: // 有轉帳紀錄
      case 1: // 只有對話紀錄
        return "關於台端積欠本人新臺幣 $amountText 元債務，請台端於函到七日內清償，特此函告。";
      case 2: // 最後通牒
        return "關於台端積欠本人新臺幣 $amountText 元債務，請台端於函到七日內清償，否則本人將立即採取法律途徑解決，特此通知。";
      case 3: // 連帶保證人
      default:
        return "關於台端積欠本人新臺幣 $amountText 元債務催清償事宜。";
    }
  }

  // Helper: Get explanation lines based on template index
  static List<String> _getExplanations(CaseModel caseModel, int templateIndex) {
    final amountText = caseModel.amount.toStringAsFixed(0);
    
    // Dates formatted
    final borrowRoc = CaseState.getRocDateParts(caseModel.borrowDate);
    final borrowDateStr = "中華民國 ${borrowRoc['year']} 年 ${borrowRoc['month']} 月 ${borrowRoc['day']} 日";
    
    final repayRoc = CaseState.getRocDateParts(caseModel.repayDate);
    final repayDateStr = "中華民國 ${repayRoc['year']} 年 ${repayRoc['month']} 月 ${repayRoc['day']} 日";

    // Safe values (empty value protection)
    final service = (caseModel.serviceDescription?.trim().isEmpty ?? true)
        ? '相關服務／工程'
        : caseModel.serviceDescription!;

    final rental = (caseModel.rentalObject?.trim().isEmpty ?? true)
        ? '租賃標的物'
        : caseModel.rentalObject!;

    switch (templateIndex) {
      case 0: // 範本一｜有轉帳紀錄
        final hasTransferDate = caseModel.transferDate != null;
        final transferRoc = CaseState.getRocDateParts(caseModel.transferDate);
        final transferDateStr = "中華民國 ${transferRoc['year']} 年 ${transferRoc['month']} 月 ${transferRoc['day']} 日";
        final firstSentence = _getDebtDescription(caseModel, debtorText: '台端', service: service, rental: rental);
        return [
          hasTransferDate
            ? "${firstSentence}本人已於$transferDateStr將款項轉帳至台端指定帳戶，此有轉帳紀錄可稽。"
            : "${firstSentence}本人已將款項轉帳至台端指定帳戶，此有轉帳紀錄可稽。",
          "詎料，台端屆期迄未依約清償上開借款，經本人多次催告，台端仍置之不理，顯已構成債務不履行。",
          "為此，特函請台端於本函送達之翌日起七日內，立即清償上開積欠之借款新臺幣 $amountText 元整，及自$repayDateStr起至清償日止，按年息百分之五計算之利息。",
          "如台端逾期仍未清償，本人將不另通知，逕行依法向法院提起訴訟，請求返還借款及利息，並請求台端負擔所有訴訟費用及相關損害賠償，屆時恐增訟累，非本人所樂見。"
        ];

      case 1: // 範本二｜只有對話紀錄
        final chatApp = caseModel.chatAppName.isNotEmpty ? caseModel.chatAppName : "LINE";
        final firstSentence = _getDebtDescription(caseModel, debtorText: '台端', service: service, rental: rental);
        return [
          "${firstSentence}此有雙方 $chatApp 對話紀錄可稽。",
          "詎料，台端屆期迄未依約清償上開借款，經本人多次催告，台端仍置之不理，顯已構成債務不履行。",
          "為此，特函請台端於本函送達之翌日起七日內，立即清償上開積欠之借款新臺幣 $amountText 元整，及自$repayDateStr起至清償日止，按年息百分之五計算之利息。",
          "如台端逾期仍未清償，本人將不另通知，逕行依法向法院提起訴訟，請求返還借款及利息，並請求台端負擔所有訴訟費用及相關損害賠償，屆時恐增訟累，非本人所樂見。"
        ];

      case 2: // 範本三｜最後通牒
        final evidenceList = <String>[];
        if (caseModel.hasTransferRecord) evidenceList.add("轉帳紀錄");
        if (caseModel.hasLineScreenshots) evidenceList.add("對話紀錄");
        if (caseModel.evidenceTypes.isNotEmpty) evidenceList.add(caseModel.evidenceTypes);
        final hasAnyEvidence = evidenceList.isNotEmpty;
        final evidence = evidenceList.join("、");
        final firstSentence = _getDebtDescription(caseModel, debtorText: '台端', service: service, rental: rental);
        return [
          hasAnyEvidence ? "${firstSentence}此有 $evidence 可稽。" : firstSentence,
          "詎料，台端屆期迄未依約清償上開借款，經本人多次催告，台端仍置之不理，顯已構成債務不履行。",
          "本人已多次給予台端清償機會，惟台端均未積極處理。為維護本人合法權益，特再次函請台端於本函送達之翌日起七日內，立即清償上開積欠之借款新臺幣 $amountText 元整，及自$repayDateStr起至清償日止，按年息百分之五計算之利息。",
          "如台端逾期仍未清償，本人將不再容忍，屆時將立即向法院提起民事訴訟，請求返還借款及利息，並請求台端負擔所有訴訟費用、律師費用及相關損害賠償。同時，本人將依法循一切合法途徑維護自身權益，請台端審慎考量，切勿自誤。"
        ];

      case 3: // 範本四｜連帶保證人
        final debtorName = caseModel.recipientName.isNotEmpty ? caseModel.recipientName : "[主債務人]";
        final evidenceList4 = <String>[];
        if (caseModel.hasTransferRecord) evidenceList4.add("轉帳紀錄");
        if (caseModel.hasLineScreenshots) evidenceList4.add("對話紀錄");
        if (caseModel.evidenceTypes.isNotEmpty) evidenceList4.add(caseModel.evidenceTypes);
        final hasAnyEvidence4 = evidenceList4.isNotEmpty;
        final evidence4 = evidenceList4.join("、");
        final firstSentence = _getDebtDescription(caseModel, debtorText: "主債務人 $debtorName", service: service, rental: rental);
        return [
          hasAnyEvidence4
            ? "${firstSentence}台端就上開債務，業已簽立連帶保證契約，同意與主債務人 $debtorName 負連帶清償責任，此有 $evidence4 可稽。"
            : "${firstSentence}台端就上開債務，業已簽立連帶保證契約，同意與主債務人 $debtorName 負連帶清償責任。",
          "詎料，主債務人 $debtorName 屆期迄未依約清償上開借款，經本人多次催告，主債務人仍置之不理，顯已構成債務不履行。",
          "依民法第739條及相關規定，台端身為連帶保證人，應與主債務人負同一清償責任，且不得主張民法第745條之先訴抗辯權。為此，特函請台端於本函送達之翌日起七日內，立即清償上開積欠之借款新臺幣 $amountText 元整，及自$repayDateStr起至清償日止，按年息百分之五計算之利息。",
          "如台端逾期仍未清償，本人將不另通知，逕行依法向法院提起訴訟，請求台端負連帶清償責任，並請求台端負擔所有訴訟費用及相關損害賠償，屆時恐增訟累，非本人所樂見。"
        ];

      default:
        return [];
    }
  }

  // Helper: Get debt description based on debtType
  static String _getDebtDescription(
    CaseModel caseModel, {
    required String debtorText,
    required String service,
    required String rental,
  }) {
    final amountText = caseModel.amount.toStringAsFixed(0);
    final borrowRoc = CaseState.getRocDateParts(caseModel.borrowDate);
    final borrowDateStr = "中華民國 ${borrowRoc['year']} 年 ${borrowRoc['month']} 月 ${borrowRoc['day']} 日";
    final repayRoc = CaseState.getRocDateParts(caseModel.repayDate);
    final repayDateStr = "中華民國 ${repayRoc['year']} 年 ${repayRoc['month']} 月 ${repayRoc['day']} 日";

    switch (caseModel.debtType) {
      case 'advance':
        return "查$debtorText曾委託本人於$borrowDateStr代為墊付新臺幣 $amountText 元整，雙方約定由$debtorText於$repayDateStr前償還上開代墊款項。";
      case 'commercial':
        return "查本人已依約於$borrowDateStr完成$debtorText委託之$service，依約$debtorText應給付本人新臺幣 $amountText 元整，並約定於$repayDateStr前完成付款。";
      case 'rental':
        return "查$debtorText就本人所有之$rental自$borrowDateStr起負有給付租金／押金新臺幣 $amountText 元整之義務，應於$repayDateStr前給付完畢。";
      case 'online_shopping':
        return "查$debtorText曾於$borrowDateStr委託本人代為購買商品，本人已依約代墊購買費用新臺幣 $amountText 元整，$debtorText應於$repayDateStr前返還上開款項。";
      case 'loan':
      default:
        return "查$debtorText曾於$borrowDateStr向本人借款新臺幣 $amountText 元整，並約定於$repayDateStr前清償完畢。";
    }
  }

  static String _getChineseNumber(int num) {
    const list = ["零", "一", "二", "三", "四", "五", "六", "七", "八", "九", "十"];
    if (num >= 0 && num <= 10) return list[num];
    return num.toString();
  }
}

