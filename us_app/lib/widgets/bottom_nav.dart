import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/app_colors.dart';
import '../providers/theme_provider.dart';

class BottomNav extends ConsumerStatefulWidget {
  const BottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final Function(int) onTap;

  @override
  ConsumerState<BottomNav> createState() => _BottomNavState();
}

class _BottomNavState extends ConsumerState<BottomNav>
    with TickerProviderStateMixin {
  static const _tabs = [
    _TabItem(icon: Icons.home_rounded,                   label: 'Home'),
    _TabItem(icon: Icons.favorite_rounded,               label: 'Memory'),
    _TabItem(icon: Icons.account_balance_wallet_rounded, label: 'Finance'),
    _TabItem(icon: Icons.calendar_month_rounded,         label: 'Planner'),
    _TabItem(icon: Icons.auto_awesome_rounded,           label: 'AI'),
  ];

  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _scales;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      _tabs.length,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 320),
      ),
    );
    _scales = _controllers.map((c) {
      return TweenSequence<double>([
        TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.15), weight: 40),
        TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 60),
      ]).animate(CurvedAnimation(parent: c, curve: Curves.easeInOut));
    }).toList();
  }

  @override
  void didUpdateWidget(BottomNav old) {
    super.didUpdateWidget(old);
    if (old.currentIndex != widget.currentIndex) {
      _controllers[widget.currentIndex].forward(from: 0);
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tc = ref.watch(themeProvider).colors;

    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: tc.bottomNavColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: AppColors.rose.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(_tabs.length, (i) {
          final active = i == widget.currentIndex;
          final activeColor = tc.iconColor;
          return GestureDetector(
            onTap: () => widget.onTap(i),
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: 56,
              height: 72,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _scales[i],
                    builder: (_, child) =>
                        Transform.scale(scale: _scales[i].value, child: child),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: active
                            ? activeColor.withValues(alpha: 0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _tabs[i].icon,
                        size: 24,
                        color: active ? activeColor : tc.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    width:  active ? 5 : 0,
                    height: active ? 5 : 0,
                    decoration: BoxDecoration(
                      color:  active ? activeColor : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _TabItem {
  const _TabItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}
