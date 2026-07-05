# Cloudflare DDNS

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A lightweight, fully parameterized Bash script to dynamically update Cloudflare DNS **A** (IPv4) and **AAAA** (IPv6) records. No hardcoded configuration — everything is passed via command-line arguments.

## Features

- **No hardcoded values** — every parameter is a CLI argument
- **IPv4 only** (`-4`), **IPv6 only** (`-6`), or **both** (`-4 -6`)
- **Auto-detect** available IPs when neither `-4` nor `-6` is specified
- **Proxy toggle** — enable or disable Cloudflare proxy (orange cloud) with `-p true` / `-p false`
- **Preserves proxy state** — if `-p` is omitted, the current proxy setting is kept untouched
- **Idempotent** — skips API calls if the IP hasn't changed
- **Creates records automatically** — if the DNS record doesn't exist, it's created on first run
- **Custom TTL** — set TTL with `-t` (default: 120, minimum: 60)
- **Zone auto-detection** — zone is extracted from the hostname if not explicitly provided
- **Comprehensive error handling** — clear messages for missing parameters, API errors, and network failures

## Prerequisites

- **curl** — for HTTP requests
- **python3** — for JSON parsing (stdlib only, no extra packages)

```bash
# Install on Debian/Ubuntu
sudo apt install curl python3 -y
```

## Installation

```bash
# Clone the repository
git clone https://github.com/aldemaroc/cloudflare-ddns.git
cd cloudflare-ddns

# Make the script executable
chmod +x cloudflare-ddns.sh

# (Optional) Install system-wide
sudo cp cloudflare-ddns.sh /usr/local/bin/cloudflare-ddns
```

## Usage

```
cloudflare-ddns -h <hostname> -k <api_token> [-z <zone>] [-4] [-6] [-p <bool>] [-t <ttl>]
```

### Required Parameters

| Parameter | Description |
|-----------|-------------|
| `-h <hostname>` | Full DNS record name (e.g. `myserver.example.com`) |
| `-k <api_token>` | Cloudflare API Token with **DNS:Edit** permission on the zone |

### Optional Parameters

| Parameter | Description |
|-----------|-------------|
| `-z <zone>` | Zone/domain name (e.g. `example.com`). Auto-extracted from hostname if omitted. |
| `-4` | Update A record (IPv4). Auto-detected if omitted together with `-6`. |
| `-6` | Update AAAA record (IPv6). Auto-detected if omitted together with `-4`. |
| `-p <bool>` | Enable (`true`) or disable (`false`) Cloudflare proxy (orange cloud). If omitted, the current proxy state is preserved. |
| `-t <ttl>` | TTL in seconds. Default: 120 (Auto). Minimum: 60. |
| `--help` | Show help and exit. |

### Examples

```bash
# Update only IPv4
cloudflare-ddns -h myserver.example.com -k token123 -4

# Update only IPv6
cloudflare-ddns -h myserver.example.com -k token123 -6

# Update both IPv4 and IPv6, enable proxy
cloudflare-ddns -h myserver.example.com -k token123 -4 -6 -p true

# Update both, disable proxy
cloudflare-ddns -h myserver.example.com -k token123 -4 -6 -p false

# Auto-detect available IPs (no -4 or -6)
cloudflare-ddns -h myserver.example.com -k token123

# Specify zone explicitly, custom TTL
cloudflare-ddns -h sub.example.com.br -k token123 -z example.com.br -4 -6 -t 300
```

## Cloudflare API Token Setup

1. Go to **Cloudflare Dashboard** → **My Profile** → **API Tokens** → **Create Token**
2. Use the **"Edit zone DNS"** template
3. Select the zone(s) you want to manage
4. Create and **copy the token** (shown only once)

The token needs only the **DNS:Edit** permission — no other scopes required.

## Automation with Cron

Run the script periodically to keep your DNS records in sync:

```bash
# Edit root's crontab
sudo crontab -e
```

Add one of these lines:

```cron
# Every 5 minutes — IPv6 only
*/5 * * * * /usr/local/bin/cloudflare-ddns -h myserver.example.com -k YOUR_TOKEN -6 >> /var/log/cloudflare-ddns.log 2>&1

# Every minute — auto-detect (IPv4 and/or IPv6)
* * * * * /usr/local/bin/cloudflare-ddns -h myserver.example.com -k YOUR_TOKEN >> /var/log/cloudflare-ddns.log 2>&1
```

## Output

```
[INFO] Obtendo Zone ID para: example.com
[INFO] Zone ID: 47cadeb1e7e572cf407d98d68e982fd0
[INFO] IPv6 público: 2804:2cbc:1f8e:e201:be24:11ff:fe75:9c22
[INFO] Buscando registro AAAA existente para myserver.example.com...
[OK] myserver.example.com AAAA já está em 2804:2cbc:1f8e:e201:be24:11ff:fe75:9c22 — nada a fazer.
```

## How It Works

1. **IP detection** — fetches the public IP from `ifconfig.me`, `icanhazip.com`, or `ipify.org` (with `-4` or `-6` flags for the correct protocol)
2. **Zone lookup** — queries the Cloudflare API to find the Zone ID for your domain
3. **Record check** — looks up the existing DNS record and compares the IP
4. **Update or skip** — if the IP changed, sends a `PUT` request; if it's the same, does nothing
5. **Auto-create** — if the record doesn't exist, creates it with a `POST` request

## License

MIT

## Credits

[Aldemaro Campos](https://aldemaro.com.br) and Chico
