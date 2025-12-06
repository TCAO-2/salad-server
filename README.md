# Introduction

I used to run Open Media Vault as my server OS since it was initially a NAS.
I gradually added extra services and created more and more custom routines
on top of Open Media Vault and it quickly became messy.

Then I decided to run a simpler and more coherent design on top of Docker,
easy to maintain, to update, to rollback and security oriented.

## Features

- Software RAID for data  (mdamdm)
- Automatic updates of the host (unattended-upgrades)
- Multi transport centralized logging (console and files)
- Simply start, stop, update, rollback any guest service on demand with Docker
- Customizable with your own Docker stacks and routine scripts
- Currently available Docker stacks out of the box:
  - SMB (Windows file share)
  - DuckDNS (DNS agent)
  - Caddy (HTTPS reverse proxy)
  - Jellyfin (Private streaming web service)
  - Minecraft server

## To do

- Automatic updates and backup of the guests Docker stacks
- Hardware and software monitoring with e-mail alerts

# Directory structure

```
/opt/salad-server       (this Git repository)
  |- dev-utils          (development stuff)
  |- docker             (run docker stacks)
  |- docker-reference   (reference docker stacks)
  |- install            (host installation)
  `- scripts            (host routines and helper scripts)

/mnt/data               (data directory i.e. probably a RAID array)
  `- salad-server       (Docker stacks backups)

/var/log/salad-server   (files transport logs)

/tmp/salad-server       (temporary directory for backups)
```
Each top level folder in this directory have it's own README file.

# Server administration overview

- Connection using noroot SSH user, then switch to the root user
- Install a new Docker stack is simply as copying a reference folder, uninstall it is
simply as removing a folder
- Every Docker stack is described in a compose file, use __docker compose up__ or __docker compose down__ commands to run or stop a stack
- Every host routine is triggered by CRON
- RAID events are triggering __scripts/raid-event.sh__
