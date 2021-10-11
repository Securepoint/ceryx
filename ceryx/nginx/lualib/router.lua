local redis = require "ceryx.redis"
local routes = require "ceryx.routes"
local utils = require "ceryx.utils"
local ck = require "resty.cookie"
                
local redisClient = redis:client()

local host = ngx.var.host
local cache = ngx.shared.ceryx

local is_not_https = (ngx.var.scheme ~= "https")

local function setUpstreamHeaders(source, target, route)
    ngx.log(ngx.DEBUG, "Setting upstream headers for " .. source .. " to " .. target .. ".")
    local upstreamHeadersKey = routes.getUpstreamHeadersKeyForSource(source)
    local cookie, flags = cache:get(host .. ":cookie")

    if cookie == nil then
        cookie, flags = redisClient:hget(upstreamHeadersKey, "cookie")
        if cookie == ngx.null then
            cookie = nil
        else
            ngx.log(ngx.DEBUG, "Cookie from redis: " .. cookie)
        end
        cache:set(host .. ":cookie", cookie, 5)
    end

    if cookie == nil then
        return
    end

    ngx.log(ngx.DEBUG, "Setting cookie for " .. source .. " to " .. target .. ": " .. cookie)
    ngx.req.set_header("Cookie", cookie)
end

local function checkValidationCookie(source)
    ngx.log(ngx.DEBUG, "Checking validation cookie for " .. source)
    local validationCookieNameKey = routes.getValidationCookieNameKeyForSource(source)
    local validationCookieValueKey = routes.getValidationCookieValueKeyForSource(source)

    local cookieName, flags = cache:get(host .. ':cookie-name')
    local cookieValue, flags = cache:get(host .. ':cookie-value')
    local _

    if cookieName == nil or cookieValue == nil then
	ngx.log(ngx.DEBUG, "cache miss")
        cookieName, _ = redisClient:get(validationCookieNameKey)
        cookieValue, _ = redisClient:get(validationCookieValueKey)
        if cookieName == ngx.null then
	    ngx.log(ngx.DEBUG, "no cookie name in redis")
            cookieName = false
            cookieValue = false
        end
	if cookieName then
	    ngx.log(ngx.DEBUG, "set cookie name in cache: " .. cookieName)
        end
        cache:set(host .. ':cookie-name', cookieName, 5)
	if cookieValue then
	    ngx.log(ngx.DEBUG, "set cookie value in cache: " .. cookieValue)
	end
        cache:set(host .. ':cookie-value', cookieValue, 5)
    end

    if cookieName == false then
	ngx.log(ngx.DEBUG, "validation cookie not required")
        return
    end
    ngx.log(ngx.DEBUG, "validation cookie required. starting validation")

    local cookie, err = ck:new()
    if not cookie then
        ngx.log(ngx.ERR, err)
        return
    end

    local cookieValueFromRequest, err = cookie:get(cookieName)
    if not cookieValueFromRequest then
        if err then
            ngx.log(ngx.ERR, err)
        else 
            ngx.log(ngx.ERR, "No cookie named " .. cookieName .. " was found in the request.")
        end
        ngx.exit(ngx.HTTP_FORBIDDEN)
    end

    if cookieValueFromRequest ~= cookieValue then
        ngx.log(ngx.ERR, "cookie validation failed")
        ngx.exit(ngx.HTTP_FORBIDDEN)
    end

end

local function formatTarget(target)
    target = utils.ensure_protocol(target)
    target = utils.ensure_no_trailing_slash(target)

    return target .. ngx.var.request_uri
end

local function redirect(source, target)
    ngx.log(ngx.INFO, "Redirecting request for " .. source .. " to " .. target .. ".")
    return ngx.redirect(target, ngx.HTTP_MOVED_PERMANENTLY)
end

local function proxy(source, target, route)
    checkValidationCookie(source)
    setUpstreamHeaders(source, target, route)
    ngx.var.target = target

    local host = target:match('^%w+://([^/]+)')
    if host then
        ngx.var.target_host = host
    end

    ngx.log(ngx.INFO, "Proxying request for " .. source .. " to " .. target .. ".")
end

local function routeRequest(source, target, mode, route)
    ngx.log(ngx.DEBUG, "Received " .. mode .. " routing request from " .. source .. " to " .. target)

    target = formatTarget(target)

    if mode == "redirect" then
        return redirect(source, target)
    end

    return proxy(source, target, route)
end

if is_not_https then
    local settings_key = routes.getSettingsKeyForSource(host)
    local enforce_https, flags = cache:get(host .. ":enforce_https")

    if enforce_https == nil then
        local res, flags = redisClient:hget(settings_key, "enforce_https")
        enforce_https = tonumber(res)
        cache:set(host .. ":enforce_https", enforce_https, 5)
    end

    if enforce_https == 1 then
        return ngx.redirect("https://" .. host .. ngx.var.request_uri, ngx.HTTP_MOVED_PERMANENTLY)
    end
end

ngx.log(ngx.INFO, "HOST " .. host)
local route = routes.getRouteForSource(host)

if route == nil then
    ngx.log(ngx.INFO, "No $wildcard target configured for fallback. Exiting with Bad Gateway.")
    return ngx.exit(ngx.HTTP_SERVICE_UNAVAILABLE)
end

-- Save found key to local cache for 5 seconds
routeRequest(host, route.target, route.mode, route)
