import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'sip/sip_account.dart';
import 'sip/sip_call.dart';
import 'sip/sip_controller.dart';
import 'sip/sip_event.dart';
import 'sip/sip_method_channel_controller.dart';
import 'sip/sip_profile_store.dart';

void main() {
  runApp(const SipTalkApp());
}

class SipTalkApp extends StatelessWidget {
  const SipTalkApp({this.controller, super.key});

  final SipController? controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff16685a)),
        useMaterial3: true,
      ),
      home: SipHomePage(controller: controller ?? SipMethodChannelController()),
    );
  }
}

class SipHomePage extends StatefulWidget {
  const SipHomePage({
    required this.controller,
    this.profileStore = const SipProfileStore(),
    super.key,
  });

  final SipController controller;
  final SipProfileStore profileStore;

  @override
  State<SipHomePage> createState() => _SipHomePageState();
}

class _SipHomePageState extends State<SipHomePage> {
  final _destinationController = TextEditingController();
  final _events = <String>[];

  SipProfile _profile = const SipProfile.defaults();
  SipAccountState _registrationState = SipAccountState.unconfigured;
  SipAudioRoute _route = SipAudioRoute.receiver;
  SipCallInfo? _activeCall;
  final _pendingIncomingCallIds = <String>{};
  Timer? _callTimer;
  int _callElapsedSeconds = 0;
  bool _profileLoaded = false;
  bool _coreReady = false;
  bool _autoRegisterStarted = false;
  bool _incomingCallScreenOpen = false;

  @override
  void initState() {
    super.initState();
    _destinationController.text = _profile.destination;
    _loadProfile();
    widget.controller.events.listen(_handleEvent);
    widget.controller.initialize();
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _destinationController.dispose();
    widget.controller.shutdown();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final profile = await widget.profileStore.load();
    if (!mounted) {
      return;
    }
    setState(() {
      _profile = profile;
      _route = profile.defaultAudioRoute;
      _destinationController.text = profile.destination;
      _profileLoaded = true;
      _registrationState = _canRegister(profile)
          ? SipAccountState.configured
          : SipAccountState.unconfigured;
    });
    await widget.controller.setAudioRoute(profile.defaultAudioRoute);
    await _maybeAutoRegister();
  }

  Future<void> _saveProfile(SipProfile profile) async {
    await widget.profileStore.save(profile);
    if (!mounted) {
      return;
    }
    setState(() {
      _profile = profile;
      _route = profile.defaultAudioRoute;
      _destinationController.text = profile.destination;
      _registrationState = _canRegister(profile)
          ? SipAccountState.configured
          : SipAccountState.unconfigured;
      _autoRegisterStarted = false;
    });
    await widget.controller.setAudioRoute(profile.defaultAudioRoute);
    await _maybeAutoRegister();
  }

  Future<void> _maybeAutoRegister() async {
    if (!_profileLoaded ||
        !_coreReady ||
        _autoRegisterStarted ||
        !_canRegister(_profile)) {
      return;
    }
    _autoRegisterStarted = true;
    await _registerCurrentProfile();
  }

  Future<void> _registerCurrentProfile() async {
    setState(() => _registrationState = SipAccountState.registering);
    try {
      await widget.controller.createAccount(
        SipAccountConfig(
          id: 'default',
          displayName: _profile.username,
          domain: _profile.domain.trim(),
          username: _profile.username.trim(),
          password: _profile.password,
          authUsername: _emptyToNull(_profile.authUsername.trim()),
          proxy: _emptyToNull(_profile.proxy.trim()),
          transport: _profile.transport,
          registrationExpiresSeconds:
              int.tryParse(_profile.expires.trim()) ?? 300,
        ),
      );
      await widget.controller.registerAccount('default');
    } on PlatformException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _registrationState = SipAccountState.registrationFailed;
        _events.insert(
          0,
          'Registration failed: ${error.message ?? error.code}',
        );
      });
    }
  }

  bool _canRegister(SipProfile profile) {
    return profile.domain.trim().isNotEmpty &&
        profile.username.trim().isNotEmpty &&
        profile.password.isNotEmpty;
  }

  void _handleEvent(SipEvent event) {
    setState(() {
      switch (event) {
        case SipCoreReady():
          _coreReady = true;
          _events.insert(0, 'Core ready');
        case SipCoreFailed(:final message):
          _events.insert(0, 'Core failed: $message');
        case SipAccountRegistrationChanged(
          :final accountId,
          :final state,
          :final reason,
          :final statusCode,
        ):
          _registrationState = state;
          final details = [
            if (statusCode != null) statusCode.toString(),
            if (reason != null && reason.isNotEmpty) reason,
          ].join(' ');
          _events.insert(
            0,
            details.isEmpty
                ? 'Account $accountId: ${state.name}'
                : 'Account $accountId: ${state.name} - $details',
          );
        case SipIncomingCall(:final call):
          _pendingIncomingCallIds.add(call.id);
          _activeCall = call;
          _events.insert(
            0,
            'Incoming call: ${call.displayName ?? call.remoteUri ?? call.id}',
          );
        case SipCallStateChanged(:final call):
          if (_isTerminalCallState(call.state)) {
            _pendingIncomingCallIds.remove(call.id);
            _activeCall = null;
            _stopCallTimer();
          } else if (_pendingIncomingCallIds.contains(call.id) &&
              call.state != SipCallState.inCall) {
            _activeCall = call.copyWith(state: SipCallState.incomingSip);
          } else {
            _pendingIncomingCallIds.remove(call.id);
            _activeCall = call;
            if (call.state == SipCallState.inCall) {
              _startCallTimer();
            }
          }
          final details = [
            if (call.statusCode != null) call.statusCode.toString(),
            if (call.failureReason != null && call.failureReason!.isNotEmpty)
              call.failureReason!,
            if (call.remoteUri != null && call.remoteUri!.isNotEmpty)
              call.remoteUri!,
          ].join(' ');
          _events.insert(
            0,
            details.isEmpty
                ? 'Call ${call.id}: ${call.state.name}'
                : 'Call ${call.id}: ${call.state.name} - $details',
          );
        case SipAudioRouteChanged(:final route):
          _route = route;
          _events.insert(0, 'Audio route: ${route.name}');
        case SipDiagnosticLog(:final level, :final message):
          _events.insert(0, '[$level] $message');
      }
    });
    switch (event) {
      case SipIncomingCall(:final call):
        _showIncomingCallScreen(call);
      case SipCallStateChanged(:final call):
        if (_isTerminalCallState(call.state) ||
            call.state == SipCallState.inCall) {
          _dismissIncomingCallScreen();
        }
      default:
    }
    _maybeAutoRegister();
  }

  Future<void> _call() async {
    final destination = _destinationController.text.trim();
    if (destination.isEmpty) {
      setState(() => _events.insert(0, 'Call failed: missing destination'));
      return;
    }
    await _saveProfile(_profile.copyWith(destination: destination));
    try {
      final callId = await widget.controller.makeCall(
        accountId: 'default',
        destination: destination,
      );
      setState(() {
        _activeCall = SipCallInfo(
          id: callId,
          accountId: 'default',
          state: SipCallState.calling,
          remoteUri: destination,
        );
      });
    } on PlatformException catch (error) {
      setState(
        () => _events.insert(0, 'Call failed: ${error.message ?? error.code}'),
      );
    }
  }

  Future<void> _hangup() async {
    final call = _activeCall;
    if (call == null) {
      return;
    }
    _pendingIncomingCallIds.remove(call.id);
    await widget.controller.hangupCall(call.id);
    _stopCallTimer();
    if (mounted) {
      setState(() => _activeCall = null);
    }
  }

  Future<void> _answer() async {
    final call = _activeCall;
    if (call == null) {
      return;
    }
    await _answerCall(call);
  }

  Future<void> _answerCall(SipCallInfo call) async {
    try {
      _pendingIncomingCallIds.remove(call.id);
      await widget.controller.answerCall(call.id);
      _dismissIncomingCallScreen();
    } on PlatformException catch (error) {
      setState(
        () =>
            _events.insert(0, 'Answer failed: ${error.message ?? error.code}'),
      );
    }
  }

  Future<void> _reject() async {
    final call = _activeCall;
    if (call == null) {
      return;
    }
    await _rejectCall(call);
  }

  Future<void> _rejectCall(SipCallInfo call) async {
    try {
      _pendingIncomingCallIds.remove(call.id);
      await widget.controller.rejectCall(call.id);
      _dismissIncomingCallScreen();
      if (mounted) {
        setState(() => _activeCall = null);
      }
    } on PlatformException catch (error) {
      setState(
        () =>
            _events.insert(0, 'Reject failed: ${error.message ?? error.code}'),
      );
    }
  }

  Future<void> _toggleSpeaker() async {
    final next = _route == SipAudioRoute.speaker
        ? SipAudioRoute.receiver
        : SipAudioRoute.speaker;
    await widget.controller.setAudioRoute(next);
  }

  Future<void> _openSettings() async {
    final updated = await Navigator.of(context).push<SipProfile>(
      MaterialPageRoute(builder: (_) => SipSettingsPage(profile: _profile)),
    );
    if (updated != null) {
      await _saveProfile(updated);
    }
  }

  String? _emptyToNull(String value) => value.isEmpty ? null : value;

  bool _isIncomingCallState(SipCallState state) {
    return state == SipCallState.incomingSip ||
        state == SipCallState.incomingPush ||
        state == SipCallState.ringing;
  }

  bool _isTerminalCallState(SipCallState state) {
    return state == SipCallState.ended || state == SipCallState.failed;
  }

  bool _isEstablishedOrConnectingCall(SipCallInfo? call) {
    return switch (call?.state) {
      SipCallState.calling ||
      SipCallState.connecting ||
      SipCallState.inCall ||
      SipCallState.held ||
      SipCallState.reconnecting ||
      SipCallState.terminating => true,
      _ => false,
    };
  }

  void _startCallTimer() {
    if (_callTimer != null) {
      return;
    }
    _callElapsedSeconds = 0;
    _callTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _callElapsedSeconds += 1);
      }
    });
  }

  void _stopCallTimer() {
    _callTimer?.cancel();
    _callTimer = null;
    _callElapsedSeconds = 0;
  }

  String _callDurationText() {
    final minutes = (_callElapsedSeconds ~/ 60)
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    final seconds = (_callElapsedSeconds % 60).toString().padLeft(2, '0');
    final hours = _callElapsedSeconds ~/ 3600;
    if (hours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  void _showIncomingCallScreen(SipCallInfo call) {
    if (_incomingCallScreenOpen || !mounted) {
      debugPrint(
        'SipTalk incoming call screen skipped: open=$_incomingCallScreenOpen mounted=$mounted call=${call.id}',
      );
      return;
    }
    _incomingCallScreenOpen = true;
    debugPrint('SipTalk incoming call screen scheduled: ${call.id}');
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        _incomingCallScreenOpen = false;
        debugPrint('SipTalk incoming call screen cancelled: widget unmounted');
        return;
      }
      final activeCall = _activeCall;
      if (activeCall?.id != call.id ||
          activeCall == null ||
          !_isIncomingCallState(activeCall.state)) {
        _incomingCallScreenOpen = false;
        debugPrint(
          'SipTalk incoming call screen cancelled: active=${activeCall?.id}/${activeCall?.state.name}',
        );
        return;
      }
      debugPrint('SipTalk incoming call screen showing: ${call.id}');
      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierLabel: 'Incoming call',
        transitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (dialogContext, _, _) => IncomingCallScreen(
          call: call,
          onAnswer: () => _answerCall(call),
          onReject: () => _rejectCall(call),
        ),
        transitionBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      );
      debugPrint('SipTalk incoming call screen closed: ${call.id}');
      _incomingCallScreenOpen = false;
    });
  }

  void _dismissIncomingCallScreen() {
    if (!_incomingCallScreenOpen || !mounted) {
      return;
    }
    debugPrint('SipTalk incoming call screen dismiss requested');
    Navigator.of(context, rootNavigator: true).maybePop();
    _incomingCallScreenOpen = false;
  }

  @override
  Widget build(BuildContext context) {
    final status = _statusView(_registrationState);
    final registeredNumber = _profile.username.trim().isEmpty
        ? 'Not configured'
        : _profile.username.trim();
    final activeCall = _activeCall;
    final showCallPanel = _isEstablishedOrConnectingCall(activeCall);
    return Scaffold(
      appBar: AppBar(
        title: const Text('SipTalk'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: _openSettings,
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(status.icon, color: status.color),
                          const SizedBox(width: 8),
                          Text(
                            status.label,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        registeredNumber,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _profile.domain,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (showCallPanel && activeCall != null)
                ActiveCallPanel(
                  call: activeCall,
                  duration: _callDurationText(),
                  route: _route,
                  onToggleSpeaker: _toggleSpeaker,
                  onHangup: _hangup,
                )
              else ...[
                TextField(
                  controller: _destinationController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Dial number',
                    prefixIcon: Icon(Icons.dialpad),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _call,
                        icon: const Icon(Icons.call),
                        label: const Text('Call'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      tooltip: _route == SipAudioRoute.speaker
                          ? 'Speaker'
                          : 'Receiver',
                      onPressed: _toggleSpeaker,
                      icon: Icon(
                        _route == SipAudioRoute.speaker
                            ? Icons.volume_up
                            : Icons.hearing,
                      ),
                    ),
                  ],
                ),
              ],
              if (_activeCall?.state == SipCallState.incomingSip ||
                  _activeCall?.state == SipCallState.incomingPush) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _answer,
                        icon: const Icon(Icons.call_received),
                        label: const Text('Answer'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: _reject,
                        icon: const Icon(Icons.phone_disabled),
                        label: const Text('Reject'),
                      ),
                    ),
                  ],
                ),
              ],
              if (!_profileLoaded) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(minHeight: 2),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RegistrationStatusView {
  const _RegistrationStatusView({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;
}

_RegistrationStatusView _statusView(SipAccountState state) {
  return switch (state) {
    SipAccountState.registered => const _RegistrationStatusView(
      label: 'Registered',
      icon: Icons.check_circle,
      color: Color(0xff147d4f),
    ),
    SipAccountState.registering => const _RegistrationStatusView(
      label: 'Registering',
      icon: Icons.sync,
      color: Color(0xff8a5a00),
    ),
    SipAccountState.registrationFailed => const _RegistrationStatusView(
      label: 'Registration failed',
      icon: Icons.error,
      color: Color(0xffb3261e),
    ),
    SipAccountState.configured => const _RegistrationStatusView(
      label: 'Ready to register',
      icon: Icons.radio_button_checked,
      color: Color(0xff4d6374),
    ),
    SipAccountState.pushReachable => const _RegistrationStatusView(
      label: 'Push reachable',
      icon: Icons.notifications_active,
      color: Color(0xff147d4f),
    ),
    SipAccountState.offline => const _RegistrationStatusView(
      label: 'Offline',
      icon: Icons.cloud_off,
      color: Color(0xff6b7280),
    ),
    SipAccountState.unconfigured => const _RegistrationStatusView(
      label: 'Account not configured',
      icon: Icons.info,
      color: Color(0xff6b7280),
    ),
  };
}

class ActiveCallPanel extends StatelessWidget {
  const ActiveCallPanel({
    required this.call,
    required this.duration,
    required this.route,
    required this.onToggleSpeaker,
    required this.onHangup,
    super.key,
  });

  final SipCallInfo call;
  final String duration;
  final SipAudioRoute route;
  final VoidCallback onToggleSpeaker;
  final VoidCallback onHangup;

  @override
  Widget build(BuildContext context) {
    final remote = call.displayName?.trim().isNotEmpty == true
        ? call.displayName!.trim()
        : call.remoteUri?.trim().isNotEmpty == true
        ? call.remoteUri!.trim()
        : 'Unknown';
    final stateLabel = switch (call.state) {
      SipCallState.calling => 'Calling',
      SipCallState.connecting => 'Connecting',
      SipCallState.inCall => 'In call',
      SipCallState.held => 'On hold',
      SipCallState.reconnecting => 'Reconnecting',
      SipCallState.terminating => 'Ending',
      _ => 'Call',
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              remote,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              stateLabel,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Text(
              duration,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filledTonal(
                  tooltip: route == SipAudioRoute.speaker
                      ? 'Speaker'
                      : 'Receiver',
                  onPressed: onToggleSpeaker,
                  icon: Icon(
                    route == SipAudioRoute.speaker
                        ? Icons.volume_up
                        : Icons.hearing,
                  ),
                ),
                const SizedBox(width: 16),
                IconButton.filled(
                  tooltip: 'Hang up',
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                  ),
                  onPressed: onHangup,
                  icon: const Icon(Icons.call_end),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class IncomingCallScreen extends StatelessWidget {
  const IncomingCallScreen({
    required this.call,
    required this.onAnswer,
    required this.onReject,
    super.key,
  });

  final SipCallInfo call;
  final Future<void> Function() onAnswer;
  final Future<void> Function() onReject;

  @override
  Widget build(BuildContext context) {
    final caller = call.displayName?.trim().isNotEmpty == true
        ? call.displayName!.trim()
        : call.remoteUri?.trim().isNotEmpty == true
        ? call.remoteUri!.trim()
        : 'Unknown caller';
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              CircleAvatar(
                radius: 48,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Icon(
                  Icons.person,
                  size: 56,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Incoming call',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(
                caller,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
                      onPressed: () async {
                        await onReject();
                      },
                      icon: const Icon(Icons.call_end),
                      label: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () async {
                        await onAnswer();
                      },
                      icon: const Icon(Icons.call),
                      label: const Text('Answer'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SipSettingsPage extends StatefulWidget {
  const SipSettingsPage({required this.profile, super.key});

  final SipProfile profile;

  @override
  State<SipSettingsPage> createState() => _SipSettingsPageState();
}

class _SipSettingsPageState extends State<SipSettingsPage> {
  late final TextEditingController _domainController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _authUsernameController;
  late final TextEditingController _proxyController;
  late final TextEditingController _expiresController;
  late final TextEditingController _destinationController;
  late SipTransport _transport;
  late SipAudioRoute _defaultAudioRoute;

  @override
  void initState() {
    super.initState();
    _domainController = TextEditingController(text: widget.profile.domain);
    _usernameController = TextEditingController(text: widget.profile.username);
    _passwordController = TextEditingController(text: widget.profile.password);
    _authUsernameController = TextEditingController(
      text: widget.profile.authUsername,
    );
    _proxyController = TextEditingController(text: widget.profile.proxy);
    _expiresController = TextEditingController(text: widget.profile.expires);
    _destinationController = TextEditingController(
      text: widget.profile.destination,
    );
    _transport = widget.profile.transport;
    _defaultAudioRoute = widget.profile.defaultAudioRoute;
  }

  @override
  void dispose() {
    _domainController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _authUsernameController.dispose();
    _proxyController.dispose();
    _expiresController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  void _save() {
    Navigator.of(context).pop(
      SipProfile(
        domain: _domainController.text.trim(),
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        authUsername: _authUsernameController.text.trim(),
        proxy: _proxyController.text.trim(),
        transport: _transport,
        expires: _expiresController.text.trim(),
        destination: _destinationController.text.trim(),
        defaultAudioRoute: _defaultAudioRoute,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          TextButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('Save'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(16),
          children: [
            Text('SIP account', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _domainController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'SIP domain',
                prefixIcon: Icon(Icons.dns),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'SIP number',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.key),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _authUsernameController,
              decoration: const InputDecoration(
                labelText: 'Auth user',
                prefixIcon: Icon(Icons.badge),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _proxyController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Outbound proxy',
                prefixIcon: Icon(Icons.route),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<SipTransport>(
                    initialValue: _transport,
                    decoration: const InputDecoration(
                      labelText: 'Transport',
                      prefixIcon: Icon(Icons.settings_ethernet),
                      border: OutlineInputBorder(),
                    ),
                    items: SipTransport.values
                        .map(
                          (transport) => DropdownMenuItem(
                            value: transport,
                            child: Text(transport.name.toUpperCase()),
                          ),
                        )
                        .toList(),
                    onChanged: (transport) {
                      if (transport != null) {
                        setState(() => _transport = transport);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _expiresController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Expires',
                      prefixIcon: Icon(Icons.timer),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Calling', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _destinationController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Default dial number',
                prefixIcon: Icon(Icons.dialpad),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            Text('Audio', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            DropdownButtonFormField<SipAudioRoute>(
              initialValue: _defaultAudioRoute,
              decoration: const InputDecoration(
                labelText: 'Default audio route',
                prefixIcon: Icon(Icons.volume_up),
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: SipAudioRoute.receiver,
                  child: Text('Receiver'),
                ),
                DropdownMenuItem(
                  value: SipAudioRoute.speaker,
                  child: Text('Speaker'),
                ),
                DropdownMenuItem(
                  value: SipAudioRoute.wiredHeadset,
                  child: Text('Wired headset'),
                ),
                DropdownMenuItem(
                  value: SipAudioRoute.bluetooth,
                  child: Text('Bluetooth'),
                ),
              ],
              onChanged: (route) {
                if (route != null) {
                  setState(() => _defaultAudioRoute = route);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
