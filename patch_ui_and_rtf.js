const fs = require('fs');
const filePath = 'lib/screens/action_center_screen.dart';

if (!fs.existsSync(filePath)) {
    console.log("錯誤：找不到 lib/screens/action_center_screen.dart 檔案！");
    process.exit(1);
}

let content = fs.readFileSync(filePath, 'utf8');

// ==========================================
// 1. 徹底修復分享座標為負值（-143.33）的閃退，改用觸發按鈕自身的全球物理邊界計算
// ==========================================
const targetShareFix = `      final box = context.findRenderObject() as RenderBox?;
      final sharePositionOrigin = box != null
          ? box.localToGlobal(Offset.zero) & box.size
          : const Rect.fromLTWH(0, 0, 1, 1);

      await Share.shareXFiles(
        [XFile(file.path)],
        sharePositionOrigin: sharePositionOrigin,
      );`;

const replacementShareFix = `      // 使用本地變數傳遞進來的按鈕物理邊界，防禦頂層座標計算為負值或零
      final sharePositionOrigin = buttonRect != null && buttonRect.width > 0 && buttonRect.left >= 0
          ? buttonRect
          : const Rect.fromLTWH(0, 0, 300, 300);

      await Share.shareXFiles(
        [XFile(file.path)],
        sharePositionOrigin: sharePositionOrigin,
      );`;

// ==========================================
// 2. 調整 _exportRtf 函數標頭，使其能接收按鈕的 Rect 參數
// ==========================================
const targetFunctionHeader = `  Future<void> _exportRtf(CaseState state, int templateIndex) async {`;
const replacementFunctionHeader = `  Future<void> _exportRtf(CaseState state, int templateIndex, {Rect? buttonRect}) async {`;

// ==========================================
// 3. 在 UI 上新增「匯出 RTF 檔」按鈕，並加註 Word 編輯提示
// ==========================================
const targetButtonsRow = `            // Action Buttons
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
            ),`;

const replacementButtonsRow = `            // Action Buttons
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
            const SizedBox(height: 12),
            Builder(
              builder: (buttonContext) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      final RenderBox? box = buttonContext.findRenderObject() as RenderBox?;
                      final rect = box != null ? (box.localToGlobal(Offset.zero) & box.size) : null;
                      _exportRtf(state, _selectedLetterTemplateIndex, buttonRect: rect);
                    },
                    icon: const Icon(Icons.edit_note, size: 18),
                    label: const Text("匯出 RTF 檔"),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: const Color(0xFF2E7D32), // 綠色彰顯可編輯性
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "※ 提示：打開此檔案可選擇以 Word 格式開啟，進行客製化內容編輯。",
                    style: TextStyle(fontSize: 11, color: Color(0xFF2E7D32), fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),`;

// ==========================================
// 4. 修正範本畫面卡片靜態文字錯置為「借款」的問題，改為動態文字
// ==========================================
const targetInjectedTextStart = `  Widget _buildInjectedText(CaseState state, int templateIndex) {`;
const targetInjectedTextEnd = `    spans.addAll([
      const TextSpan(text: "\\n此致\\n"),
      if (templateIndex == 3) ...[
        TextSpan(text: cosignerName, style: valStyle),
        const TextSpan(text: " 先生/小姐/公司\\n\\n"),
      ] else ...[
        TextSpan(text: opponentName, style: valStyle),
        const TextSpan(text: " 先生/小姐/公司\\n\\n"),
      ],
      TextSpan(text: senderName, style: valStyle),
      const TextSpan(text: "（簽章）"),
    ]);

    return RichText(
      text: TextSpan(style: plainStyle, children: spans),
    );
  }`;

const replacementInjectedText = `  Widget _buildInjectedText(CaseState state, int templateIndex) {
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
        const TextSpan(text: " 先生/小姐/公司\\n　　　　"),
        TextSpan(text: cosignerAddr, style: valStyle),
        const TextSpan(text: "\\n\\n"),
      ]);
    } else {
      spans.addAll([
        const TextSpan(text: "受文者："),
        TextSpan(text: opponentName, style: valStyle),
        const TextSpan(text: " 先生/小姐/公司\\n　　　　"),
        TextSpan(text: opponentAddr, style: valStyle),
        const TextSpan(text: "\\n\\n"),
      ]);
    }

    spans.addAll([
      const TextSpan(text: "發文者："),
      TextSpan(text: senderName, style: valStyle),
      const TextSpan(text: " 先生/小姐\\n　　　　"),
      TextSpan(text: senderAddr, style: valStyle),
      const TextSpan(text: "\\n\\n"),
      const TextSpan(text: "發文日期："),
      TextSpan(text: sendDate, style: valStyle),
      const TextSpan(text: "\\n\\n"),
      const TextSpan(text: "主旨："),
    ]);

    final isNonCash = ['commercial', 'rental', 'online_shopping'].contains(model.debtType);
    final debtNoun = isNonCash ? "款項" : "借款";

    // Subject
    if (templateIndex == 3) {
      spans.addAll([
        const TextSpan(text: "關於主債務人 "),
        TextSpan(text: opponentName, style: valStyle),
        TextSpan(text: isNonCash ? " 應給付本人之款項，" : " 積欠本人新臺幣 "),
        if (!isNonCash) ...[
          TextSpan(text: amountText, style: valStyle),
          const TextSpan(text: " 元債務，"),
        ],
        const TextSpan(text: "台端身為連帶保證人應負連帶清償責任，請台端於函到七日內清償，特此函告。\\n\\n"),
      ]);
    } else if (templateIndex == 2) {
      spans.addAll([
        TextSpan(text: isNonCash ? "關於台端應給付本人之款項，" : "關於台端積欠本人新臺幣 "),
        if (!isNonCash) ...[
          TextSpan(text: amountText, style: valStyle),
          const TextSpan(text: " 元債務，"),
        ],
        const TextSpan(text: "請台端於函到七日內清償，否則本人將立即採取法律行動，特此函告。\\n\\n"),
      ]);
    } else {
      spans.addAll([
        TextSpan(text: isNonCash ? "關於台端應給付本人之款項，" : "關於台端積欠本人新臺幣 "),
        if (!isNonCash) ...[
          TextSpan(text: amountText, style: valStyle),
          const TextSpan(text: " 元債務，"),
        ],
        const TextSpan(text: "請台端於函到七日內清償，特此函告。\\n\\n"),
      ]);
    }

    spans.add(const TextSpan(text: "說明：\\n"));

    // Explanations list
    if (templateIndex == 0) {
      if (isNonCash) {
        String relationText = "";
        if (model.debtType == 'commercial') {
          relationText = "本人已依約於 \${borrowDate} 完成台端委託之 \${(model.serviceDescription ?? '').isNotEmpty ? model.serviceDescription : '相關服務'}，依約台端應給付本人新臺幣 \${amountText} 元整，並約定於 \${repayDate} 前完成付款。";
        } else if (model.debtType == 'rental') {
          relationText = "台端就本人所有之 \${(model.rentalObject ?? '').isNotEmpty ? model.rentalObject : '租賃標的'} 自 \${borrowDate} 起負有給付租金／押金新臺幣 \${amountText} 元整之義務，應於 \${repayDate} 前給付完畢。";
        } else {
          // online_shopping
          relationText = "台端曾於 \${borrowDate} 委託本人代為購買商品，本人已依約代墊購買費用新臺幣 \${amountText} 元整，台端應於 \${repayDate} 前返還上開款項。";
        }
        spans.addAll([
          const TextSpan(text: "一、查"),
          TextSpan(text: relationText),
          const TextSpan(text: "本人已於 "),
          TextSpan(text: transferDate, style: valStyle),
          const TextSpan(text: " 取得相關交付／履行之憑證紀錄，此有相關紀錄可稽。\\n"),
        ]);
      } else {
        spans.addAll([
          const TextSpan(text: "一、查台端曾於 "),
          TextSpan(text: borrowDate, style: valStyle),
          const TextSpan(text: " 向本人借款新臺幣 "),
          TextSpan(text: amountText, style: valStyle),
          const TextSpan(text: " 元整，並約定於 "),
          TextSpan(text: repayDate, style: valStyle),
          const TextSpan(text: " 前清償完畢。本人已於 "),
          TextSpan(text: transferDate, style: valStyle),
          const TextSpan(text: " 將款項轉帳至台端指定帳戶，此有轉帳紀錄可稽。\\n"),
        ]);
      }
      spans.addAll([
        TextSpan(text: "二、詎料，台端屆期迄未依約清償上開\${debtNoun}，經本人多次催告，台端仍置之不理，顯已構成債務不履行。\\n"),
        TextSpan(text: "三、為此，特函請台端於本函送達之翌日起七日內，立即清償上開積欠之\${debtNoun}新臺幣 "),
        TextSpan(text: amountText, style: valStyle),
        const TextSpan(text: " 元整，及自 "),
        TextSpan(text: repayDate, style: valStyle),
        const TextSpan(text: " 起至清償日止，按年息百分之五計算之利息。\\n"),
        TextSpan(text: "四、如台端逾期仍未清償，本人將不另通知，逕行依法向法院提起訴訟，請求返還\${debtNoun}及利息，並請求台端負擔所有訴訟費用及相關損害賠償，屆時恐增訟累，非本人所樂見。\\n"),
      ]);
    } else if (templateIndex == 1) {
      if (isNonCash) {
        String relationText = "";
        if (model.debtType == 'commercial') {
          relationText = "本人已依約於 \${borrowDate} 完成台端委託之 \${(model.serviceDescription ?? '').isNotEmpty ? model.serviceDescription : '相關服務'}，依約台端應給付本人新臺幣 \${amountText} 元整，並約定於 \${repayDate} 前完成付款。";
        } else if (model.debtType == 'rental') {
          relationText = "台端就本人所有之 \${(model.rentalObject ?? '').isNotEmpty ? model.rentalObject : '租賃標的'} 自 \${borrowDate} 起負有給付租金／押金新臺幣 \${amountText} 元整之義務，應於 \${repayDate} 前給付完畢。";
        } else {
          // online_shopping
          relationText = "台端曾於 \${borrowDate} 委託本人代為購買商品，本人已依約代墊購買費用新臺幣 \${amountText} 元整，台端應於 \${repayDate} 前返還上開款項。";
        }
        spans.addAll([
          const TextSpan(text: "一、查"),
          TextSpan(text: relationText),
          const TextSpan(text: "此有雙方 "),
          TextSpan(text: chatApp, style: valStyle),
          const TextSpan(text: " 對話紀錄可稽。\\n"),
        ]);
      } else {
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
          const TextSpan(text: " 對話紀錄可稽。\\n"),
        ]);
      }
      spans.addAll([
        TextSpan(text: "二、詎料，台端屆期迄未依約清償上開\${debtNoun}，經本人多次催告，台端仍置之不理，顯已構成債務不履行。\\n"),
        TextSpan(text: "三、為此，特函請台端於本函送達之翌日起七日內，立即清償上開積欠之\${debtNoun}新臺幣 "),
        TextSpan(text: amountText, style: valStyle),
        const TextSpan(text: " 元整，及自 "),
        TextSpan(text: repayDate, style: valStyle),
        const TextSpan(text: " 起至清償日止，按年息百分之五計算之利息。\\n"),
        TextSpan(text: "四、如台端逾期仍未清償，本人將不另通知，逕行依法向法院提起訴訟，請求返還\${debtNoun}及利息，並請求台端負擔所有訴訟費用及相關損害賠償，屆時恐增訟累，非本人所樂見。\\n"),
      ]);
    } else if (templateIndex == 2) {
      if (isNonCash) {
        String relationText = "";
        if (model.debtType == 'commercial') {
          relationText = "本人已依約於 \${borrowDate} 完成台端委託之 \${(model.serviceDescription ?? '').isNotEmpty ? model.serviceDescription : '相關服務'}，依約台端應給付本人新臺幣 \${amountText} 元整，並約定於 \${repayDate} 前完成付款。";
        } else if (model.debtType == 'rental') {
          relationText = "台端就本人所有之 \${(model.rentalObject ?? '').isNotEmpty ? model.rentalObject : '租賃標的'} 自 \${borrowDate} 起負有給付租金／押金新臺幣 \${amountText} 元整之義務，應於 \${repayDate} 前給付完畢。";
        } else {
          // online_shopping
          relationText = "台端曾於 \${borrowDate} 委託本人代為購買商品，本人已依約代墊購買費用新臺幣 \${amountText} 元整，台端應於 \${repayDate} 前返還上開款項。";
        }
        spans.addAll([
          const TextSpan(text: "一、查"),
          TextSpan(text: relationText),
          const TextSpan(text: "此有 "),
          TextSpan(text: evidence, style: valStyle),
          const TextSpan(text: " 可稽。\\n"),
        ]);
      } else {
        spans.addAll([
          const TextSpan(text: "一、查台端曾於 "),
          TextSpan(text: borrowDate, style: valStyle),
          const TextSpan(text: " 向本人借款新臺幣 "),
          TextSpan(text: amountText, style: valStyle),
          const TextSpan(text: " 元整，並約定於 "),
          TextSpan(text: repayDate, style: valStyle),
          const TextSpan(text: " 前清償完畢。此有 "),
          TextSpan(text: evidence, style: valStyle),
          const TextSpan(text: " 可稽。\\n"),
        ]);
      }
      spans.addAll([
        TextSpan(text: "二、詎料，台端屆期迄未依約清償上開\${debtNoun}，經本人多次催告，台端仍置之不理，顯已構成債務不履行.\\n"),
        TextSpan(text: "三、本人已多次給予台端清償機會，惟台端均未積極處理。為維護本人合法權益，特再次函請台端於本函送達之翌日起七日內，立即清償上開積欠之\${debtNoun}新臺幣 "),
        TextSpan(text: amountText, style: valStyle),
        const TextSpan(text: " 元整，及自 "),
        TextSpan(text: repayDate, style: valStyle),
        const TextSpan(text: " 起至清償日止，按年息百分之五計算之利息。\\n"),
        TextSpan(text: "四、如台端逾期仍未清償，本人將不再容忍，屆時將立即向法院提起民事訴訟，請求返還\${debtNoun}及利息，並請求台端負擔所有訴訟費用、律師費用及相關損害賠償。同時，本人將依法循一切合法途徑維護自身權益，請台端審慎考量，切勿自誤。\\n"),
      ]);
    } else if (templateIndex == 3) {
      if (isNonCash) {
        String relationText = "";
        if (model.debtType == 'commercial') {
          relationText = "主債務人 \${opponentName} 應給付本人之款項，源於本人已依約於 \${borrowDate} 完成其委託之 \${(model.serviceDescription ?? '').isNotEmpty ? model.serviceDescription : '相關服務'}，其應給付本人新臺幣 \${amountText} 元整，並約定於 \${repayDate} 前完成付款。";
        } else if (model.debtType == 'rental') {
          relationText = "主債務人 \${opponentName} 就本人所有之 \${(model.rentalObject ?? '').isNotEmpty ? model.rentalObject : '租賃標的'} 自 \${borrowDate} 起負有給付租金／押金新臺幣 \${amountText} 元整之義務，應於 \${repayDate} 前給付完畢。";
        } else {
          // online_shopping
          relationText = "主債務人 \${opponentName} 曾於 \${borrowDate} 委託本人代為購買商品，本人已依約代墊購買費用新臺幣 \${amountText} 元整，其應於 \${repayDate} 前返還上開款項。";
        }
        spans.addAll([
          const TextSpan(text: "一、查"),
          TextSpan(text: relationText),
          const TextSpan(text: "台端就上開債務，業已簽立連帶保證契約，同意與主債務人 "),
          TextSpan(text: opponentName, style: valStyle),
          const TextSpan(text: " 負連帶清償責任，此有 "),
          TextSpan(text: evidence, style: valStyle),
          const TextSpan(text: " 可稽。\\n"),
        ]);
      } else {
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
          const TextSpan(text: " 可稽。\\n"),
        ]);
      }
      spans.addAll([
        TextSpan(text: "二、詎料，主債務人 \${opponentName} 屆期迄未依約清償上開\${debtNoun}，經本人多次催告，主債務人仍置之不理，顯已構成債務不履行。\\n"),
        TextSpan(text: "三、依民法第739條及相關規定，台端身為連帶保證人，應與主債務人負同一清償責任，且不得主張民法第745條之先訴抗辯權。為此，特函請台端於本函送達之翌日起七日內，立即清償上開積欠之\${debtNoun}新臺幣 "),
        TextSpan(text: amountText, style: valStyle),
        const TextSpan(text: " 元整，及自 "),
        TextSpan(text: repayDate, style: valStyle),
        const TextSpan(text: " 起至清償日止，按年息百分之五計算之利息。\\n"),
        TextSpan(text: "四、如台端逾期仍未清償，本人將不另通知，逕行依法向法院提起訴訟，請求台端負連帶清償責任，並請求台端負擔所有訴訟費用及相關損害賠償，屆時恐增訟累，非本人所樂見。\\n"),
      ]);
    }

    spans.addAll([
      const TextSpan(text: "\\n此致\\n"),
      if (templateIndex == 3) ...[
        TextSpan(text: cosignerName, style: valStyle),
        const TextSpan(text: " 先生/小姐/公司\\n\\n"),
      ] else ...[
        TextSpan(text: opponentName, style: valStyle),
        const TextSpan(text: " 先生/小姐/公司\\n\\n"),
      ],
      TextSpan(text: senderName, style: valStyle),
      const TextSpan(text: "（簽章）"),
    ]);

    return RichText(
      text: TextSpan(style: plainStyle, children: spans),
    );
  }`;

// Helper: Normalize lines for finding exact text
const normalize = str => str.replace(/\\r\\n/g, '\\n').trim();

// Replacing targets
if (normalize(content).includes(normalize(targetShareFix))) {
    content = content.replace(targetShareFix, replacementShareFix);
    console.log("【1. 分享坐標防禦修改成功】");
} else {
    console.log("【1. 分享坐標防禦修改失敗】：找不到 targetShareFix！");
}

if (normalize(content).includes(normalize(targetFunctionHeader))) {
    content = content.replace(targetFunctionHeader, replacementFunctionHeader);
    console.log("【2. 函數標頭修改成功】");
} else {
    console.log("【2. 函數標頭修改失敗】：找不到 targetFunctionHeader！");
}

if (normalize(content).includes(normalize(targetButtonsRow))) {
    content = content.replace(targetButtonsRow, replacementButtonsRow);
    console.log("【3. RTF 按鈕新增成功】");
} else {
    console.log("【3. RTF 按鈕新增失敗】：找不到 targetButtonsRow！");
}

const startIdx = content.indexOf(targetInjectedTextStart);
const endIdx = content.indexOf(targetInjectedTextEnd);

if (startIdx !== -1 && endIdx !== -1) {
    const fullTargetText = content.substring(startIdx, endIdx + targetInjectedTextEnd.length);
    content = content.replace(fullTargetText, replacementInjectedText);
    console.log("【4. 範本畫面動態文字修正成功】");
} else {
    console.log("【4. 範本畫面動態文字修正失敗】：找不到目標區段！", startIdx, endIdx);
}

fs.writeFileSync(filePath, content, 'utf8');
console.log("【修改完成】");
