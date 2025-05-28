import 'package:flutter/material.dart';

class LedIndicator extends StatelessWidget {
  final Color color;
  final String? text; // Text to display on the LED
  final TextStyle textStyle;
  final Color bezelColor;
  final double width;
  final double height;
  final double bezelWidth;
  final bool isGlowing;

  const LedIndicator({
    super.key,
    required this.color,
    this.text,
    this.textStyle = const TextStyle(fontSize: 14,
        color: Colors.white,
        fontWeight: FontWeight.bold), // Default style
    this.bezelColor = Colors.black54,
    this.width = 120.0, // May need to be wider for text
    this.height = 24.0, // May need to be taller for text
    this.bezelWidth = 1.0,
    this.isGlowing = false,
  });

  @override
  Widget build(BuildContext context) {
    // ... (boxShadows logic remains the same as before) ...
    final List<BoxShadow> boxShadows = [];
    if (isGlowing) {
      boxShadows.add(
        BoxShadow(
          color: color.withValues(alpha: 0.7),
          blurRadius: 6.0,
          spreadRadius: 2.0,
        ),
      );
    } else {
      boxShadows.add(
        BoxShadow(
          color: color.withValues(alpha: 0.5),
          blurRadius: 2.0,
          spreadRadius: 0.5,
        ),
      );
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(height / 4),
        // Might want less rounding with text
        border: Border.all(
          color: bezelColor,
          width: bezelWidth,
        ),
        boxShadow: boxShadows,
      ),
      child: text != null
          ? Center(
        child: Text(
          text!,
          style: textStyle,
          overflow: TextOverflow.ellipsis, // Prevent overflow
          textAlign: TextAlign.center,
        ),
      )
          : null,
    );
  }
}