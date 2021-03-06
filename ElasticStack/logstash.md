##### 安装部署
---

```shell
cd /data/softsrc
wget -c https://artifacts.elastic.co/downloads/logstash/logstash-7.7.1.tar.gz
tar zxf logstash-7.7.1.tar.gz -C /usr/local/
ln -sf logstash-7.7.1.tar.gz logstash
```

##### 配置路径：/usr/local/logstash/logstash.conf
---
```yaml
input {
    beats { port => "5044" }

    #kafka {
    #    group_id => "groupid"
    #    client_id => "clientid"
    #    bootstrap_servers => ["30.30.40.106:9092,30.30.40.107:9092,30.30.40.108:9092"]
    #    topics_pattern  => "topicnames"
    #    auto_offset_reset => "latest"
    #    codec => "json"
    #}

}

filter {

########################################################################################

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
            strip => ["@timestamp", "timestamps", "domin_name" ,"status", "request_length", "bytes_sent", "upstream_addr", "upstream_response_time", "http_referer", "remote_addr", "remote_port", "remote_user", "request", "http_user_agent", "http_x_forwarded_for"]
            
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

        #### 新增索引字段 logTimestamp 将日志时间插入该字段 ####
        date {
            match => ["timestamps", "dd/MMM/yyyy:HH:mm:ss +0800"]
            target => "logTimestamp"
            timezone => "UTC"
        }

        mutate {
            #### 截取字符串做索引 ####
            convert => { "logTimestamp" => "string" }
            gsub => [ "logTimestamp", "T([\S\s]*?)Z", "" ]
        }

    }

########################################################################################

    #### 过滤 JAVA 日志 ####
    if "sql" in [tags] or "request" in [tags] or "stat" in [tags] {


        #### JAVA日志区隔处理 ####
        ruby {
            code => "
                array1 = event.get('message').split('`')
                array1.each do |temp1|
                array2 = temp1.split('=')
                key = array2[0]
                value = array2[1..-1].join('=')
                event.set(key, value)
                end
            "

        }

        #### 将日志时间处理成时间戳 ####
        date {
            match => ["t", "yyyy-MM-dd HH:mm:ss,SSS"]
            target => "@timestamp"
        }

        #### 新增索引字段 logTimestamp 将日志时间插入该字段 ####
        date {
            match => ["t", "yyyy-MM-dd HH:mm:ss,SSS"]
            target => "logTimestamp"
        }

        #### 转换日期类型 ####
        mutate {

            convert => { "logTimestamp" => "string" }
            gsub => [ "logTimestamp", "T([\S\s]*?)Z", "" ]

            #### 统一处理删除无用的字段 ####
            remove_field => [ "message", "@version" ]
            remove_tag => ["beats_input_codec_plain_applied"]

        }

    }

    #### 过滤 JAVA 日志 ####
    if "app" in [tags] {

        #### 获取时间戳 ####
        grok {
            match => [ "message","^(?<timeStampLogs>\d+-\d+-\d+ \d+:\d+:\d+,\d+)" ]
        }

        #### 将日志时间切换成处理时间 ####
        date {
            match => ["timeStampLogs", "yyyy-MM-dd HH:mm:ss,SSS"]
            target => "@timestamp"
            locale => "en"
            timezone => "+08:00"
        }

        #### 新增索引字段 logTimestamp 将日志时间插入该字段 ####
        date {
            match => ["timeStampLogs", "yyyy-MM-dd HH:mm:ss,SSS"]
            target => "logTimestamp"
        }

        mutate {
            convert => { "logTimestamp" => "string" }
            gsub => [ "logTimestamp", "T([\S\s]*?)Z", "" ]

            #### 统一处理删除无用的字段 ####
            remove_field => ["@version"]
            remove_tag => ["beats_input_codec_plain_applied"]
        }

    }

########################################################################################

    #### 过滤 MySQL 日志 ####
   if "mysql57" in [tags] {

        grok {

            match => [
               "message",
               "^#\s+Time:\s+(?<timeStampLogs>\d+-\d+-\d+T\d+:\d+:\d+\.\d+\+08:00)\n#\s+User@Host:\s+(?<USER>[a-zA-Z0-9._-]+)\[[^\]]+\]\s+@\s+(?:(?<clienthost>.*[^ ]?))\[(?:(?<clientip>.*))?\]\s+Id:\s+(?<ID>\d+)\n#\s+Query_time:\s+(?<querytime>\d+\.\d+)\s+Lock_time:\s+(?<locktime>\d+\.\d+)\s+Rows_sent:\s+(?<rowssent>\d+)\s+Rows_examined:\s+(?<rowsexamined>\d+)\nSET\s+timestamp=(?<timestamp>\d+);\n(?<query>[\s\S]*)"
            ]
       }

        #### 新增索引字段 logTimestamp 将日志时间插入该字段 ####
        date {
            match => ["timeStampLogs", "ISO8601"]
            target => "@timestamp"
            timezone => "UTC"
        }

        #### 新增索引字段 logTimestamp 将日志时间插入该字段 ####
        date {
            match => ["timeStampLogs", "ISO8601"]
            target => "logTimestamp"
            timezone => "UTC"
        }

        mutate {
            convert => { "logTimestamp" => "string" }
            gsub => [ "logTimestamp", "T([\S\s]*?)Z", "" ]

            #### 统一处理删除无用的字段 ####
            remove_field => ["message","@version"]
            remove_tag => ["beats_input_codec_plain_applied","_grokparsefailure"]
        }

    }

########################################################################################

}

output {

    #### NGINX 入口机日志 ####
    if "nginx" in [tags] {

        elasticsearch {
            hosts => [ "30.30.40.102:9200", "30.30.40.103:9200", "30.30.40.104:9200" ]
            index => "%{domin_name}.%{logTimestamp}"
        }

    }

#    #### JAVA 应用日志 ####
#    if "app" in [tags] or "request" in [tags] or "sql" in [tags] or "stat" in [tags] {
#
#        elasticsearch {
#            hosts => [ "30.30.40.102:9200", "30.30.40.103:9200", "30.30.40.104:9200" ]
#            index => "%{[fields][project]}.%{logTimestamp}"
#        }
#
#    }

    #### JAVA 应用日志 ####
    if "app" in [tags] {

        elasticsearch {
            hosts => [ "30.30.40.102:9200", "30.30.40.103:9200", "30.30.40.104:9200" ]
            index => "%{[fields][project]}.%{logTimestamp}"
        }

    }

    #### JAVA 应用日志 ####
    if "request" in [tags] {

        elasticsearch {
            hosts => [ "30.30.40.102:9200", "30.30.40.103:9200", "30.30.40.104:9200" ]
            index => "%{[fields][project]}.%{logTimestamp}"
        }

    }

    #### JAVA 应用日志 ####
    if "sql" in [tags] {

        elasticsearch {
            hosts => [ "30.30.40.102:9200", "30.30.40.103:9200", "30.30.40.104:9200" ]
            index => "%{[fields][project]}.%{logTimestamp}"
        }

    }

    #### JAVA 应用日志 ####
    if "stat" in [tags] {

        elasticsearch {
            hosts => [ "30.30.40.102:9200", "30.30.40.103:9200", "30.30.40.104:9200" ]
            index => "%{[fields][project]}.%{logTimestamp}"
        }

    }

    #### JAVA 应用日志 ####
    if "mysql57" in [tags] {

        elasticsearch {
            hosts => [ "30.30.40.102:9200", "30.30.40.103:9200", "30.30.40.104:9200" ]
            index => "%{[fields][project]}.%{logTimestamp}"
        }

    }

    #### 控制台打印 ####
    stdout { codec => rubydebug }
}
```


