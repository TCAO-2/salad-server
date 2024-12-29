# Introduction

I used to run Open Media Vault as my server OS since it was initially a NAS.
I gradually added extra services and created more and more custom routines
on top of Open Media Vault and it quickly became messy.

Then I decided to run a simpler and more coherent design, without specific code
for each service and more security oriented.

## Features

- Software RAID for data
- Automatic updates of the host
- Multi transport centralized logging (console and files)
- Flexible, start or stop any guest service on demand with Docker
- Customizable with your own Docker stacks and routine scripts
- Currently available stacks out of the box:
  - samba (Windows file share)
  - duckdns, caddy, jellyfin (Private streaming web service with HTTPS and domain name)

## To do

- Automatic updates and backup of the guests Docker stacks
- Hardware and software monitoring with e-mail alerts

# Repository structure

Each folder have it's own README file.

| Folder    | Description                                               |
|-----------|-----------------------------------------------------------|
| dev-utils | Development stuff, unit tests and virtualization material |
| docker    | Guest services definition and persistent data             |
| install   | Host installation                                         |
| scripts   | Host side routines, backup, monitoring and so one         |

# Server administration overview

- Connection using noroot SSH user, then switch to the root user
- Every Docker stack is described in a compose file, use __docker compose up__ or __docker compose down__ commands to run or stop a stack
- Every host routine is triggered by CRON
- RAID events are triggering __scripts/raid-event.sh__
