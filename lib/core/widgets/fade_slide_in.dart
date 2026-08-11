import 'package:flutter/material.dart';

/// Wraps [child] in a one-shot fade + slide-up entrance animation, staggered
/// by [index] so grid/list items cascade in rather than popping in together.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  static const _stepDelay = Duration(milliseconds: 40);
  static const _duration = Duration(milliseconds: 320);
  static const _maxDelaySteps = 10;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: FadeSlideIn._duration,
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.08),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    // Cap the stagger so a long grid doesn't leave the last rows waiting on
    // an ever-growing delay — items beyond this all start together.
    final steps = widget.index.clamp(0, FadeSlideIn._maxDelaySteps);
    Future.delayed(FadeSlideIn._stepDelay * steps, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
