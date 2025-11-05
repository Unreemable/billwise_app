// lib/warranties/models/warranty_prefill.dart
import 'dart:io';

class WarrantyPrefill {
  final String? provider;        // اسم المتجر/المزوّد
  final String? serial;          // اختياري
  final DateTime? startDate;     // غالباً = تاريخ الشراء
  final DateTime? endDate;       // تخمين سنة افتراضيًا (اختياري)
  final File? attachmentFile;    // نفس صورة الفاتورة لو تبغى

  const WarrantyPrefill({
    this.provider,
    this.serial,
    this.startDate,
    this.endDate,
    this.attachmentFile,
  });
}
