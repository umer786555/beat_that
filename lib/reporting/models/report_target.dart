import 'package:equatable/equatable.dart';

enum ReportTargetType { video }

extension ReportTargetTypeLabel on ReportTargetType {
  String get label {
    switch (this) {
      case ReportTargetType.video:
        return 'Video';
    }
  }
}

class ReportTarget extends Equatable {
  const ReportTarget._({required this.type, required this.id});

  const ReportTarget.video(String id)
    : this._(type: ReportTargetType.video, id: id);

  final ReportTargetType type;
  final String id;

  @override
  List<Object?> get props => [type, id];
}
