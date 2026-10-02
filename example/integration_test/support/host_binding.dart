import 'dart:async';
import 'dart:convert';

import 'package:integration_test/integration_test.dart';

class HostBinding extends IntegrationTestWidgetsFlutterBinding {
  int _sequence = 0;
  Map<String, Object?>? _request;
  Completer<Map<String, dynamic>>? _reply;

  Future<Map<String, dynamic>> hostCommand(String command) async {
    if (_request != null) throw StateError('A host command is already pending');
    final reply = Completer<Map<String, dynamic>>();
    _reply = reply;
    _request = {'id': ++_sequence, 'command': command};
    try {
      return await reply.future.timeout(
        const Duration(seconds: 45),
        onTimeout: () => throw TimeoutException(
          'Host command $command timed out. Run tool/run_android_integration.dart '
          'so the Dart ADB driver is connected.',
        ),
      );
    } finally {
      _request = null;
      _reply = null;
    }
  }

  @override
  Future<Map<String, dynamic>> callback(Map<String, String> params) async {
    final message = params['message'] ?? '';
    if (params['command'] != 'request_data' || !message.startsWith('host:')) {
      return super.callback(params);
    }
    Object response;
    if (message == 'host:next') {
      response =
          _request ??
          {'done': allTestsPassed.isCompleted, 'testCount': results.length};
    } else if (message.startsWith('host:reply:')) {
      final data =
          jsonDecode(message.substring('host:reply:'.length))
              as Map<String, dynamic>;
      if (data['id'] != _request?['id'] ||
          _reply == null ||
          _reply!.isCompleted) {
        throw StateError('Unexpected host response: $data');
      }
      if (data['error'] != null) {
        _reply!.completeError(StateError('ADB driver: ${data['error']}'));
      } else {
        _reply!.complete((data['data'] as Map).cast<String, dynamic>());
      }
      response = {'ack': true};
    } else {
      throw StateError('Unknown host message: $message');
    }
    return {
      'isError': false,
      'response': {'message': jsonEncode(response)},
    };
  }
}
