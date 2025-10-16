import 'package:flutter/material.dart';

// تبويبات
import '../home/home_screen.dart';                // HomeContent
import '../warranties/ui/warranty_list_page.dart';
import '../bills/ui/bill_list_page.dart';

/// تدرّج موحّد (90° يسار → يمين)
const LinearGradient _kAppGradient = LinearGradient(
  colors: [Color(0xFF5F33E1), Color(0xFF000000)],
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
);

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  final _homeKey = GlobalKey<NavigatorState>();
  final _warrKey = GlobalKey<NavigatorState>();
  final _billKey = GlobalKey<NavigatorState>();

  NavigatorState get _currentNav =>
      [_homeKey, _warrKey, _billKey][_index].currentState!;

  Future<bool> _onWillPop() async {
    if (_currentNav.canPop()) {
      _currentNav.pop();
      return false;
    }
    if (_index != 0) {
      setState(() => _index = 0);
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        floatingActionButton: _CenterHomeButton(
          selected: _index == 0,
          onTap: () => setState(() => _index = 0),
        ),
        bottomNavigationBar: _CurvedBottomBar(
          selectedTab: _index,
          onTapLeft: () => setState(() => _index = 1),
          onTapRight: () => setState(() => _index = 2),
        ),
        body: IndexedStack(
          index: _index,
          children: [
            Navigator(
              key: _homeKey,
              onGenerateRoute: (s) =>
                  MaterialPageRoute(builder: (_) => const HomeContent(), settings: s),
            ),
            Navigator(
              key: _warrKey,
              onGenerateRoute: (s) =>
                  MaterialPageRoute(builder: (_) => const WarrantyListPage(), settings: s),
            ),
            Navigator(
              key: _billKey,
              onGenerateRoute: (s) =>
                  MaterialPageRoute(builder: (_) => const BillListPage(), settings: s),
            ),
          ],
        ),
      ),
    );
  }
}

// ====== Bottom bar + Center button ======

class _CurvedBottomBar extends StatelessWidget {
  final int selectedTab; // 0 home, 1 warr, 2 bills
  final VoidCallback onTapLeft;
  final VoidCallback onTapRight;

  const _CurvedBottomBar({
    required this.selectedTab,
    required this.onTapLeft,
    required this.onTapRight,
  });

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      shape: const AutomaticNotchedShape(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.only(topLeft: Radius.circular(26), topRight: Radius.circular(26)),
        ),
        CircleBorder(),
      ),
      clipBehavior: Clip.antiAlias,
      notchMargin: 8,
      elevation: 12,
      child: DecoratedBox(
        decoration: const BoxDecoration(gradient: _kAppGradient),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _BottomItem(
                        icon: Icons.verified,
                        label: 'Warranties',
                        selected: selectedTab == 1,
                        onTap: onTapLeft,
                      ),
                    ),
                  ),
                  const SizedBox(width: 64),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _BottomItem(
                        icon: Icons.receipt_long,
                        label: 'Bills',
                        selected: selectedTab == 2,
                        onTap: onTapRight,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _BottomItem({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Colors.white,
      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: selected ? 26 : 24),
            const SizedBox(height: 2),
            Text(label, style: textStyle),
          ],
        ),
      ),
    );
  }
}

class _CenterHomeButton extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;

  const _CenterHomeButton({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        transform: Matrix4.translationValues(0, selected ? -6 : 0, 0),
        width: 64, height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF5F33E1), Color(0xFF000000)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          border: Border.all(color: Colors.white, width: 4),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: const Icon(Icons.home_filled, color: Colors.white, size: 28),
      ),
    );
  }
}
