# Overview

Agent checking your public IP to keep your DNS name up to date
([Reference documentation](https://docs.linuxserver.io/images/docker-duckdns)).

This service is dynamic (will automatically updates your DNS entry if your IP changes)
and supports subdomains creations (mandatory for Caddy)

# Prerequisite

You need to create an account in [the DuckDNS website](https://www.duckdns.org/)
and reserve a subdomain in .duckdns.org for your server.
Then note the provided user token and your subdomain.

# Configuration

Update the following environment in the compose file:
- TZ
- SUBDOMAINS
- TOKEN
