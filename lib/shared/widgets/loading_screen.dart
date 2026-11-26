import 'package:flutter/material.dart';

// full-screen placeholder shown while the app or a route is still loading
class LoadingScreen extends StatelessWidget {
  final String message;
  final Color backgroundColor;
  final Color foregroundColor;
  final bool showSpinner;

  const LoadingScreen({
    super.key,
    required this.message,
    required this.backgroundColor,
    required this.foregroundColor,
    this.showSpinner = true,
  });

  @override
  Widget build(BuildContext context) {
    final baseStyle = Theme.of(context).textTheme.bodyMedium;
    final textStyle =
        baseStyle?.copyWith(
          color: foregroundColor,
          fontWeight: FontWeight.w500,
        ) ??
        TextStyle(
          color: foregroundColor,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        );

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showSpinner)
                SizedBox(
                  width: 64,
                  height: 64,
                  child: CircularProgressIndicator(
                    strokeWidth: 4,
                    valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
                  ),
                ),
              if (showSpinner) const SizedBox(height: 16),
              Text(message, style: textStyle, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
