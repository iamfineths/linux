##### 安装部署
***
```shell
cd /data/softsrc/
wget -c https://artifacts.elastic.co/downloads/kibana/kibana-7.7.1-linux-x86_64.tar.gz
tar zxf kibana-7.7.1-linux-x86_64.tar.gz -C /usr/local/
cd /usr/local/
ln -sf kibana-7.7.1-linux-x86_64 kibana
```

##### 配置文件位置：/usr/local/kibana/config/kibana.yml
---
```yaml
server.port: 5601
server.host: "0.0.0.0"
elasticsearch.hosts: ["http://192.168.100.232:9200", "http://192.168.100.233:9200", "http://192.168.100.234:9200"]
kibana.index: ".kibana"
```
