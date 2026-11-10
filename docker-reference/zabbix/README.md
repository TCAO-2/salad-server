# Compose file
- Change POSTGRES_PASSWORD

# Install Zabbix agent2 on the host

```bash
# Adapted from the procedure from https://www.zabbix.com/download to install Zabbix agent2.
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
cp src/custom.conf /etc/zabbix/zabbix_agent2.d/custom.conf
systemctl daemon-reload
systemctl restart zabbix-agent2

# Allow user to Docker group.
usermod -aG docker zabbix

# Allow sudo commands for some scripts.
apt install sudo
visudo
# Add this line.
zabbix ALL=(ALL) NOPASSWD:/opt/salad-server/scripts/check-all-disks-health.sh, NOPASSWD:/opt/salad-server/scripts/check-docker-containers.sh, NOPASSWD:/opt/salad-server/scripts/check-mdadm.sh

# Add the RME table widget to Zabbix web.
# Go to zabbix-web/modules directory from the host.
git clone -b main https://github.com/gryan337/zabbix-widgets-table zabbix-web/modules/
```

# Configure Zabbix web

Connect to the web interface (default login Admin password zabbix):
- Change the default password in User settings > Profile
- Scan directory and Enable RME Table in Administration > General > Modules
- Import src/zabbix-salad-server-templates.yml in Data collection > Templates
- Go to Data collection > Hosts and change the interface to the IP address of the host then add salad-server template to Zabbix server
- Go to Dashboards and import src/zabbix-salad-server-dashboard.yml
- Change the network interfaces in the network widget for yours   
