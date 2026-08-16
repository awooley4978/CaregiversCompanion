import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';
import '/backend/schema/enums/enums.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class IconnameRecord extends FirestoreRecord {
  IconnameRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "water" field.
  String? _water;
  String get water => _water ?? '';
  bool hasWater() => _water != null;

  // "pill" field.
  String? _pill;
  String get pill => _pill ?? '';
  bool hasPill() => _pill != null;

  // "food" field.
  String? _food;
  String get food => _food ?? '';
  bool hasFood() => _food != null;

  // "exercise" field.
  String? _exercise;
  String get exercise => _exercise ?? '';
  bool hasExercise() => _exercise != null;

  // "general" field.
  String? _general;
  String get general => _general ?? '';
  bool hasGeneral() => _general != null;

  // "bathroom" field.
  String? _bathroom;
  String get bathroom => _bathroom ?? '';
  bool hasBathroom() => _bathroom != null;

  // "sleep" field.
  String? _sleep;
  String get sleep => _sleep ?? '';
  bool hasSleep() => _sleep != null;

  void _initializeFields() {
    _water = snapshotData['water'] as String?;
    _pill = snapshotData['pill'] as String?;
    _food = snapshotData['food'] as String?;
    _exercise = snapshotData['exercise'] as String?;
    _general = snapshotData['general'] as String?;
    _bathroom = snapshotData['bathroom'] as String?;
    _sleep = snapshotData['sleep'] as String?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('iconname');

  static Stream<IconnameRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => IconnameRecord.fromSnapshot(s));

  static Future<IconnameRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => IconnameRecord.fromSnapshot(s));

  static IconnameRecord fromSnapshot(DocumentSnapshot snapshot) =>
      IconnameRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static IconnameRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      IconnameRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'IconnameRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is IconnameRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createIconnameRecordData({
  String? water,
  String? pill,
  String? food,
  String? exercise,
  String? general,
  String? bathroom,
  String? sleep,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'water': water,
      'pill': pill,
      'food': food,
      'exercise': exercise,
      'general': general,
      'bathroom': bathroom,
      'sleep': sleep,
    }.withoutNulls,
  );

  return firestoreData;
}

class IconnameRecordDocumentEquality implements Equality<IconnameRecord> {
  const IconnameRecordDocumentEquality();

  @override
  bool equals(IconnameRecord? e1, IconnameRecord? e2) {
    return e1?.water == e2?.water &&
        e1?.pill == e2?.pill &&
        e1?.food == e2?.food &&
        e1?.exercise == e2?.exercise &&
        e1?.general == e2?.general &&
        e1?.bathroom == e2?.bathroom &&
        e1?.sleep == e2?.sleep;
  }

  @override
  int hash(IconnameRecord? e) => const ListEquality().hash([
        e?.water,
        e?.pill,
        e?.food,
        e?.exercise,
        e?.general,
        e?.bathroom,
        e?.sleep
      ]);

  @override
  bool isValidKey(Object? o) => o is IconnameRecord;
}
