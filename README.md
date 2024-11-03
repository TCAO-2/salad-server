# Disclaimer

This is a work in progress and the first usable version is not available yet.

# Introduction

This repository contains the source to install a minimalist home server
running Docker with a few side features.
- Software RAID
- Automatic backups of Docker services
- Automatic updates of the host and Docker services
- Hardware and software monitoring with e-mail alerts
- Highly customizable with your own Docker stacks

# Provided Docker stacks overview

You can run these stacks out of the box included in the repository.

| Name          | Description                                                |
|---------------|------------------------------------------------------------|
| reverse-proxy | DNS and HTTPS for web services, based on Caddy and DuckDNS |

# Repository overview

Every directory has its own README file.

| Folder name | Description                                                    |
|-------------|----------------------------------------------------------------|
| dev-utils   | Helper material used during development                        |
| docker      | All Docker stacks you can run, including their persistent data |
| install     | Server installation scripts                                    |
| scripts     | Routine and events scripts                                     |

# Server administration

- Connection using noroot SSH user, then switch to the root user
- Every Docker stack is described in a compose file, use __docker compose up__ or __docker compose down__ commands to run or stop a stack
- Every host routine is triggered by CRON
- RAID events are triggering __scripts/raid-event.sh__
