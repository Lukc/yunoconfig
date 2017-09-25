
service "nginx", {
	provides "http", {}
	provides "www", {}
	provides "php", {}
	consumes "http", {
		optional: true
		publicPorts: {80, 443}
	}

	service: =>
		configFile = "#{@\getConfigurationRoot!.rootDirectory}/etc/nginx.cfg"
		{
			start: "nginx -c #{configFile}"
			preStart: "nginx -t #{configFile}"
			reload: "signal:HUP"
			-- Default handler.
			--stop: "signal:TERM"
			after: {"networking", "dns", "logger", "netmount"}
			requiredFiles: {configFile}
		}

	configure: =>
		@\writeTemplate "nginx", "etc/nginx.cfg"
}

