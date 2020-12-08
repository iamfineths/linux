##### 安装部署
---

```shell
cd /data/softsrc
wget -c https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-7.7.1-linux-x86_64.tar.gz
tar zxf elasticsearch-7.7.1-linux-x86_64.tar.gz -C /usr/local/
ln -sf elasticsearch-7.7.1-linux-x86_64 es
! getent passwd es &>/dev/null && useradd -M es -s /bin/false
chown -R es.es /usr/local/{es,elasticsearch-7.7.1}
install -g es -o es -d /data/es && install -g es -o es -d /data/logs/es
```

- ##### 添加系统参数以及生效
---
```shell
cat > /etc/sysctl.d/es.conf <<EOF
vm.max_map_count=262144
EOF
sysctl --system
```

##### 启动命令行
---
```shell
su - es -c "/usr/local/es/bin/elasticsearch -d"
```

##### 配置文件位置：/usr/local/es/config/elasticsearch.yml
---

```yaml
cluster.name: MiaoGame
node.name: MiaoES233
path.data: /data/es
path.logs: /data/logs/es
network.host: 0.0.0.0
discovery.seed_hosts: ["192.168.100.232", "192.168.100.233", "192.168.100.234"]
cluster.initial_master_nodes: ["ES232", "ES233", "ES234"]
http.cors.enabled: true
http.cors.allow-origin: "*"
```