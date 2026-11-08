# Compose file
- Change POSTGRES_PASSWORD

# Install Zabbix agent2 on the host

```bash
# Adapted from the procedure from https://www.zabbix.com/ to install Zabbix agent2.
# Replace with your OS version and the Zabbix version you are using in the compose file.
# Install Zabbix repository.
wget https://repo.zabbix.com/zabbix/8.0/release/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_8.0+ubuntu26.04_all.deb
dpkg -i zabbix-release_latest_8.0+ubuntu26.04_all.deb
apt update
apt install zabbix-agent2
apt install zabbix-agent2-plugin-mongodb zabbix-agent2-plugin-mssql zabbix-agent2-plugin-postgresql
systemctl restart zabbix-agent2
systemctl enable zabbix-agent2
```

# Configure the agent

```bash
# Import the custom configuration file that is in the src subdir.
# Check that "Include=/etc/zabbix/zabbix_agent2.d/*.conf" is in /etc/zabbix/zabbix_agent2.conf
/etc/zabbix/zabbix_agent2.d/custom.conf

# Allow user to Docker group.
sudo usermod -aG docker zabbix

# Allow sudo commands for some scripts.
visudo
# Add this line.
zabbix ALL=(ALL) NOPASSWD:/opt/salad-server/scripts/check-all-disks-health.sh, NOPASSWD:/opt/salad-server/scripts/check-docker-containers.sh, NOPASSWD:/opt/salad-server/scripts/check-mdadm.sh

# Add the RME table widget to Zabbix web.
# Go to zabbix-web/modules directory from the host.
git clone -b main https://github.com/gryan337/zabbix-widgets-table \
  /usr/share/zabbix/modules/zabbix-widgets-table
```

# Configure Zabbix web

Connect to the web interface:
- Change the default password
- Enable RME Table in Administration > General
- Import src/zabbix-salad-server-templates.yml in Data collection > Templates
- Import src/zabbix-salad-server-dashboard.yml in Dashboards
