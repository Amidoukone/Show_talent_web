// Local entry point used by the browser regression check.
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:show_talent/services/admin_document_service.dart';
import 'package:show_talent/utils/admin_storage_reference.dart';
import 'package:show_talent/widgets/admin_document_preview.dart';

void main() {
  final navigator = GlobalKey<NavigatorState>();
  runApp(MaterialApp(navigatorKey: navigator, home: const Scaffold()));
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    final document = AdminDocumentLink.resolved(
      bytes: Uint8List.fromList(_fixturePdf().codeUnits),
      reference: const AdminStorageReference(bucket: 'demo', objectPath: 'accord.pdf'),
    );
    globalContext['closePreview'] = (() => navigator.currentState!.pop(false)).toJS;
    final confirmed = await showAdminDocumentPreview(navigator.currentState!.overlay!.context, document);
    globalContext['previewClosed'] = (!confirmed).toJS;
  });
}

String _fixturePdf() {
  final pdf = StringBuffer('%PDF-1.4\n');
  final offsets = <int>[];
  for (final body in [
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 200] /Resources << >> >>',
  ]) {
    offsets.add(pdf.length);
    pdf.write('${offsets.length} 0 obj\n$body\nendobj\n');
  }
  final start = pdf.length;
  pdf.write('xref\n0 4\n0000000000 65535 f \n');
  for (final offset in offsets) {
    pdf.write('${offset.toString().padLeft(10, '0')} 00000 n \n');
  }
  pdf.write('trailer\n<< /Size 4 /Root 1 0 R >>\nstartxref\n$start\n%%EOF\n');
  return pdf.toString();
}
