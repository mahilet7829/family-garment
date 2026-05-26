import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/inventory/screens/inventory_screen.dart';
import '../../features/products/screens/product_builder_screen.dart';
import '../../features/production/screens/record_production_screen.dart';
import '../../features/expenses/screens/expenses_screen.dart';
import '../../features/reports/screens/reports_screen.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    DashboardScreen(),
    InventoryScreen(),
    ProductBuilderScreen(),
    RecordProductionScreen(),
    ExpensesScreen(),
    ReportsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: AppColors.navy.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.white,
          selectedItemColor: AppColors.navy,
          unselectedItemColor: AppColors.textSecondary,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.calculate_outlined),
              activeIcon: Icon(Icons.calculate),
              label: 'Simulator',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2_outlined),
              activeIcon: Icon(Icons.inventory_2),
              label: 'Inventory',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.checkroom_outlined),
              activeIcon: Icon(Icons.checkroom),
              label: 'Products',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.check_circle_outline),
              activeIcon: Icon(Icons.check_circle),
              label: 'Record',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.monetization_on_outlined),
              activeIcon: Icon(Icons.monetization_on),
              label: 'Expenses',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_outlined),
              activeIcon: Icon(Icons.bar_chart),
              label: 'Reports',
            ),
          ],
        ),
      ),
    );
  }
}