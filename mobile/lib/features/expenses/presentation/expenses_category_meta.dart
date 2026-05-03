import 'package:flutter/material.dart';

class ExpenseCategoryMeta {
  const ExpenseCategoryMeta(this.label, this.icon, this.color, this.bg);
  final String label;
  final IconData icon;
  final Color color;
  final Color bg;
}

const kExpenseCategories = <String, ExpenseCategoryMeta>{
  'inventory_purchase': ExpenseCategoryMeta(
    'Inventory',
    Icons.shopping_cart_rounded,
    Color(0xFF0F766E),
    Color(0xFFE6F4F1),
  ),
  'transport': ExpenseCategoryMeta(
    'Transport',
    Icons.directions_car_rounded,
    Color(0xFF2563EB),
    Color(0xFFEFF6FF),
  ),
  'utilities': ExpenseCategoryMeta(
    'Utilities',
    Icons.bolt_rounded,
    Color(0xFFD97706),
    Color(0xFFFFFBEB),
  ),
  'rent': ExpenseCategoryMeta(
    'Rent',
    Icons.home_rounded,
    Color(0xFFEA580C),
    Color(0xFFFFF7ED),
  ),
  'salary': ExpenseCategoryMeta(
    'Salary',
    Icons.people_rounded,
    Color(0xFF7C3AED),
    Color(0xFFF5F3FF),
  ),
  'tax': ExpenseCategoryMeta(
    'Tax',
    Icons.account_balance_rounded,
    Color(0xFFDC2626),
    Color(0xFFFEF2F2),
  ),
  'other': ExpenseCategoryMeta(
    'Other',
    Icons.receipt_long_rounded,
    Color(0xFF6B7280),
    Color(0xFFF9FAFB),
  ),
};

ExpenseCategoryMeta expenseMetaFor(String category) =>
    kExpenseCategories[category] ?? kExpenseCategories['other']!;
