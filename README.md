<div align="center">
  <a href="https://github.com/TrustTunnel/TrustTunnel">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://cdn.adguardcdn.com/website/github.com/TrustTunnel/logo_dark.svg">
      <source media="(prefers-color-scheme: light)" srcset="https://cdn.adguardcdn.com/website/github.com/TrustTunnel/logo_light.svg">
      <img src="https://cdn.adguardcdn.com/website/github.com/TrustTunnel/logo_light.svg" alt="TrustTunnel" style="width:100%; max-width:100%; height:auto;">
    </picture>
  </a>
</div>

---
<div align="center">
	
[:us: **⬇️ English version below ⬇️** 🇬🇧](#trusttunnel-vpn-server-and-client-in-a-single-container)

</div>

---

# VPN сервер и клиент TrustTunnel в одном контейнере

> [!NOTE]
> Этот репозиторий является частью [проекта "Феникс"](https://github.com/OctoHare/VDS-Blueprint) и содержит конфигурацию для автоматической сборки Docker-образа сервера и клиента для протокола TrustTunnel в одном контейнере.

## 🔄 Автосборка

* Образ автоматически пересобирается **каждое 1-е число месяца**, подтягивая свежую версию **TrustTunnel** и обновленные зависимости.
* Публикация происходит в *GitHub Container Registry* — **[`ghcr.io/octohare/ttunnel-srvcli:latest`](https://github.com/OctoHare/TTunnel-SrvCli/pkgs/container/ttunnel-srvcli)**

## 📌 Описание

Образ `ghcr.io/octohare/ttunnel-srvcli:latest` собран из официальных репозиториев [`github.com/TrustTunnel`](https://github.com/TrustTunnel):
* **[`TrustTunnel/TrustTunnel`](https://github.com/TrustTunnel/TrustTunnel)** — серверная часть
* **[`TrustTunnel/TrustTunnelClient`](https://github.com/TrustTunnel/TrustTunnelClient)** — клиентская часть

## ❔ Зачем это нужно?

Универсальный Docker-образ «2-в-1» объединяет функционал сервера и клиента TrustTunnel. Это избавляет от необходимости использовать разные образы и упрощает управление инфраструктурой:
* Вы можете поднять как серверную, так и клиентскую часть туннеля из одного и того же образа, просто изменив параметры **Stack** в **Portainer**.
* Больше не нужно плодить разные Docker-образы. Запускайте столько изолированных серверов и клиентов TrustTunnel на одном сервере, сколько требуется, используя единый базовый образ.
* Однообразное обновление и единый источник образов упрощают автоматическое поддержание туннелей в актуальном состоянии.

## 📄 Пример использования

> [!IMPORTANT]
> **Требования к окружению**
> 
> Данная инструкция предполагает развертывание сервиса с помощью **Stack** в графической панели **Portainer** с использование сертификатов, выпущенных **Caddy**. Для выполнения описанных шагов на сервере должны быть заранее установлены **Docker**, **Portainer** и **Caddy**.

## Установка в режиме VPN cервера TrustTunnel с сертификатами от Caddy

1. Создаём каталог для настроек сервера:<br><br>
   ```bash
   mkdir -p /opt/trusttunnel/server-config
   ```

<br>

2. Создаём файл `vpn.toml`, содержащий основные настройки сервера:<br>
   - **`listen_address`** — порт, который будет слушать сервер для входящих подключений.
   - **`ipv6_available`** — укажите `true` или `false`, доступно ли подключение по IPv6 к данному серверу.
   
   Все остальные параметры можно оставить по умолчанию.
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

	С такими настройками сервер отправляет весь входящий трафик напрямую в интернет. Если необходимо перенаправлять трафик через SOCKS5-прокси, замените в файле `/opt/trusttunnel/server-config/vpn.toml` секцию:
	   
	```toml
	[forward_protocol]
	direct = {}
	```
	на секцию:
	```toml
	[forward_protocol.socks5]
	address = "127.0.0.1:1080"
	```
	> Порт для приёма трафика выберите любой свободный.

<br>

3. Создаём файл `hosts.toml` с указанием доменного имени и путей к сертификатам.<br>
   Замените `tt_server_url` на ваш домен/субдомен сервера.
   ```bash
   cat << 'EOF' > /opt/trusttunnel/server-config/hosts.toml
   [[main_hosts]]
   hostname = "tt_server_url"
   cert_chain_path = "/etc/caddy/data/caddy/certificates/acme-v02.api.letsencrypt.org-directory/tt_server_url/tt_server_url.crt"
   private_key_path = "/etc/caddy/data/caddy/certificates/acme-v02.api.letsencrypt.org-directory/tt_server_url/tt_server_url.key"
   EOF
   ```
 
   > ⚠️ Для корректного доступа к сертификатам в **Portainer** **Stack** отвечающий за **Caddy** должен отдавать каталог с сертификатами. Убедитесь, что в его конфигурации присутствует volume:
   > ```yml
   > volumes:
   >   - /etc/caddy/data:/data
   > ```

<br>

4. Создаём файл `credentials.toml` с учётными данными для подключения к серверу.
   ```bash
   cat << 'EOF' > /opt/trusttunnel/server-config/credentials.toml
   [[client]]
   username = "connect_login_on_server"
   password = "connect_password_on_server"
   EOF
   ```

   Дополнительные учётные записи добавляются копированием секции `[[client]]`. Пример файла с несколькими пользователями:
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
   > Одну учётную запись можно использовать для множества клиентов, если не требуется отдельная статистика и возможность блокировки отдельных подключений.

<br>

5. Создаём файл `rules.toml`, отвечающий за [права доступа](https://github.com/TrustTunnel/TrustTunnel/blob/master/CONFIGURATION.md#rules-file-rulestoml). Пока он пустой — всем пользователям разрешено подключение.

   ```bash
   touch /opt/trusttunnel/server-config/rules.toml
   ```

<br>

6. Разворачиваем сервер TrustTunnel через Portainer:
   - Переходим в раздел **"Stacks"**.
   - Нажимаем кнопку **"+ Add stack"**.
   - Задаём имя – **Name:** `tt-server`.
   - В поле **Web editor** вставляем следующий код:<br><br>
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

         logging:
           driver: "json-file"
           options:
             max-size: "10m"
             max-file: "2"

         healthcheck:
           test: ["CMD-SHELL", "ss -ltn | grep -q ':8443 '"]
           interval: 30s
           timeout: 5s
           retries: 3
           start_period: 15s
     ```
   - Нажимаем **"Deploy the stack"**.<br><br>

   > ⚠️ В секции `healthcheck` обязательно замените порт `8443` на тот, который вы указали в `vpn.toml` в параметре `listen_address`.

---

## Установка в режиме VPN клиента TrustTunnel

Клиент можно настроить в двух режимах: **SOCKS5-прокси** или **TUN VPN**.

Создаём каталог для конфигурации клиента:
```bash
mkdir -p /opt/trusttunnel-client
```
---

### Клиент в режиме SOCKS5-прокси

1. Создаём файл `client.toml` с настройками подключения к серверу.<br><br>
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
   > Порт, на который будет отправляться трафик, выберите любой свободный и укажите в строке `address`.

<br>

2. Разворачиваем клиент через Portainer:
   - Переходим в раздел **"Stacks"**.
   - Нажимаем кнопку **"+ Add stack"**.
   - Задаём имя – **Name:** `tt-client`.
   - В поле **Web editor** вставляем код:<br><br>
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

         logging:
           driver: "json-file"
           options:
             max-size: "10m"
             max-file: "2"

         healthcheck:
           test: ["CMD-SHELL", "ss -ltn | grep -q ':1080 '"]
           interval: 30s
           timeout: 5s
           retries: 3
           start_period: 10s
     ```
   - Нажимаем **"Deploy the stack"**.<br><br>

   > ⚠️ В секции `healthcheck` замените порт `1080` на тот, который вы указали в `client.toml`.

---

### Клиент в режиме TUN VPN

1. Создаём файл `client.toml` с настройками TUN-интерфейса.
   
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

<br>

2. Разворачиваем клиент через Portainer:
   - Переходим в раздел **"Stacks"**.
   - Нажимаем кнопку **"+ Add stack"**.
   - Задаём имя – **Name:** `tt-client`.
   - В поле **Web editor** вставляем код:<br><br>
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

         logging:
           driver: "json-file"
           options:
             max-size: "10m"
             max-file: "2"

         healthcheck:
           test: ["CMD-SHELL", "ip link | grep -q 'tun'"]
           interval: 30s
           timeout: 5s
           retries: 3
           start_period: 10s
     ```
     
   - Нажимаем **"Deploy the stack"**.

---

# TrustTunnel VPN server and client in a single container

> [!NOTE]
> This repository is part of the ["Phoenix" project](https://github.com/OctoHare/VDS-Blueprint) and contains the configuration for automatic building of a Docker image combining both server and client for the TrustTunnel protocol in one container.

## 🔄 Autobuild

* The image is automatically rebuilt **on the 1st of every month**, pulling the latest version of **TrustTunnel** and updated dependencies.
* Published to *GitHub Container Registry* — **[`ghcr.io/octohare/ttunnel-srvcli:latest`](https://github.com/OctoHare/TTunnel-SrvCli/pkgs/container/ttunnel-srvcli)**

## 📌 Description

The `ghcr.io/octohare/ttunnel-srvcli:latest` image is built from the official repositories at [`github.com/TrustTunnel`](https://github.com/TrustTunnel):
* **[`TrustTunnel/TrustTunnel`](https://github.com/TrustTunnel/TrustTunnel)** — the server part
* **[`TrustTunnel/TrustTunnelClient`](https://github.com/TrustTunnel/TrustTunnelClient)** — the client part

## ❔ Why is this needed?

A universal "2-in-1" Docker image combines TrustTunnel server and client functionality. It eliminates the need for separate images and simplifies infrastructure management:
* You can deploy both the server and client sides of a tunnel from the same image by simply changing **Stack** parameters in **Portainer**.
* No more multiple Docker images to maintain. Run as many isolated TrustTunnel servers and clients on a single host as needed, using a single base image.
* Consistent updates and a single image source simplify automatic tunnel maintenance.

## 📄 Usage example

> [!IMPORTANT]
> **Environment requirements**
> 
> This guide assumes deployment of the service using a **Stack** in the **Portainer** graphical interface, with certificates issued by **Caddy**.  
> The server must have **Docker**, **Portainer**, and **Caddy** pre-installed to follow these steps.

## Installing TrustTunnel as a VPN server with Caddy certificates

1. Create a directory for server configuration:<br><br>
   ```bash
   mkdir -p /opt/trusttunnel/server-config
   ```

<br>

2. Create the `vpn.toml` file containing the basic server settings:<br>
   - **`listen_address`** — the port the server will listen on for incoming connections.
   - **`ipv6_available`** — set to `true` or `false`, depending on whether IPv6 connectivity is available to this server.
   
   All other options can be left at their defaults.
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

	With these settings, the server sends all incoming traffic directly to the internet. If you need to forward traffic through a SOCKS5 proxy, replace the section in `/opt/trusttunnel/server-config/vpn.toml`:
	   
	```toml
	[forward_protocol]
	direct = {}
	```
	with:
	```toml
	[forward_protocol.socks5]
	address = "127.0.0.1:1080"
	```
	> Choose any free port for traffic reception.

<br>

3. Create the `hosts.toml` file with the domain name and certificate paths.<br>
   Replace `tt_server_url` with your server's domain/subdomain.
   ```bash
   cat << 'EOF' > /opt/trusttunnel/server-config/hosts.toml
   [[main_hosts]]
   hostname = "tt_server_url"
   cert_chain_path = "/etc/caddy/data/caddy/certificates/acme-v02.api.letsencrypt.org-directory/tt_server_url/tt_server_url.crt"
   private_key_path = "/etc/caddy/data/caddy/certificates/acme-v02.api.letsencrypt.org-directory/tt_server_url/tt_server_url.key"
   EOF
   ```
 
   > ⚠️ For correct access to certificates, the **Portainer** **Stack** responsible for **Caddy** must expose the certificates directory. Make sure its configuration includes the volume:
   > ```yml
   > volumes:
   >   - /etc/caddy/data:/data
   > ```

<br>

4. Create the `credentials.toml` file with authentication data for connecting to the server.
   ```bash
   cat << 'EOF' > /opt/trusttunnel/server-config/credentials.toml
   [[client]]
   username = "connect_login_on_server"
   password = "connect_password_on_server"
   EOF
   ```

   Additional accounts are added by copying the `[[client]]` section. Example of a file with multiple users:
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
   > One account can be used for multiple clients, if per-client statistics and the ability to block individual connections are not required.

<br>

5. Create the `rules.toml` file responsible for [access permissions](https://github.com/TrustTunnel/TrustTunnel/blob/master/CONFIGURATION.md#rules-file-rulestoml). While it remains empty, all created users are allowed to connect.

   ```bash
   touch /opt/trusttunnel/server-config/rules.toml
   ```

<br>

6. Deploy the TrustTunnel server via Portainer:
   - Go to the **"Stacks"** section.
   - Click the **"+ Add stack"** button.
   - Set the name – **Name:** `tt-server`.
   - In the **Web editor** field, paste the following code:<br><br>
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

         logging:
           driver: "json-file"
           options:
             max-size: "10m"
             max-file: "2"

         healthcheck:
           test: ["CMD-SHELL", "ss -ltn | grep -q ':8443 '"]
           interval: 30s
           timeout: 5s
           retries: 3
           start_period: 15s
     ```
   - Click **"Deploy the stack"**.<br><br>

   > ⚠️ In the `healthcheck` section, make sure to replace the port `8443` with the one you set in `vpn.toml` under `listen_address`.

---

## Installing TrustTunnel as a VPN client

The client can be configured in two modes: **SOCKS5 proxy** or **TUN VPN**.

Create a directory for client configuration:
```bash
mkdir -p /opt/trusttunnel-client
```
---

### Client in SOCKS5 proxy mode

1. Create the `client.toml` file with connection settings to the server.<br><br>
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
   > Choose any free port for the traffic to be sent to, and specify it in the `address` line.

<br>

2. Deploy the client via Portainer:
   - Go to the **"Stacks"** section.
   - Click the **"+ Add stack"** button.
   - Set the name – **Name:** `tt-client`.
   - In the **Web editor** field, paste the following code:<br><br>
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

         logging:
           driver: "json-file"
           options:
             max-size: "10m"
             max-file: "2"

         healthcheck:
           test: ["CMD-SHELL", "ss -ltn | grep -q ':1080 '"]
           interval: 30s
           timeout: 5s
           retries: 3
           start_period: 10s
     ```
   - Click **"Deploy the stack"**.<br><br>

   > ⚠️ In the `healthcheck` section, replace the port `1080` with the one you specified in `client.toml`.

---

### Client in TUN VPN mode

1. Create the `client.toml` file with TUN interface settings.
   
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

<br>

2. Deploy the client via Portainer:
   - Go to the **"Stacks"** section.
   - Click the **"+ Add stack"** button.
   - Set the name – **Name:** `tt-client`.
   - In the **Web editor** field, paste the following code:<br><br>
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

         logging:
           driver: "json-file"
           options:
             max-size: "10m"
             max-file: "2"

         healthcheck:
           test: ["CMD-SHELL", "ip link | grep -q 'tun'"]
           interval: 30s
           timeout: 5s
           retries: 3
           start_period: 10s
     ```
   - Click **"Deploy the stack"**.
