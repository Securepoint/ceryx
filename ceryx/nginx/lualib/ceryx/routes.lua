local redis = require "ceryx.redis"

local exports = {}

local function getRouteKeyForSource(source)
    return redis.prefix .. ":routes:" .. source
end

local function getSettingsKeyForSource(source)
    return redis.prefix .. ":settings:" .. source
end

local function getUpstreamHeadersKeyForSource(source)
    return redis.prefix .. ":upstream-headers:" .. source
end

local function getValidationCookieNameKeyForSource(source)
    return redis.prefix .. ":validation-cookie-name:" .. source
end

local function getValidationCookieValueKeyForSource(source)
    return redis.prefix .. ":validation-cookie-value:" .. source
end

local function targetIsInValid(target)
    return not target or target == ngx.null
end

local function getTargetForSource(source, redisClient)
    -- Construct Redis key and then
    -- try to get target for host
    local key = getRouteKeyForSource(source)
    local target, _ = redisClient:get(key)

    if targetIsInValid(target) then
        ngx.log(ngx.INFO, "Could not find target for " .. source .. ".")

        -- Construct Redis key for $wildcard
        key = getRouteKeyForSource("$wildcard")
        target, _ = redisClient:get(key)

        if targetIsInValid(target) then
            return nil
        end

        ngx.log(ngx.DEBUG, "Falling back to " .. target .. ".")
    end

    return target
end

local function getModeForSource(source, redisClient)
    ngx.log(ngx.DEBUG, "Get routing mode for " .. source .. ".")
    local settings_key = getSettingsKeyForSource(source)
    local mode, _ = redisClient:hget(settings_key, "mode")

    if mode == ngx.null or not mode then
        mode = "proxy"
    end

    return mode
end

local function getRouteForSource(source)
    local _
    local route = {}
    local cache = ngx.shared.ceryx
    local redisClient = redis:client()

    ngx.log(ngx.DEBUG, "Looking for a route for " .. source)
    -- Check if key exists in local cache
    local cached_value, _ = cache:get(source)

    if cached_value then
        ngx.log(ngx.DEBUG, "Cache hit for " .. source .. ".")
        route.target = cached_value
    else
        ngx.log(ngx.DEBUG, "Cache miss for " .. source .. ".")
        route.target = getTargetForSource(source, redisClient)

        if targetIsInValid(route.target) then
            return nil
        end
        cache:set(host, res, 5)
        ngx.log(ngx.DEBUG, "Caching from " .. source .. " to " .. route.target .. " for 5 seconds.")
    end

    route.mode = getModeForSource(source, redisClient)

    return route
end

exports.getSettingsKeyForSource = getSettingsKeyForSource
exports.getUpstreamHeadersKeyForSource = getUpstreamHeadersKeyForSource
exports.getRouteForSource = getRouteForSource
exports.getTargetForSource = getTargetForSource
exports.getValidationCookieNameKeyForSource = getValidationCookieNameKeyForSource
exports.getValidationCookieValueKeyForSource = getValidationCookieValueKeyForSource

return exports
