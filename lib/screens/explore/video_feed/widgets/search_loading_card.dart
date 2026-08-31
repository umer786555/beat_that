import 'package:flutter/material.dart';

class SearchLoadingCard extends StatelessWidget {
  const SearchLoadingCard({super.key, required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: isDark ? Colors.white10 : Colors.black12,
      ),
    );
  }
}
