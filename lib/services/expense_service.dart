import '../core/database/database_helper.dart';
import '../models/expense_model.dart';

class ExpenseService {
  final DatabaseHelper _db = DatabaseHelper();

  Future<int> createExpense(ExpenseModel expense) async {
    final db = await _db.database;
    return await db.insert('expenses', expense.toMap());
  }

  Future<List<ExpenseModel>> getAllExpenses() async {
    final db = await _db.database;
    final maps = await db.query('expenses', orderBy: 'name ASC');
    return maps.map((map) => ExpenseModel.fromMap(map)).toList();
  }

  Future<List<ExpenseModel>> getExpensesByCategory(String category) async {
    final db = await _db.database;
    final maps = await db.query('expenses', where: 'category = ?', whereArgs: [category], orderBy: 'name ASC');
    return maps.map((map) => ExpenseModel.fromMap(map)).toList();
  }

  Future<int> updateExpense(ExpenseModel expense) async {
    final db = await _db.database;
    return await db.update('expenses', expense.toMap(), where: 'id = ?', whereArgs: [expense.id]);
  }

  Future<int> deleteExpense(int id) async {
    final db = await _db.database;
    await db.delete('expense_payments', where: 'expenseId = ?', whereArgs: [id]);
    return await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> createPayment(ExpensePaymentModel payment) async {
    final db = await _db.database;
    return await db.insert('expense_payments', payment.toMap());
  }

  Future<List<ExpensePaymentModel>> getPayments(int expenseId) async {
    final db = await _db.database;
    final maps = await db.query('expense_payments', where: 'expenseId = ?', whereArgs: [expenseId], orderBy: 'paidAt DESC');
    return maps.map((map) => ExpensePaymentModel.fromMap(map)).toList();
  }

  Future<List<ExpensePaymentModel>> getPaymentsForMonth(DateTime month) async {
    final db = await _db.database;
    final from = DateTime(month.year, month.month, 1);
    final to = DateTime(month.year, month.month + 1, 0, 23, 59, 59, 999);
    final maps = await db.query('expense_payments', where: 'paidAt >= ? AND paidAt <= ?', whereArgs: [from.toIso8601String(), to.toIso8601String()], orderBy: 'paidAt DESC');
    return maps.map((map) => ExpensePaymentModel.fromMap(map)).toList();
  }

  Future<Map<String, double>> getMonthlySummary(DateTime month) async {
    final db = await _db.database;
    final from = DateTime(month.year, month.month, 1);
    final to = DateTime(month.year, month.month + 1, 0, 23, 59, 59, 999);
    final result = await db.rawQuery('SELECT category, COALESCE(SUM(amount),0) as total FROM expense_payments WHERE paidAt>=? AND paidAt<=? GROUP BY category', [from.toIso8601String(), to.toIso8601String()]);
    final summary = <String, double>{};
    for (var row in result) {
      summary[row['category'].toString()] = (row['total'] as num).toDouble();
    }
    return summary;
  }
}