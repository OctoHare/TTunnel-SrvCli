# TTunnel-SrvCli

---

## Клиент в режиме SOCKS5-прокси

`/opt/trusttunnel-client/client.toml`

```toml
loglevel = "info"
vpn_mode = "general"

[endpoint]
hostname = "tt_server_url"
addresses = ["192.168.1.100:8443"]
username = "connect_login_on_server"
password = "connect_password_on_server"
skip_verification = true

# Отключаем TUN (VPN маршрутизацию)
[listener.tun]
included_routes = []

# Включаем SOCKS5 прокси для сети
[listener.socks]
address = "0.0.0.0:1080"
```

Portainer Stack:

```yml
trusttunnel-client-socks:
    image: ghcr.io/octohare/trusttunnel:latest
    container_name: trusttunnel-client
    restart: unless-stopped
    environment:
      - TT_MODE=client
    ports:
      - "1080:1080"
    volumes:
      - /opt/trusttunnel-client:/trusttunnel:rw
```

---

## Клиент в режиме полноценного TUN VPN

`/opt/trusttunnel-client/client.toml`

```toml
loglevel = "info"
vpn_mode = "general"

[endpoint]
hostname = "tt_server_url"
addresses = ["192.168.1.100:8443"]
username = "connect_login_on_server"
password = "connect_password_on_server"
skip_verification = true

[listener.tun]
included_routes = ["0.0.0.0/0", "2000::/3"]
excluded_routes = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
mtu_size = 1350
```

Portainer Stack:

```yml
trusttunnel-client-vpn:
    image: ghcr.io/octohare/trusttunnel:latest
    container_name: trusttunnel-client
    restart: unless-stopped
    environment:
      - TT_MODE=client
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/net/tun:/dev/net/tun
    volumes:
      - /opt/trusttunnel-client:/trusttunnel:rw
```
