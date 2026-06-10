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
  final _domainController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authUsernameController = TextEditingController();
  final _proxyController = TextEditingController();
  final _expiresController = TextEditingController();
  final _destinationController = TextEditingController();
  final _events = <String>[];
  final _profileSaveListeners = <TextEditingController, VoidCallback>{};
  String? _activeCallId;
  SipAudioRoute _route = SipAudioRoute.receiver;
  SipTransport _transport = SipTransport.udp;
  bool _profileLoaded = false;
  bool _applyingProfile = false;

  @override
  void initState() {
    super.initState();
    _applyProfile(const SipProfile.defaults());
    _installProfileSaveListeners();
    _loadProfile();
    widget.controller.events.listen(_handleEvent);
    widget.controller.initialize();
  }

  @override
  void dispose() {
    for (final entry in _profileSaveListeners.entries) {
      entry.key.removeListener(entry.value);
    }
    _domainController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _authUsernameController.dispose();
    _proxyController.dispose();
    _expiresController.dispose();
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
      _applyProfile(profile);
      _profileLoaded = true;
    });
  }

  void _applyProfile(SipProfile profile) {
    _applyingProfile = true;
    _domainController.text = profile.domain;
    _usernameController.text = profile.username;
    _passwordController.text = profile.password;
    _authUsernameController.text = profile.authUsername;
    _proxyController.text = profile.proxy;
    _expiresController.text = profile.expires;
    _destinationController.text = profile.destination;
    _transport = profile.transport;
    _applyingProfile = false;
  }

  void _installProfileSaveListeners() {
    for (final controller in [
      _domainController,
      _usernameController,
      _passwordController,
      _authUsernameController,
      _proxyController,
      _expiresController,
      _destinationController,
    ]) {
      void listener() => _saveProfile();
      _profileSaveListeners[controller] = listener;
      controller.addListener(listener);
    }
  }

  Future<void> _saveProfile() async {
    if (_applyingProfile) {
      return;
    }
    await widget.profileStore.save(_currentProfile());
  }

  SipProfile _currentProfile() {
    return SipProfile(
      domain: _domainController.text,
      username: _usernameController.text,
      password: _passwordController.text,
      authUsername: _authUsernameController.text,
      proxy: _proxyController.text,
      transport: _transport,
      expires: _expiresController.text,
      destination: _destinationController.text,
    );
  }

  void _handleEvent(SipEvent event) {
    setState(() {
      switch (event) {
        case SipCoreReady():
          _events.insert(0, 'Core ready');
        case SipCoreFailed(:final message):
          _events.insert(0, 'Core failed: $message');
        case SipAccountRegistrationChanged(
          :final accountId,
          :final state,
          :final reason,
          :final statusCode,
        ):
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
          _activeCallId = call.id;
          _events.insert(
            0,
            'Incoming call: ${call.displayName ?? call.remoteUri ?? call.id}',
          );
        case SipCallStateChanged(:final call):
          _activeCallId = call.id;
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
  }

  Future<void> _register() async {
    await _saveProfile();
    final domain = _domainController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    if (domain.isEmpty || username.isEmpty) {
      setState(
        () => _events.insert(0, 'Account default: missing domain or username'),
      );
      return;
    }

    await widget.controller.createAccount(
      SipAccountConfig(
        id: 'default',
        displayName: username,
        domain: domain,
        username: username,
        password: password,
        authUsername: _emptyToNull(_authUsernameController.text.trim()),
        proxy: _emptyToNull(_proxyController.text.trim()),
        transport: _transport,
        registrationExpiresSeconds:
            int.tryParse(_expiresController.text.trim()) ?? 300,
      ),
    );
    await widget.controller.registerAccount('default');
  }

  Future<void> _call() async {
    try {
      final callId = await widget.controller.makeCall(
        accountId: 'default',
        destination: _destinationController.text.trim(),
      );
      setState(() => _activeCallId = callId);
    } on PlatformException catch (error) {
      setState(
        () => _events.insert(0, 'Call failed: ${error.message ?? error.code}'),
      );
    }
  }

  Future<void> _hangup() async {
    final callId = _activeCallId;
    if (callId == null) {
      return;
    }
    await widget.controller.hangupCall(callId);
  }

  Future<void> _answer() async {
    final callId = _activeCallId;
    if (callId == null) {
      return;
    }
    try {
      await widget.controller.answerCall(callId);
    } on PlatformException catch (error) {
      setState(
        () =>
            _events.insert(0, 'Answer failed: ${error.message ?? error.code}'),
      );
    }
  }

  Future<void> _reject() async {
    final callId = _activeCallId;
    if (callId == null) {
      return;
    }
    await widget.controller.rejectCall(callId);
  }

  Future<void> _toggleSpeaker() async {
    final next = _route == SipAudioRoute.speaker
        ? SipAudioRoute.receiver
        : SipAudioRoute.speaker;
    await widget.controller.setAudioRoute(next);
  }

  String? _emptyToNull(String value) => value.isEmpty ? null : value;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SipTalk')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _usernameController,
                      keyboardType: TextInputType.text,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        prefixIcon: Icon(Icons.key),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _authUsernameController,
                      decoration: const InputDecoration(
                        labelText: 'Auth user',
                        prefixIcon: Icon(Icons.badge),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _proxyController,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: 'Proxy',
                        prefixIcon: Icon(Icons.route),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<SipTransport>(
                      key: ValueKey(_transport),
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
                          _saveProfile();
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
              const SizedBox(height: 12),
              TextField(
                controller: _destinationController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Destination',
                  prefixIcon: Icon(Icons.dialpad),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: _register,
                    icon: const Icon(Icons.login),
                    label: const Text('Register'),
                  ),
                  FilledButton.icon(
                    onPressed: _call,
                    icon: const Icon(Icons.call),
                    label: const Text('Call'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _toggleSpeaker,
                    icon: Icon(
                      _route == SipAudioRoute.speaker
                          ? Icons.volume_up
                          : Icons.hearing,
                    ),
                    label: Text(
                      _route == SipAudioRoute.speaker ? 'Speaker' : 'Receiver',
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _hangup,
                    icon: const Icon(Icons.call_end),
                    label: const Text('Hang up'),
                  ),
                  FilledButton.icon(
                    onPressed: _answer,
                    icon: const Icon(Icons.call_received),
                    label: const Text('Answer'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _reject,
                    icon: const Icon(Icons.phone_disabled),
                    label: const Text('Reject'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (!_profileLoaded)
                const LinearProgressIndicator(minHeight: 2)
              else
                const SizedBox(height: 2),
              const SizedBox(height: 8),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _events.length,
                    itemBuilder: (context, index) => Text(_events[index]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
