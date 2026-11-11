# Overview

HTTPS redirects traffic to HTTP services using subdomains
([Reference documentation](https://hub.docker.com/_/caddy)).

# Configuration

Update the compose file to comment unused HTTP services.
You will need to update the _services.caddy.networks_ and the _networks_ sections.
Check the port binding fits to you 8443, e.g. you will use https://zabbix.salad.local:8443

Update the Caddyfile to comment unused HTTP services.
Check the default IP whitelist fits to you 192.168.0.0/16

# Client configuration
Start once Caddy and get the internal root.crt in _data/caddy/pki/authorities/local/root.crt_
Install this root certificate in your browser.
In Firefox it in _about:preferences#connectionSecurity_ > Certificates > Manage certificates > Import

Add local third-level DNS entries in your device or router.
In Linux _/etc/hosts_ , in Windows _C:\Windows\System32\drivers\etc_ add this line:
192.168.0.100 zabbix.salad.local
With the IP of your host, for each service you expose internally.
