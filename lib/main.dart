import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'sip/sip_account.dart';
import 'sip/sip_call.dart';
import 'sip/sip_controller.dart';
import 'sip/sip_event.dart';
import 'sip/sip_method_channel_controller.dart';

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
  const SipHomePage({required this.controller, super.key});

  final SipController controller;

  @override
  State<SipHomePage> createState() => _SipHomePageState();
}

class _SipHomePageState extends State<SipHomePage> {
  final _domainController = TextEditingController(text: 'sip.example.com');
  final _usernameController = TextEditingController(text: '1000');
  final _passwordController = TextEditingController(text: 'change-me');
  final _authUsernameController = TextEditingController();
  final _proxyController = TextEditingController();
  final _expiresController = TextEditingController(text: '300');
  final _destinationController = TextEditingController(text: '1001');
  final _events = <String>[];
  String? _activeCallId;
  SipAudioRoute _route = SipAudioRoute.receiver;
  SipTransport _transport = SipTransport.udp;

  @override
  void initState() {
    super.initState();
    widget.controller.events.listen(_handleEvent);
    widget.controller.initialize();
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
    widget.controller.shutdown();
    super.dispose();
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
                ],
              ),
              const SizedBox(height: 16),
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
