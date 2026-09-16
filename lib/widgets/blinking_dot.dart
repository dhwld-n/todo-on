import 'package:flutter/material.dart';

class BlinkingDot extends StatefulWidget {
  final double size;
  final Color? color;

  const BlinkingDot({super.key, this.size = 7, this.color});

  @override
  State<BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<BlinkingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    return FadeTransition(
      opacity: Tween<double>(
        begin: 1,
        end: 0.2,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
