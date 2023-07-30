# Disclaimer

This is a work in progress and the first usable version is not yet available.

# About the project

This project proposes the use of Docker stacks to host all the services of a home server. It provides configuration, backup, security and monitoring tools for the host, as well as reference Docker stacks for setting up common services.

# Hardware architecture
```mermaid
flowchart TB;
    subgraph salad-server["Salad server"];
        subgraph ssd["system SSD"];
            main-server["/srv"];
            app-data["/srv/app-data"];
            app-data-infra["/srv/app-data-infra"];
            backups-ssd["/var/app-backups"];
            logs["/var/logs"];
        end;
        subgraph hdd-raid5["HDD RAID5"];
            hdd-content["/app-backups\n/some-data"];
        end;
        app-data--"archive\nlogarithmic sheme"-->backups-ssd;
        app-data-infra--"archive\nlogarithmic sheme"-->backups-ssd;
        backups-ssd--"rsync\nonce a week"-->hdd-content;
    end;
    subgraph remote-computer["remote computer"];
        subgraph backup-disk["backup disk"];
            remote-content["/app-backups\n/some-data"];
        end;
    end;
    hdd-raid5--"rsync\nonce a month"-->backup-disk;
```
