import 'package:flutter/foundation.dart';

@immutable
class BillDetails {
  final String id;                 // 👈 مهم: document id
  final String title;
  final String? product;
  final double? amount;
  final DateTime purchaseDate;
  final DateTime? returnDeadline;
  final DateTime? exchangeDeadline;
  final bool hasWarranty;
  final DateTime? warrantyExpiry;

  const BillDetails({

    required this.id,              // 👈 لازم تمرره
    required this.title,
    this.product,
    this.amount,
    required this.purchaseDate,
    this.returnDeadline,
    this.exchangeDeadline,
    this.hasWarranty = false,
    this.warrantyExpiry,
  });
}

@immutable
class WarrantyDetails {
  final String title;
  final String? id;
  final String product;
  final DateTime warrantyStart;
  final DateTime warrantyExpiry;
  final DateTime? returnDeadline;
  final DateTime? reminderDate;

  const WarrantyDetails({
    required this.id,
    required this.title,
    required this.product,
    required this.warrantyStart,
    required this.warrantyExpiry,
    this.returnDeadline,
    this.reminderDate,
  });
}
