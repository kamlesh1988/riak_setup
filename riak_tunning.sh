#!/bin/bash -ex
 
cat >sysctl.conf <<END_OF_FILE
vm.swappiness = 0
net.ipv4.tcp_max_syn_backlog = 40000
net.core.somaxconn=4000
net.ipv4.tcp_timestamps = 0
net.ipv4.tcp_sack = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_tw_reuse = 1
net.core.rmem_default = 8388608
net.core.rmem_max = 8388608
net.core.wmem_default = 8388608
net.core.wmem_max = 8388608
net.core.netdev_max_backlog = 10000
END_OF_FILE
sudo mv sysctl.conf /etc/sysctl.conf
service networking restart

cat >limits.conf <<END_OF_FILE
* soft nofile 32768
* hard nofile 32768
root soft nofile 32768
root hard nofile 32768
* soft memlock unlimited
* hard memlock unlimited
root soft memlock unlimited
root hard memlock unlimited
* soft as unlimited
* hard as unlimited
root soft as unlimited
root hard as unlimited
END_OF_FILE
sudo mv limits.conf /etc/security/limits.conf
sudo chown root:root /etc/security/limits.conf
sudo chmod 755 /etc/security/limits.conf

# echo "{drive} {mountedat} ext4 remount,noatime,barrier=0,data=writeback 0 0" | sudo tee -a /etc/fstab
# echo deadline | sudo tee -a /sys/block/xvda/queue/scheduler
