import 'dart:async';

import 'package:flutter/services.dart';

import 'sip_account.dart';
import 'sip_call.dart';
import 'sip_controller.dart';
import 'sip_event.dart';

class SipMethodChannelController implements SipController {
  SipMethodChannelController({
    MethodChannel? commandChannel,
    EventChannel? eventChannel,
  }) : _commandChannel =
           commandChannel ?? const MethodChannel('siptalk/sip_commands'),
       _eventChannel = eventChannel ?? const EventChannel('siptalk/sip_events');

  final MethodChannel _commandChannel;
  final EventChannel _eventChannel;
  final _events = StreamController<SipEvent>.broadcast();
  StreamSubscription<dynamic>? _nativeEvents;

  @override
  Stream<SipEvent> get events => _events.stream;

  @override
  Future<void> initialize() async {
    _nativeEvents ??= _eventChannel.receiveBroadcastStream().listen(
      _handleNativeEvent,
      onError: (Object error) {
        _events.add(SipCoreFailed(error.toString()));
      },
    );
    await _commandChannel.invokeMethod<void>('initialize');
  }

  @override
  Future<void> shutdown() async {
    await _commandChannel.invokeMethod<void>('shutdown');
    await _nativeEvents?.cancel();
    _nativeEvents = null;
    await _events.close();
  }

  @override
  Future<void> createAccount(SipAccountConfig config) {
    return _commandChannel.invokeMethod<void>('createAccount', {
      'id': config.id,
      'displayName': config.displayName,
      'domain': config.domain,
      'username': config.username,
      'password': config.password,
      'authUsername': config.authUsername,
      'proxy': config.proxy,
      'transport': config.transport.name,
      'registrationExpiresSeconds': config.registrationExpiresSeconds,
    });
  }

  @override
  Future<void> registerAccount(String accountId) {
    return _commandChannel.invokeMethod<void>('registerAccount', {
      'accountId': accountId,
    });
  }

  @override
  Future<void> unregisterAccount(String accountId) {
    return _commandChannel.invokeMethod<void>('unregisterAccount', {
      'accountId': accountId,
    });
  }

  @override
  Future<String> makeCall({
    required String accountId,
    required String destination,
  }) async {
    final callId = await _commandChannel.invokeMethod<String>('makeCall', {
      'accountId': accountId,
      'destination': destination,
    });
    return callId!;
  }

  @override
  Future<void> answerCall(String callId) {
    return _callCommand('answerCall', callId);
  }

  @override
  Future<void> rejectCall(String callId) {
    return _callCommand('rejectCall', callId);
  }

  @override
  Future<void> hangupCall(String callId) {
    return _callCommand('hangupCall', callId);
  }

  @override
  Future<void> holdCall(String callId) {
    return _callCommand('holdCall', callId);
  }

  @override
  Future<void> resumeCall(String callId) {
    return _callCommand('resumeCall', callId);
  }

  @override
  Future<void> sendDtmf({required String callId, required String digits}) {
    return _commandChannel.invokeMethod<void>('sendDtmf', {
      'callId': callId,
      'digits': digits,
    });
  }

  @override
  Future<void> setMuted({required String callId, required bool muted}) {
    return _commandChannel.invokeMethod<void>('setMuted', {
      'callId': callId,
      'muted': muted,
    });
  }

  @override
  Future<void> setAudioRoute(SipAudioRoute route) {
    return _commandChannel.invokeMethod<void>('setAudioRoute', {
      'route': route.name,
    });
  }

  Future<void> _callCommand(String command, String callId) {
    return _commandChannel.invokeMethod<void>(command, {'callId': callId});
  }

  void _handleNativeEvent(Object? rawEvent) {
    if (rawEvent is! Map) {
      _events.add(
        SipDiagnosticLog(
          level: 'warning',
          message: 'Dropped malformed native event',
        ),
      );
      return;
    }

    final event = Map<String, Object?>.from(rawEvent);
    final type = event['type'] as String?;

    switch (type) {
      case 'CoreReady':
        _events.add(const SipCoreReady());
      case 'CoreFailed':
        _events.add(
          SipCoreFailed(
            (event['message'] as String?) ?? 'Unknown native error',
          ),
        );
      case 'AccountRegistrationChanged':
        _events.add(
          SipAccountRegistrationChanged(
            accountId: (event['accountId'] as String?) ?? '',
            state: _accountState((event['state'] as String?) ?? ''),
            reason: event['reason'] as String?,
            statusCode: _intValue(event['statusCode']),
          ),
        );
      case 'IncomingCall':
        _events.add(SipIncomingCall(_callInfo(event)));
      case 'CallStateChanged':
        _events.add(SipCallStateChanged(_callInfo(event)));
      case 'AudioRouteChanged':
        _events.add(
          SipAudioRouteChanged(
            _audioRoute((event['route'] as String?) ?? 'receiver'),
          ),
        );
      case 'DiagnosticLog':
        _events.add(
          SipDiagnosticLog(
            level: (event['level'] as String?) ?? 'info',
            message: (event['message'] as String?) ?? '',
            accountId: event['accountId'] as String?,
            callId: event['callId'] as String?,
          ),
        );
      default:
        _events.add(
          SipDiagnosticLog(
            level: 'debug',
            message: 'Native event: ${type ?? 'unknown'}',
            accountId: event['accountId'] as String?,
            callId: event['callId'] as String?,
          ),
        );
    }
  }

  SipCallInfo _callInfo(Map<String, Object?> event) {
    return SipCallInfo(
      id: (event['callId'] as String?) ?? '',
      accountId: (event['accountId'] as String?) ?? '',
      state: _callState((event['state'] as String?) ?? ''),
      remoteUri: event['remoteUri'] as String?,
      displayName: event['displayName'] as String?,
      failureReason: event['reason'] as String?,
      statusCode: _intValue(event['statusCode']),
    );
  }

  SipAccountState _accountState(String value) {
    return SipAccountState.values.firstWhere(
      (state) => state.name.toLowerCase() == value.toLowerCase(),
      orElse: () => SipAccountState.offline,
    );
  }

  SipCallState _callState(String value) {
    return SipCallState.values.firstWhere(
      (state) => state.name.toLowerCase() == value.toLowerCase(),
      orElse: () => SipCallState.failed,
    );
  }

  SipAudioRoute _audioRoute(String value) {
    return SipAudioRoute.values.firstWhere(
      (route) => route.name.toLowerCase() == value.toLowerCase(),
      orElse: () => SipAudioRoute.receiver,
    );
  }

  int? _intValue(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }
}
