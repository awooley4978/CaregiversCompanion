import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';
import '/backend/schema/enums/enums.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class CarechecklistRecord extends FirestoreRecord {
  CarechecklistRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "title" field.
  String? _title;
  String get title => _title ?? '';
  bool hasTitle() => _title != null;

  // "subtitle" field.
  String? _subtitle;
  String get subtitle => _subtitle ?? '';
  bool hasSubtitle() => _subtitle != null;

  // "icone_name" field.
  String? _iconeName;
  String get iconeName => _iconeName ?? '';
  bool hasIconeName() => _iconeName != null;

  // "completed" field.
  bool? _completed;
  bool get completed => _completed ?? false;
  bool hasCompleted() => _completed != null;

  // "order" field.
  int? _order;
  int get order => _order ?? 0;
  bool hasOrder() => _order != null;

  // "created_time" field.
  DateTime? _createdTime;
  DateTime? get createdTime => _createdTime;
  bool hasCreatedTime() => _createdTime != null;

  DocumentReference get parentReference => reference.parent.parent!;

  void _initializeFields() {
    _title = snapshotData['title'] as String?;
    _subtitle = snapshotData['subtitle'] as String?;
    _iconeName = snapshotData['icone_name'] as String?;
    _completed = snapshotData['completed'] as bool?;
    _order = castToType<int>(snapshotData['order']);
    _createdTime = snapshotData['created_time'] as DateTime?;
  }

  static Query<Map<String, dynamic>> collection([DocumentReference? parent]) =>
      parent != null
          ? parent.collection('carechecklist')
          : FirebaseFirestore.instance.collectionGroup('carechecklist');

  static DocumentReference createDoc(DocumentReference parent, {String? id}) =>
      parent.collection('carechecklist').doc(id);

  static Stream<CarechecklistRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => CarechecklistRecord.fromSnapshot(s));

  static Future<CarechecklistRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => CarechecklistRecord.fromSnapshot(s));

  static CarechecklistRecord fromSnapshot(DocumentSnapshot snapshot) =>
      CarechecklistRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static CarechecklistRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      CarechecklistRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'CarechecklistRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is CarechecklistRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createCarechecklistRecordData({
  String? title,
  String? subtitle,
  String? iconeName,
  bool? completed,
  int? order,
  DateTime? createdTime,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'title': title,
      'subtitle': subtitle,
      'icone_name': iconeName,
      'completed': completed,
      'order': order,
      'created_time': createdTime,
    }.withoutNulls,
  );

  return firestoreData;
}

class CarechecklistRecordDocumentEquality
    implements Equality<CarechecklistRecord> {
  const CarechecklistRecordDocumentEquality();

  @override
  bool equals(CarechecklistRecord? e1, CarechecklistRecord? e2) {
    return e1?.title == e2?.title &&
        e1?.subtitle == e2?.subtitle &&
        e1?.iconeName == e2?.iconeName &&
        e1?.completed == e2?.completed &&
        e1?.order == e2?.order &&
        e1?.createdTime == e2?.createdTime;
  }

  @override
  int hash(CarechecklistRecord? e) => const ListEquality().hash([
        e?.title,
        e?.subtitle,
        e?.iconeName,
        e?.completed,
        e?.order,
        e?.createdTime
      ]);

  @override
  bool isValidKey(Object? o) => o is CarechecklistRecord;
}
