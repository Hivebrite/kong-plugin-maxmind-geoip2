-- Load the base plugin and create a subclass.
local plugin   = require("kong.plugins.base_plugin"):extend()
local cjson    = require "cjson"
local body     = ngx.req.read_body
local set_body = ngx.req.set_body_data
local get_body = ngx.req.get_body_data
local header   = ngx.req.set_header
local pcall    = pcall

-- Function to parse JSON.
local function parse_json(body)
	if body then
		local status, res = pcall(cjson.decode, body)
		if status then
			return res
		end
	end
end

-- Subclass constructor.
function plugin:new()
	plugin.super.new(self, "maxmind-geoip2")
end

-- Runs inside of the access_by_lua_block hook.
function plugin:access(config)
	-- Make sure the base plugin also runs the access function.
	plugin.super.access(self)

	-- Set geolocation headers.
	if config.headers then
		header("X-Visitor-Continent", ngx.var.geoip2_continent)
		header("X-Visitor-Country-Name", ngx.var.geoip2_country_name)
		header("X-Visitor-Country-Code", ngx.var.geoip2_country_code)
		header("X-Visitor-Registered-Country-Name", ngx.var.geoip2_registered_country_name)
		header("X-Visitor-Registered-Country-Code", ngx.var.geoip2_registered_country_code)
		header("X-Visitor-Subdivision-Name", ngx.var.geoip2_subdivision_name)
		header("X-Visitor-Subdivision-Code", ngx.var.geoip2_subdivision_code)
		header("X-Visitor-City-Name", ngx.var.geoip2_city_name)
		header("X-Visitor-Postal-Code", ngx.var.geoip2_postal_code)
		header("X-Visitor-Latitude", ngx.var.geoip2_latitude)
		header("X-Visitor-Longitude", ngx.var.geoip2_longitude)
	end

	-- Prepare to append geolocation data to the request JSON body.
	if config.body then
		-- Prepare body.
		body()
		local base_body = get_body()
		local content_length = (base_body and #base_body) or 0
		if content_length <= 0 then
			return
		end

		-- Set client IP.
		local client_ip = ngx.var.remote_addr
		if ngx.req.get_headers()['x-forwarded-for'] then
			client_ip = string.match(ngx.req.get_headers()['x-forwarded-for'], "[^,%s]+")
		end

	  	-- Append the data to the body.
	  	local parameters  = parse_json(base_body)
	  	parameters["gct"] = ngx.var.geoip2_continent
	  	parameters["gcs"] = ngx.var.geoip2_country_name
	  	parameters["gcc"] = ngx.var.geoip2_country_code
	  	parameters["grn"] = ngx.var.geoip2_registered_country_name
	  	parameters["grc"] = ngx.var.geoip2_registered_country_code
	  	parameters["gsn"] = ngx.var.geoip2_subdivision_name
	  	parameters["gnc"] = ngx.var.geoip2_subdivision_code
	  	parameters["gcn"] = ngx.var.geoip2_city_name
	  	parameters["gpc"] = ngx.var.geoip2_postal_code
	  	parameters["glt"] = ngx.var.geoip2_latitude
	  	parameters["gln"] = ngx.var.geoip2_longitude
	  	parameters["ip"]  = client_ip

	  	-- Finally, save the new body data.
	  	local transformed_body = cjson.encode(parameters)
	  	set_body(transformed_body)
	  	header("Content-Length", #transformed_body)
	end
end

-- Set a custom plugin priority.
plugin.PRIORITY = 799

-- Return the plugin.
return plugin