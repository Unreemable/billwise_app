import 'package:flutter/material.dart';

// الصفحات اللي نمشي بينها عن طريق البار السفلي
import '../home/home_screen.dart';                // شاشة الهوم
import '../warranties/ui/warranty_list_page.dart'; // قائمة الضمانات
import '../bills/ui/bill_list_page.dart';          // قائمة الفواتير

/// تدرج موحد للبار (بنفسجي → لافندر ناعم)
const LinearGradient _kAppGradient = LinearGradient(
  colors: [
    Color(0xFF9B5CFF), // البنفسجي الأساسي
    Color(0xFF9B5CFF), // لافندر وردي ناعم بدل الأزرق
  ],
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
);

// الـ Shell العامة للتطبيق: فيها البار السفلي + تغيير التبويبات
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0; // 0 = Home, 1 = Warranties, 2 = Bills

  // مفاتيح للنّافيقيتور الداخلي لكل تبويب (عشان كل تبويب يكون له ستاك خاص)
  final _homeKey = GlobalKey<NavigatorState>();
  final _warrKey = GlobalKey<NavigatorState>();
  final _billKey = GlobalKey<NavigatorState>();

  // this.currentNav = النّافيقيتور الخاص بالتبويب الحالي
  NavigatorState get _currentNav =>
      [_homeKey, _warrKey, _billKey][_index].currentState!;

  // منطق زر الباك (رجوع) في الجوال
  Future<bool> _onWillPop() async {
    // لو أقدر أرجع صفحة داخل نفس التبويب  أرجع بس داخل التبويب
    if (_currentNav.canPop()) {
      _currentNav.pop();
      return false; // لا تطلع من التطبيق
    }
    // لو مو واقفة على الهوم → رجّعني للهوم بدل ما تقفل التطبيق
    if (_index != 0) {
      setState(() => _index = 0);
      return false;
    }
    // لو أصلاً على الهوم ومافي شي ورا  اسمح بالخروج
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop, // نربط منطق زر الرجوع
      child: Scaffold(
        // الخلفية شفافة عشان تبان خلفية الباستيل من الـ main
        backgroundColor: Colors.transparent,
        // يخلي الجسم يمتد تحت البار السفلي (يقلل القصّة السوداء)
        extendBody: true,

        // زر الهوم اللي بالنص
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        floatingActionButton: _CenterHomeButton(
          selected: _index == 0,            // لو إحنا في الهوم نخليه مرفوع شوي
          onTap: () => setState(() => _index = 0),
        ),

        // البار السفلي المنحني (دايم موجود لكل الشاشات)
        bottomNavigationBar: _CurvedBottomBar(
          selectedTab: _index,              // يحدد أي تبويب مفعل
          onTapLeft:  () => setState(() => _index = 1), // نروح للضمانات
          onTapRight: () => setState(() => _index = 2), // نروح للفواتير
        ),

        // IndexedStack عشان نحافظ على حالة كل تبويب (ما يعيد تحميل القائمة كل مرة)
        body: IndexedStack(
          index: _index,
          children: [
            // تبويب الهوم
            Navigator(
              key: _homeKey,
              onGenerateRoute: (s) => MaterialPageRoute(
                builder: (_) => const HomeContent(),
                settings: s,
              ),
            ),
            // تبويب الضمانات
            Navigator(
              key: _warrKey,
              onGenerateRoute: (s) => MaterialPageRoute(
                builder: (_) => const WarrantyListPage(),
                settings: s,
              ),
            ),
            // تبويب الفواتير
            Navigator(
              key: _billKey,
              onGenerateRoute: (s) => MaterialPageRoute(
                builder: (_) => const BillListPage(),
                settings: s,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================== البار السفلي المنحني ==================

class _CurvedBottomBar extends StatelessWidget {
  final int selectedTab; // 0 home, 1 warr, 2 bills
  final VoidCallback onTapLeft;  // لما أضغط زر Warranties
  final VoidCallback onTapRight; // لما أضغط زر Bills

  const _CurvedBottomBar({
    required this.selectedTab,
    required this.onTapLeft,
    required this.onTapRight,
  });

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      // نخليه شفاف بالكامل، التدرّج بنرسمه في DecoratedBox تحت
      color: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      // AutomaticNotchedShape = شكل منحني فيه فتحة للزر الدائري اللي في النص
      shape: const AutomaticNotchedShape(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            // زاوية البار من فوق (كل ما كبرت القيمة يصير الكيرف أنعم)
            topLeft: Radius.circular(60),
            topRight: Radius.circular(60),
          ),
        ),
        CircleBorder(), // الفتحة الدائرية حق زر الهوم
      ),
      clipBehavior: Clip.antiAlias, // يقص المحتوى على شكل البار المنحني
      child: DecoratedBox(
        // هنا نرسم التدرج البنفسجي/الأزرق
        decoration: const BoxDecoration(gradient: _kAppGradient),
        child: SafeArea(
          top: false, // ما نهتم بالـ top لأنه تحت الشاشة
          child: SizedBox(
            height: 64, // ارتفاع البار
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 50),
              child: Row(
                children: [
                  // زر Warranties على اليسار
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
                  const SizedBox(width: 64), // فراغ للزر الدائري اللي في النص
                  // زر Bills على اليمين
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

// عنصر واحد داخل البار (أيقونة + نص)
class _BottomItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;   // هل هذا التبويب هو الحالي؟
  final VoidCallback onTap;

  const _BottomItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // نمط النص: لو التبويب مختار نخلي الخط أسمك شوي
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
            // الأيقونة، تكبر شوي لو التبويب مختار
            Icon(icon, color: Colors.white, size: selected ? 26 : 24),
            const SizedBox(height: 2),
            Text(label, style: textStyle),
          ],
        ),
      ),
    );
  }
}

// زر الهوم الدائري اللي في النص (Floating Action Button مخصص)
class _CenterHomeButton extends StatelessWidget {
  final bool selected;   // هل إحنا الآن في الهوم؟
  final VoidCallback onTap;

  const _CenterHomeButton({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap, // لما نضغط يرجuنا للهوم
      child: AnimatedContainer(
        // أنيميشن بسيط لما يتغير التبويب
        duration: const Duration(milliseconds: 180),
        // لو الزر مختار (في الهوم) نرفعه شوي لفوق عشان يبان "طالع"
        transform: Matrix4.translationValues(0, selected ? -6 : 0, 0),
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          // نفس تدرّج البار عشان يطلع منسجم
          gradient: const LinearGradient(
            colors: [Color(0xFF9B5CFF), Color(0xFF6C3EFF)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          // حدود بيضاء حوالين الزر
          border: Border.all(color: Colors.white, width: 4),
          // ظل خفيف تحت الزر يعطي إحساس عمق
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Icon(Icons.home_filled, color: Colors.white, size: 28),
      ),
    );
  }
}
