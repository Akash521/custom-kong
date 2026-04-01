curl -X PATCH http://localhost:9440/routes/api-route/plugins/<PRE_FUNCTION_PLUGIN_ID> \
  --data "config.access[1]=
local method = kong.request.get_method()

-- Read groups from X-Userinfo header set by OIDC plugin
local userinfo_header = kong.request.get_header('X-Userinfo')

kong.log.err('DEBUG userinfo header: ' .. tostring(userinfo_header))
kong.log.err('DEBUG method: ' .. tostring(method))

if not userinfo_header then
  return kong.response.exit(401, { message = 'Unauthorized - no userinfo found' })
end

-- Decode base64 userinfo
local decoded = ngx.decode_base64(userinfo_header)
kong.log.err('DEBUG decoded userinfo: ' .. tostring(decoded))

if not decoded then
  return kong.response.exit(401, { message = 'Unauthorized - could not decode userinfo' })
end

-- Check groups in decoded userinfo
local is_get_user  = string.find(decoded, 'Kong%-Get%-Users')
local is_post_user = string.find(decoded, 'Kong%-Post%-Users')

kong.log.err('DEBUG is_get_user: ' .. tostring(is_get_user))
kong.log.err('DEBUG is_post_user: ' .. tostring(is_post_user))

if not is_get_user and not is_post_user then
  return kong.response.exit(403, { message = 'Forbidden - not in any allowed group' })
end

if (method == 'POST' or method == 'PUT' or method == 'DELETE') and not is_post_user then
  return kong.response.exit(403, { message = 'Forbidden - Kong-Post-Users group required for ' .. method })
end
"
