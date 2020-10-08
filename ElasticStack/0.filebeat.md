[下载地址：https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-7.7.1-linux-x86_64.tar.gz](http:https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-7.7.1-linux-x86_64.tar.gz// "下载地址：https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-7.7.1-linux-x86_64.tar.gz")

    cd /data/softsrc
    wget -c https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-7.7.1-linux-x86_64.tar.gz
    tar zxf filebeat-7.7.1-linux-x86_64.tar.gz -C /usr/local/
    cd /usr/local/
    ln -sf filebeat-7.7.1-linux-x86_64 filebeat

- ###### 关停脚本放到/etc/init.d/下，并执行chmod u+x /etc/init.d/filebeat


    #!/bin/bash
    # chkconfig: 345 20 80
    # description: filebeat
    #
    ########################################################
    #
    #    脚本名称: filebeat.sh
    #
    #    功    能: 启动、关停 服务
    #
    #    用    法: bash filebeat.sh [<stop>|<start>|<restart>]
    #
    #    作    者: JerryHan
    #
    #    日    期: 2019/08/13
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
        pgrep -f "${HOME_FILEBEAT}/filebeat" &>/dev/null || exec nohup ${HOME_FILEBEAT}/filebeat -c ${HOME_FILEBEAT}/filebeat.yml -e &>/dev/null &
    }
    
    _STOP(){
        pgrep -f "${HOME_FILEBEAT}/filebeat" &>/dev/null && pgrep -f "${HOME_FILEBEAT}/filebeat" | xargs kill -9
    }
    
    readonly HOME_FILEBEAT="/usr/local/filebeat"
    
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

- ###### filebeat.yml 采用了全局配置与外部配置方式（external configuration files）


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

- ###### 数据库配置 MySQL.yml，存放路径：/usr/local/filebeat/inputs.d/MySQL.yml


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

- ###### Nginx 入口机配置 nginx.yml，存放路径：/usr/local/filebeat/inputs.d/nginx.yml


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

- ###### JAVA 工程配置 java.yml，存放路径：/usr/local/filebeat/inputs.d/java.yml


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

- ###### JAVA 工程配置 java.1.yml，存放路径：/usr/local/filebeat/inputs.d/java.1.yml


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