class PrivateJournalEntry {
  final String id;
  final DateTime createdAt;
  final String kind;
  final String text;
  const PrivateJournalEntry({required this.id,required this.createdAt,required this.kind,required this.text});
  Map<String,dynamic> toJson()=>{'id':id,'createdAt':createdAt.toIso8601String(),'kind':kind,'text':text};
  factory PrivateJournalEntry.fromJson(Map<String,dynamic> json)=>PrivateJournalEntry(
    id:'${json['id']??''}',createdAt:DateTime.tryParse('${json['createdAt']}')??DateTime.fromMillisecondsSinceEpoch(0),
    kind:'${json['kind']??'Nota'}',text:'${json['text']??''}');
}
