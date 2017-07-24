#!/bin/sh
# firewall      Start iptables firewall
# chkconfig: 2345 08 92
# description:  Starts, stops and saves iptables firewall
# This script sets up the firewall for the INPUT chain (which is for
# the HN itself) and then processes the config files under
# /etc/firewall.d to set up additional rules in the FORWARD chain
# to allow access to containers' services.

#. /etc/init.d/functions

# History
# 20120928 Miguel Flores 

# the IP block allocated to this server
SEGMENT="192.168.254/24"
# the IP used by the hosting server itself
THISHOST="192.168.254.200"
# services that should be allowed to the HN;
# services for containers are configured in /etc/firewall.d/*
OKPORTS="22 53"
# hosts allowed full access through the firewall,
# to all containers and to this server
DMZS="192.168.254.12 192.168.254.18 192.168.254.21"

DMZSTEMP="192.168.30.1"

BLACKLIST="192.168.100.1"

purge() {
    echo -n "Firewall: Purging and allowing all traffic... "
    /sbin/iptables -P OUTPUT ACCEPT
    /sbin/iptables -P FORWARD ACCEPT
    /sbin/iptables -P INPUT ACCEPT
    /sbin/iptables -F
    echo "Done!"
}

setup() {
    echo -n "Firewall: Setting default policies to DROP... "
    /sbin/iptables -P INPUT DROP
    /sbin/iptables -P FORWARD DROP
    /sbin/iptables -I INPUT   -j ACCEPT -m state --state ESTABLISHED,RELATED
    /sbin/iptables -I FORWARD -j ACCEPT -m state --state ESTABLISHED,RELATED
    /sbin/iptables -I INPUT -j ACCEPT -i lo
    /sbin/iptables -I FORWARD -j ACCEPT --source $SEGMENT
    echo "Done!"
    
    echo "Firewall: Allowing access to Host..."
    /sbin/iptables -A INPUT -p icmp -j ACCEPT
    /sbin/iptables -A INPUT -p tcp -j ACCEPT -d $THISHOST --destination-port 32277
    /sbin/iptables -A INPUT -p tcp -j ACCEPT -d $THISHOST --destination-port 45200
    
    for port in $OKPORTS ; do
        echo -n "          port $port"
        /sbin/iptables -I INPUT -j ACCEPT -s $SEGMENT -d $THISHOST --protocol tcp --destination-port $port
        /sbin/iptables -I INPUT -j ACCEPT -s $SEGMENT -d $THISHOST --protocol udp --destination-port $port
        echo " Done!"
    done
    
    for ip in $DMZS ; do
        echo -n "       DMZ $ip"
        /sbin/iptables -I INPUT   -i vmbr0 -j ACCEPT -s $ip
        /sbin/iptables -I FORWARD -i vmbr0 -j ACCEPT -s $ip
        echo " Done!"
    done
    
    for ip in $DMZSTEMP ; do
        echo -n "       DMZ TEMP $ip"
        /sbin/iptables -I INPUT   -i vmbr0 -j ACCEPT -s $ip
        /sbin/iptables -I FORWARD -i vmbr0 -j ACCEPT -s $ip
        echo " Done!"
    done
    
    CTSETUPS=`echo /etc/firewall.d/*`
    
    if [ "$CTSETUPS" != "/etc/firewall.d/*" ] ; then
        echo "Firewall: Setting up container firewalls... "
        for i in $CTSETUPS ; do
            . $i
            echo -n "          $CTNAME CT$CTID"
            
            if [ -n "$BLACKLIST" ]; then
                for ip in $BLACKLIST; do /sbin/iptables -I FORWARD -j DROP --source $ip ; done
            fi
            
            if [ -n "$BANNED" ]; then
                for source in $BANNED ;  do /sbin/iptables -I FORWARD -j DROP --destination $CTIP --source $source ; done
            fi
            
            if [ -n "$OPENPORTS" ]; then
                #for port in $OPENPORTS ; do /sbin/iptables -I FORWARD -j ACCEPT --protocol tcp --destination $CTIP --destination-port $port ; done
                #for port in $OPENPORTS ; do /sbin/iptables -I FORWARD -j ACCEPT --protocol udp --destination $CTIP --destination-port $port ; done
                for port in $OPENPORTS ; do /sbin/iptables -I FORWARD -j ACCEPT --protocol tcp --destination $CTIP --destination-port $port --syn -m state --state NEW -m limit --limit 100/minute --limit-burst 50 ; done
                for port in $OPENPORTS ; do /sbin/iptables -I FORWARD -j ACCEPT --protocol udp --destination $CTIP --destination-port $port --syn -m state --state NEW -m limit --limit 100/minute --limit-burst 50 ; done
                for port in $OPENPORTS ; do /sbin/iptables -I FORWARD -j ACDEPT --protocol tcp --destination $CTIP --destination-port $port -m state --state RELATED,ESTABLISHED -m limit --limit 100/minute --limit-burst 50 ; done
                for port in $OPENPORTS ; do /sbin/iptables -I FORWARD -j ACDEPT --protocol udp --destination $CTIP --destination-port $port -m state --state RELATED,ESTABLISHED -m limit --limit 100/minute --limit-burst 50 ; done
            fi
            
            if [ -n "$DMZS" ]; then
                for source in $DMZS ; do /sbin/iptables -I FORWARD -j ACCEPT --protocol tcp --destination $CTIP --source $source ; done
                for source in $DMZS ; do /sbin/iptables -I FORWARD -j ACCEPT --protocol udp --destination $CTIP --source $source ; done
            fi
            
            if [ -n "$DMZSTEMP" ]; then
                for sourcetemp in $DMZSTEMP ; do /sbin/iptables -I FORWARD -j ACCEPT --protocol tcp --destination $CTIP --source $sourcetemp ; done
                for sourcetemp in $DMZSTEMP ; do /sbin/iptables -I FORWARD -j ACCEPT --protocol udp --destination $CTIP --source $sourcetemp ; done
            fi
            
            /sbin/iptables -I FORWARD -j ACCEPT --protocol icmp  --destination $CTIP 
            /sbin/iptables -I FORWARD -j ACCEPT --protocol esp --destination $CTIP
            /sbin/iptables -I FORWARD -j ACCEPT --protocol ah --destination $CTIP
            
            echo " Done!"
            
        done
    fi
}

case "$1" in
    start)
        echo "Starting firewall... "
        purge
        setup
        exit 0
        ;;
    stop)
        echo "Stopping firewall... (actually starting!) "
        purge
        setup
        exit 0
        ;;
    flush)
        purge
        exit 0
        ;;
    status)
        /sbin/iptables -n -L
        ;;
    *)
        echo "Usage: $0 <start|stop|flush|status>"
        ;;
esac
