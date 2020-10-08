[下载链接：https://artifacts.elastic.co/downloads/logstash/logstash-7.7.1.tar.gz](https://artifacts.elastic.co/downloads/logstash/logstash-7.7.1.tar.gz "下载链接：https://artifacts.elastic.co/downloads/logstash/logstash-7.7.1.tar.gz")

    cd /data/softsrc
    wget -c https://artifacts.elastic.co/downloads/logstash/logstash-7.7.1.tar.gz
    tar zxf logstash-7.7.1.tar.gz -C /usr/local/
    ln -sf logstash-7.7.1.tar.gz logstash

- ###### 路径：/etc/init.d/logstash;执行命令：chmod u+x /etc/init.d/logstash


    #!/bin/bash
    # chkconfig: 345 20 80
    # description: logstash
    #
    ########################################################
    #
    #    脚本名称: logstash.sh
    #
    #    功    能: 启动、关停 服务
    #
    #    用    法: bash logstash.sh [<stop>|<start>|<restart>]
    #
    #    作    者: JerryHan
    #
    #    日    期: 2019/08/13
    #
    ########################################################
    #
    
    BIN_LOGSTASH="/usr/local/logstash/bin/logstash"
    CONF_LOGSTASH="/usr/local/logstash/config/logstash.conf"
    
    _START(){
        pgrep -f "${BIN_LOGSTASH}" &>/dev/null || exec nohup ${BIN_LOGSTASH} -f ${CONF_LOGSTASH} --config.reload.automatic &>/dev/null &
    }
    
    _STOP(){
        jps | grep -i logstash | awk '{print $1}' &>/dev/null && jps | grep -i logstash | awk '{print $1}' | xargs kill -9
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
    
        "*"|"")
            { echo "Invalid Parameter" 2>&1;exit 1; }
            ;;
    
    esac
    # (END)

- ###### 配置路径：/usr/local/logstash/logstash.conf


    ################################################################################
    #
    #    配置名称: logstash.conf
    #
    #    功    能: 日志分析系统组件 logstash 配置文件
    #
    #    用    法: /<PATH>/bin/logstash -f logstash --config.reload.automatic
    #
    #    作    者: JerryHan
    #
    #    日    期: 2020/06/11
    #
    ################################################################################
    #
    
    input {

        #beats { port => "5044" }

    	kafka {
        	group_id => "{{ TOPIC }}.logs"
        	client_id => "{{ TOPIC }}.logs"
        	bootstrap_servers => ["192.168.60.221:9092,192.168.60.221:9092,192.168.60.221:9092"]
        	topics_pattern  => "{{ TOPIC }}"
        	auto_offset_reset => "latest"
        	codec => "json"
    	}

    }
    
    filter {
    
        #### 过滤 nginx 日志 ####
        if "nginx" in [tags] {
    
            #### 区隔字段 并重新赋值 ####
            mutate {
                split => ["message", "|"]
    
                add_field => { "timestamps" => "%{[message][0]}" }
                add_field => { "domin_name" => "%{[message][1]}" }
                add_field => { "status" => "%{[message][2]}" }
                add_field => { "request_length" => "%{[message][3]}" }
                add_field => { "bytes_sent" => "%{[message][4]}" }
                add_field => { "upstream_addr" => "%{[message][5]}" }
                add_field => { "upstream_response_time" => "%{[message][6]}" }
                add_field => { "http_referer" => "%{[message][7]}" }
                add_field => { "remote_addr" => "%{[message][8]}" }
                add_field => { "remote_port" => "%{[message][9]}" }
                add_field => { "remote_user" => "%{[message][10]}" }
                add_field => { "request" => "%{[message][11]}" }
                add_field => { "http_user_agent" => "%{[message][12]}" }
                add_field => { "http_x_forwarded_for" => "%{[message][13]}" }
            }
    
            mutate {
                #### 处理字段前后空格 ####
                strip => ["@timestamp", "logTimestamp", "timestamps", "domin_name" ,"status", "request_length", "bytes_sent", "upstream_addr", "upstream_response_time", "http_referer", "remote_addr", "remote_port", "remote_user", "request", "http_user_agent", "http_x_forwarded_for"]
                
                #### 删除无用的字段 ####
                remove_field => [ "message", "@version" ]
                remove_tag => ["beats_input_codec_plain_applied"]
            }
    
            #### 将日志时间切换成基准  @timestamp 时间戳 ####
            date {
                match => ["timestamps", "dd/MMM/yyyy:HH:mm:ss +0800"]
                target => "@timestamp"
                #timezone => "UTC"
            }
    
        }
    
    ################################################################################
    
        #### 过滤 MySQL 5.7 日志 ####
        if "mysql57" in [tags] {
    
            grok {
    
               match => [
                    "message",
                    "^#\s+Time:\s+(?<timeStampLogs>\d+-\d+-\d+T\d+:\d+:\d+\.\d+\+08:00)\n#\s+User@Host:\s+(?<USER>[a-zA-Z0-9._-]+)\[[^\]]+\]\s+@\s+(?:(?<clienthost>.*[^ ]?))\[(?:(?<clientip>.*))?\]\s+Id:\s+(?<ID>\d+)\n#\s+Query_time:\s+(?<querytime>\d+\.\d+)\s+Lock_time:\s+(?<locktime>\d+\.\d+)\s+Rows_sent:\s+(?<rowssent>\d+)\s+Rows_examined:\s+(?<rowsexamined>\d+)\nSET\s+timestamp=(?<timestamp>\d+);\n(?<query>[\s\S]*)"
               ]
    
            }
    
            #### 转换日期类型 ####
            mutate {
    
               #### 删除无用的字段 ####
               remove_field => [ "message", "@version" ]
               remove_tag => ["beats_input_codec_plain_applied", "_grokparsefailure", "_dateparsefailure"]
    
            }
    
            #### 将日志时间切换成处理时间 ####
            date {
               match => ["timeStampLogs", "ISO8601"]
               target => "@timestamp"
            }
    
        }
    
        #### 过滤 MySQL 5.6 日志 ####
        if "mysql56" in [tags] {
    
            grok {
    
                match => [
                    "message",
                    "^#\s+User@Host:\s+(?<USER>[a-zA-Z0-9._-]+)\[[^\]]+\]\s+@\s+(?:(?<clienthost>.*[^ ]?))\[(?:(?<clientip>.*))?\]\s+Id:\s+(?<ID>\d+)\n#\s+Query_time:\s+(?<querytime>\d+\.\d+)\s+Lock_time:\s+(?<locktime>\d+\.\d+)\s+Rows_sent:\s+(?<rowssent>\d+)\s+Rows_examined:\s+(?<rowsexamined>\d+)\nSET\s+timestamp=(?<timestamp>\d+);\n(?<query>[\s\S]*[;])(?:\n#\s+Time:\s+\d+\s+\d+:\d+:\d+)?"
               ]
    
            }
    
            #### 删除无用字段 ####
            mutate {
    
                remove_field => [ "message", "@version" ]
                remove_tag => ["beats_input_codec_plain_applied", "_grokparsefailure"]
    
            }
    
            #### 将显示时间标记为输出时间 ####
            date {
                match => ["timestamp", "UNIX"]
                target => "@timestamp"
            }
    
        }
    
    ################################################################################
    
        #### 过滤 JAVA 日志 ####
        if "java" in [tags] {
    
            #### 获取时间戳 ####
            grok {
                match => [
                    "message", "^\[(?<PPID>\d+)\]\[INFO\s+:(?<timeStampLogs>\d+-\d+-\d+\s+\d+:\d+:\d+,\d+):",
                    "message", "^\[(?<PPID>\d+)\]\[ERROR:(?<timeStampLogs>\d+-\d+-\d+\s+\d+:\d+:\d+,\d+):",
                    "message", "^\[(?<PPID>\d+)\]\[DEBUG:(?<timeStampLogs>\d+-\d+-\d+\s+\d+:\d+:\d+,\d+):"
                    ]
            }
    
            #### 删除无用字段 ####
            mutate {
    
                remove_field => [ "@version" ]
                remove_tag => ["beats_input_codec_plain_applied", "_grokparsefailure"]
    
            }
    
            #### 将日志时间切换成处理时间 ####
            date {
                match => ["timeStampLogs", "yyyy-MM-dd HH:mm:ss,SSS"]
                target => "@timestamp"
                locale => "en"
                timezone => "+08:00"
            }
    
        }
    
    #    #### 过滤 JAVA 日志 ####
    #    if "java.1" in [tags] {
    #
    #        #### 获取时间戳 ####
    #        grok {
    #            match => [
    #                "message", "^\[(?<PPID>\d+)\]\[INFO\s+:(?<timeStampLogs>\d+-\d+-\d+\s+\d+:\d+:\d+,\d+):.*\]====协议号:(?<protocol>\d+)?-响应时间：(?<times>\d+) 毫秒"
    #                ]
    #        }
    #
    #        #### 删除无用字段 ####
    #        mutate {
    #
    #            remove_field => [ "message", "@version" ]
    #            remove_tag => ["beats_input_codec_plain_applied", "_grokparsefailure"]
    #
    #        }
    #
    #        #### 将日志时间切换成处理时间 ####
    #        date {
    #            match => ["timeStampLogs", "yyyy-MM-dd HH:mm:ss,SSS"]
    #            target => "@timestamp"
    #            locale => "en"
    #            timezone => "+08:00"
    #        }
    #
    #    }
    
    }
    
    output {
    
        #### 输出 JAVA 日志 ####
        if [fields][project] == "{{ PROJECT_1 }}" {
    
            elasticsearch {
                hosts => [ "192.168.100.232:9200", "192.168.100.233:9200", "192.168.100.234:9200" ]
                index => "1.%{[fields][project]}"
            }
    
        }
    
    #    if [fields][project] == "acc.java.1" {
    #
    #        elasticsearch {
    #            hosts => [ "192.168.100.232:9200", "192.168.100.233:9200", "192.168.100.234:9200" ]
    #            #index => "%{[fields][project]}-%{+YYYY.MM.dd}"
    #        }
    #
    #    }
    
        if [fields][project] == "{{ PROJECT_2 }}" {
    
            elasticsearch {
                hosts => [ "192.168.100.232:9200", "192.168.100.233:9200", "192.168.100.234:9200" ]
                index => "1.%{[fields][project]}"
            }
    
        }
    
        if [fields][project] == "{{ PROJECT_3 }}" {
    
            elasticsearch {
                hosts => [ "192.168.100.232:9200", "192.168.100.233:9200", "192.168.100.234:9200" ]
                index => "1.%{[fields][project]}"
            }
    
        }
    
        if [fields][project] == "{{ PROJECT_4 }}" {
    
            elasticsearch {
                hosts => [ "192.168.100.232:9200", "192.168.100.233:9200", "192.168.100.234:9200" ]
                index => "1.%{[fields][project]}"
            }
    
        }
    
    ################################################################################
    
        #### 输出 Nginx 日志 ####
        if [fields][project] == "ios.nginx" {
    
            elasticsearch {
                hosts => [ "192.168.100.232:9200", "192.168.100.233:9200", "192.168.100.234:9200" ]
                #index => "%{domin_name}-%{[fields][project]}-%{+YYYY.MM.dd}"
                index => "%{domin_name}"
            }
    
        }
    
        if [fields][project] == "sdk.nginx" {
    
            elasticsearch {
                hosts => [ "192.168.100.232:9200", "192.168.100.233:9200", "192.168.100.234:9200" ]
                index => "%{domin_name}"
            }
    
        }
    
        if [fields][project] == "ys.nginx" {
    
            elasticsearch {
                hosts => [ "192.168.100.232:9200", "192.168.100.233:9200", "192.168.100.234:9200" ]
                index => "%{domin_name}"
            }
    
        }
    
        if [fields][project] == "admin.nginx" {
    
            elasticsearch {
                hosts => [ "192.168.100.232:9200", "192.168.100.233:9200", "192.168.100.234:9200" ]
                index => "%{domin_name}"
            }
    
        }
    
    ################################################################################
    
        #### 输出 MySQL 日志 ####
        if [fields][project] == "sdk.mysql" {
    
            elasticsearch {
                hosts => [ "192.168.100.232:9200", "192.168.100.233:9200", "192.168.100.234:9200" ]
                index => "0.%{[fields][project]}"
            }
    
        }
    
        if [fields][project] == "ios.mysql" {
    
            elasticsearch {
                hosts => [ "192.168.100.232:9200", "192.168.100.233:9200", "192.168.100.234:9200" ]
                index => "0.%{[fields][project]}"
            }
    
        }
    
        if [fields][project] == "pay.mysql" {
    
            elasticsearch {
                hosts => [ "192.168.100.232:9200", "192.168.100.233:9200", "192.168.100.234:9200" ]
                index => "0.%{[fields][project]}"
            }
    
        }
    
    ################################################################################
    
        #### 控制台打印 ####
        stdout { codec => rubydebug }
    }