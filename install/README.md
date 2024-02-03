# Install the Debian distribution from the ISO

- Keep default network settings for the installation (DHCP).
- Create a regular user called _noroot_ or another name but you will need to edit some parameters.
- Do not encrypt the system, guided partitioning, separated _/home_ _/var_ and _/tmp_ partitions.
- Keep only standard system utilities.

---

# Use the installation script

## First execution
- Edit the _install.sh_ script _parameters_ __core__ section:
| Constant name    | Description                                    | Default value |
|------------------|------------------------------------------------|---------------|
| CORE_REGULAR_USR | The main admin user, will have sudo privileges | "noroot"      |

```
# As the root user.
./install.sh core
```

## Second execution
- Edit the _install.sh_ script _parameters_ __SELECTED_COMPONENTS__ parameters and keep only wanted components.
- Edit the _install.sh_ script _parameters_ for each remaining components sections to suit your needs.

### ssh
In order to remote access the server console, you can enable the SSH daemon.
For best security a few measures are taken:
- A "bastion" user is used, this is the only one allowed to login through SSH, then you must switch to the "noroot" user which requires a password.
- The allowed IP range can be changed to reduce the attack surface, default :22/TCP port can also be changed for a non-standard one.
- RSA key usage can be enforced and you must provide your pubkey into ./ssh/authorized_keys file.
- IP tables will be configured to allow connections only from the allowed IP range and will drop anything else. As Docker will add its own rules into IP tables, we do not need further configuration because SSH is the only inbound connection for our server.
- fail2ban will be used to avoid brute force attack. An alert will be triggered to the _monitoring_ component if installed.

| Constant name              | Description                                     | Default value |
|----------------------------|-------------------------------------------------|---------------|
| SSH_AllowUsers             | Allowed to login through SSH and to switch user | "bastion"     |
| SSH_Match_Address name     | Attack surface reduction, range or single IP    | "0.0.0.0/0"   |
| SSH_Port                   |                                                 | "22"          |
| SSH_PasswordAuthentication | If "no", ./ssh/authorized_keys required         | "no"          |

```
su - noroot
./install.sh
```

## Extra executions
You can install particular components for debugging or if you want extra functionalities you may not have already installed.

```
# As the noroot user.
./install.sh <component_name>
# Or display the help for available components.
./install.sh help
```
