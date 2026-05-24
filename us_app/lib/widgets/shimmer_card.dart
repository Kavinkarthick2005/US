import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../config/app_colors.dart';

class ShimmerCard extends StatelessWidget {
  const ShimmerCard({
    super.key,
    this.height = 80,
    this.width = double.infinity,
    this.borderRadius = 16,
    this.baseColor,
    this.highlightColor,
  });

  final double height;
  final double width;
  final double borderRadius;
  final Color? baseColor;
  final Color? highlightColor;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: baseColor ?? AppColors.blush,
      highlightColor: highlightColor ?? AppColors.rosePale,
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: baseColor ?? AppColors.blush,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

class ShimmerList extends StatelessWidget {
  const ShimmerList({
    super.key,
    this.count = 3,
    this.itemHeight = 80,
    this.spacing = 12,
    this.baseColor,
    this.highlightColor,
  });

  final int count;
  final double itemHeight;
  final double spacing;
  final Color? baseColor;
  final Color? highlightColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        count,
        (i) => Padding(
          padding: EdgeInsets.only(bottom: i < count - 1 ? spacing : 0),
          child: ShimmerCard(
            height: itemHeight,
            baseColor: baseColor,
            highlightColor: highlightColor,
          ),
        ),
      ),
    );
  }
}
