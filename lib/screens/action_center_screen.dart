import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import '../providers/case_state.dart';
import '../services/pdf_service.dart';
import '../services/notification_service.dart';
import '../theme.dart';
import '../services/ad_service.dart';

class ActionCenterScreen extends StatefulWidget {
  const ActionCenterScreen({super.key});

  @override
  State<ActionCenterScreen> createState() => _ActionCenterScreenState();
}

class _ActionCenterScreenState extends State<ActionCenterScreen> with SingleTickerProviderStateMixin {
  late TabController _letterTabController;
  int _selectedMessageIndex = 0; // 0: 不撕破臉, 1: 正式催告, 2: 最後通牒
  int _selectedLetterTemplateIndex = 0; // 0: 有轉帳, 1: 只有對話, 2: 最後通牒, 3: 連保人

  // Checklist items state
  final List<bool> _checklistValues = List.generate(5, (_) => false);
  final List<String> _checklistItems = [
    "將所有 LINE 對話截圖備份至相簿或雲端",
    "截圖轉帳紀錄的完整頁面（含帳號與金額）",
    "將本次發出的催告訊息截圖留存",
    "記錄對方帳戶資訊或身分證字號（如果知道）",
    "避免刪除任何對話記錄"
  ];

  @override
  void initState() {
    super.initState();
    _letterTabController = TabController(length: 4, vsync: this);

    // Auto-set the recommended tab
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = Provider.of<CaseState>(context, listen: false);
      final recommendedIndex = _getRecommendedTemplateIndex(state);
      setState(() {
        _selectedLetterTemplateIndex = recommendedIndex;
        _letterTabController.animateTo(recommendedIndex);
      });
    });
  }

  @override
  void dispose() {
    _letterTabController.dispose();
    super.dispose();
  }

  // Recommendation logic
  int _getRecommendedTemplateIndex(CaseState state) {
    final model = state.currentCase;
    if (model.hasCosigner) {
      return 3; // 範本四｜連帶保證人
    } else if (model.situation == "對方已失聯") {
      return 2; // 範本三｜最後通牒
    } else if (model.hasTransferRecord) {
      return 0; // 範本一｜有轉帳紀錄
    } else if (model.hasLineScreenshots) {
      return 1; // 範本二｜只有對話紀錄
    }
    // 無轉帳紀錄、無對話截圖（例如僅現金交付或口頭承諾）
    // 不可預設帶入「有轉帳紀錄」或「有對話紀錄」等不實內容
    // 改用最後通牒範本，其內容不強制主張特定證據類型
    return 2;
  }

  String _getRecommendedTemplateName(int index) {
    switch (index) {
      case 0:
        return "範本一（有轉帳紀錄）";
      case 1:
        return "範本二（只有對話紀錄）";
      case 2:
        return "範本三（最後通牒）";
      case 3:
        return "範本四（連帶保證人）";
      default:
        return "";
    }
  }

  String _getRecommendedReason(int index) {
    switch (index) {
      case 0:
        return "因為你有匯款紀錄，這份存證信函的法律效力最強。";
      case 1:
        return "因為你只有通訊軟體的對話內容，以此信函促使對方確認債權。";
      case 2:
        return "因為對方已失聯封鎖，透過此信函進行法律程序前的最終催告。";
      case 3:
        return "因為你的案件有連帶保證人，應依法向其主張連帶債務清償責任。";
      default:
        return "";
    }
  }

  // Helper to get formatted message content
  String _getMessageContent(CaseState state, int index) {
    final model = state.currentCase;
    final amountText = model.amount.toStringAsFixed(0);
    final opponentName = model.recipientName.isNotEmpty ? model.recipientName : "對方";
    final chatApp = model.chatAppName.isNotEmpty ? model.chatAppName : "LINE";
    final borrowDate = CaseState.formatToRocString(model.borrowDate);
    final repayDate = CaseState.formatToRocString(model.repayDate);
    
    // Calculate 7 days after today for repayment deadline
    final deadlineDate = DateTime.now().add(const Duration(days: 7));
    final deadlineRocStr = CaseState.formatToRocString(deadlineDate);

    switch (index) {
      case 0: // 不撕破臉
        return "${opponentName}，我們之前說好 ${repayDate.replaceAll("中華民國 ", "")} 要還的 NT\$$amountText，到今天還沒收到。請你在 ${deadlineRocStr.replaceAll("中華民國 ", "")} 前完成匯款，帳號是 [您的銀行與帳號]。謝謝。";
      case 1: // 正式催告
        return "${opponentName} 先生／小姐，茲通知你，你積欠本人新台幣 $amountText 元整（借款日期：$borrowDate），已逾約定清償期 $repayDate 至今未履行。本人正式要求你於收到此訊息後七日內清償完畢，並以銀行匯款方式匯入本人帳戶，並保留此通知作為催告紀錄。";
      case 2: // 最後通牒
        return "${opponentName}，本人已多次催告，截至今日你仍未履行還款義務。本人保留透過法律途徑追討上述款項之一切權利，相關訴訟費用亦將一併請求。此為最終通知。";
      default:
        return "";
    }
  }

  // Copy text to clipboard
  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("✓ 已複製到剪貼簿，可直接傳送給對方"),
        backgroundColor: AppTheme.actionGreen,
        duration: Duration(seconds: 2),
      ),
    );
    if (!Provider.of<CaseState>(context, listen: false).isPremium) {
      AdService.showInterstitialAd(context: context, onAdDismissed: () {});
    }
  }

  // Print/Preview PDF
  Future<void> _previewPdf(CaseState state, int templateIndex) async {
    final pdfBytes = await PdfService.generatePdf(state.currentCase, templateIndex);
    if (!mounted) return;
    
    // Open full page interactive preview
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text("預覽：${_getRecommendedTemplateName(templateIndex)}"),
          ),
          body: PdfPreview(
            build: (format) => pdfBytes,
            allowPrinting: true,
            allowSharing: true,
            canChangePageFormat: false,
            canChangeOrientation: false,
            actions: const [],
          ),
        ),
      ),
    );
  }

  // Share/Save PDF file
  Future<void> _downloadPdf(CaseState state, int templateIndex) async {
    final pdfBytes = await PdfService.generatePdf(state.currentCase, templateIndex);
    final fileName = "存證信函_${_getRecommendedTemplateName(templateIndex)}.pdf";
    
    // Share sheet lets mobile users "Save to Files", send to computer, print, etc.
    await Printing.sharePdf(bytes: pdfBytes, filename: fileName);
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<CaseState>(context);
    final model = state.currentCase;
    final recommendedIndex = _getRecommendedTemplateIndex(state);

    return Scaffold(
      bottomNavigationBar: state.isPremium ? null : const BannerAdWidget(),
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryNavy,
        title: const Text("行動與證據保全中心"),
        actions: [
          // Show quick PDF download in appbar if Action Pack is unlocked
          if (state.isPurchasedAction)
            IconButton(
              icon: const Icon(Icons.download_rounded),
              tooltip: "快速下載推薦存證信函 PDF",
              onPressed: () => _downloadPdf(state, recommendedIndex),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 2. Banner indicating which packages are unlocked
            _buildUnlockBanner(state),

            // ================== 債權保全包模組 ==================
            if (state.isPurchasedProtection) ...[
              // 3A. Case summary
              _buildCaseSummary(state),

              // 4A. Strategy advice
              _buildStrategyAdvice(),

              // 5A. 3 Collection templates
              _buildMessageTemplates(state),

              // 6A. Preservation checklist
              _buildPreservationChecklist(),
            ] else ...[
              // If they somehow got here without unlocking Protection Pack
              _buildLockedModuleCard(
                title: "🔒 債權保全包功能（已鎖定）",
                description: "解鎖後即可享有客觀案件分析、完備催收策略、三種情境一鍵複製簡訊，以及精準債權保全清單動作。",
              ),
            ],

            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFDEE2E6)),
            const SizedBox(height: 16),

            // ================== 存證信函包模組 ==================
            if (state.isPurchasedAction) ...[
              // 7B. Recommended Banner
              _buildRecommendationBanner(state, recommendedIndex),

              // 8B. Tabs of the 4 templates
              _buildLetterTemplatesTabs(state, recommendedIndex),

              // 9B. Post office sending guide
              _buildPostOfficeGuide(),
            ] else ...[
              // If they somehow got here without unlocking Action Pack
              _buildLockedModuleCard(
                title: "🔒 討錢行動準備包｜存證信函產生器（已鎖定）",
                description: "解鎖即可帶入您的資料，一鍵產生 4 種情境具法律效力的專業存證信函 PDF，包含詳細寄送指引。",
              ),
            ],

            const SizedBox(height: 16),
            const Divider(height: 1, color: Color(0xFFDEE2E6)),
            const SizedBox(height: 16),

            // 10. Push Notifications Setting
            _buildNotificationSettings(state),

            // 11. Bottom disclaimer
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: Center(
                child: Text(
                  "本報告由使用者自行填寫資料並經系統自動生成與排版，內容僅屬客觀事實數據梳理與大眾科普程序介紹，不構成任何正式法律意見。存證信函範本由用戶自行確認內容正確後自行寄送，平台不負擔寄送責任。請依實際個案情況自行判斷，或諮詢專業律師。",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // 2. Lock / Unlock top banner
  Widget _buildUnlockBanner(CaseState state) {
    String text = "";
    Color bgColor = Colors.grey;
    Color textColor = Colors.white;

    if (state.isPurchasedYearly) {
      text = "✓ 年度訂閱 兩項工具已解鎖";
      bgColor = AppTheme.primaryNavy;
    } else if (state.isPurchasedProtection && state.isPurchasedAction) {
      text = "✓ 債權保全包 & 存證信函已解鎖";
      bgColor = AppTheme.actionGreen;
    } else if (state.isPurchasedProtection) {
      text = "✓ 債權保全包 已解鎖";
      bgColor = AppTheme.actionGreen;
    } else if (state.isPurchasedAction) {
      text = "✓ 討錢行動準備包 已解鎖";
      bgColor = AppTheme.secondaryYellow;
      textColor = AppTheme.primaryNavy;
    } else {
      text = "🔒 尚未解鎖任何工具，請返回付費頁";
      bgColor = Colors.grey.shade400;
      textColor = Colors.black87;
    }

    return Container(
      width: double.infinity,
      height: 48,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // 3A. Objective Case Summary
  Widget _buildCaseSummary(CaseState state) {
    final model = state.currentCase;
    final borrowDate = model.borrowDate != null ? DateFormat('yyyy/MM/dd').format(model.borrowDate!) : "未填";
    final repayDate = model.repayDate != null ? DateFormat('yyyy/MM/dd').format(model.repayDate!) : "未填";
    
    List<String> proofs = [];
    if (model.hasTransferRecord) proofs.add("銀行轉帳紀錄");
    if (model.hasCash) proofs.add("現金交付無紀錄");
    if (model.isUnprovable) proofs.add("無法證明金流");
    if (model.hasLineScreenshots) proofs.add("${model.chatAppName}對話截圖");
    if (model.hasVerbalPromise) proofs.add("僅口頭承諾");
    if (model.hasNoResponse) proofs.add("對方已不回應");

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "你的案件摘要",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
            ),
            const SizedBox(height: 12),
            _buildSummaryRow("欠款金額：", "NT\$ ${model.amount.toStringAsFixed(0)}"),
            _buildSummaryRow("借款日期：", borrowDate),
            _buildSummaryRow("約定還款日：", "$repayDate（已逾期 ${state.overdueDays} 天）"),
            _buildSummaryRow("目前狀態：", model.situation),
            _buildSummaryRow("現有證據：", proofs.isEmpty ? "無" : proofs.join("、")),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryNavy, fontSize: 13)),
          Expanded(child: Text(value, style: const TextStyle(color: AppTheme.textDark, fontSize: 13))),
        ],
      ),
    );
  }

  // 4A. Strategy Advice Card
  Widget _buildStrategyAdvice() {
    return Card(
      color: const Color(0xFFEEF4FF),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.check_circle, color: AppTheme.actionGreen, size: 20),
                SizedBox(width: 8),
                Text(
                  "現在可以做的事",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.actionGreen),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildStrategyBullet("發送正式限期催告訊息（使用下方範本）"),
            _buildStrategyBullet("截圖並保存本次催告紀錄"),
            _buildStrategyBullet("確認對方帳戶資訊（為強制執行預做準備）"),
            
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(Icons.cancel, color: AppTheme.dangerRed, size: 20),
                SizedBox(width: 8),
                Text(
                  "千萬不要做的事",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.dangerRed),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildStrategyBullet("繼續情緒爭論或求對方", isDo: false),
            _buildStrategyBullet("接受對方口頭承諾而不要求書面紀錄", isDo: false),
            _buildStrategyBullet("在對話中透露你已準備提告（打草驚蛇）", isDo: false),
          ],
        ),
      ),
    );
  }

  Widget _buildStrategyBullet(String text, {bool isDo = true}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0, horizontal: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isDo ? "• " : "• ",
            style: TextStyle(color: isDo ? AppTheme.actionGreen : AppTheme.dangerRed, fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: AppTheme.textDark),
            ),
          ),
        ],
      ),
    );
  }

  // 5A. Template Messages
  Widget _buildMessageTemplates(CaseState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "催告簡訊與通訊對話範本",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
            ),
            const SizedBox(height: 12),
            
            // Toggle Segmented Control for message templates
            Row(
              children: [
                _buildMessageTabButton("不撕破臉", 0),
                _buildMessageTabButton("正式催告", 1),
                _buildMessageTabButton("最後通牒", 2),
              ],
            ),
            const SizedBox(height: 16),
            
            // Template display box
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.bgLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFDEE2E6)),
              ),
              child: Text(
                _getMessageContent(state, _selectedMessageIndex),
                style: const TextStyle(fontSize: 13, height: 1.5, color: AppTheme.textDark),
              ),
            ),
            const SizedBox(height: 12),
            
            ElevatedButton.icon(
              icon: const Icon(Icons.copy, size: 16),
              label: const Text("一鍵複製此催告訊息"),
              onPressed: () => _copyToClipboard(_getMessageContent(state, _selectedMessageIndex)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.actionGreen,
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageTabButton(String text, int index) {
    final isSelected = _selectedMessageIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedMessageIndex = index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? AppTheme.primaryNavy : Colors.transparent,
                width: 2.0,
              ),
            ),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? AppTheme.primaryNavy : AppTheme.textMuted,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  // 6A. Checklist Card
  Widget _buildPreservationChecklist() {
    return Card(
      color: const Color(0xFFFFF8E1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.security, color: AppTheme.secondaryYellow, size: 20),
                SizedBox(width: 8),
                Text(
                  "你現在必須完成的債權保全動作",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF5D4037)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Checkbox list
            ...List.generate(_checklistItems.length, (index) {
              return CheckboxListTile(
                title: Text(
                  _checklistItems[index],
                  style: const TextStyle(fontSize: 13, color: Color(0xFF5D4037)),
                ),
                value: _checklistValues[index],
                activeColor: AppTheme.primaryNavy,
                onChanged: (val) {
                  setState(() {
                    _checklistValues[index] = val ?? false;
                  });
                },
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
              );
            }),
          ],
        ),
      ),
    );
  }

  // 7B. Recommended Banner for Certificate Letters
  Widget _buildRecommendationBanner(CaseState state, int recommendedIndex) {
    return Card(
      color: const Color(0xFFEEF4FF),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFD0E1FD), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "系統根據你的案件資料，推薦以下存證信函",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.stars, color: AppTheme.secondaryYellow, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "推薦：${_getRecommendedTemplateName(recommendedIndex)}",
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _getRecommendedReason(recommendedIndex),
                        style: const TextStyle(fontSize: 12, color: AppTheme.textDark, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              "  你也可以切換查看其他情境範本",
              style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  // 8B. Tabs of 4 templates
  Widget _buildLetterTemplatesTabs(CaseState state, int recommendedIndex) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "存證信函產出預覽與下載",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
            ),
            const SizedBox(height: 12),
            
            // TabBar inside card to switch templates
            TabBar(
              controller: _letterTabController,
              isScrollable: true,
              labelColor: AppTheme.primaryNavy,
              unselectedLabelColor: AppTheme.textMuted,
              indicatorColor: AppTheme.primaryNavy,
              tabs: [
                _buildTemplateTabLabel("範本一｜轉帳", 0, recommendedIndex),
                _buildTemplateTabLabel("範本二｜對話", 1, recommendedIndex),
                _buildTemplateTabLabel("範本三｜失聯", 2, recommendedIndex),
                _buildTemplateTabLabel("範本四｜保證人", 3, recommendedIndex),
              ],
              onTap: (index) {
                setState(() {
                  _selectedLetterTemplateIndex = index;
                });
              },
            ),
            
            const SizedBox(height: 16),
            
            // Render the letter text with user data injected
            Container(
              padding: const EdgeInsets.all(14),
              height: 250,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFDEE2E6)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.center,
                      child: const Text("存  證  信  函", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                    const SizedBox(height: 12),
                    _buildInjectedText(state, _selectedLetterTemplateIndex),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.remove_red_eye_rounded, size: 18),
                    label: const Text("預覽 PDF"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryNavy,
                      side: const BorderSide(color: AppTheme.primaryNavy, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => _previewPdf(state, _selectedLetterTemplateIndex),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text("下載 PDF"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryNavy,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => _downloadPdf(state, _selectedLetterTemplateIndex),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateTabLabel(String label, int index, int recommendedIndex) {
    final isRecommended = index == recommendedIndex;
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (isRecommended) ...[
            const SizedBox(width: 4),
            const Text("⭐", style: TextStyle(fontSize: 10)),
          ]
        ],
      ),
    );
  }

  // Inject user variables into display text for the UI preview
  Widget _buildInjectedText(CaseState state, int templateIndex) {
    final model = state.currentCase;
    final amountText = model.amount.toStringAsFixed(0);
    
    // Variables
    final opponentName = model.recipientName.isNotEmpty ? model.recipientName : "____";
    final opponentAddr = model.recipientAddress.isNotEmpty ? model.recipientAddress : "____";
    final senderName = model.senderName.isNotEmpty ? model.senderName : "____";
    final senderAddr = model.senderAddress.isNotEmpty ? model.senderAddress : "____";
    final chatApp = model.chatAppName.isNotEmpty ? model.chatAppName : "LINE";
    final cosignerName = model.cosignerName.isNotEmpty ? model.cosignerName : "____";
    final cosignerAddr = model.cosignerAddress.isNotEmpty ? model.cosignerAddress : "____";
    final evidence = model.evidenceTypes.isNotEmpty ? model.evidenceTypes : "借據、轉帳紀錄、對話紀錄";

    // Format Dates
    final sendDate = CaseState.formatToRocString(model.sendDate);
    final borrowDate = CaseState.formatToRocString(model.borrowDate);
    final repayDate = CaseState.formatToRocString(model.repayDate);
    final transferDate = CaseState.formatToRocString(model.transferDate);

    TextStyle valStyle = const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 13);
    TextStyle plainStyle = const TextStyle(color: AppTheme.textDark, fontSize: 13, height: 1.6);

    List<InlineSpan> spans = [];

    // Recipient & Sender blocks
    if (templateIndex == 3) {
      // Cosigner is recipient
      spans.addAll([
        const TextSpan(text: "受文者："),
        TextSpan(text: cosignerName, style: valStyle),
        const TextSpan(text: " 先生/小姐/公司\n　　　　"),
        TextSpan(text: cosignerAddr, style: valStyle),
        const TextSpan(text: "\n\n"),
      ]);
    } else {
      spans.addAll([
        const TextSpan(text: "受文者："),
        TextSpan(text: opponentName, style: valStyle),
        const TextSpan(text: " 先生/小姐/公司\n　　　　"),
        TextSpan(text: opponentAddr, style: valStyle),
        const TextSpan(text: "\n\n"),
      ]);
    }

    spans.addAll([
      const TextSpan(text: "發文者："),
      TextSpan(text: senderName, style: valStyle),
      const TextSpan(text: " 先生/小姐\n　　　　"),
      TextSpan(text: senderAddr, style: valStyle),
      const TextSpan(text: "\n\n"),
      const TextSpan(text: "發文日期："),
      TextSpan(text: sendDate, style: valStyle),
      const TextSpan(text: "\n\n"),
      const TextSpan(text: "主旨："),
    ]);

    // Subject
    if (templateIndex == 3) {
      spans.addAll([
        const TextSpan(text: "關於主債務人 "),
        TextSpan(text: opponentName, style: valStyle),
        const TextSpan(text: " 積欠本人新臺幣 "),
        TextSpan(text: amountText, style: valStyle),
        const TextSpan(text: " 元債務，台端身為連帶保證人應負連帶清償責任，請台端於函到七日內清償，特此函告。\n\n"),
      ]);
    } else if (templateIndex == 2) {
      spans.addAll([
        const TextSpan(text: "關於台端積欠本人新臺幣 "),
        TextSpan(text: amountText, style: valStyle),
        const TextSpan(text: " 元債務，請台端於函到七日內清償，否則本人將立即採取法律行動，特此函告。\n\n"),
      ]);
    } else {
      spans.addAll([
        const TextSpan(text: "關於台端積欠本人新臺幣 "),
        TextSpan(text: amountText, style: valStyle),
        const TextSpan(text: " 元債務，請台端於函到七日內清償，特此函告。\n\n"),
      ]);
    }

    spans.add(const TextSpan(text: "說明：\n"));

    // Explanations list
    if (templateIndex == 0) {
      spans.addAll([
        const TextSpan(text: "一、查台端曾於 "),
        TextSpan(text: borrowDate, style: valStyle),
        const TextSpan(text: " 向本人借款新臺幣 "),
        TextSpan(text: amountText, style: valStyle),
        const TextSpan(text: " 元整，並約定於 "),
        TextSpan(text: repayDate, style: valStyle),
        const TextSpan(text: " 前清償完畢。本人已於 "),
        TextSpan(text: transferDate, style: valStyle),
        const TextSpan(text: " 將款項轉帳至台端指定帳戶，此有轉帳紀錄可稽。\n"),
        const TextSpan(text: "二、詎料，台端屆期迄未依約清償上開借款，經本人多次催告，台端仍置之不理，顯已構成債務不履行。\n"),
        const TextSpan(text: "三、為此，特函請台端於本函送達之翌日起七日內，立即清償上開積欠之借款新臺幣 "),
        TextSpan(text: amountText, style: valStyle),
        const TextSpan(text: " 元整，及自 "),
        TextSpan(text: repayDate, style: valStyle),
        const TextSpan(text: " 起至清償日止，按年息百分之五計算之利息。\n"),
        const TextSpan(text: "四、如台端逾期仍未清償，本人將不另通知，逕行依法向法院提起訴訟，請求返還借款及利息，並請求台端負擔所有訴訟費用及相關損害賠償，屆時恐增訟累，非本人所樂見。\n"),
      ]);
    } else if (templateIndex == 1) {
      spans.addAll([
        const TextSpan(text: "一、查台端曾於 "),
        TextSpan(text: borrowDate, style: valStyle),
        const TextSpan(text: " 透過 "),
        TextSpan(text: chatApp, style: valStyle),
        const TextSpan(text: " 向本人借款新臺幣 "),
        TextSpan(text: amountText, style: valStyle),
        const TextSpan(text: " 元整，並約定於 "),
        TextSpan(text: repayDate, style: valStyle),
        const TextSpan(text: " 前清償完畢。此有雙方 "),
        TextSpan(text: chatApp, style: valStyle),
        const TextSpan(text: " 對話紀錄可稽。\n"),
        const TextSpan(text: "二、詎料，台端屆期迄未依約清償上開借款，經本人多次催告，台端仍置之不理，顯已構成債務不履行。\n"),
        const TextSpan(text: "三、為此，特函請台端於本函送達之翌日起七日內，立即清償上開積欠之借款新臺幣 "),
        TextSpan(text: amountText, style: valStyle),
        const TextSpan(text: " 元整，及自 "),
        TextSpan(text: repayDate, style: valStyle),
        const TextSpan(text: " 起至清償日止，按年息百分之五計算之利息。\n"),
        const TextSpan(text: "四、如台端逾期仍未清償，本人將不另通知，逕行依法向法院提起訴訟，請求返還借款及利息，並請求台端負擔所有訴訟費用及相關損害賠償，屆時恐增訟累，非本人所樂見。\n"),
      ]);
    } else if (templateIndex == 2) {
      spans.addAll([
        const TextSpan(text: "一、查台端曾於 "),
        TextSpan(text: borrowDate, style: valStyle),
        const TextSpan(text: " 向本人借款新臺幣 "),
        TextSpan(text: amountText, style: valStyle),
        const TextSpan(text: " 元整，並約定於 "),
        TextSpan(text: repayDate, style: valStyle),
        const TextSpan(text: " 前清償完畢。此有 "),
        TextSpan(text: evidence, style: valStyle),
        const TextSpan(text: " 可稽。\n"),
        const TextSpan(text: "二、詎料，台端屆期迄未依約清償上開借款，經本人多次催告，台端仍置之不理，顯已構成債務不履行。\n"),
        const TextSpan(text: "三、本人已多次給予台端清償機會，惟台端均未積極處理。為維護本人合法權益，特再次函請台端於本函送達之翌日起七日內，立即清償上開積欠之借款新臺幣 "),
        TextSpan(text: amountText, style: valStyle),
        const TextSpan(text: " 元整，及自 "),
        TextSpan(text: repayDate, style: valStyle),
        const TextSpan(text: " 起至清償日止，按年息百分之五計算之利息。\n"),
        const TextSpan(text: "四、如台端逾期仍未清償，本人將不再容忍，屆時將立即向法院提起民事訴訟，請求返還借款及利息，並請求台端負擔所有訴訟費用、律師費用及相關損害賠償。同時，本人將依法循一切合法途徑維護自身權益，請台端審慎考量，切勿自誤。\n"),
      ]);
    } else if (templateIndex == 3) {
      spans.addAll([
        const TextSpan(text: "一、查主債務人 "),
        TextSpan(text: opponentName, style: valStyle),
        const TextSpan(text: " 曾於 "),
        TextSpan(text: borrowDate, style: valStyle),
        const TextSpan(text: " 向本人借款新臺幣 "),
        TextSpan(text: amountText, style: valStyle),
        const TextSpan(text: " 元整，並約定於 "),
        TextSpan(text: repayDate, style: valStyle),
        const TextSpan(text: " 前清償完畢。台端就上開債務，業已簽立連帶保證契約，同意與主債務人 "),
        TextSpan(text: opponentName, style: valStyle),
        const TextSpan(text: " 負連帶清償責任，此有 "),
        TextSpan(text: evidence, style: valStyle),
        const TextSpan(text: " 可稽。\n"),
        const TextSpan(text: "二、詎料，主債務人 "),
        TextSpan(text: opponentName, style: valStyle),
        const TextSpan(text: " 屆期迄未依約清償上開借款，經本人多次催告，主債務人仍置之不理，顯已構成債務不履行。\n"),
        const TextSpan(text: "三、依民法第739條及相關規定，台端身為連帶保證人，應與主債務人負同一清償責任，且不得主張民法第745條之先訴抗辯權。為此，特函請台端於本函送達之翌日起七日內，立即清償上開積欠之借款新臺幣 "),
        TextSpan(text: amountText, style: valStyle),
        const TextSpan(text: " 元整，及自 "),
        TextSpan(text: repayDate, style: valStyle),
        const TextSpan(text: " 起至清償日止，按年息百分之五計算之利息。\n"),
        const TextSpan(text: "四、如台端逾期仍未清償，本人將不另通知，逕行依法向法院提起訴訟，請求台端負連帶清償責任，並請求台端負擔所有訴訟費用及相關損害賠償，屆時恐增訟累，非本人所樂見。\n"),
      ]);
    }

    spans.addAll([
      const TextSpan(text: "\n此致\n"),
      if (templateIndex == 3) ...[
        TextSpan(text: cosignerName, style: valStyle),
        const TextSpan(text: " 先生/小姐/公司\n\n"),
      ] else ...[
        TextSpan(text: opponentName, style: valStyle),
        const TextSpan(text: " 先生/小姐/公司\n\n"),
      ],
      TextSpan(text: senderName, style: valStyle),
      const TextSpan(text: "（簽章）"),
    ]);

    return RichText(
      text: TextSpan(style: plainStyle, children: spans),
    );
  }

  // 9B. How to send via post office
  Widget _buildPostOfficeGuide() {
    return Card(
      color: const Color(0xFFF5F5F5),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.mark_email_read_rounded, color: AppTheme.primaryNavy, size: 20),
                SizedBox(width: 8),
                Text(
                  "如何透過郵局寄送存證信函",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildGuideStep("1", "下載並列印 PDF，共需列印三份（一份寄出、一份郵局留存、一份寄件人自行留存）"),
            _buildGuideStep("2", "攜帶身分證正本及印章至任一郵局辦事處"),
            _buildGuideStep("3", "告知郵局櫃檯人員「要寄存證信函」"),
            _buildGuideStep("4", "櫃檯人員會協助核對與蓋郵戳章"),
            _buildGuideStep("5", "繳交郵資（約新台幣 100~150 元，視紙張數與是否加買雙掛號回執而定）"),
            _buildGuideStep("6", "保留郵局提供給您的「收據」與蓋有郵局認證戳章的「副本」作為法庭證據"),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.only(left: 8.0),
              child: Text(
                "💡 若對方拒收或查無此人被退回，請務必保留郵局退件信封（切勿拆封），此退件紀錄在法律上同樣具有「已盡催告通知義務」之擬制送達效力。",
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuideStep(String stepNumber, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 8.5,
            backgroundColor: AppTheme.primaryNavy,
            child: Text(stepNumber, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: AppTheme.textDark),
            ),
          ),
        ],
      ),
    );
  }

  // 10. Alarm setting card (FCM & local)
  Widget _buildNotificationSettings(CaseState state) {
    return Card(
      color: const Color(0xFFEEF4FF),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.alarm_on_rounded, color: AppTheme.primaryNavy, size: 20),
                SizedBox(width: 8),
                Text(
                  "設定追款提醒",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              "催告發出後，若對方無回應，系統會在你設定的時間提醒你升級下一步。",
              style: TextStyle(fontSize: 13, color: AppTheme.textDark),
            ),
            const SizedBox(height: 12),
            
            // Segmented days picker
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("提醒等待天數：", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy)),
                ToggleButtons(
                  isSelected: [state.alertDays == 3, state.alertDays == 7, state.alertDays == 14],
                  borderRadius: BorderRadius.circular(8),
                  selectedColor: Colors.white,
                  fillColor: AppTheme.primaryNavy,
                  color: AppTheme.primaryNavy,
                  constraints: const BoxConstraints(minWidth: 50, minHeight: 32),
                  onPressed: (index) async {
                    int days = 7;
                    if (index == 0) days = 3;
                    if (index == 1) days = 7;
                    if (index == 2) days = 14;
                    
                    await state.setAlertPreferences(days, state.isAlertEnabled);
                    if (state.isAlertEnabled) {
                      await NotificationService.scheduleChaseReminder(days);
                    }
                  },
                  children: const [
                    Text("3天", style: TextStyle(fontSize: 12)),
                    Text("7天", style: TextStyle(fontSize: 12)),
                    Text("14天", style: TextStyle(fontSize: 12)),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Switch Toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("開啟追款推播提醒", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.primaryNavy)),
                Switch(
                  value: state.isAlertEnabled,
                  activeColor: Colors.white,
                  activeTrackColor: AppTheme.actionGreen,
                  onChanged: (val) async {
                    await state.setAlertPreferences(state.alertDays, val);
                    if (val) {
                      await NotificationService.scheduleChaseReminder(state.alertDays);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("⏰ 提醒已設定！將於 ${state.alertDays} 天後發出追款通知。"),
                            backgroundColor: AppTheme.actionGreen,
                          ),
                        );
                      }
                    } else {
                      await NotificationService.cancelReminder();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("⏰ 提醒已取消。"),
                            backgroundColor: AppTheme.textMuted,
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
            
            // Test Button for developers/users to see immediate reaction
            if (state.isAlertEnabled) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.notifications_active_rounded, size: 16),
                label: const Text("發送 5 秒後測試通知"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryNavy,
                  side: const BorderSide(color: AppTheme.primaryNavy, width: 1),
                  minimumSize: const Size.fromHeight(38),
                ),
                onPressed: () async {
                  await NotificationService.scheduleTestNotification();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("🧪 測試排程成功！請回到桌面，通知將在 5 秒後響起。"),
                        backgroundColor: AppTheme.primaryNavy,
                      ),
                    );
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Locked Module display card
  Widget _buildLockedModuleCard({required String title, required String description}) {
    return Card(
      color: Colors.grey.shade100,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lock_outline_rounded, color: AppTheme.textMuted),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(fontSize: 13, color: AppTheme.textMuted, height: 1.4),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryNavy,
                minimumSize: const Size(120, 36),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onPressed: () {
                // Return to Screen 2 to unlock
                Navigator.pop(context);
              },
              child: const Text("返回健檢頁進行解鎖", style: TextStyle(fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }
}
