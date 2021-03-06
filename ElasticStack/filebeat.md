##### 安装部署
---

```shell
cd /data/softsrc
wget -c https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-7.7.1-linux-x86_64.tar.gz
tar zxf filebeat-7.7.1-linux-x86_64.tar.gz -C /usr/local/
cd /usr/local/
ln -sf filebeat-7.7.1-linux-x86_64 filebeat
```

##### 组件配置
------

-  filebeat.yml 采用了全局配置与外部配置方式（external configuration files）


```yaml
filebeat.config.inputs:
  enabled: true
  path: /usr/local/filebeat/inputs.d/*.yml
  reload.enabled: true
  reload.period: 10s

processors:
  - drop_fields:
      fields: ["agent", "input", "ecs", "log.flags", "@version"]

name: 192.168.60.143

output.logstash:
  enabled: false
  hosts: ["192.168.60.213:5044"]

output.kafka:
  enabled: true
  hosts: ["192.168.60.221:9092","192.168.60.222:9092","192.168.60.223:9092"]
  topic: "{{ TOPIC }}"
```

- ##### 数据库配置 MySQL.yml，存放路径：/usr/local/filebeat/inputs.d/MySQL.yml


```yaml
- type: log
  enabled: true
  paths:
    - /data/mysql/data1/*-slow.log

  tags: ["mysql56"]

  exclude_lines: ['^\# Time']

  multiline.pattern: '^\# User@Host:'
  multiline.negate: true
  multiline.match: after

  fields:
    hostname: {{ HOSTNAME }}
    project: sdk.mysql
```

- ##### Nginx 入口机配置 nginx.yml，存放路径：/usr/local/filebeat/inputs.d/nginx.yml


```yaml
- type: log
  enabled: true
  paths:
    - /data/logs/nginx/*.log*

  #tail_files: true
  #close_older: 10m

  tags: ["nginx"]

  fields:
    hostname: {{ HOSTNAME }}
    project: ios.nginx
```

- ##### JAVA 工程配置 java.yml，存放路径：/usr/local/filebeat/inputs.d/java.yml


```yaml
- type: log
  enabled: true
  paths:
    - /data/logs/{{ PROJECT }}/log.txt*
  exclude_files: ['\.gz$']

  multiline.pattern: '^\[\d+\]\[INFO\s+:|^\[\d+\]\[ERROR:|^\[\d+\]\[DEBUG:'
  multiline.negate: true
  multiline.match: after

  tags: ["java"]

  fields:
    hostname: {{ HOSTNAME }}
    project: acc.java
```

- ##### JAVA 工程配置 java.1.yml，存放路径：/usr/local/filebeat/inputs.d/java.1.yml


```yaml
- type: log
  enabled: true
  paths:
    - /data/logs/{{ PROJECT }}/log.txt*
  exclude_files: ['\.gz$']

  include_lines: ['-响应时间：']

  tags: ["java.1"]

  fields:
    hostname: {{ HOSTNAME }}
    project: acc.java.1
```

