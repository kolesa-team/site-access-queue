local redis = require "resty.redis"
local red = redis:new()

red:set_timeouts(ngx.var.queue_redis_timeout, ngx.var.queue_redis_timeout, ngx.var.queue_redis_timeout) -- 1 sec

local ok, err = red:connect(ngx.var.queue_redis_host, ngx.var.queue_redis_port)
if not ok then
    ngx.say("failed to connect to redis: ", err)
end

local args, err = ngx.req.get_uri_args()

if not args.offset then
    ngx.say("Usage: ?offset=123")
else
    local offset = tonumber(args.offset)
    local updated, err = red:incrby("global_offset", offset)
    ngx.say("ok, new offset is ", updated)
end