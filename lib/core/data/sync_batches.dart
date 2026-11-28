import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:numer_app/core/data/entities.dart';

const _maxOperations = 450;

Future<void> pushInBatches<T extends SyncEntity>(
  FirebaseFirestore firestore,
  List<T> items,
  Future<void> Function(WriteBatch batch, T item) writer,
) async {
  var offset = 0;
  while (offset < items.length) {
    final slice = items.sublist(
      offset,
      min(offset + _maxOperations, items.length),
    );
    final updatedAt = [for (final item in slice) item.updatedAtMs];
    var committed = false;
    try {
      final batch = firestore.batch();
      for (final item in slice) {
        await writer(batch, item);
      }
      await batch.commit();
      committed = true;
    } finally {
      // a failed commit must leave the records dirty so sign-out keeps them
      if (!committed) {
        for (var i = 0; i < slice.length; i++) {
          slice[i]
            ..dirty = true
            ..updatedAtMs = updatedAt[i];
        }
      }
    }
    offset += slice.length;
  }
}
