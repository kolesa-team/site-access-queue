--- Site Access Queue
-- @module queue
-- @license MIT
-- @release 0.0.2


local _M = {
    _VERSION = '0.0.2'
}

function _M.getStats()
    local redis = require "resty.redis"
    local red = redis:new()

    red:set_timeouts(ngx.var.queue_redis_timeout, ngx.var.queue_redis_timeout, ngx.var.queue_redis_timeout) -- 1 sec

    local ok, err = red:connect(ngx.var.queue_redis_host, ngx.var.queue_redis_port)
    if not ok then
        return 0, 0, 0, err
    end

    local globalOffset, err = red:get("global_offset")
    if globalOffset == ngx.null then
        globalOffset = tonumber(ngx.var.queue_max_sessions)
    end

    local globalCounter, err = red:get("global_counter")
    if globalCounter == ngx.null then
        globalCounter = 0
    end

    globalCounter = tonumber(globalCounter)
    globalOffset = tonumber(globalOffset)

    local availableSessions = globalOffset - globalCounter

    if availableSessions < 0 then
        availableSessions = 0
    end

    local queueSize = globalCounter - globalOffset
    if queueSize < 0 then
        queueSize = 0
    end

    return availableSessions, queueSize, tonumber(ngx.var.queue_max_sessions), nil
end

function _M.getPosition()
    local ck = require "resty.cookie"
    local cookie, err = ck:new()
    if not cookie then
        ngx.log(ngx.ERR, err)
        return nil, err
    end

    local redis = require "resty.redis"
    local red = redis:new()

    red:set_timeouts(ngx.var.queue_redis_timeout, ngx.var.queue_redis_timeout, ngx.var.queue_redis_timeout) -- 1 sec

    local ok, err = red:connect(ngx.var.queue_redis_host, ngx.var.queue_redis_port)
    if not ok then
        return nil, err
    end

    local uuidGenerator = require "resty.jit-uuid"
    local currentUuid
    local uuidCookie, err = cookie:get(ngx.var.queue_cookie_name)
    if not uuidCookie then
        currentUuid = uuidGenerator()
        local ok, err = cookie:set({
            key = ngx.var.queue_cookie_name,
            value = currentUuid,
            samesite = "Strict"
        })
    else
        currentUuid = uuidCookie
    end

    local myPosition, err = red:get(currentUuid)
    if myPosition == ngx.null then
        myPosition, err = red:incr("global_counter")
    end

    -- время жизни юзера
    red:setex(currentUuid, tonumber(ngx.var.queue_session_lifetime), myPosition)

    myPosition=tonumber(myPosition)
    ngx.log(ngx.INFO, "client position: " .. myPosition)

    local globalOffset, err = red:get("global_offset")
    if globalOffset == ngx.null then
        globalOffset = tonumber(ngx.var.queue_max_sessions)
        red:set("global_offset", tostring(ngx.var.queue_max_sessions))
    end

    return myPosition - globalOffset, nil
end

return _M
