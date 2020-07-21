--[[ 定义关闭redis函数 --]]
local function close_redis(red)
    if not red then
        return
    end
    local ok, err = red:set_keepalive(10000, 100)
    if not ok then
        ngx.log(ngx.CRIT, "set redis keepalive error : ", err)
        return
    end
end

--[[ 连接redis --]]
local redis = require('resty.redis')
local red = redis.new()
      red:set_timeout(1000)
local ok, err = red:connect("127.0.0.1", 6379)
if not ok then
    ngx.log(ngx.CRIT, "failed to connect: ", err)
    return
end

local res, err = red:auth("password")
if not res then
    ngx.log(ngx.CRIT, "failed to authenticate: ", err)
    return
end

--[[ 获取客户端真实的ip --]]
local clientIP = ngx.req.get_headers()["X-Real-IP"]
if clientIP == nil then
   clientIP = ngx.req.get_headers()["x_forwarded_for"]
end
if clientIP == nil then
   clientIP = ngx.var.remote_addr
end

--[[ 定义redis key值格式，incrkey 请求的频率，blockKey被阻塞的key，后面会存入redis --]]
local incrKey = "user:"..clientIP..":freq"
local blockKey = "user:"..clientIP..":block"

--[[ 检查是否被禁止 --]]
local is_block,err = red:get(blockKey)
if tonumber(is_block) == 1 then
    ngx.exit(403)
    close_redis(red)
end

--[[ incr redis操作 默认是从0开始，执行一次会累加1 --]]
local inc  = red:incr(incrKey)
if inc <= 10 then
   inc = red:expire(incrKey,1)
end

--[[ 每秒10次以上访问即视为非法，会阻止1分钟的访问 --]]
if inc > 10 then
    --[[ 设置block 为 True 计数开始为1 --]]
    red:set(blockKey,1)
    red:expire(blockKey,60)
end
close_redis(red)