```
#!/bin/bash
#
########################################################
#
#    脚本名称：iptables.sh
#
#    功    能: Setup Iptables Rules
#
#    用    法: bash iptables.sh
#
#    作    者: Jerry
#
#    日    期: ####/##/##
#
########################################################
#

modprobe ipt_MASQUERADE
modprobe ip_conntrack_ftp
modprobe ip_nat_ftp

/sbin/iptables -F
/sbin/iptables -X
/sbin/iptables -t nat -F
/sbin/iptables -t nat -X

/sbin/iptables -P INPUT  DROP
/sbin/iptables -P FORWARD ACCEPT
/sbin/iptables -P OUTPUT ACCEPT

/sbin/iptables -A INPUT -i lo -j ACCEPT
/sbin/iptables -A INPUT -p icmp -j ACCEPT
/sbin/iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

/sbin/iptables -A INPUT -p tcp -s ###.###.###.###/24 -m comment --comment "开放内网间访问" -j ACCEPT
/sbin/iptables -A INPUT -p tcp -s ###.###.###.### -m comment --comment "公司办公室网络" -j ACCEPT

######################### GATEWAY SETTING ###########################
/sbin/iptables -t nat -A POSTROUTING -s 0/0 -m comment --comment "内网转换外网" -j MASQUERADE
#####################################################################

service iptables save
#(END)
```