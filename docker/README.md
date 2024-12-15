# Overview

The Debian host OS do not provides any network service by itself.
Each independent service is managed by a docker stack, making it easier to manage.

| Stack type    | Stack name | Description                                                    |
|---------------|------------|----------------------------------------------------------------|
| DNS provider  | duckdns    | Agent checking your public IP to keep your DNS name up to date |
| HTTP service  | jellyfin   | Private streaming web interface for your media                 |
| reverse proxy | caddy      | HTTPS redirects traffic to HTTP services using subdomains      |

# Common guideline

Each stack have it's own README file to follow.
Everything is based on free to use services.
Each stack directory contains the services persistent data.
On a high level stack management are done with these commands:

```bash
# Start a stack.
cd docker/<stack name>  # You must be in the stack directory to start it.
vim docker-compose.yml  # Check/edit parameters.
docker compose up -d

# Stop a stack.
cd docker/<stack name>
docker compose down
```
