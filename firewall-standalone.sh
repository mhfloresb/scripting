#!/bin/bash
# version v0.8
# firewall	  Start iptables firewall
# chkconfig: 2345 08 92
# description:  Starts, stops and saves iptables firewall
# This script sets up the firewall for the INPUT chain (which is for
# the HN itself) and then processes the config files under
# /etc/firewall.d to set up additional rules in the FORWARD chain
# to allow access to containers' services.

#. /etc/init.d/functions

# History
# 20120928 Miguel Flores 
# 20130128 Fabrizio Cabaleiro
# 20131216 Miguel Flores: modificación para funcionamiento standalone.

####################
# Global Variables #
####################
IPTABLES=$(whereis iptables | awk '{for(i=1; i < NF; i++)if($i == "/usr/sbin/iptables" || $i == "/sbin/iptables") print $i}')
debug="0"

# Variables for iptables

# The IP block allocated to this server
# There can be multiples IPs separated by a ","
# Example: SEGMENT="192.168.14.105/20,193.168.15.20/24"
SEGMENT="192.168.0.0/16"

# The IP used by the hosting server itself
THISHOST="192.168.15.214"

# services that should be allowed to the HN;
# services for containers are configured in /etc/firewall.d/*
# each OK Ports must be separated for a single comma
OKPORTS="32277,45200"

# hosts allowed full access through the firewall,
# to all containers and to this server
# each IP[/mask] is separated by one or multiples spaces
# example DMZS="192.168.14.100/24 192.168.3.3/32"
DMZS=""

# Similar to DMZS but for temporal cases
DMZSTEMP=""

# List of IPs to block, each one separated by a single or multiples spaces
BLACKLIST=""

# interfaces
PUBLIC="eth0"

# Yellow net
PRIVATE="eth1"

# Limits for Graphic and Access Control
# NLR = New Limit Rate
# ELR = Established/related Limit Rate
NLR="300/minute"
NLB="300"
ELR="1200/minute"
ELB="600"

#############
# Functions #
#############
function cmd
{
	echo $*
	if test $debug -ne 1
	then
		$*
	fi
}

function cleanlv
{
	CTID=""
	CTNAME=""
	CTIP=""
	PORTS=""
	DMZS=""
	DMZSTEMP=""
	EXCLUSIVE=""
	BLACKLIST=""
	nrate=""
	irate=""
}

function checkgv
{
	if test -z "$SEGMENT" -o -z "$THISHOST"
	then
		echo -e "\t\e[1;41mSEGMENT or THISHOST not set\e[1;0m"
		exit
	fi
}

function checklv
{
	if test -z "$CTID" 
	then
		echo -e "\t\e[1;41mLocal variable CTID in $1 not defined\e[1;0m"
		exit
	fi
	if test -z "$CTNAME" 
	then
		echo -e "\t\e[1;41mLocal variable CTNAME in $1 not defined\e[1;0m"
		exit
	fi
	if test -z "$CTIP"
	then
		echo -e "\t\e[1;41mLocal variable CTIP in $1 not defined\e[1;0m"
		exit
	fi
}

setupfw() 
{
	# Last rule does a drop of everything that didn't match
	echo -e "\t\e[1;31mSetting default policies to ACCEPT\e[1;0m" 
	cmd $IPTABLES -P INPUT ACCEPT
	cmd $IPTABLES -P FORWARD ACCEPT

	echo -e "\t\e[1;31mYellow net\e[1;0m"
    for PRIVATE in $PRIVATE
    do
        cmd $IPTABLES -A INPUT  --in-interface  $PRIVATE -j ACCEPT
        cmd $IPTABLES -A OUTPUT --out-interface $PRIVATE -j ACCEPT
    done

	echo -e "\t\e[1;31mDemilitarized Zone\e[1;0m"
	for ip in $DMZS $DMZSTEMP 
	do
		cmd $IPTABLES -A INPUT   --in-interface $PUBLIC -j ACCEPT --source $ip
	done
	   
	echo -e "\t\e[1;31mBlack List for Host\e[1;0m"
	for ip in $BLACKLIST 
	do 
		cmd $IPTABLES -A INPUT  -j DROP --source      $ip
		cmd $IPTABLES -A OUTPUT -j DROP --destination $ip
	done

	echo -e "\t\e[1;31mInternal Connections\e[1;0m"
	cmd $IPTABLES -A INPUT -j ACCEPT -i lo
	cmd $IPTABLES -A INPUT -j ACCEPT --source $SEGMENT
	
	echo -e "\t\e[1;31mAllowing access to Host\e[1;0m"
	cmd $IPTABLES -A INPUT -p icmp -j ACCEPT
	
	echo -e "\t\e[1;31mGraphics\e[1;0m"
	cmd $IPTABLES -A INPUT -j ACCEPT --protocol tcp --destination $THISHOST --destination-port 45200 -m state --state NEW -m limit --limit $NLR --limit-burst $NLB
	cmd $IPTABLES -A INPUT -j ACCEPT --protocol tcp --destination $THISHOST --destination-port 45200 -m state --state RELATED,ESTABLISHED -m limit --limit $ELR --limit-burst $ELB
	
	echo -e "\t\e[1;31mSegment, Ports $OKPORTS\e[1;0m"
	cmd $IPTABLES -A INPUT -j ACCEPT --destination $THISHOST --protocol tcp -m multiport --destination-ports $OKPORTS
	cmd $IPTABLES -A INPUT -j ACCEPT --destination $THISHOST --protocol udp -m multiport --destination-ports $OKPORTS
	
	# Rules for every virtual machine
	echo -e "\n\t\e[1;31mSetting up rules for each container\e[1;0m"
	for conf in $CTSETUPS  
	do
		cleanlv       # Clean local variables
		. $conf       # Load  local variables
		checklv $conf # Check local variables
		echo -e "\t\e[1;31m$CTNAME CT $CTID\e[1;0m"
		
		if [ -n "$DMZS" ] || [ -n "$DMZSTEMP" ]
		then
			echo -e "\t\e[1;31mDemilitarized zone for container $CTID \"$CTNAME\"\e[1;0m"
			for source in $DMZS $DMZSTEMP  
			do 
				cmd $IPTABLES -A INPUT -j ACCEPT --protocol tcp --destination $CTIP --source $source 
				cmd $IPTABLES -A INPUT -j ACCEPT --protocol udp --destination $CTIP --source $source
			done
		fi
			
		echo -e "\t\e[1;31mBlack List for $CTNAME\e[1;0m"
		if [ -n "$BLACKLIST" ]
		then
			for ip in $BLACKLIST 
			do 
				cmd $IPTABLES -A INPUT -j DROP --source $ip --destination $CTIP 
				cmd $IPTABLES -A OUTPUT -j DROP --source $CTIP --destination $ip 
			done
		fi

		if [ -n "$EXCLUSIVE" ]
		then
			echo -e "\t\e[1;31mExclusive Access for container $CTID \"$CTNAME\"\e[1;0m"
			for ex in $EXCLUSIVE 
			do
				TIP=${ex%%;*}
				TPORT=${ex#*;}
				cmd $IPTABLES -A INPUT -j ACCEPT --protocol tcp --destination $CTIP --destination-port $TPORT --source $TIP 
				cmd $IPTABLES -A INPUT -j ACCEPT --protocol udp --destination $CTIP --destination-port $TPORT --source $TIP 
			done
		fi
	
		echo -e "\t\e[1;31mDefault open protocols for container $CTID \"$CTNAME\"\e[1;0m"
		cmd $IPTABLES -A INPUT -j ACCEPT --protocol icmp  --destination $CTIP 
		cmd $IPTABLES -A INPUT -j ACCEPT --protocol esp   --destination $CTIP
		cmd $IPTABLES -A INPUT -j ACCEPT --protocol ah	--destination $CTIP
		
		IFSBU=$IFS  # back up current IFS value
		if [ -n "$PORTS" ]
		then
			echo -e "\t\e[1;31mOpen Ports with limits for container $CTID \"$CTNAME\"\e[1;0m"
			IFS=';'
			for p in $PORTS 
			do
				IFS=$IFSBU
				parr=($p)   # port elements to array
				crule="--destination $CTIP --destination-port ${parr[0]} -m limit --limit ${parr[1]}/second --limit-burst ${parr[2]}" # common rule
				cmd $IPTABLES -A INPUT -j ACCEPT --protocol tcp $crule -m state --state NEW 
				cmd $IPTABLES -A INPUT -j ACCEPT --protocol udp $crule -m state --state NEW
				cmd $IPTABLES -A INPUT -j ACCEPT --protocol tcp $crule -m state --state RELATED,ESTABLISHED 
				cmd $IPTABLES -A INPUT -j ACCEPT --protocol udp $crule -m state --state RELATED,ESTABLISHED
			done
		fi
	done

	echo -e "\t\e[1;31mAccept ESTABLISHED,RELATED connections\e[1;0m"
	cmd $IPTABLES -A INPUT   -j ACCEPT -m state --state ESTABLISHED,RELATED
	cmd $IPTABLES -A FORWARD   -j ACCEPT -m state --state ESTABLISHED,RELATED

	echo -e "\t\e[1;31mIf it didn't match any other rule, then DROP\e[1;0m"
	cmd $IPTABLES -A INPUT -j DROP
	cmd $IPTABLES -A FORWARD -j DROP
}

function purgefw
{
	# Set policy to ACCEPT and flush iptables
	echo -e "\t\e[1;31mAllowing and Purging all traffic\e[1;0m"
	cmd $IPTABLES -P OUTPUT ACCEPT
	cmd $IPTABLES -P FORWARD ACCEPT
	cmd $IPTABLES -P INPUT ACCEPT
	cmd $IPTABLES -F
}

#########
# Usage #
#########
case "$1" in
	start)
		echo -e "\t\e[1;36mStarting firewall\e[1;0m"
		checkgv
		CTSETUPS=$(find /etc/firewall.d -name "*.conf")
		purgefw    # start begins with a flush to satisfy some requirements coming from CC
		setupfw
		;;
	status)
		echo -e "\t\e[1;36mFirewall status\e[1;0m"
		checkgv
		cmd $IPTABLES -n -L
		;;
	reload)
		echo -e "\t\e[1;36mReloading firewall\e[1;0m"
		checkgv
		CTSETUPS=$(find /etc/firewall.d -name "*.conf")
		purgefw
		setupfw
		;;
	stop)         # stop and then restart, this behavior is to satisfy heartbeat
		echo -e "\t\e[1;36mStoping and Starting firewall\e[1;0m"
		checkgv
		purgefw
		setupfw
		;;
	flush)         # stop and then restart, this behavior is to satisfy heartbeat
		echo -e "\t\e[1;36mFlushing firewall\e[1;0m"
		purgefw
		;;
	test)
		echo -e "\t\e[1;36mTesting firewall\e[1;0m"
		checkgv
		CTSETUPS=$(find /etc/firewall.d -name "*.conf")
		debug="1"
		setupfw
		;;
	*)
		echo -e "Usage:\t$0 { start | stop | flush | reload | status | test}"
		;;
esac
