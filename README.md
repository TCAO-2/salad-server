# Disclaimer

This is a work in progress and the first usable version is not yet available.

# Introduction

This project proposes the use of Docker stacks to host all the services of a home server. It provides configuration, backup and monitoring tools for the host, as well as reference Docker stacks for setting up predefined common services.
Included features:
- Software RAID5 with hot swap and automated spare support
- Automated backups of services data with recent versions history
- Automated updates for both host and Docker services
- Hardware and software monitoring with automated e-mail alert
- Automated DNS with subdomains and HTTPS support for web services
- SMB service for private network use
- Flexible and simple upgrades using Docker stacks

# Data architecture

```mermaid
flowchart LR
    subgraph salad-server["Salad server"]
        subgraph ssd["system SSD"]
            main-server["/srv/salad-server"]
            app-data["/srv/salad-server/app-data"]
            app-data-infra["/srv/salad-server/app-data-infra"]
            backups-ssd["/var/app-backups"]
            logs["/var/logs"]
        end
        subgraph hdd-raid5["HDD RAID5"]
            hdd-content["/app-backups\n/some-data"]
        end
        app-data--"hot archive\nlogarithmic sheme"-->backups-ssd
        app-data-infra--"hot archive\nlogarithmic sheme"-->backups-ssd
        backups-ssd--"cold rsync\nonce a week"-->hdd-content
    end
    subgraph remote-computer["remote computer"]
        subgraph backup-disk["backup disk"]
            remote-content["/app-backups\n/some-data"]
        end
    end
    hdd-content--"cold rsync\nonce a month"-->remote-content
```
# Network architecture

Each service has a reduced connection to the network, in particular:
- Excepted the Duckdns service, Docker services cannot access the internet.
- Web services must be accessed through the Caddy reverse-proxy, caddy is the only service to have an IP address in each web service stack network.

```mermaid
flowchart LR
    public["public network"]
    private["private network"]
    subgraph salad-server
        subgraph host["host services"]
            SSHD
        end
        subgraph docker["Docker stacks"]
            subgraph infra-stack["infrastructure stack"]
                subgraph smb-service-network["SMB service network"]
                    SMB
                end
                subgraph duckdns-service-network["Duckdns service network"]
                    Duckdns
                end
                subgraph caddy-service-network["Caddy service network"]
                    Caddy
                end
            end
            subgraph jellyfin-stack-network["Jellyfin stack network"]
                Jellyfin
            end
            subgraph wordpress-stack-network["Wordpress stack network"]
                wordpress-stack-wordpress["Wordpress"]
                wordpress-stack-mariadb["MariaDB"]
            end
            subgraph nextcloud-stack-network["Nextcloud stack network"]
                nextcloud-stack-nextcloud["Nextcloud"]
                nextcloud-stack-mariadb["MariaDB"]
            end
            subgraph minecraft-stack-network["Minecraft stack network"]
                Minecraft
            end
            Caddy-->jellyfin-stack-network
            Caddy-->wordpress-stack-network
            Caddy-->nextcloud-stack-network
        end
    end
    private--"22/TCP"-->SSHD
    private--"139,445/TCP"-->SMB
    public--"443/TCP"-->Caddy
    public--"25565/TCP"-->Minecraft
    public---Duckdns
```
