# Overview

HTTPS redirects traffic to HTTP services using subdomains
([Reference documentation](https://hub.docker.com/_/caddy)).

# Prerequisite

You need a full IPV4 (all ports available or at least 80 and 443).
You do not need a static IPV4 as DuckDNS handles dynamic IPV4.
You need to redirect 80/TCP and 443/TCP-UDP to your server in your ISP router.
Start first HTTP services you want (i.e. jellyfin).

# Configuration

Update the compose file to comment unused HTTP services.
You will need to update the _services.caddy.networks_ and the _networks_ sections.

Update the Caddyfile to comment unused HTTP services.
