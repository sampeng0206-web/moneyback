import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/case_model.dart';
import '../providers/case_state.dart';
import '../theme.dart';
import '../services/ad_service.dart';

class CaseEntryScreen extends StatefulWidget {
  const CaseEntryScreen({super.key});

  @override
  State<CaseEntryScreen> createState() => _CaseEntryScreenState();
}

class _CaseEntryScreenState extends State<CaseEntryScreen> {
  final _formKey = GlobalKey<FormState>();

  // Text Controllers
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _senderNameController = TextEditingController();
  final TextEditingController _senderAddressController = TextEditingController();
  final TextEditingController _recipientNameController = TextEditingController();
  final TextEditingController _recipientAddressController = TextEditingController();
  final TextEditingController _cosignerNameController = TextEditingController();
  final TextEditingController _cosignerAddressController = TextEditingController();
  final TextEditingController _chatAppNameController = TextEditingController(text: "LINE");
  final TextEditingController _evidenceTypesController = TextEditingController();
  final TextEditingController _serviceDescriptionController = TextEditingController();
  final TextEditingController _rentalObjectController = TextEditingController();

  // Selected Dates
  DateTime? _borrowDate;
  DateTime? _repayDate;
  DateTime _sendDate = DateTime.now();
  DateTime? _transferDate;

  // Selected Situation
  String _situation = "對方不還錢";
  String _selectedDebtType = "loan";

  // Checkboxes
  bool _hasTransferRecord = false;
  bool _hasCash = false;
  bool _isUnprovable = false;

  bool _hasLineScreenshots = false;
  bool _hasVerbalPromise = false;
  bool _hasNoResponse = false;

  // Switches
  bool _hasCosigner = false;

  // Collapsible section state
  bool _isSenderSectionExpanded = true;

  @override
  void initState() {
    super.initState();
    // Load initial values from CaseState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = Provider.of<CaseState>(context, listen: false);
      final model = state.currentCase;
      
      setState(() {
        _situation = model.situation;
        _amountController.text = model.amount > 0 ? model.amount.toStringAsFixed(0) : "";
        _borrowDate = model.borrowDate;
        _repayDate = model.repayDate;
        _sendDate = model.sendDate;
        
        _hasTransferRecord = model.hasTransferRecord;
        _transferDate = model.transferDate;
        _hasCash = model.hasCash;
        _isUnprovable = model.isUnprovable;
        
        _hasLineScreenshots = model.hasLineScreenshots;
        _hasVerbalPromise = model.hasVerbalPromise;
        _hasNoResponse = model.hasNoResponse;
        
        _hasCosigner = model.hasCosigner;
        _cosignerNameController.text = model.cosignerName;
        _cosignerAddressController.text = model.cosignerAddress;
        
        _senderNameController.text = model.senderName;
        _senderAddressController.text = model.senderAddress;
        _recipientNameController.text = model.recipientName;
        _recipientAddressController.text = model.recipientAddress;
        
        _chatAppNameController.text = model.chatAppName.isNotEmpty ? model.chatAppName : "LINE";
        _evidenceTypesController.text = model.evidenceTypes;
        _selectedDebtType = model.debtType;
        _serviceDescriptionController.text = model.serviceDescription ?? "";
        _rentalObjectController.text = model.rentalObject ?? "";
      });
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _senderNameController.dispose();
    _senderAddressController.dispose();
    _recipientNameController.dispose();
    _recipientAddressController.dispose();
    _cosignerNameController.dispose();
    _cosignerAddressController.dispose();
    _chatAppNameController.dispose();
    _evidenceTypesController.dispose();
    _serviceDescriptionController.dispose();
    _rentalObjectController.dispose();
    super.dispose();
  }

  // Format Date for display
  String _formatDate(DateTime? date) {
    if (date == null) return "選擇日期";
    return DateFormat('yyyy / MM / dd').format(date);
  }

  // Getters for dynamic labels based on debtType
  String get _borrowDateLabel {
    switch (_selectedDebtType) {
      case 'advance':
        return "代墊發生日期";
      case 'commercial':
        return "完成服務／交貨日期";
      case 'rental':
        return "租約開始日期";
      case 'online_shopping':
        return "代購委託日期";
      case 'loan':
      default:
        return "借款日期";
    }
  }

  String get _repayDateLabel {
    switch (_selectedDebtType) {
      case 'advance':
        return "約定償還日";
      case 'commercial':
        return "約定付款日";
      case 'rental':
        return "應付款截止日";
      case 'online_shopping':
        return "約定返還日";
      case 'loan':
      default:
        return "約定還款日";
    }
  }

  String get _amountLabel {
    switch (_selectedDebtType) {
      case 'advance':
        return "代墊金額（新台幣）";
      case 'commercial':
        return "應收款項金額（新台幣）";
      case 'rental':
        return "應收租金／押金金額（新台幣）";
      case 'online_shopping':
        return "代購款項金額（新台幣）";
      case 'loan':
      default:
        return "欠款金額（新台幣）";
    }
  }

  // Show Date Picker helper
  Future<void> _selectDate(BuildContext context, DateTime initialDate, Function(DateTime) onSelected) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryNavy,
              onPrimary: Colors.white,
              onSurface: AppTheme.primaryNavy,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        onSelected(picked);
      });
    }
  }

  // Form Submission
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("請填寫必要的欄位項目"),
          backgroundColor: AppTheme.dangerRed,
        ),
      );
      return;
    }

    // Additional Validations
    if (_borrowDate == null) {
      _showError("請選擇$_borrowDateLabel");
      return;
    }
    if (_repayDate == null) {
      _showError("請選擇$_repayDateLabel");
      return;
    }
    if (_borrowDate!.isAfter(_repayDate!)) {
      _showError("$_borrowDateLabel不可在$_repayDateLabel之後");
      return;
    }
    if (_hasTransferRecord && _transferDate == null) {
      _showError("請選擇銀行轉帳日期");
      return;
    }
    
    // Check if at least one evidence source is selected
    if (!_hasTransferRecord && !_hasCash && !_isUnprovable) {
      _showError("請至少勾選一項金流證明選項");
      return;
    }
    if (!_hasLineScreenshots && !_hasVerbalPromise && !_hasNoResponse) {
      _showError("請至少勾選一項對話紀錄選項");
      return;
    }

    // Save to State (and thus SharedPreferences)
    final double amountValue = double.tryParse(_amountController.text) ?? 0.0;
    
    final updatedCase = CaseModel(
      situation: _situation,
      amount: amountValue,
      borrowDate: _borrowDate,
      repayDate: _repayDate,
      sendDate: _sendDate,
      hasTransferRecord: _hasTransferRecord,
      transferDate: _hasTransferRecord ? _transferDate : null,
      hasCash: _hasCash,
      isUnprovable: _isUnprovable,
      hasLineScreenshots: _hasLineScreenshots,
      hasVerbalPromise: _hasVerbalPromise,
      hasNoResponse: _hasNoResponse,
      hasCosigner: _hasCosigner,
      cosignerName: _hasCosigner ? _cosignerNameController.text : "",
      cosignerAddress: _hasCosigner ? _cosignerAddressController.text : "",
      senderName: _senderNameController.text,
      senderAddress: _senderAddressController.text,
      recipientName: _recipientNameController.text,
      recipientAddress: _recipientAddressController.text,
      chatAppName: _hasLineScreenshots ? _chatAppNameController.text : "LINE",
      evidenceTypes: _evidenceTypesController.text,
      debtType: _selectedDebtType,
      serviceDescription: _selectedDebtType == 'commercial' ? _serviceDescriptionController.text : "",
      rentalObject: _selectedDebtType == 'rental' ? _rentalObjectController.text : "",
    );

    await Provider.of<CaseState>(context, listen: false).updateCase(updatedCase);
    
    // Navigate to Screen 2 with Interstitial Ad check
    if (!mounted) return;
    final isPremium = Provider.of<CaseState>(context, listen: false).isPremium;
    if (isPremium) {
      if (mounted) {
        Navigator.pushNamed(context, '/ai_check');
      }
    } else {
      AdService.showInterstitialAd(
        context: context,
        onAdDismissed: () {
          if (mounted) {
            Navigator.pushNamed(context, '/ai_check');
          }
        },
      );
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.dangerRed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: Provider.of<CaseState>(context).isPremium ? null : const BannerAdWidget(),
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        titleSpacing: 24,
        title: const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            "MoneyBack",
            style: TextStyle(
              color: AppTheme.primaryNavy,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ),
        actions: const [], // Right side has nothing, keeping it clean
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 2. Large header block
              Container(
                width: double.infinity,
                color: AppTheme.primaryNavy,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "你現在卡在哪一步？",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      "先搞清楚狀況，才能做對下一步。",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              // Debt Nature Section
              Container(
                width: double.infinity,
                color: const Color(0xFF1A2B4C),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "你的錢是什麼性質？",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildDebtTypeCard(
                      "💰 借款類",
                      "借出去的錢，對方答應要還",
                      const Color(0xFF1565C0),
                      'loan',
                    ),
                    _buildDebtTypeCard(
                      "🤝 代墊類",
                      "幫對方墊付、代買的費用",
                      const Color(0xFF6A1B9A),
                      'advance',
                    ),
                    _buildDebtTypeCard(
                      "🏢 商業類",
                      "貨款、工程款、服務費未收",
                      const Color(0xFFE65100),
                      'commercial',
                    ),
                    _buildDebtTypeCard(
                      "🏠 租賃類",
                      "房租、押金、設備租借費用",
                      const Color(0xFF2E7D32),
                      'rental',
                    ),
                    _buildDebtTypeCard(
                      "📦 網購類",
                      "代購、團購、網拍款項糾紛",
                      const Color(0xFFF9A825),
                      'online_shopping',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 3. Situation selection buttons
              _buildSituationCard(
                title: "對方不還錢",
                subtitle: "到了約定日子，各種理由推託",
                color: const Color(0xFFD32F2F),
                value: "對方不還錢",
              ),
              _buildSituationCard(
                title: "對方一直拖",
                subtitle: "說下個月、下週，無限循環",
                color: AppTheme.secondaryYellow,
                value: "對方一直拖",
              ),
              _buildSituationCard(
                title: "對方已失聯",
                subtitle: "不讀不回、封鎖、人間蒸發",
                color: const Color(0xFF388E3C),
                value: "對方已失聯",
              ),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  children: [
                    Expanded(child: Divider(color: Color(0xFFDEE2E6))),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        "補充你的案件基本資料",
                        style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                      ),
                    ),
                    Expanded(child: Divider(color: Color(0xFFDEE2E6))),
                  ],
                ),
              ),

              // 5. Debt Amount
              _buildSectionHeader(_amountLabel),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    prefixIcon: Padding(
                      padding: EdgeInsets.all(14.0),
                      child: Text("NT\$", style: TextStyle(color: AppTheme.primaryNavy, fontWeight: FontWeight.bold)),
                    ),
                    prefixIconConstraints: BoxConstraints(minWidth: 0, minHeight: 0),
                    hintText: "請輸入金額",
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return "請輸入金額";
                    final numValue = double.tryParse(value);
                    if (numValue == null || numValue <= 0) return "請輸入大於0的有效數字金額";
                    return null;
                  },
                ),
              ),

              const SizedBox(height: 16),

              // 6. Borrow & Repay Date Pickers
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            " $_borrowDateLabel",
                            style: const TextStyle(color: AppTheme.primaryNavy, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () => _selectDate(context, _borrowDate ?? DateTime.now(), (date) => _borrowDate = date),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: const Color(0xFFDEE2E6)),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatDate(_borrowDate),
                                    style: TextStyle(
                                      color: _borrowDate == null ? AppTheme.textMuted : AppTheme.textDark,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const Icon(Icons.calendar_today, size: 16, color: AppTheme.primaryNavy),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            " $_repayDateLabel",
                            style: const TextStyle(color: AppTheme.primaryNavy, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () => _selectDate(context, _repayDate ?? DateTime.now().add(const Duration(days: 30)), (date) => _repayDate = date),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: const Color(0xFFDEE2E6)),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatDate(_repayDate),
                                    style: TextStyle(
                                      color: _repayDate == null ? AppTheme.textMuted : AppTheme.textDark,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const Icon(Icons.calendar_today, size: 16, color: AppTheme.primaryNavy),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 7. Send Date Picker
              _buildSectionHeader("存證信函發文日期"),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () => _selectDate(context, _sendDate, (date) => _sendDate = date),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: const Color(0xFFDEE2E6)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDate(_sendDate),
                              style: const TextStyle(color: AppTheme.textDark, fontSize: 14),
                            ),
                            const Icon(Icons.calendar_today, size: 16, color: AppTheme.primaryNavy),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "  預設為今天，可自行調整",
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 8. Money proof Checkboxes
              _buildSectionHeader("你有哪些金流證明？"),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      CheckboxListTile(
                        title: const Text("有銀行匯款／轉帳紀錄", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        subtitle: const Text("（需填寫轉帳日期）", style: TextStyle(fontSize: 12)),
                        value: _hasTransferRecord,
                        activeColor: AppTheme.primaryNavy,
                        onChanged: (val) {
                          setState(() {
                            _hasTransferRecord = val ?? false;
                            if (_hasTransferRecord) {
                              _isUnprovable = false;
                            }
                          });
                        },
                      ),
                      if (_hasTransferRecord)
                        Padding(
                          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12, top: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("轉帳日期", style: TextStyle(color: AppTheme.primaryNavy, fontSize: 12, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: () => _selectDate(context, _transferDate ?? _borrowDate ?? DateTime.now(), (date) => _transferDate = date),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.bgLight,
                                    border: Border.all(color: const Color(0xFFDEE2E6)),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _formatDate(_transferDate),
                                        style: TextStyle(
                                          color: _transferDate == null ? AppTheme.textMuted : AppTheme.textDark,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const Icon(Icons.calendar_today, size: 14, color: AppTheme.primaryNavy),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      CheckboxListTile(
                        title: const Text("給了現金（無紀錄）", style: TextStyle(fontSize: 14)),
                        value: _hasCash,
                        activeColor: AppTheme.primaryNavy,
                        onChanged: (val) {
                          setState(() {
                            _hasCash = val ?? false;
                            if (_hasCash) {
                              _isUnprovable = false;
                            }
                          });
                        },
                      ),
                      CheckboxListTile(
                        title: const Text("無法證明", style: TextStyle(fontSize: 14)),
                        value: _isUnprovable,
                        activeColor: AppTheme.primaryNavy,
                        onChanged: (val) {
                          setState(() {
                            _isUnprovable = val ?? false;
                            if (_isUnprovable) {
                              _hasTransferRecord = false;
                              _hasCash = false;
                              _transferDate = null;
                            }
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),

              if (_selectedDebtType == 'commercial') ...[
                const SizedBox(height: 12),
                _buildSectionHeader("服務／交貨／工程內容"),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: TextFormField(
                    controller: _serviceDescriptionController,
                    decoration: const InputDecoration(
                      hintText: "例如：網站設計、裝潢工程、商品出貨",
                    ),
                  ),
                ),
              ],
              if (_selectedDebtType == 'rental') ...[
                const SizedBox(height: 12),
                _buildSectionHeader("租賃標的"),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: TextFormField(
                    controller: _rentalObjectController,
                    decoration: const InputDecoration(
                      hintText: "例如：台北市信義區某某路房屋、攝影器材",
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // 9. Communication proof Checkboxes
              _buildSectionHeader("你們之間有哪些對話紀錄？"),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      CheckboxListTile(
                        title: const Text("有 LINE 截圖", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        value: _hasLineScreenshots,
                        activeColor: AppTheme.primaryNavy,
                        onChanged: (val) {
                          setState(() {
                            _hasLineScreenshots = val ?? false;
                          });
                        },
                      ),
                      CheckboxListTile(
                        title: const Text("只有口頭承諾", style: TextStyle(fontSize: 14)),
                        value: _hasVerbalPromise,
                        activeColor: AppTheme.primaryNavy,
                        onChanged: (val) {
                          setState(() {
                            _hasVerbalPromise = val ?? false;
                          });
                        },
                      ),
                      CheckboxListTile(
                        title: const Text("對方已不回應", style: TextStyle(fontSize: 14)),
                        value: _hasNoResponse,
                        activeColor: AppTheme.primaryNavy,
                        onChanged: (val) {
                          setState(() {
                            _hasNoResponse = val ?? false;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // 13. Dynamic chat app name input (when screenshots selected)
              if (_hasLineScreenshots) ...[
                const SizedBox(height: 12),
                _buildSectionHeader("通訊軟體名稱"),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: TextFormField(
                    controller: _chatAppNameController,
                    decoration: const InputDecoration(
                      hintText: "例如：LINE、微信",
                    ),
                    validator: (value) {
                      if (_hasLineScreenshots && (value == null || value.isEmpty)) {
                        return "請填寫通訊軟體名稱";
                      }
                      return null;
                    },
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // 10. Cosigner Option (Switch Toggle)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "是否有連帶保證人？",
                      style: TextStyle(color: AppTheme.primaryNavy, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    Switch(
                      value: _hasCosigner,
                      activeColor: Colors.white,
                      activeTrackColor: AppTheme.actionGreen,
                      onChanged: (val) {
                        setState(() {
                          _hasCosigner = val;
                        });
                      },
                    ),
                  ],
                ),
              ),

              if (_hasCosigner) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("連帶保證人姓名", style: TextStyle(color: AppTheme.primaryNavy, fontSize: 13, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _cosignerNameController,
                            decoration: const InputDecoration(
                              hintText: "請輸入連帶保證人姓名",
                            ),
                            validator: (value) {
                              if (_hasCosigner && (value == null || value.isEmpty)) {
                                return "請輸入連帶保證人姓名";
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          const Text("連帶保證人地址", style: TextStyle(color: AppTheme.primaryNavy, fontSize: 13, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _cosignerAddressController,
                            decoration: const InputDecoration(
                              hintText: "請輸入連帶保證人地址",
                            ),
                            validator: (value) {
                              if (_hasCosigner && (value == null || value.isEmpty)) {
                                return "請輸入連帶保證人地址";
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // 11. Collapsible Sender Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ExpansionPanelList(
                  elevation: 0,
                  expandedHeaderPadding: EdgeInsets.zero,
                  expansionCallback: (index, isExpanded) {
                    setState(() {
                      _isSenderSectionExpanded = isExpanded;
                    });
                  },
                  children: [
                    ExpansionPanel(
                      backgroundColor: Colors.white,
                      isExpanded: _isSenderSectionExpanded,
                      headerBuilder: (context, isExpanded) {
                        return const ListTile(
                          title: Text(
                            "你的資料（存證信函必填）",
                            style: TextStyle(color: AppTheme.primaryNavy, fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16),
                        );
                      },
                      body: Padding(
                        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("寄件人姓名", style: TextStyle(color: AppTheme.primaryNavy, fontSize: 13, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _senderNameController,
                              decoration: const InputDecoration(hintText: "請輸入您的真實姓名"),
                              validator: (value) {
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            const Text("寄件人地址", style: TextStyle(color: AppTheme.primaryNavy, fontSize: 13, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _senderAddressController,
                              decoration: const InputDecoration(hintText: "請輸入您的通訊/戶籍地址"),
                              validator: (value) {
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 12. Recipient Section (Opponent details)
              _buildSectionHeader("對方資料（存證信函寄送必填）"),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("對方姓名", style: TextStyle(color: AppTheme.primaryNavy, fontSize: 13, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _recipientNameController,
                          decoration: const InputDecoration(hintText: "請輸入對方的姓名"),
                          validator: (value) {
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        const Text("對方地址", style: TextStyle(color: AppTheme.primaryNavy, fontSize: 13, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _recipientAddressController,
                          decoration: const InputDecoration(
                            hintText: "請輸入對方地址",
                          ),
                          validator: (value) {
                            return null;
                          },
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "若不知道地址，可填對方的戶籍地",
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 14. Optional Evidence types (for ultimatum text)
              _buildSectionHeader("你手上有哪些證據？（選填）"),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextFormField(
                  controller: _evidenceTypesController,
                  decoration: const InputDecoration(
                    hintText: "例如：轉帳紀錄、LINE對話截圖",
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // 15. Fixed Bottom CTA Button (We add padding to ensure scroll is comfortable)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: ElevatedButton(
                  onPressed: _submitForm,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("開始 AI 案件健檢  "),
                      Icon(Icons.arrow_forward),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // Situation Selection Card Builder
  Widget _buildSituationCard({
    required String title,
    required String subtitle,
    required Color color,
    required String value,
  }) {
    final isSelected = _situation == value;
    return InkWell(
      onTap: () {
        setState(() {
          _situation = value;
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primaryNavy : const Color(0xFFE9ECEF),
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: AppTheme.primaryNavy.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 4))]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Row(
            children: [
              // Left color strip
              Container(
                width: 6,
                height: 72,
                color: color,
              ),
              const SizedBox(width: 16),
              // Main content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryNavy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              // Right selected checkmark icon
              if (isSelected)
                const Padding(
                  padding: EdgeInsets.only(right: 16.0),
                  child: Icon(
                    Icons.check_circle,
                    color: AppTheme.primaryNavy,
                    size: 24,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDebtTypeCard(
    String title,
    String subtitle,
    Color stripColor,
    String value,
  ) {
    final isSelected = _selectedDebtType == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDebtType = value;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF1565C0) : Colors.transparent,
            width: 2,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Row(
            children: [
              // Left color strip
              Container(
                width: 6,
                height: 64,
                color: stripColor,
              ),
              const SizedBox(width: 12),
              // Text Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryNavy,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Right check icon if selected
              if (isSelected)
                const Padding(
                  padding: EdgeInsets.only(right: 16.0),
                  child: Icon(
                    Icons.check_circle,
                    color: Color(0xFF1565C0),
                    size: 20,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 16, top: 8, bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          color: AppTheme.primaryNavy,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
