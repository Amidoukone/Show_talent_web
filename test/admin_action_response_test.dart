import 'package:flutter_test/flutter_test.dart';
import 'package:show_talent/models/admin_action_response.dart';

void main() {
  group('AdminActionResponse', () {
    test('fromMap parses dynamic payload safely', () {
      final response = AdminActionResponse.fromMap(<String, dynamic>{
        'success': true,
        'code': 'ok',
        'message': 'done',
        'retriable': false,
        'data': <String, dynamic>{'id': '123'},
      });

      expect(response.success, true);
      expect(response.code, 'ok');
      expect(response.message, 'done');
      expect(response.data?['id'], '123');
    });

    test('failure factory sets defaults', () {
      final response = AdminActionResponse.failure(
        message: 'failed',
      );

      expect(response.success, false);
      expect(response.code, 'action_failed');
      expect(response.message, 'failed');
      expect(response.retriable, false);
    });
  });
}
