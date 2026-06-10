class SipAccountConfig {
  const SipAccountConfig({
    required this.id,
    required this.displayName,
    required this.domain,
    required this.username,
    required this.password,
    this.authUsername,
    this.proxy,
    this.transport = SipTransport.tls,
    this.registrationExpiresSeconds = 300,
  });

  final String id;
  final String displayName;
  final String domain;
  final String username;
  final String password;
  final String? authUsername;
  final String? proxy;
  final SipTransport transport;
  final int registrationExpiresSeconds;
}

enum SipTransport { udp, tcp, tls }

enum SipAccountState {
  unconfigured,
  configured,
  registering,
  registered,
  registrationFailed,
  pushReachable,
  offline,
}
