#!/bin/bash

# this script set up iptables based on various rules





##################################################
# allowed network trafic flow parameters
##################################################

# zones definition
zonesList=(public private admin)

##################################################

# public zone
publicNet=(0.0.0.0/0)
publicTCP=()
publicUDP=()

##################################################

# private zone
privateNet=(192.168.10.0/24 192.168.27.80)
privateTCP=()
privateUDP=()

##################################################

# admin zone
# raphael-desktop-ubuntu raphael-freebox-vpn
adminNet=(192.168.0.120 192.168.27.80 82.64.219.199 90.83.243.181)
# ssh
adminTCP=(22)
adminUDP=()

###################################################





# first flush previous configuration
iptables -F

# set up configuration as described in trafic flow parameters
for zone in ${zonesList[*]}; do
	network=${zone}Net[*]
	tcpPorts=${zone}TCP[*]
	udpPorts=${zone}UDP[*]

	for ipSrc in ${!network};do
		for port in ${!tcpPorts};do
			ipDest=$( echo $port | grep -Po '.*(?=:)' )
			if [ $? -eq 0 ]; then
				port=$( echo $port | grep -Po '(?<=:).*' )
				iptables -I INPUT -p tcp --dport $port -s $ipSrc -d $ipDest -j ACCEPT
			else
				iptables -I INPUT -p tcp --dport $port -s $ipSrc -j ACCEPT
			fi
		done
		for port in ${!udpPorts};do
			ipDest=$( echo $port | grep -Po '.*(?=:)' )
			if [ $? -eq 0 ]; then
				port=$( echo $port | grep -Po '(?<=:).*' )
				iptables -I INPUT -p udp --dport $port -s $ipSrc -d $ipDest -j ACCEPT
			else
				iptables -I INPUT -p udp --dport $port -s $ipSrc -j ACCEPT
			fi
		done
	done
done

# allow initiated and accepted connection to bypass rule checking
iptables -I INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# allow unlimited traffic on the loopback interface
iptables -I INPUT -i lo -j ACCEPT

# Drop ICMP echo-request messages sent to broadcast or multicast addresses
echo 1 > /proc/sys/net/ipv4/icmp_echo_ignore_broadcasts

# Drop source routed packets
echo 0 > /proc/sys/net/ipv4/conf/all/accept_source_route

# Enable TCP SYN cookie protection from SYN floods
echo 1 > /proc/sys/net/ipv4/tcp_syncookies

# Don't accept ICMP redirect messages
echo 0 > /proc/sys/net/ipv4/conf/all/accept_redirects

# Don't send ICMP redirect messages
echo 0 > /proc/sys/net/ipv4/conf/all/send_redirects

# Enable source address spoofing protection
echo 1 > /proc/sys/net/ipv4/conf/all/rp_filter

# Log packets with impossible source addresses
echo 1 > /proc/sys/net/ipv4/conf/all/log_martians

# drop all other traffic
iptables -A INPUT -j DROP
iptables --policy INPUT DROP

# finally display the configuration set
iptables -L INPUT --line-numbers
systemctl restart iptables
echo "to make rules persistents: /etc/init.d/netfilter-persistent save"
