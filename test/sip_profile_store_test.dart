import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:siptalk/sip/sip_account.dart';
import 'package:siptalk/sip/sip_call.dart';
import 'package:siptalk/sip/sip_profile_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('saves and loads SIP profile fields', () async {
    const store = SipProfileStore();
    const profile = SipProfile(
      domain: 'pbx.example.test',
      username: '2001',
      password: 'secret',
      authUsername: 'auth-2001',
      proxy: 'sip:proxy.example.test;transport=tcp',
      transport: SipTransport.tcp,
      expires: '600',
      destination: '2002',
      defaultAudioRoute: SipAudioRoute.speaker,
    );

    await store.save(profile);
    final loaded = await store.load();

    expect(loaded.domain, profile.domain);
    expect(loaded.username, profile.username);
    expect(loaded.password, profile.password);
    expect(loaded.authUsername, profile.authUsername);
    expect(loaded.proxy, profile.proxy);
    expect(loaded.transport, profile.transport);
    expect(loaded.expires, profile.expires);
    expect(loaded.destination, profile.destination);
    expect(loaded.defaultAudioRoute, profile.defaultAudioRoute);
  });

  test('migrates legacy preferences password into secure storage', () async {
    SharedPreferences.setMockInitialValues({
      'sip_profile.password': 'legacy-secret',
    });
    FlutterSecureStorage.setMockInitialValues({});

    const store = SipProfileStore();

    final loaded = await store.load();
    final preferences = await SharedPreferences.getInstance();

    expect(loaded.password, 'legacy-secret');
    expect(preferences.getString('sip_profile.password'), isNull);
  });
}
