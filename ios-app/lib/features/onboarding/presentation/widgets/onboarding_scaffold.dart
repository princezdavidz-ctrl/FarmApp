import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';

class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    required this.body,
    required this.actions,
    this.progress,
    this.topAction,
    super.key,
  });

  final Widget body;
  final Widget actions;
  final double? progress;
  final Widget? topAction;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          if (topAction != null)
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: topAction!,
              ),
            ),
          if (progress != null)
            LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: AppColors.leaf.withValues(alpha: 0.22),
            ),
          Expanded(child: body),
        ],
      ),
    ),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDimensions.pagePadding,
          10,
          AppDimensions.pagePadding,
          16,
        ),
        child: actions,
      ),
    ),
  );
}

class OnboardingEntry extends StatefulWidget {
  const OnboardingEntry({required this.child, super.key});

  final Widget child;

  @override
  State<OnboardingEntry> createState() => _OnboardingEntryState();
}

class _OnboardingEntryState extends State<OnboardingEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  )..forward();
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );
  late final Animation<Offset> _slide = Tween(
    begin: const Offset(0, 0.035),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return widget.child;
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
