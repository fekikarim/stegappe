import 'package:equatable/equatable.dart';

/// One assistant conversation row. Local-only persistence (T11): the
/// participant path has no server history endpoint, so the conversation
/// survives restarts in device storage keyed by user id and is wiped on
/// logout. Never sent anywhere except as display state.
class AssistantMessage extends Equatable {
  const AssistantMessage({
    required this.mine,
    required this.text,
    this.failed = false,
  });

  final bool mine;
  final String text;

  /// True when the answer request failed: the row renders with a retry
  /// affordance instead of pretending an answer arrived.
  final bool failed;

  Map<String, dynamic> toJson() => {
        'mine': mine,
        'text': text,
        'failed': failed,
      };

  factory AssistantMessage.fromJson(Map<String, dynamic> json) =>
      AssistantMessage(
        mine: json['mine'] == true,
        text: (json['text'] ?? '').toString(),
        failed: json['failed'] == true,
      );

  @override
  List<Object?> get props => [mine, text, failed];
}
