

#### OpenVPN结合FreeOTP和密码做双因子认证

---

- 安装服务端

  ```
  yum -y install ntpdate
  yum -y install openssh-server lzo openssl openssl-devel openvpn NetworkManager-openvpn openvpn-auth-ldap zip unzip
  wget -c https://github.com/OpenVPN/easy-rsa/archive/master.zip -O /etc/openvpn/master.zip
  cd /etc/openvpn && unzip master.zip && rm -f master.zip
  ```

- 安装二维码工具

  ```
  yum install qrencode -y
  ```

- 安装FreeOTP插件

  ```
  /usr/local/python/bin/pip install pyotp
  ```

- 切换目录开始生成服务端证书

  ```
  cd /etc/openvpn/easy-rsa-master/easyrsa3
  \cp -fp vars.example vars
  cat <<EOF >> vars
  set_var EASYRSA_REQ_COUNTRY     "CN"
  set_var EASYRSA_REQ_PROVINCE    "GuangDong"
  set_var EASYRSA_REQ_CITY        "GuangZhuo"
  set_var EASYRSA_REQ_ORG         "SA"
  set_var EASYRSA_REQ_EMAIL       "sa@handl.cn"
  set_var EASYRSA_REQ_OU          "TEC"
  EOF
  ```

- 初始化

  ```
  ./easyrsa init-pki
  ```
  
- 创建CA证书，密码自定义

  ```
  ./easyrsa build-ca
  ```

- 创建服务端证书

  ```
  ./easyrsa build-server-full ${<server>} nopass
  ```

- 生成 Diffie-Hellman 算法

  ```
  ./easyrsa gen-dh
  ```

- 生成防DDOS TLS攻击密钥

  ```
  openvpn --genkey --secret pki/ta.key
  ```

- 生成吊销用户密钥

  ```
  ./easyrsa  gen-crl
  ```

- 设置系统转发

  ```
  sed -i "s#net.ipv4.ip_forward = 0#net.ipv4.ip_forward = 1#g" /etc/sysctl.d/net.ipv4.conf
  sysctl --system
  ```

- 配置iDRAC网段子接口

  ```
  ip addr add 192.168.${<net>}.100/24 broadcast 255.255.255.0 dev eth0 label eth0:0
  ```

- 开放防火墙

  ```
  /sbin/iptables -A INPUT -p tcp -s 192.168.100.0/24 -m comment --comment "开放业务网段互访" -j ACCEPT
  /sbin/iptables -A INPUT -p tcp -s 192.168.108.0/24 -m comment --comment "开放iDRAC远程卡网间互访" -j ACCEPT
  /sbin/iptables -A INPUT -p tcp -s 10.100.0.0/24 -m comment --comment "打开 OpenVPN 网段" -j ACCEPT
  ```

- 启动脚本

  ```
  #!/bin/bash
  # chkconfig: 345 20 80
  # description: openvpn
  #
  ########################################################
  #
  #    脚本名称: openvpn
  #
  #    功    能: 启动、关停 服务
  #
  #    用    法: bash openvpn [<stop>|<start>|<restart>]
  #
  #    作    者: JerryHan
  #
  #    日    期: 2020/06/15
  #
  ########################################################
  #
  _HELP()
  {
      echo
      grep -w "^#    用    法:" < "$0" | cut -c6-
      exit 1
  }
  _START(){
      killall -TERM openvpn
  }
  _STOP(){
      openvpn --daemon --config /etc/openvpn/server.conf
  }
  case ${1} in
      "start")
          _START
          ;;
      "stop")
          _STOP
          ;;
      "restart")
          _STOP
          sleep 2
          _START
          ;;
      "")
          _HELP
          ;;
      *)
          { echo "Invalid Parameter" 2>&1;exit 1; }
          ;;
  esac
  # (END)
  ```

- 服务器配置 /etc/openvpn/server.conf

  ```
  port 1194
  proto tcp
  dev tun
  tls-server
  tls-auth /etc/openvpn/easy-rsa-master/easyrsa3/pki/ta.key 0
  ca /etc/openvpn/easy-rsa-master/easyrsa3/pki/ca.crt
  dh /etc/openvpn/easy-rsa-master/easyrsa3/pki/dh.pem
  crl-verify /etc/openvpn/easy-rsa-master/easyrsa3/pki/crl.pem
  cert /etc/openvpn/easy-rsa-master/easyrsa3/pki/issued/${<server>}.crt
  key /etc/openvpn/easy-rsa-master/easyrsa3/pki/private/${<server>}.key
  #ifconfig-pool-persist /etc/openvpn/ipp.txt
  server 10.100.0.0 255.255.255.0
  push "route 192.168.${<NET1>}.0 255.255.255.0"
  push "route 192.168.${<NET2>}.0 255.255.255.0"
  push "dhcp-option DNS 114.114.114.114"
  client-config-dir ccd
  keepalive 10 120
  comp-lzo
  max-clients 100
  persist-key
  persist-tun
  status /var/log/openvpn-status.log
  verb 3
  
  #### 需求1 需要的配置 ####
  client-config-dir /etc/openvpn/ccd
  
  #### 需求2 需要的配置 ####
  verify-client-cert none
  script-security 2
  username-as-common-name
  auth-user-pass-verify "/usr/local/python/bin/python /etc/openvpn/openvpn-auth-script/auth.py" via-file
  ```

- 客户端配置

  ```
  client
  dev tun
  proto tcp
  remote ${<IPADDRESS1>} 1194
  remote ${<IPADDRESS2>} 1194
  remote-random
  resolv-retry infinite
  remote-cert-tls server
  auth-nocache
  nobind
  persist-key
  persist-tun
  tls-client
  tls-auth    "C:/Program Files/OpenVPN/config/100段/ta.key" 1
  ca          "C:/Program Files/OpenVPN/config/100段/ca.crt"
  comp-lzo
  verb 3
  #### 主要在于区别以下配置 ####
  auth-user-pass
  ```

#### 访问控制

- /etc/openvpn/ccd/handl 以用户名作为文件名生成以下文件

```
#规则命令# #起始IP# #终止IP#
ifconfig-push 10.100.0.65 10.100.0.66
```

- OpenVPN规定使用该配置时子网掩码为255.255.255.252，抛开首个为网络地址，未尾为广播地址外，一个IP分配给客户端，一个IP分配给服务端，如下所示

```
10.100.0.0   , 10.100.0.1   到 10.100.0.2   , 10.100.0.3
10.100.0.4   , 10.100.0.5   到 10.100.0.6   , 10.100.0.7
10.100.0.8   , 10.100.0.9   到 10.100.0.10  , 10.100.0.11
10.100.0.12  , 10.100.0.13  到 10.100.0.14  , 10.100.0.15
10.100.0.16  , 10.100.0.17  到 10.100.0.18  , 10.100.0.19
10.100.0.20  , 10.100.0.21  到 10.100.0.22  , 10.100.0.23
10.100.0.24  , 10.100.0.25  到 10.100.0.26  , 10.100.0.27
10.100.0.28  , 10.100.0.29  到 10.100.0.30  , 10.100.0.31
10.100.0.32  , 10.100.0.33  到 10.100.0.34  , 10.100.0.35
10.100.0.36  , 10.100.0.37  到 10.100.0.38  , 10.100.0.39
10.100.0.40  , 10.100.0.41  到 10.100.0.42  , 10.100.0.43
10.100.0.44  , 10.100.0.45  到 10.100.0.46  , 10.100.0.47
10.100.0.48  , 10.100.0.49  到 10.100.0.50  , 10.100.0.51
10.100.0.52  , 10.100.0.53  到 10.100.0.54  , 10.100.0.55
10.100.0.56  , 10.100.0.57  到 10.100.0.58  , 10.100.0.59
10.100.0.60  , 10.100.0.61  到 10.100.0.62  , 10.100.0.63
10.100.0.64  , 10.100.0.65  到 10.100.0.66  , 10.100.0.67
10.100.0.68  , 10.100.0.69  到 10.100.0.70  , 10.100.0.71
10.100.0.72  , 10.100.0.73  到 10.100.0.74  , 10.100.0.75
10.100.0.76  , 10.100.0.77  到 10.100.0.78  , 10.100.0.79
10.100.0.80  , 10.100.0.81  到 10.100.0.82  , 10.100.0.83
10.100.0.84  , 10.100.0.85  到 10.100.0.86  , 10.100.0.87
10.100.0.88  , 10.100.0.89  到 10.100.0.90  , 10.100.0.91
10.100.0.92  , 10.100.0.93  到 10.100.0.94  , 10.100.0.95
10.100.0.96  , 10.100.0.97  到 10.100.0.98  , 10.100.0.99
10.100.0.100 , 10.100.0.101 到 10.100.0.102 , 10.100.0.103
10.100.0.104 , 10.100.0.105 到 10.100.0.106 , 10.100.0.107
10.100.0.108 , 10.100.0.109 到 10.100.0.110 , 10.100.0.111
10.100.0.112 , 10.100.0.113 到 10.100.0.114 , 10.100.0.115
10.100.0.116 , 10.100.0.117 到 10.100.0.118 , 10.100.0.119
10.100.0.120 , 10.100.0.121 到 10.100.0.122 , 10.100.0.123
10.100.0.124 , 10.100.0.125 到 10.100.0.126 , 10.100.0.127
10.100.0.128 , 10.100.0.129 到 10.100.0.130 , 10.100.0.131
10.100.0.132 , 10.100.0.133 到 10.100.0.134 , 10.100.0.135
10.100.0.136 , 10.100.0.137 到 10.100.0.138 , 10.100.0.139
10.100.0.140 , 10.100.0.141 到 10.100.0.142 , 10.100.0.143
10.100.0.144 , 10.100.0.145 到 10.100.0.146 , 10.100.0.147
10.100.0.148 , 10.100.0.149 到 10.100.0.150 , 10.100.0.151
10.100.0.152 , 10.100.0.153 到 10.100.0.154 , 10.100.0.155
10.100.0.156 , 10.100.0.157 到 10.100.0.158 , 10.100.0.159
10.100.0.160 , 10.100.0.161 到 10.100.0.162 , 10.100.0.163
10.100.0.164 , 10.100.0.165 到 10.100.0.166 , 10.100.0.167
10.100.0.168 , 10.100.0.169 到 10.100.0.170 , 10.100.0.171
10.100.0.172 , 10.100.0.173 到 10.100.0.174 , 10.100.0.175
10.100.0.176 , 10.100.0.177 到 10.100.0.178 , 10.100.0.179
10.100.0.180 , 10.100.0.181 到 10.100.0.182 , 10.100.0.183
10.100.0.184 , 10.100.0.185 到 10.100.0.186 , 10.100.0.187
10.100.0.188 , 10.100.0.189 到 10.100.0.190 , 10.100.0.191
10.100.0.192 , 10.100.0.193 到 10.100.0.194 , 10.100.0.195
10.100.0.196 , 10.100.0.197 到 10.100.0.198 , 10.100.0.199
10.100.0.200 , 10.100.0.201 到 10.100.0.202 , 10.100.0.203
10.100.0.204 , 10.100.0.205 到 10.100.0.206 , 10.100.0.207
10.100.0.208 , 10.100.0.209 到 10.100.0.210 , 10.100.0.211
10.100.0.212 , 10.100.0.213 到 10.100.0.214 , 10.100.0.215
10.100.0.216 , 10.100.0.217 到 10.100.0.218 , 10.100.0.219
10.100.0.220 , 10.100.0.221 到 10.100.0.222 , 10.100.0.223
10.100.0.224 , 10.100.0.225 到 10.100.0.226 , 10.100.0.227
10.100.0.228 , 10.100.0.229 到 10.100.0.230 , 10.100.0.231
10.100.0.232 , 10.100.0.233 到 10.100.0.234 , 10.100.0.235
10.100.0.236 , 10.100.0.237 到 10.100.0.238 , 10.100.0.239
10.100.0.240 , 10.100.0.241 到 10.100.0.242 , 10.100.0.243
10.100.0.244 , 10.100.0.245 到 10.100.0.246 , 10.100.0.247
10.100.0.248 , 10.100.0.249 到 10.100.0.250 , 10.100.0.251
10.100.0.252 , 10.100.0.253 到 10.100.0.254 , 10.100.0.255
```

- 结合防火墙做访问控制，目前使用的是禁止方式，以后视业务而定，看看是否优化为先禁止后开放规则；

```
/sbin/iptables -A FORWARD -i tun0 -m iprange --src-range 10.100.0.65-10.100.0.66 -d 10.108.0.0/24 -m comment --comment "禁止开发访问iDRAC远程卡" -j DROP
```

#### FreeOTP与密码相结合

- 生成授权脚本路径：/etc/openvpn/openvpn-auth-script/auth.py

  ```
  #!/usr/local/python/bin/python
  import sys
  import hashlib
  import pyotp
  tmpFile = open(sys.argv[1], 'r')
  lines = tmpFile.readlines()
  input_user = lines[0].strip()
  input_pass = lines[1].strip().encode("utf-8")
  prefix_pass = input_pass[:-6]
  suffix_pass = input_pass[-6:]
  prefix_pass = hashlib.sha256(prefix_pass).hexdigest()
  f = open('/etc/openvpn/openvpn-auth-script/users.db', 'r')
  for line in f:
      line = line.strip()
      array = line.split(":")
      user = array[0]
      password = array[1]
      secret = array[2]
      secret = pyotp.TOTP(secret).now()
      if user == input_user:
          if password == prefix_pass:
                  if secret == suffix_pass:
                          print("auth success! ")
                          sys.exit(0)
  print("epic fail")
  sys.exit(1)
  ```

- 生成二难码给用户扫描，这一部份可以用py脚本发送邮件形式，迟点再做优化

  ```
  import pyotp
  >>> keys ="HanDongLin" 
  >>> mail ="handl@ewan.cn"
  >>> m = pyotp.totp.TOTP(keys).provisioning_uri(mail)
  >>> print m
  >>> otpauth://totp/admin%40sinacloud.com?secret=HanDongLin
  
  #### 根据上面结果生成二维码 扫描进去FreeOTP ####
  qrencode -o handl.png -t png -s 20 'otpauth://totp/handl%40ewan.cn?secret=HanDongLin'
  py脚本检验，看看FreeOTP跟服务器生成的是否一致
  >>> import pyotp
  >>> pyotp.TOTP('HanDongLin').now()
  ```

  