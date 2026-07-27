#!/bin/bash

set -e

TT_MODE="${TT_MODE:-server}"

check_file() {
    local file="$1"
    if [ ! -f "$file" ]; then
        return 1
    fi
    return 0
}

verify_server_configs() {
    local missing=0
    check_file "credentials.toml" || missing=1
    check_file "vpn.toml" || missing=1
    check_file "hosts.toml" || missing=1
    return $missing
}

run_server_setup_noninteractive() {
    if [ -z "${TT_HOSTNAME:-}" ] || [ -z "${TT_CREDENTIALS:-}" ]; then
        echo "Error: TT_HOSTNAME and TT_CREDENTIALS are required for non-interactive setup"
        return 1
    fi

    local args=(
        "-m" "non-interactive"
        "-a" "${TT_LISTEN_ADDRESS:-0.0.0.0:8443}"
        "-c" "$TT_CREDENTIALS"
        "-n" "$TT_HOSTNAME"
        "--lib-settings" "vpn.toml"
        "--hosts-settings" "hosts.toml"
    )

    case "${TT_CERT_TYPE:-self-signed}" in
        self-signed) args+=("--cert-type" "self-signed") ;;
        letsencrypt)
            if [ -z "${TT_ACME_EMAIL:-}" ]; then
                echo "Error: TT_ACME_EMAIL is required when TT_CERT_TYPE=letsencrypt"
                return 1
            fi
            args+=("--cert-type" "letsencrypt" "--acme-email" "$TT_ACME_EMAIL")
            [ "${TT_ACME_STAGING:-false}" = "true" ] && args+=("--acme-staging")
            ;;
        provided)
            if [ -z "${TT_CERT_PROVIDED_CHAIN_PATH:-}" ] || [ -z "${TT_CERT_PROVIDED_KEY_PATH:-}" ]; then
                echo "Error: TT_CERT_PROVIDED_CHAIN_PATH and TT_CERT_PROVIDED_KEY_PATH are required"
                return 1
            fi
            args+=("--cert-type" "provided" "--cert-chain-path" "$TT_CERT_PROVIDED_CHAIN_PATH" "--cert-key-path" "$TT_CERT_PROVIDED_KEY_PATH")
            ;;
        *)
            echo "Error: Unsupported TT_CERT_TYPE='$TT_CERT_TYPE'"
            return 1
            ;;
    esac

    echo "Missing server config(s). Running setup_wizard_server..."
    setup_wizard_server "${args[@]}"
}

main() {
    # --- РЕЖИМ КЛИЕНТА ---
    if [ "$TT_MODE" = "client" ]; then
        echo "Starting TrustTunnel Client..."

        # 1. Если переданы кастомные аргументы через command в docker-compose
        if [ "$#" -gt 0 ]; then
            exec trusttunnel_client "$@"
        # 2. Ищем файл конфигурации клиента
        elif check_file "client.toml"; then
            exec trusttunnel_client --config client.toml
        elif check_file "trusttunnel_client.toml"; then
            exec trusttunnel_client --config trusttunnel_client.toml
        else
            echo "Error: No client configuration file found (expected client.toml or trusttunnel_client.toml)"
            exit 1
        fi
    fi

    # --- РЕЖИМ СЕРВЕРА (по умолчанию) ---
    if ! verify_server_configs; then
        if [ -t 0 ]; then
            echo "Missing server config(s). Launching setup wizard in interactive mode..."
            setup_wizard_server
        else
            run_server_setup_noninteractive
        fi
    fi

    echo "Starting trusttunnel_endpoint"
    exec trusttunnel_endpoint vpn.toml hosts.toml
}

main "$@"
