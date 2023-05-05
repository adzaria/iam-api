-- auth.lua
-- todo: alert legacy: must be unit-tested and refactored

local cjson = require "cjson"

-- NB: lifespan of the tokens are set regardless the lifespan of the cookies
-- in  the future, get expiration date from the received jwt itself
local access_token_lifetime_seconds = 900
local refresh_token_lifetime_seconds = 259200

-- Utils

local function create_cookie(name, value, expiration)
    return string.format("%s=%s; Expires=%s; Path=/; HttpOnly; Secure", name, value, expiration)
end

-- Handlers

local _Handlers = {}

function _Handlers.email_verification_code ()
    local res = ngx.location.capture("/api/proxy-iam-public", { method = ngx.HTTP_PATCH })

    local body = cjson.decode(res.body)

    local auto_login = body.data and (body.data.auto_login == true)

    -- if auto_login is enabled we need to set the cookies
    if auto_login and body.status == "success" and res.status >= 200 and res.status < 400 then
        local access_token = (body.data and body.data.access_token) or ""
        local refresh_token = (body.data and body.data.refresh_token) or ""

        if (access_token == nil or #access_token == 0) or
                (refresh_token == nil or #refresh_token == 0) then
            ngx.log(ngx.ERR, "EmailVerificationCode: received \"success\" but no access_token or refresh_token")
            ngx.status = 500
            ngx.say('{"status":"error","message":"Internal server error"}')
            return
        end

        local cookies = {}
        table.insert(cookies, create_cookie("access_token", access_token, ngx.cookie_time(ngx.time() + access_token_lifetime_seconds)))
        table.insert(cookies, create_cookie("refresh_token", refresh_token, ngx.cookie_time(ngx.time() + refresh_token_lifetime_seconds)))

        ngx.header["Set-Cookie"] = cookies;
        ngx.status = res.status
        ngx.say("{\"status\":\"success\"}");
        return
    end

    ngx.status = res.status
    if res.body.data ~= nil then
        res.body.data = nil
    end
    ngx.say(res.body);
end

function _Handlers.login ()
    local res = ngx.location.capture("/api/proxy-iam-public", { method = ngx.HTTP_POST })

    local body = cjson.decode(res.body)

    if body.status == "success" and res.status >= 200 and res.status < 400 then
        local access_token = (body.data and body.data.access_token) or ""
        local refresh_token = (body.data and body.data.refresh_token) or ""

        if (access_token == nil or #access_token == 0) or
                (refresh_token == nil or #refresh_token == 0) then
            ngx.log(ngx.ERR, "Login: received \"success\" but no access_token or refresh_token")
            ngx.status = 500
            ngx.say('{"status":"error","message":"Internal server error"}')
            return
        end

        local cookies = {}
        table.insert(cookies, create_cookie("access_token", access_token, ngx.cookie_time(ngx.time() + access_token_lifetime_seconds)))
        table.insert(cookies, create_cookie("refresh_token", refresh_token, ngx.cookie_time(ngx.time() + refresh_token_lifetime_seconds)))

        ngx.header["Set-Cookie"] = cookies;
        ngx.status = res.status
        ngx.say("{\"status\":\"success\"}");
        return
    end

    ngx.status = res.status
    if res.body.data ~= nil then
        res.body.data = nil
    end
    ngx.say(res.body);
end

-- logout sets cookies to expire in the past
-- it should also blacklist the refresh token
function _Handlers.logout ()
    local expired = ngx.time() - 1
    local refresh_cookie = string.format("refresh_token=; Expires=%s; Path=/; HttpOnly; Secure", ngx.cookie_time(expired))
    local access_cookie = string.format("access_token=; Expires=%s; Path=/; HttpOnly; Secure", ngx.cookie_time(expired))
    ngx.header["Set-Cookie"] = {refresh_cookie, access_cookie}
    ngx.header.content_type = "application/json; charset=utf-8"
    ngx.say('{"status":"success logout"}')
end

function _Handlers.refresh ()
    local res = ngx.location.capture("/api/proxy-iam-public", { method = ngx.HTTP_POST })

    local body = cjson.decode(res.body)

    if body.status == "success" and res.status >= 200 and res.status < 400 then
        local access_token = (body.data and body.data.access_token) or ""
        local refresh_token = (body.data and body.data.refresh_token) or ""

        if (access_token == nil or #access_token == 0) or
                (refresh_token == nil or #refresh_token == 0) then
            ngx.log(ngx.ERR, "Refresh: received \"success\" but no access_token or refresh_token")
            ngx.status = 500
            ngx.say('{"status":"error","message":"Internal server error"}')
            return
        end

        local cookies = {}
        table.insert(cookies, create_cookie("access_token", access_token, ngx.cookie_time(ngx.time() + access_token_lifetime_seconds)))
        table.insert(cookies, create_cookie("refresh_token", refresh_token, ngx.cookie_time(ngx.time() + refresh_token_lifetime_seconds)))

        ngx.header["Set-Cookie"] = cookies;
        ngx.status = res.status
        ngx.say("{\"status\":\"success\"}");
        return
    end

    ngx.status = res.status
    if res.body.data ~= nil then
        res.body.data = nil
    end
    ngx.say(res.body);
end

return _Handlers