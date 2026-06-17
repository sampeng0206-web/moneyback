import 'dart:convert';

class CaseModel {
  String situation; // "對方不還錢", "對方一直拖", "對方已失聯" (Default is empty or first option)
  double amount;
  DateTime? borrowDate;
  DateTime? repayDate;
  DateTime sendDate;
  
  // 金流證明
  bool hasTransferRecord;
  DateTime? transferDate;
  bool hasCash;
  bool isUnprovable;

  // 對話紀錄
  bool hasLineScreenshots;
  bool hasVerbalPromise;
  bool hasNoResponse;

  // 連帶保證人
  bool hasCosigner;
  String cosignerName;
  String cosignerAddress;

  // 寄件人與受件人
  String senderName;
  String senderAddress;
  String recipientName;
  String recipientAddress;

  // 額外欄位
  String chatAppName; // 預設 LINE
  String evidenceTypes; // 證據種類
  String debtType; // 預設 'loan'
  String? serviceDescription;
  String? rentalObject;

  CaseModel({
    this.situation = "對方不還錢",
    this.amount = 0.0,
    this.borrowDate,
    this.repayDate,
    DateTime? sendDate,
    this.hasTransferRecord = false,
    this.transferDate,
    this.hasCash = false,
    this.isUnprovable = false,
    this.hasLineScreenshots = false,
    this.hasVerbalPromise = false,
    this.hasNoResponse = false,
    this.hasCosigner = false,
    this.cosignerName = "",
    this.cosignerAddress = "",
    this.senderName = "",
    this.senderAddress = "",
    this.recipientName = "",
    this.recipientAddress = "",
    this.chatAppName = "LINE",
    this.evidenceTypes = "",
    this.debtType = "loan",
    this.serviceDescription = "",
    this.rentalObject = "",
  }) : this.sendDate = sendDate ?? DateTime.now();

  // From JSON Map
  factory CaseModel.fromJson(Map<String, dynamic> json) {
    return CaseModel(
      situation: json['situation'] ?? "對方不還錢",
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      borrowDate: json['borrowDate'] != null ? DateTime.tryParse(json['borrowDate']) : null,
      repayDate: json['repayDate'] != null ? DateTime.tryParse(json['repayDate']) : null,
      sendDate: json['sendDate'] != null ? DateTime.tryParse(json['sendDate']) : DateTime.now(),
      hasTransferRecord: json['hasTransferRecord'] ?? false,
      transferDate: json['transferDate'] != null ? DateTime.tryParse(json['transferDate']) : null,
      hasCash: json['hasCash'] ?? false,
      isUnprovable: json['isUnprovable'] ?? false,
      hasLineScreenshots: json['hasLineScreenshots'] ?? false,
      hasVerbalPromise: json['hasVerbalPromise'] ?? false,
      hasNoResponse: json['hasNoResponse'] ?? false,
      hasCosigner: json['hasCosigner'] ?? false,
      cosignerName: json['cosignerName'] ?? "",
      cosignerAddress: json['cosignerAddress'] ?? "",
      senderName: json['senderName'] ?? "",
      senderAddress: json['senderAddress'] ?? "",
      recipientName: json['recipientName'] ?? "",
      recipientAddress: json['recipientAddress'] ?? "",
      chatAppName: json['chatAppName'] ?? "LINE",
      evidenceTypes: json['evidenceTypes'] ?? "",
      debtType: json['debtType'] ?? "loan",
      serviceDescription: json['serviceDescription'] ?? "",
      rentalObject: json['rentalObject'] ?? "",
    );
  }

  // To JSON Map
  Map<String, dynamic> toJson() {
    return {
      'situation': situation,
      'amount': amount,
      'borrowDate': borrowDate?.toIso8601String(),
      'repayDate': repayDate?.toIso8601String(),
      'sendDate': sendDate.toIso8601String(),
      'hasTransferRecord': hasTransferRecord,
      'transferDate': transferDate?.toIso8601String(),
      'hasCash': hasCash,
      'isUnprovable': isUnprovable,
      'hasLineScreenshots': hasLineScreenshots,
      'hasVerbalPromise': hasVerbalPromise,
      'hasNoResponse': hasNoResponse,
      'hasCosigner': hasCosigner,
      'cosignerName': cosignerName,
      'cosignerAddress': cosignerAddress,
      'senderName': senderName,
      'senderAddress': senderAddress,
      'recipientName': recipientName,
      'recipientAddress': recipientAddress,
      'chatAppName': chatAppName,
      'evidenceTypes': evidenceTypes,
      'debtType': debtType,
      'serviceDescription': serviceDescription,
      'rentalObject': rentalObject,
    };
  }

  // Copy with helper
  CaseModel copyWith({
    String? situation,
    double? amount,
    DateTime? borrowDate,
    DateTime? repayDate,
    DateTime? sendDate,
    bool? hasTransferRecord,
    DateTime? transferDate,
    bool? hasCash,
    bool? isUnprovable,
    bool? hasLineScreenshots,
    bool? hasVerbalPromise,
    bool? hasNoResponse,
    bool? hasCosigner,
    String? cosignerName,
    String? cosignerAddress,
    String? senderName,
    String? senderAddress,
    String? recipientName,
    String? recipientAddress,
    String? chatAppName,
    String? evidenceTypes,
    String? debtType,
    String? serviceDescription,
    String? rentalObject,
  }) {
    return CaseModel(
      situation: situation ?? this.situation,
      amount: amount ?? this.amount,
      borrowDate: borrowDate ?? this.borrowDate,
      repayDate: repayDate ?? this.repayDate,
      sendDate: sendDate ?? this.sendDate,
      hasTransferRecord: hasTransferRecord ?? this.hasTransferRecord,
      transferDate: transferDate ?? this.transferDate,
      hasCash: hasCash ?? this.hasCash,
      isUnprovable: isUnprovable ?? this.isUnprovable,
      hasLineScreenshots: hasLineScreenshots ?? this.hasLineScreenshots,
      hasVerbalPromise: hasVerbalPromise ?? this.hasVerbalPromise,
      hasNoResponse: hasNoResponse ?? this.hasNoResponse,
      hasCosigner: hasCosigner ?? this.hasCosigner,
      cosignerName: cosignerName ?? this.cosignerName,
      cosignerAddress: cosignerAddress ?? this.cosignerAddress,
      senderName: senderName ?? this.senderName,
      senderAddress: senderAddress ?? this.senderAddress,
      recipientName: recipientName ?? this.recipientName,
      recipientAddress: recipientAddress ?? this.recipientAddress,
      chatAppName: chatAppName ?? this.chatAppName,
      evidenceTypes: evidenceTypes ?? this.evidenceTypes,
      debtType: debtType ?? this.debtType,
      serviceDescription: serviceDescription ?? this.serviceDescription,
      rentalObject: rentalObject ?? this.rentalObject,
    );
  }
}
