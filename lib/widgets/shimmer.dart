import 'package:flutter/material.dart';

class ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  const ShimmerBox({super.key, required this.width, required this.height});

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
    _animation = Tween<double>(begin: -1, end: 2).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            stops: [
              (_animation.value - 0.3).clamp(0.0, 1.0),
              _animation.value.clamp(0.0, 1.0),
              (_animation.value + 0.3).clamp(0.0, 1.0),
            ],
            colors: const [
              Color(0xFF151720),
              Color(0xFF1e2130),
              Color(0xFF151720),
            ],
          ),
        ),
      ),
    );
  }
}

class ShimmerBrowseCard extends StatelessWidget {
  const ShimmerBrowseCard({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 130,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ShimmerBox(width: 130, height: 185),
          const SizedBox(height: 6),
          ShimmerBox(width: 110, height: 12),
          const SizedBox(height: 4),
          ShimmerBox(width: 70, height: 10),
        ],
      ),
    );
  }
}
