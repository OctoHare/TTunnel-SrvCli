# TrustTunnel server and client in container

[Русская версия](README.md)

## TrustTunnel server with certificates from Caddy

---

Create a directory for configuration:
```bash
mkdir -p /opt/trusttunnel/server-config
```

---

Create a `vpn.toml` file, which contains the main server settings:

- The `listen_address` parameter specifies the port the server will listen on and which will be used for connection.
- The `ipv6_available` parameter specifies `true` or `false`, whether IPv6 connection to this server is available or not.

Everything else can be left as default.

```bash
cat << 'EOF' > /opt/trusttunnel/server-config/vpn.toml
listen_address = "0.0.0.0:8443"
ipv6_available = false
allow_private_network_connections = false
tls_handshake_timeout_secs = 10
client_listener_timeout_secs = 600
connection_establishment_timeout_secs = 30
tcp_connections_timeout_secs = 604800
udp_connections_timeout_secs = 300
credentials_file = "credentials.toml"
rules_file = "rules.toml"

[listen_protocols]

[listen_protocols.http1]
upload_buffer_size = 32768

[listen_protocols.http2]
initial_connection_window_size = 8388608
initial_stream_window_size = 131072
max_concurrent_streams = 1000
max_frame_size = 16384
header_table_size = 65536

[listen_protocols.quic]
recv_udp_payload_size = 1350
send_udp_payload_size = 1350
initial_max_data = 104857600
initial_max_stream_data_bidi_local = 1048576
initial_max_stream_data_bidi_remote = 1048576
initial_max_stream_data_uni = 1048576
initial_max_streams_bidi = 4096
initial_max_streams_uni = 4096
max_connection_window = 25165824
max_stream_window = 16777216
disable_active_migration = true
enable_early_data = true
message_queue_capacity = 4096

[forward_protocol]
direct = {}
EOF
```

With these settings, the server forwards everything it receives directly to the internet.

If you need to redirect traffic somewhere, there is a SOCKS5 proxy mode.

To enable this mode, in the server configuration file `/opt/trusttunnel/server-config/vpn.toml`, replace the entire section:

```toml
[forward_protocol]
direct = {}
```

with:

```toml
[forward_protocol.socks5]
address = "127.0.0.1:1080"
```

> Choose any free port from which you will take traffic.

---

Create a `hosts.toml` file, which contains the domain name and certificate paths:

Replace `tt_server_url` with your server domain/subdomain.

```bash
cat << 'EOF' > /opt/trusttunnel/server-config/hosts.toml
[[main_hosts]]
hostname = "tt_server_url"
cert_chain_path = "/etc/caddy/data/caddy/certificates/acme-v02.api.letsencrypt.org-directory/tt_server_url/tt_server_url.crt"
private_key_path = "/etc/caddy/data/caddy/certificates/acme-v02.api.letsencrypt.org-directory/tt_server_url/tt_server_url.key"
EOF
```

For proper access to certificates, the Caddy Stack in Portainer must expose the certificate directory:
```yml
    volumes:
      - /etc/caddy/data:/data
```

---

Create a `credentials.toml` file containing user accounts for connecting to the server:

```bash
cat << 'EOF' > /opt/trusttunnel/server-config/credentials.toml
[[client]]
username = "connect_login_on_server"
password = "connect_password_on_server"
EOF
```

Additional accounts can be added by copying the entire section; for example, `credentials.toml` might look like this:

```toml
[[client]]
username = "connect_login_on_server1"
password = "connect_password_on_server1"

[[client]]
username = "connect_login_on_server2"
password = "connect_password_on_server2"

[[client]]
username = "connect_login_on_server3"
password = "connect_password_on_server3"
```

One account can be used for many clients, if you don't need additional statistics and the ability to block individual clients.

---

Create an empty `rules.toml` file, which controls access permissions for specific users. While the file is empty, all created users are allowed to connect.

```bash
touch /opt/trusttunnel/server-config/rules.toml
```

---

Next, to install the TrustTunnel server, go to Portainer:

1. Section "**Stacks**"
2. Button "**+ Add stack**"
3. Set name - Name: `tt-server`
4. In the Web editor window, paste:

```yml
services:
  tt-server:
    image: ghcr.io/octohare/ttunnel-srvcli:latest
    container_name: tt-server
    restart: unless-stopped
    network_mode: host

    environment:
      - TT_MODE=server

    volumes:
      - /opt/trusttunnel/server-config:/trusttunnel:rw
      - /etc/caddy/data:/etc/caddy/data:ro

    healthcheck:
      test: ["CMD-SHELL", "ss -ltn | grep -q ':8443 '"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 15s
```

> In the `healthcheck` section, in the `test` item, specify the port you chose for the server.

---

## TrustTunnel Client

---

Create a directory for configuration:

```bash
mkdir -p /opt/trusttunnel-client
```

---

### Client in SOCKS5 proxy mode

Create a `client.toml` file with connection settings for the server:

```bash
cat << 'EOF' > /opt/trusttunnel-client/client.toml
loglevel = "info"
vpn_mode = "general"

[endpoint]
hostname = "tt_server_url"
addresses = ["tt_server_url:8443"]
username = "connect_login_on_server"
password = "connect_password_on_server"
upstream_protocol = "http2"
skip_verification = false
has_ipv6 = false

[listener.socks]
address = "127.0.0.1:1080"
EOF
```

> Choose any free port to which you will send traffic.

---

Next, to install the TrustTunnel client, go to Portainer:

1. Section "**Stacks**"
2. Button "**+ Add stack**"
3. Set name - Name: `tt-client`
4. In the Web editor window, paste:

```yml
services:
  tt-client-socks:
    image: ghcr.io/octohare/ttunnel-srvcli:latest
    container_name: tt-client
    restart: unless-stopped
    network_mode: host

    environment:
      - TT_MODE=client

    volumes:
      - /opt/trusttunnel-client:/trusttunnel:rw

    healthcheck:
      test: ["CMD-SHELL", "ss -ltn | grep -q ':1080 '"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 10s
```

> In the `healthcheck` section, in the `test` item, specify the port you chose for the client.

---

### Client in TUN VPN mode

Create a `client.toml` file with connection settings for the server:

```bash
cat << 'EOF' > /opt/trusttunnel-client/client.toml
loglevel = "info"
vpn_mode = "general"

[endpoint]
hostname = "tt_server_url"
addresses = ["tt_server_url:8443"]
username = "connect_login_on_server"
password = "connect_password_on_server"
upstream_protocol = "http2"
skip_verification = false
has_ipv6 = false

[listener.tun]
included_routes = ["0.0.0.0/0", "2000::/3"]
excluded_routes = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
mtu_size = 1350
change_system_dns = false
EOF
```

---

Next, to install the TrustTunnel client, go to Portainer:

1. Section "**Stacks**"
2. Button "**+ Add stack**"
3. Set name - Name: `tt-client`
4. In the Web editor window, paste:

```yml
services:
  tt-client-tun:
    image: ghcr.io/octohare/ttunnel-srvcli:latest
    container_name: tt-client
    restart: unless-stopped
    network_mode: host

    environment:
      - TT_MODE=client

    cap_add:
      - NET_ADMIN

    devices:
      - /dev/net/tun:/dev/net/tun

    volumes:
      - /opt/trusttunnel-client:/trusttunnel:rw

    healthcheck:
      test: ["CMD-SHELL", "ip link | grep -q 'tun'"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 10s
```
