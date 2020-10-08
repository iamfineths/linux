--[[ 连接kafka --]]
local DEFAULT_THRESHOLD = 100000
local PARTITION_NUM = 3
local TOPIC = 'nginx'
local POLLING_KEY = "POLLING_KEY"

local function partitioner(key, num, correlation_id)
    return tonumber(key)
end

local broker_list = {
    { host = "192.168.60.146", port = 9092 },
    { host = "192.168.60.147", port = 9092 },
    { host = "192.168.60.148", port = 9092 }
}

local CONNECT_PARAMS = { producer_type = "async", socket_timeout = 30000, flush_time = 10000, request_timeout = 20000, partitioner = partitioner }

local shared_data = ngx.shared.shared_data
local pollingVal = shared_data:get(POLLING_KEY)
if not pollingVal then
    pollingVal = 1
    shared_data:set(POLLING_KEY, pollingVal)
end

local partitions = '' .. (tonumber(pollingVal) % PARTITION_NUM)
shared_data:incr(POLLING_KEY, 1)

if ngx.var.host == '127.0.0.1' then
    return
end

local log_json = {}
log_json["time_local"]=ngx.var.time_local
log_json["host"]=ngx.var.host
log_json["status"]=ngx.var.status
log_json["request_length"]=ngx.var.request_length
log_json["bytes_sent"]=ngx.var.bytes_sent
log_json["upstream_addr"]=ngx.var.upstream_addr
log_json["upstream_response_time"]=ngx.var.upstream_response_time
log_json["http_referer"]=ngx.var.http_referer
log_json["remote_addr"] = ngx.var.remote_addr
log_json["remote_port"] = ngx.var.remote_port
log_json["remote_user"] = ngx.var.remote_user
log_json["request"] = ngx.var.request
log_json["http_user_agent"] = ngx.var.http_user_agent
log_json["http_x_forwarded_for"] = ngx.var.http_x_forwarded_for
log_json["connections_active"] = ngx.var.connections_active

-- 引入cjson
local cjson = require "cjson"
-- 封装数据
local message = cjson.encode(log_json)

-- 引入生产者
local producer = require "resty.kafka.producer"
-- 创建生产者
local bp = producer:new(broker_list, CONNECT_PARAMS)
-- 发送消息
local ok, err = bp:send(TOPIC, partitions, message)
-- 打印错误日志
if not ok then
    ngx.log(ngx.ERR, "kafka send err:", err)
    return
end