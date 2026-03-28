class ServerSetupConfig {
  final String host;
  final int sshPort;
  final String sshUsername;
  final String sshPassword;
  final String domain;
  final String email;
  final int listenPort;
  final String vpnUsername;
  final String vpnPassword;

  const ServerSetupConfig({
    required this.host,
    this.sshPort = 22,
    this.sshUsername = 'root',
    required this.sshPassword,
    required this.domain,
    required this.email,
    this.listenPort = 443,
    required this.vpnUsername,
    required this.vpnPassword,
  });

  String generateVpnToml() {
    return 'listen_address = "0.0.0.0:$listenPort"\n'
        'credentials_file = "/opt/trusttunnel/credentials.toml"\n';
  }

  String generateCredentialsToml() {
    return '[[client]]\n'
        'username = "$vpnUsername"\n'
        'password = "$vpnPassword"\n';
  }

  String generateHostsToml() {
    return '[[main_hosts]]\n'
        'hostname = "$domain"\n'
        'cert_chain_path = "/etc/letsencrypt/live/$domain/fullchain.pem"\n'
        'private_key_path = "/etc/letsencrypt/live/$domain/privkey.pem"\n';
  }
}
