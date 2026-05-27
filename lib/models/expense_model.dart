/// Represents a recurring expense (Labor, Transport, etc.)
class ExpenseModel {
  final int? id;
  final String name;
  final String category;
  final double monthlyCost;
  final String expenseFrequency;
  final DateTime createdAt;

  ExpenseModel({
    this.id,
    required this.name,
    required this.category,
    required this.monthlyCost,
    this.expenseFrequency = 'monthly',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'category': category,
      'monthlyCost': monthlyCost,
      'expenseFrequency': expenseFrequency,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ExpenseModel.fromMap(Map<String, dynamic> map) {
    return ExpenseModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      category: map['category'] as String,
      monthlyCost: (map['monthlyCost'] as num).toDouble(),
      expenseFrequency: (map['expenseFrequency'] as String?) ?? 'monthly',
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}

/// Represents a single payment for an expense
class ExpensePaymentModel {
  final int? id;
  final int expenseId;
  final String name;
  final String category;
  final double amount;
  final String notes;
  final DateTime paidAt;

  ExpensePaymentModel({
    this.id,
    required this.expenseId,
    required this.name,
    required this.category,
    required this.amount,
    this.notes = '',
    DateTime? paidAt,
  }) : paidAt = paidAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'expenseId': expenseId,
      'name': name,
      'category': category,
      'amount': amount,
      'notes': notes,
      'paidAt': paidAt.toIso8601String(),
    };
  }

  factory ExpensePaymentModel.fromMap(Map<String, dynamic> map) {
    return ExpensePaymentModel(
      id: map['id'] as int?,
      expenseId: map['expenseId'] as int,
      name: map['name'] as String,
      category: map['category'] as String,
      amount: (map['amount'] as num).toDouble(),
      notes: (map['notes'] as String?) ?? '',
      paidAt: DateTime.parse(map['paidAt'] as String),
    );
  }
}