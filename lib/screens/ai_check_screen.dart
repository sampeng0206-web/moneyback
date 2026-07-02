import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../providers/case_state.dart';
import '../theme.dart';
import '../services/ad_service.dart';

class AiCheckScreen extends StatefulWidget {
  const AiCheckScreen({super.key});

  @override
  State<AiCheckScreen> createState() => _AiCheckScreenState();
}

class _AiCheckScreenState extends State<AiCheckScreen> {
  bool _isProcessing = false;

  // Process purchase
  Future<void> _handlePurchase(String productId, String name) async {
    setState(() {
      _isProcessing = true;
    });

    final state = Provider.of<CaseState>(context, listen: false);

    bool success = false;
    try {
      if (productId == "moneyback.protection.pack.190") {
        success = await state.buyProtectionPack();
      } else if (productId == "moneyback.action.pack.190") {
        success = await state.buyActionPack();
      } else if (productId == "moneyback.yearly.490") {
        success = await state.buyYearlySubscription();
      }
    } catch (e) {
      success = false;
      debugPrint("Purchase error: $e");
    }

    setState(() {
      _isProcessing = false;
    });

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("🎉 成功解鎖：$name"),
          backgroundColor: AppTheme.actionGreen,
          duration: const Duration(seconds: 2),
        ),
      );
      Navigator.pushNamed(context, '/action_center');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("購買未完成，請稍後再試或聯絡客服。"),
          backgroundColor: AppTheme.dangerRed,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _handleRestore() async {
    setState(() {
      _isProcessing = true;
    });

    final state = Provider.of<CaseState>(context, listen: false);
    await state.restorePurchases();

    setState(() {
      _isProcessing = false;
    });

    if (!mounted) return;

    if (state.isPremium) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✅ 已成功恢復您的購買紀錄"),
          backgroundColor: AppTheme.actionGreen,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("找不到可恢復的購買紀錄"),
          backgroundColor: AppTheme.textMuted,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<CaseState>(context);
    final caseModel = state.currentCase;
    final completeness = state.evidenceCompleteness;
    final completedList = state.completedItems;
    final missingList = state.missingItems;

    return Stack(
      children: [
        Scaffold(
          bottomNavigationBar: state.isPremium ? null : const BannerAdWidget(),
          backgroundColor: AppTheme.bgLight,
          appBar: AppBar(
            backgroundColor: AppTheme.primaryNavy,
            elevation: 0,
            title: const Text("AI 案件健檢"),
            actions: [
              // Developer Fast-Pass buttons (debug 模式才會顯示，正式上架版本自動隱藏)
              if (kDebugMode) ...[
                IconButton(
                  icon: const Icon(Icons.developer_mode, color: AppTheme.secondaryYellow),
                  tooltip: "測試：解鎖所有功能",
                  onPressed: () async {
                    await state.simulatePurchaseMock("moneyback.yearly.490");
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("🔧 [測試模式] 已解鎖全部債權保全與存證信函工具！"),
                          backgroundColor: AppTheme.primaryNavy,
                        ),
                      );
                      Navigator.pushNamed(context, '/action_center');
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: "測試：重設所有購買狀態",
                  onPressed: () async {
                    await state.resetPurchases();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("🔧 [測試模式] 已重設所有購買狀態。"),
                          backgroundColor: AppTheme.dangerRed,
                        ),
                      );
                    }
                  },
                ),
              ],
            ],
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 2. Progress Board Card
                Card(
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
                          "你的證據完成度",
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: completeness,
                                  backgroundColor: const Color(0xFFDEE2E6),
                                  color: AppTheme.actionGreen,
                                  minHeight: 8,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              "${(completeness * 100).toStringAsFixed(0)}%",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.actionGreen,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Completed Checklist
                        if (completedList.isNotEmpty) ...[
                          const Text("已取得的項目：", style: TextStyle(color: AppTheme.primaryNavy, fontSize: 13, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          ...completedList.map((item) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3.0),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle, color: AppTheme.actionGreen, size: 16),
                                const SizedBox(width: 8),
                                Text(item, style: const TextStyle(fontSize: 13, color: AppTheme.textDark)),
                              ],
                            ),
                          )),
                          const SizedBox(height: 12),
                        ],

                        // Missing Checklist (warnings)
                        if (missingList.isNotEmpty) ...[
                          const Text("缺漏項目與風險警示：", style: TextStyle(color: AppTheme.dangerRed, fontSize: 13, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          ...missingList.map((item) => Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF8E1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFFFECB3), width: 0.5),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.warning_rounded, color: AppTheme.secondaryYellow, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    item,
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF5D4037), fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                          )),
                        ],
                      ],
                    ),
                  ),
                ),

                // 3. Current Situation Card
                _buildEdgeCard(
                  title: "你目前的狀況",
                  content: state.situationDescription,
                  edgeColor: AppTheme.primaryNavy,
                  bgColor: Colors.white,
                  textColor: AppTheme.textDark,
                ),

                // 4. Tactical Warning Card
                _buildEdgeCard(
                  title: "先不要做這件事",
                  content: state.situationWarningText,
                  edgeColor: AppTheme.dangerRed,
                  bgColor: const Color(0xFFFDECEC),
                  textColor: AppTheme.dangerRed,
                  isWarning: true,
                ),

                // 5. Debt Preservation Card
                _buildEdgeCard(
                  title: "現在最重要的一件事",
                  content: "在你採取任何行動之前，先把現有的 LINE 截圖與轉帳紀錄備份並保存。這是你最重要的底牌，必須先保住。",
                  edgeColor: AppTheme.actionGreen,
                  bgColor: const Color(0xFFE8F5E9),
                  textColor: AppTheme.actionGreen,
                  isPreserve: true,
                ),

                const SizedBox(height: 12),
                
                // Directly navigate to screen 3 if they have bought anything already
                if (state.isPurchasedProtection || state.isPurchasedAction)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryNavy,
                      ),
                      onPressed: () {
                        Navigator.pushNamed(context, '/action_center');
                      },
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("進入已解鎖行動中心  "),
                          Icon(Icons.arrow_forward),
                        ],
                      ),
                    ),
                  ),

                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Text(
                    "選擇你需要的工具",
                    style: TextStyle(
                      color: AppTheme.primaryNavy,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                // 7. Payment Tier 1: Protection Pack
                _buildPaymentCard(
                  badge: "基礎工具",
                  badgeColor: AppTheme.actionGreen,
                  badgeTextColor: Colors.white,
                  title: "債權保全包",
                  price: "NT\$190",
                  priceColor: AppTheme.actionGreen,
                  items: [
                    "客觀案件摘要",
                    "催收策略引導（可做與不可做）",
                    "三種催告訊息範本（一鍵複製）",
                    "債權保全清單",
                  ],
                  buttonText: state.isPurchasedProtection ? "已擁有該權限 (進入行動中心)" : "解鎖債權保全包 NT\$190",
                  buttonColor: AppTheme.actionGreen,
                  onPressed: () {
                    if (state.isPurchasedProtection) {
                      Navigator.pushNamed(context, '/action_center');
                    } else {
                      _handlePurchase("moneyback.protection.pack.190", "債權保全包");
                    }
                  },
                ),

                // 8. Payment Tier 2: Action Pack
                _buildPaymentCard(
                  badge: "核心工具",
                  badgeColor: AppTheme.secondaryYellow,
                  badgeTextColor: AppTheme.primaryNavy,
                  title: "討錢行動準備包",
                  subtitle: "存證信函產生器",
                  price: "NT\$190",
                  priceColor: const Color(0xFFD48806), // Amber text
                  items: [
                    "四種情境存證信函一次全解鎖",
                    "系統自動推薦最適合你的情境範本",
                    "所有欄位自動帶入你剛才填寫的資料",
                    "一鍵生成可列印的正式 PDF 存證信函",
                    "寄送說明與郵局辦理指引",
                  ],
                  smallText: "付費一次，四種情境範本永久解鎖",
                  buttonText: state.isPurchasedAction ? "已擁有該權限 (進入行動中心)" : "解鎖討錢行動準備包 NT\$190",
                  buttonColor: AppTheme.secondaryYellow,
                  buttonTextColor: AppTheme.primaryNavy,
                  onPressed: () {
                    if (state.isPurchasedAction) {
                      Navigator.pushNamed(context, '/action_center');
                    } else {
                      _handlePurchase("moneyback.action.pack.190", "討錢行動準備包");
                    }
                  },
                ),

                // 9. Payment Tier 3: Yearly Subscription
                _buildPaymentCard(
                  badge: "最划算",
                  badgeColor: AppTheme.primaryNavy,
                  badgeTextColor: Colors.white,
                  title: "年度訂閱方案",
                  price: "NT\$490／年",
                  priceColor: AppTheme.primaryNavy,
                  subtitle: "約每月 NT\$41，兩個工具無限次使用",
                  items: [
                    "債權保全包無限次使用",
                    "討錢行動準備包｜存證信函產生器無限次使用",
                    "新情境範本優先取得",
                  ],
                  buttonText: state.isPurchasedYearly ? "已擁有年度訂閱 (進入行動中心)" : "訂閱年方案 NT\$490／年",
                  buttonColor: AppTheme.primaryNavy,
                  onPressed: () {
                    if (state.isPurchasedYearly) {
                      Navigator.pushNamed(context, '/action_center');
                    } else {
                      _handlePurchase("moneyback.yearly.490", "年度訂閱方案");
                    }
                  },
                  cardBgColor: const Color(0xFFF5F7FF),
                ),

                // Legal links required for subscription apps
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () => launchUrl(Uri.parse('https://sampeng0206-web.github.io/moneyback/privacy-policy.html')),
                        child: const Text(
                          "隱私權政策",
                          style: TextStyle(
                            color: AppTheme.primaryNavy,
                            fontSize: 13,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      const Text("　｜　", style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                      GestureDetector(
                        onTap: () => launchUrl(Uri.parse('https://www.apple.com/legal/internet-services/itunes/dev/stdeula/')),
                        child: const Text(
                          "使用條款（EULA）",
                          style: TextStyle(
                            color: AppTheme.primaryNavy,
                            fontSize: 13,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      const Text("　｜　", style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                      GestureDetector(
                        onTap: _isProcessing ? null : _handleRestore,
                        child: const Text(
                          "恢復購買",
                          style: TextStyle(
                            color: AppTheme.primaryNavy,
                            fontSize: 13,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 10. Bottom disclaimer
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                  child: Center(
                    child: Text(
                      "本工具僅提供客觀數據梳理與大眾科普程序介紹，不構成任何法律意見。存證信函範本由用戶自行確認內容後寄送，平台不負擔寄送責任。",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        if (_isProcessing)
          Container(
            color: Colors.black.withOpacity(0.5),
            child: const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: AppTheme.primaryNavy),
                      SizedBox(height: 16),
                      Text("安全交易處理中，請稍候...", style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // Edge Card Widget Builder
  Widget _buildEdgeCard({
    required String title,
    required String content,
    required Color edgeColor,
    required Color bgColor,
    required Color textColor,
    bool isWarning = false,
    bool isPreserve = false,
  }) {
    return Card(
      color: bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: edgeColor.withOpacity(0.2), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 4,
              height: 90,
              color: edgeColor,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (isWarning) const Icon(Icons.warning, color: AppTheme.dangerRed, size: 16),
                        if (isPreserve) const Icon(Icons.lock, color: AppTheme.actionGreen, size: 16),
                        if (isWarning || isPreserve) const SizedBox(width: 6),
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      content,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textDark,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Payment Card Widget Builder
  Widget _buildPaymentCard({
    required String badge,
    required Color badgeColor,
    required Color badgeTextColor,
    required String title,
    required String price,
    required Color priceColor,
    required List<String> items,
    required String buttonText,
    required Color buttonColor,
    required VoidCallback onPressed,
    String? subtitle,
    String? smallText,
    Color? cardBgColor,
    Color? buttonTextColor,
  }) {
    return Stack(
      children: [
        Card(
          color: cardBgColor ?? Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: buttonColor, width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryNavy,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 14, color: AppTheme.textMuted),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  price,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: priceColor,
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: Color(0xFFE9ECEF)),
                const SizedBox(height: 16),
                
                // Features checklist
                ...items.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check, color: priceColor, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item,
                          style: const TextStyle(fontSize: 14, color: AppTheme.textDark),
                        ),
                      ),
                    ],
                  ),
                )),
                
                if (smallText != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    smallText,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                ],

                const SizedBox(height: 16),
                
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: buttonColor,
                    foregroundColor: buttonTextColor ?? Colors.white,
                    side: buttonTextColor != null ? BorderSide(color: buttonColor) : null,
                  ),
                  onPressed: onPressed,
                  child: Text(buttonText),
                ),
              ],
            ),
          ),
        ),
        
        // Ribbon/Badge at top-right
        Positioned(
          top: 20,
          right: 28,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              badge,
              style: TextStyle(
                color: badgeTextColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
