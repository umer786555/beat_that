import 'package:flutter/material.dart';

class HomeVideoFeedDropdownMenu extends StatelessWidget {
  const HomeVideoFeedDropdownMenu({super.key, this.onReportPressed});

  final VoidCallback? onReportPressed;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.white),
      elevation: 8,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      onSelected: (String value) {
        if (value == 'report' && onReportPressed != null) {
          onReportPressed!();
        }
      },
      itemBuilder: (BuildContext context) => [
        const PopupMenuItem<String>(
          value: 'report',
          child: Text(
            'Report',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
