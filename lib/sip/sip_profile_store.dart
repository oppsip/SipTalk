import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sip_account.dart';
import 'sip_call.dart';

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
    required this.defaultAudioRoute,
  });

  const SipProfile.defaults()
    : domain = 'sip.example.com',
      username = '1000',
      password = '',
      authUsername = '',
      proxy = '',
      transport = SipTransport.udp,
      expires = '300',
      destination = '1001',
      defaultAudioRoute = SipAudioRoute.receiver;

  final String domain;
  final String username;
  final String password;
  final String authUsername;
  final String proxy;
  final SipTransport transport;
  final String expires;
  final String destination;
  final SipAudioRoute defaultAudioRoute;

  SipProfile copyWith({
    String? domain,
    String? username,
    String? password,
    String? authUsername,
    String? proxy,
    SipTransport? transport,
    String? expires,
    String? destination,
    SipAudioRoute? defaultAudioRoute,
  }) {
    return SipProfile(
      domain: domain ?? this.domain,
      username: username ?? this.username,
      password: password ?? this.password,
      authUsername: authUsername ?? this.authUsername,
      proxy: proxy ?? this.proxy,
      transport: transport ?? this.transport,
      expires: expires ?? this.expires,
      destination: destination ?? this.destination,
      defaultAudioRoute: defaultAudioRoute ?? this.defaultAudioRoute,
    );
  }
}

class SipProfileStore {
  const SipProfileStore({
    FlutterSecureStorage secureStorage = const FlutterSecureStorage(),
  }) : _secureStorage = secureStorage;

  final FlutterSecureStorage _secureStorage;

  static const _prefix = 'sip_profile.';
  static const _domain = '${_prefix}domain';
  static const _username = '${_prefix}username';
  static const _legacyPassword = '${_prefix}password';
  static const _securePassword = '${_prefix}password';
  static const _authUsername = '${_prefix}authUsername';
  static const _proxy = '${_prefix}proxy';
  static const _transport = '${_prefix}transport';
  static const _expires = '${_prefix}expires';
  static const _destination = '${_prefix}destination';
  static const _defaultAudioRoute = '${_prefix}defaultAudioRoute';

  Future<SipProfile> load() async {
    final preferences = await SharedPreferences.getInstance();
    final password = await _loadPassword(preferences);
    const defaults = SipProfile.defaults();
    return SipProfile(
      domain: preferences.getString(_domain) ?? defaults.domain,
      username: preferences.getString(_username) ?? defaults.username,
      password: password ?? defaults.password,
      authUsername:
          preferences.getString(_authUsername) ?? defaults.authUsername,
      proxy: preferences.getString(_proxy) ?? defaults.proxy,
      transport: _transportValue(
        preferences.getString(_transport),
        defaults.transport,
      ),
      expires: preferences.getString(_expires) ?? defaults.expires,
      destination: preferences.getString(_destination) ?? defaults.destination,
      defaultAudioRoute: _audioRouteValue(
        preferences.getString(_defaultAudioRoute),
        defaults.defaultAudioRoute,
      ),
    );
  }

  Future<void> save(SipProfile profile) async {
    final preferences = await SharedPreferences.getInstance();
    await Future.wait<void>([
      preferences.setString(_domain, profile.domain),
      preferences.setString(_username, profile.username),
      preferences.setString(_authUsername, profile.authUsername),
      preferences.setString(_proxy, profile.proxy),
      preferences.setString(_transport, profile.transport.name),
      preferences.setString(_expires, profile.expires),
      preferences.setString(_destination, profile.destination),
      preferences.setString(_defaultAudioRoute, profile.defaultAudioRoute.name),
      preferences.remove(_legacyPassword),
      _secureStorage.write(key: _securePassword, value: profile.password),
    ]);
  }

  Future<String?> _loadPassword(SharedPreferences preferences) async {
    final password = await _secureStorage.read(key: _securePassword);
    if (password != null) {
      return password;
    }

    final legacyPassword = preferences.getString(_legacyPassword);
    if (legacyPassword == null) {
      return null;
    }

    await _secureStorage.write(key: _securePassword, value: legacyPassword);
    await preferences.remove(_legacyPassword);
    return legacyPassword;
  }

  SipTransport _transportValue(String? value, SipTransport fallback) {
    return SipTransport.values.firstWhere(
      (transport) => transport.name == value,
      orElse: () => fallback,
    );
  }

  SipAudioRoute _audioRouteValue(String? value, SipAudioRoute fallback) {
    return SipAudioRoute.values.firstWhere(
      (route) => route.name == value,
      orElse: () => fallback,
    );
  }
}
