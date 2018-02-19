#!/bin/bash -ex

# Make sure the Riak cluster is stopped
sudo /usr/sbin/riak stop
# Change IP from 127.0.0.1 to whatever the eth0 ip is
my_ip=`ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1'`
sed -i -e "s|127.0.0.1|$my_ip|" /etc/riak/app.config
sed -i -e "s|127.0.0.1|$my_ip|" /etc/riak/vm.args
# Get rid of old info that is stored on the node
sudo rm -rf /var/lib/riak/ring/*
# Now start
sudo /usr/sbin/riak start
sudo /usr/sbin/riak-admin cluster replace riak@127.0.0.1 "riak@$my_ip"
# If you are not the first node, join the party.
if [ -n "$1" ] ; then
  sudo /usr/sbin/riak-admin cluster join "riak@$1"
  sudo /usr/sbin/riak-admin cluster plan
  sudo /usr/sbin/riak-admin cluster commit
fi
