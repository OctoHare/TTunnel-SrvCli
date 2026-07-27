# TTunnel-SrvCli

## Сервер TrustTunnel с сертификатами от Caddy

---

Создаём каталог для настроек:
```bash
mkdir -p /opt/trusttunnel/server-config
```

---

Создаём файл `vpn.toml`, который содержит основные настройки сервера:

- параметр `listen_address` укажите порт, который будет слушать сервер и по которому будет осуществляться подключение
- параметр `ipv6_available` укажи `true` или `false`, доступно или нет подключение по IPv6 к данному серверу

Всё остальное можно оставить по умолчанию

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
С такими настройками сервер отправляет всё, что на него приходит напрямую в интернет.
Если необходимо перенаправить трафик куда-то, есть режиим SOCKS5 прокси.
Для включения данного режима в настройках сервера `/opt/trusttunnel/server-config/vpn.toml` замените целиком раздел

```toml
[forward_protocol]
direct = {}
```

на раздел
```toml
[forward_protocol.socks5]
address = "127.0.0.1:1080"
```

> Порт, с которого будете забираться трафик выберите сами из свободных

---

Создаём файл `hosts.toml`, который содержит имя домена и путь к сертификатам:

Замените `tt_server_url` на ваш домен/субдомен сервера

```bash
cat << 'EOF' > /opt/trusttunnel/server-config/hosts.toml
[[main_hosts]]
hostname = "tt_server_url"
cert_chain_path = "/etc/caddy/data/caddy/certificates/acme-v02.api.letsencrypt.org-directory/tt_server_url/tt_server_url.crt"
private_key_path = "/etc/caddy/data/caddy/certificates/acme-v02.api.letsencrypt.org-directory/tt_server_url/tt_server_url.key"
EOF
```

Для корректного доступа к сертификатам Stack Caddy в Portainer должен отдавать каталог с сертификатами:
```yml
    volumes:
      - /etc/caddy/data:/data
```

---

Создаём файл `credentials.toml`, который содержит учётные записи для подключения к серверу:

```bash
cat << 'EOF' > /opt/trusttunnel/server-config/credentials.toml
[[client]]
username = "connect_login_on_server"
password = "connect_password_on_server"
EOF
```

Дополнительные учётные записи можно добавлять копируя секцию целиком, например файл `credentials.toml` может выглядеть так:

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

Одну учётную запись можно использовать для множества клиентов. Если вам не нужна дополнительная статистика и возможность блокировки отдельных клиентов.

---

Создаём пустой файл `rules.toml`, которы отвечает за [разрешения доступа](https://github.com/TrustTunnel/TrustTunnel/blob/master/CONFIGURATION.md#rules-file-rulestoml) конкретных пользователей. Пока файл пустой всем созданным пользователям разрешено подключение.

```bash
touch /opt/trusttunnel/server-config/rules.toml
```

---

Далее для установки сервера TrustTunnel переходим в Portainer:

1. Раздел "**Stacks**"
2. Кнопка "**+ Add stack**"
3. Задаём имя - Name: `tt-server`
4. В окном Web editor вставляем:

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

> В секции `healthcheck` в пункте `test` укажите тот порт, который вы выбрали для работы сервера

---

## Клиент TrustTunnel

---

Создаём каталог для настроек:

```bash
mkdir -p /opt/trusttunnel-client
```

---

### Клиент в режиме SOCKS5-прокси

Создаём файл `client.toml`, который содержит настройки для подключения к серверу:

```bash
cat << 'EOF' > /opt/trusttunnel-client/client.toml
loglevel = "info"
vpn_mode = "general"

[endpoint]
hostname = "tt_server_url"
addresses = ["tt_server_url:8443"]
username = "connect_login_on_server"
password = "connect_password_on_server"
skip_verification = false
has_ipv6 = false

# Отключаем TUN (VPN маршрутизацию)
[listener.tun]
included_routes = []

# Включаем SOCKS5 прокси для сети
[listener.socks]
address = "127.0.0.1:1080"
EOF
```

> Порт, на который будете отправлять трафик выберите сами из свободных

---

Далее для установки клиента TrustTunnel переходим в Portainer:

1. Раздел "**Stacks**"
2. Кнопка "**+ Add stack**"
3. Задаём имя - Name: `tt-client`
4. В окном Web editor вставляем:

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

> В секции `healthcheck` в пункте `test` укажите тот порт, который вы выбрали для работы клиента

---

### Клиент в режиме TUN VPN

Создаём файл `client.toml`, который содержит настройки для подключения к серверу:

```bash
cat << 'EOF' > /opt/trusttunnel-client/client.toml
loglevel = "info"
vpn_mode = "general"

[endpoint]
hostname = "tt_server_url"
addresses = ["tt_server_url:8443"]
username = "connect_login_on_server"
password = "connect_password_on_server"
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

Далее для установки клиента TrustTunnel переходим в Portainer:

1. Раздел "**Stacks**"
2. Кнопка "**+ Add stack**"
3. Задаём имя - Name: `tt-client`
4. В окном Web editor вставляем:

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
