import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ShimmerCard extends StatelessWidget {
  final double height;
  final double width;
  final double borderRadius;
  final EdgeInsetsGeometry margin;

  const ShimmerCard({
    super.key,
    this.height = 100,
    this.width = double.infinity,
    this.borderRadius = 16,
    this.margin = const EdgeInsets.symmetric(vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: Shimmer.fromColors(
        baseColor: const Color(0xFFF9E4EA).withValues(alpha: 0.5), // blush with opacity
        highlightColor: const Color(0xFFE8607A).withValues(alpha: 0.2), // rosePale with opacity
        child: Container(
          height: height,
          width: width,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
      ),
    );
  }
}

class ShimmerList extends StatelessWidget {
  final int itemCount;
  final double itemHeight;

  const ShimmerList({
    super.key,
    this.itemCount = 5,
    this.itemHeight = 100,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: itemCount,
      itemBuilder: (context, index) => ShimmerCard(height: itemHeight),
    );
  }
}
