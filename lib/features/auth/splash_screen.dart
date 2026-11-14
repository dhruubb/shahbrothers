import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/brand.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.maroon900,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrandMark(size: 84, onDark: true),
            SizedBox(height: 18),
            BrandWordmark(onDark: true, size: 30),
            SizedBox(height: 36),
            SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.2, color: AppColors.goldLight)),
          ],
        ),
      ),
    );
  }
}
