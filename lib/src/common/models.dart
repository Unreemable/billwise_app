class BillDetails {
  final String title;           // مثال: Carrefour / Extra
  final String product;         // Dell Laptop
  final double amount;          // 299.0
  final DateTime purchaseDate;  // تاريخ الشراء
  final DateTime? returnDeadline;
  final DateTime? warrantyExpiry;

  BillDetails({
    required this.title,
    required this.product,
    required this.amount,
    required this.purchaseDate,
    this.returnDeadline,
    this.warrantyExpiry,
  });
}

class WarrantyDetails {
  final String title;                // اسم المتجر/الضمان
  final String product;              // اسم المنتج
  final DateTime warrantyStart;      // بداية الضمان
  final DateTime warrantyExpiry;     // نهاية الضمان
  final DateTime? returnDeadline;    // (اختياري) موعد الاستبدال
  final DateTime? reminderDate;      // (اختياري) تذكير
  WarrantyDetails({
    required this.title,
    required this.product,
    required this.warrantyStart,
    required this.warrantyExpiry,
    this.returnDeadline,
    this.reminderDate,
  });
}
