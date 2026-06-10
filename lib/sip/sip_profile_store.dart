import 'package:shared_preferences/shared_preferences.dart';

import 'sip_account.dart';

class SipProfile {
  const SipProfile({
    required this.domain,
    required this.username,
    required this.password,
    required this.authUsername,
    required this.proxy,
    required this.transport,
    required this.expires,
    required this.destination,
  });

  const SipProfile.defaults()
    : domain = 'sip.example.com',
      username = '1000',
      password = 'change-me',
      authUsername = '',
      proxy = '',
      transport = SipTransport.udp,
      expires = '300',
      destination = '1001';

  final String domain;
  final String username;
  final String password;
  final String authUsername;
  final String proxy;
  final SipTransport transport;
  final String expires;
  final String destination;
}

class SipProfileStore {
  const SipProfileStore();

  static const _prefix = 'sip_profile.';
  static const _domain = '${_prefix}domain';
  static const _username = '${_prefix}username';
  static const _password = '${_prefix}password';
  static const _authUsername = '${_prefix}authUsername';
  static const _proxy = '${_prefix}proxy';
  static const _transport = '${_prefix}transport';
  static const _expires = '${_prefix}expires';
  static const _destination = '${_prefix}destination';

  Future<SipProfile> load() async {
    final preferences = await SharedPreferences.getInstance();
    const defaults = SipProfile.defaults();
    return SipProfile(
      domain: preferences.getString(_domain) ?? defaults.domain,
      username: preferences.getString(_username) ?? defaults.username,
      password: preferences.getString(_password) ?? defaults.password,
      authUsername:
          preferences.getString(_authUsername) ?? defaults.authUsername,
      proxy: preferences.getString(_proxy) ?? defaults.proxy,
      transport: _transportValue(
        preferences.getString(_transport),
        defaults.transport,
      ),
      expires: preferences.getString(_expires) ?? defaults.expires,
      destination: preferences.getString(_destination) ?? defaults.destination,
    );
  }

  Future<void> save(SipProfile profile) async {
    final preferences = await SharedPreferences.getInstance();
    await Future.wait([
      preferences.setString(_domain, profile.domain),
      preferences.setString(_username, profile.username),
      preferences.setString(_password, profile.password),
      preferences.setString(_authUsername, profile.authUsername),
      preferences.setString(_proxy, profile.proxy),
      preferences.setString(_transport, profile.transport.name),
      preferences.setString(_expires, profile.expires),
      preferences.setString(_destination, profile.destination),
    ]);
  }

  SipTransport _transportValue(String? value, SipTransport fallback) {
    return SipTransport.values.firstWhere(
      (transport) => transport.name == value,
      orElse: () => fallback,
    );
  }
}
