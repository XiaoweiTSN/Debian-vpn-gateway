#!/bin/bash
cat > /etc/network/interfaces <<EOF
auto lo
iface lo inet loopback

auto ens33
iface ens33 inet static
    address 192.168.137.100
    netmask 255.255.255.0
    gateway 192.168.137.1
    dns-nameservers 26.26.26.53

auto ens37
iface ens37 inet static
    address 192.168.0.123
    netmask 255.255.255.0
EOF

echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
sysctl -p

apt update
apt install iptables dnsmasq iptables-persistent -y

iptables -t nat -F
iptables -F
iptables -t nat -A POSTROUTING -s 192.168.0.0/24 -o ens33 -j MASQUERADE
iptables -A FORWARD -i ens37 -o ens33 -j ACCEPT
iptables -A FORWARD -i ens33 -o ens37 -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables-save > /etc/iptables/rules.v4

cat > /etc/dnsmasq.conf <<EOF
listen-address=127.0.0.1,192.168.0.123
server=26.26.26.53
no-resolv
cache-size=500
EOF

systemctl restart dnsmasq
systemctl enable dnsmasq

echo "✅ VPN 网关配置完成，建议重启系统"
