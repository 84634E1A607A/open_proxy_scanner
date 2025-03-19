# Proxy Scanner

This is a simple script to scan for open 7890 socks5 proxies in the WAN (or CGNAT), and use them as upstream proxy.

See [my blog](https://aajax.top/2025/03/19/OpenProxyScanner/) for details.

## Installation

- Generate a Clash API secret (token) and global search for $TOKEN.
- Sepcify the list of IPs you want to scan in scan.sh
- Optionally, patch Dockerfile, scan.sh to scan other ports
- Optionally, use Zmap instead of Nmap in initial scan for better performance.
- Run `docker compose up`.

## WARNING

This docker compose file listens on port 7890 as open proxy too! Configure your firewall wisely.
