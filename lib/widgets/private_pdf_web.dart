import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

@JS('Blob')
extension type _Blob._(JSObject _) implements JSObject {
  external factory _Blob(JSArray<JSAny> parts, JSObject options);
}
@JS()
@anonymous
extension type _Options._(JSObject _) implements JSObject {
  external factory _Options({String type});
}
@JS('URL.createObjectURL')
external String _createUrl(_Blob blob);
@JS('URL.revokeObjectURL')
external void _revokeUrl(String url);
@JS('navigator.pdfViewerEnabled')
external bool? get _pdfViewerEnabled;
bool get supportsPrivatePdf => _pdfViewerEnabled != false;

extension type _ObjectElement._(JSObject _) implements JSObject {
  external set type(String value);
  external set data(String value);
  external set textContent(String value);
  external void setAttribute(String name, String value);
}

class PrivatePdf extends StatefulWidget {
  const PrivatePdf(this.bytes, {super.key});
  final Uint8List bytes;
  @override
  State<PrivatePdf> createState() => _PrivatePdfState();
}

class _PrivatePdfState extends State<PrivatePdf> {
  late final String _url = _createUrl(
    _Blob(<JSAny>[widget.bytes.toJS].toJS, _Options(type: 'application/pdf')),
  );

  @override
  Widget build(BuildContext context) => HtmlElementView.fromTagName(
    tagName: 'object',
    onElementCreated: (node) {
      _ObjectElement._(node as JSObject)
        ..type = 'application/pdf'
        ..setAttribute('aria-label', 'Document PDF')
        ..setAttribute('style', 'width:100%;height:100%')
        ..textContent = 'Ce navigateur ne peut pas afficher le PDF.'
        ..data = _url;
    },
  );

  @override
  void dispose() {
    _revokeUrl(_url);
    super.dispose();
  }
}
