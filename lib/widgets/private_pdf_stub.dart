import 'dart:typed_data';
import 'package:flutter/widgets.dart';

bool get supportsPrivatePdf => false;

class PrivatePdf extends StatelessWidget {
  const PrivatePdf(Uint8List bytes, {super.key});
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
