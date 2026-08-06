# Overview

HTTPS web interface for drive and collaborative workspace.
([Reference documentation](https://docs.nextcloud.com/server/stable/admin_manual/)).

This stack includes:
- dedicated MariaBD database
- Redis cache layer
- Collabora instance for editing office document from nextcloud

This stack does not include a dedicated performance backend for video calls, so these will be done only over HTTPS.

# Prerequisite

DNS registration for the host (duckDNS running).
Caddy reverse-proxy running with entries for Nextcloud and Collabora.

# Configuration

Update the following environment in the compose file:
- MYSQL_ROOT_PASSWORD
- MYSQL_PASSWORD
- password
- server_name

Public resolution is mandatory from guest services, so if you need local DNS instead of duckDNS, add:
```yml
services:
  nextcloud:
    extra_hosts:
      - "collabora.local:192.168.x.x" # Your host IP.
  nextcloud_collabora:
    extra_hosts:
      - "nextcloud.local:192.168.x.x" # Yout host IP.
```

Actually, Collabora is being access by both the client and the Nextcloud server.
