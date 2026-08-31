import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../cubit/content_report_cubit.dart';
import '../models/report_target.dart';
import 'content_report_bottom_sheet.dart';

Future<String?> showContentReportBottomSheet(
  BuildContext context, {
  required ReportTarget target,
}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(16),
        topRight: Radius.circular(16),
      ),
    ),
    builder: (sheetContext) {
      return BlocProvider(
        create: (_) => ContentReportCubit(target: target),
        child: ContentReportBottomSheet(target: target),
      );
    },
  );
}
