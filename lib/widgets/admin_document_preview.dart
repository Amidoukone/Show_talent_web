import 'package:flutter/material.dart';
import '../services/admin_document_service.dart';
import 'private_pdf_stub.dart'
    if (dart.library.js_interop) 'private_pdf_web.dart';

Future<bool> showAdminDocumentPreview(
  BuildContext context,
  AdminDocumentLink document,
) async {
  return await showDialog<bool>(
        context: context,
        builder: (_) => _Preview(document),
      ) ??
      false;
}

class _Preview extends StatefulWidget {
  const _Preview(this.document);
  final AdminDocumentLink document;
  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  bool imageReady = false;
  late final image = MemoryImage(widget.document.bytes!);

  @override
  void dispose() {
    if (widget.document.reference!.looksLikeImage) image.evict();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final file = widget.document.reference!;
    final bytes = widget.document.bytes!;
    final pdf =
        file.extension == 'pdf' &&
        supportsPrivatePdf &&
        bytes.length >= 5 &&
        String.fromCharCodes(bytes.take(5)) == '%PDF-';
    final Widget content;
    if (pdf) {
      content = PrivatePdf(bytes);
    } else if (file.looksLikeImage) {
      content = InteractiveViewer(
        child: Image(
          image: image,
          fit: BoxFit.contain,
          frameBuilder: (context, child, frame, synchronous) {
            if (frame != null && !imageReady) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && !imageReady) setState(() => imageReady = true);
              });
            }
            return child;
          },
          errorBuilder: (_, _, _) =>
              const Center(child: Text('Image illisible.')),
        ),
      );
    } else {
      content = const Center(
        child: Text('Aperçu indisponible pour ce document sur ce navigateur.'),
      );
    }
    return AlertDialog(
      title: Text(file.fileName),
      content: SizedBox(
        width: 900,
        height: MediaQuery.sizeOf(context).height * .65,
        child: content,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Fermer'),
        ),
        FilledButton(
          onPressed: pdf || imageReady
              ? () => Navigator.pop(context, true)
              : null,
          child: const Text('Pièce consultée'),
        ),
      ],
    );
  }
}
