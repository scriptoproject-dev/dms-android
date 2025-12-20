class HelpfulContext {
  final double? date; // use double for epoch seconds
  final String? antibioticId;
  final bool? chat;
  final bool? complied;
  final String? lineTypes;
  final List<String>? lineItemsIds;
  final String? reasonId;
  final String? message;
  final String? otherDrugs;
  final String? otherDrugsReasonId;
  final String? otherDrugsMessage;
  final String? source;
  final String? category;
  final bool? helpful;
  final String? helpfulMessage;

  HelpfulContext({
    this.date,
    this.antibioticId,
    this.chat,
    this.complied,
    this.lineTypes,
    this.lineItemsIds,
    this.reasonId,
    this.message,
    this.otherDrugs,
    this.otherDrugsReasonId,
    this.otherDrugsMessage,
    this.source,
    this.category,
    this.helpful,
    this.helpfulMessage,
  });

  /// Convert to API JSON format
  Map<String, dynamic> toJson() {
    return {
      "date": date ?? DateTime.now().millisecondsSinceEpoch / 1000,
      "antibiotic_id": antibioticId,
      "chat": chat ?? true,
      "complied": complied,
      "line_types": lineTypes,
      "line_items_ids": lineItemsIds,
      "reason_id": reasonId,
      "message": message,
      "other_durgs": otherDrugs,
      "other_durgs_reason_id": otherDrugsReasonId,
      "other_durgs_message": otherDrugsMessage,
      "helpful": helpful,
      "helpful_message": helpfulMessage,
      "source": source,
      "category": category,
    };
  }

  @override
  String toString() {
    return '''
HelpfulContext(
  date: $date,
  antibioticId: $antibioticId,
  chat: $chat,
  complied: $complied,
  lineTypes: $lineTypes,
  lineItemsIds: $lineItemsIds,
  reasonId: $reasonId,
  message: $message,
  otherDrugs: $otherDrugs,
  otherDrugsReasonId: $otherDrugsReasonId,
  otherDrugsMessage: $otherDrugsMessage,
  helpful: $helpful,
  helpfulMessage: $helpfulMessage
)''';
  }
}
