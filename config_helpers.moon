
_M = {}

local Service, Domain, Root

Domain = class
	new: (name, opt) =>
		@name = name

		@domain = opt.domain

		@services = {}
		@domains = {}

		for e in *opt
			if e.__class == Service
				e.parent = self

				table.insert @services, e
			elseif e.__class == Domain
				e.parent = self

				table.insert @domains, e

	getDomain: =>
		domain = @domain or @name

		if @parent
			parentDomain = @parent\getDomain!

			if parentDomain
				return domain .. "." .. @parent\getDomain!

		domain

	getServices: =>
		coroutine.wrap ->
			for service in *@services
				coroutine.yield service
			for domain in *@domains
				for service in domain\getServices!
					coroutine.yield service

	-- FIXME: Service ID model is just plain broken and stupid.
	getServiceById: (id) =>
		origin, name = id\match "([^.]*)%.(.*)"

		if origin == "domain"
			for s in *@services
				if s.name == name
					return s
		elseif origin == "parent"
			if @parent
				for s in *@parent.services
					if s.name == name
						return s
		elseif origin == "root"
			root = @parent
			while root.parent
				root = root.parent


			for s in *root.services
				if s.name == name
					return s

	print: (i = 0) =>
		for _ = 1, i
			io.write "  "
		print "#{@\getDomain!}"

		for service in *@services
			service\print i+1

		for domain in *@domains
			domain\print i+1

Root = class extends Domain
	new: (opt) =>
		super "{{ROOT}}", opt

	getDomain: => nil

	print: =>
		for s in *@services
			s\print!
		for d in *@domains
			d\print!

Service = class
	new: (name, opt) =>
		@name = name

		@domain = opt.domain

		@depends = {}

		ref = registeredServices[@name]
		unless ref
			error "no such service has been defined: #{@name}", 0

		for d in *ref.depends
			@depends[d.name] = opt[d.name]

	isBroken: =>
		ref = registeredServices[@name]

		for d in *ref.depends
			-- Services not configured.
			unless @depends[d.name]
				return "missing dependency"

		-- Services configured, but invalid IDs.
			depend = @\getServiceById @depends[d.name]

			unless depend
				return "invalid service id"

		false

	getServiceById: (id) =>
		@parent\getServiceById id

	getUsers: =>
		users = {}
		parent = @parent

		for service in parent\getServices!
			ref = registeredServices[service.name]

			for d in *ref.depends
				dependsId = service.depends[d.name]

				unless dependsId
					continue

				s = service\getServiceById dependsId

				if s == self
					table.insert users, service

		users

	print: (indent = 0) =>
		for _ = 1, indent
			io.write "  "

		io.write "#{@name}  "

		-- Printable domain indicator.
		domain = @\getDomain! or "---"

		for i = @name\len!, 20 - indent * 2
			io.write "-"

		broken = @\isBroken!
		if broken
			io.write "  #{broken\upper!}"
		else
			io.write "  #{domain}"

		io.write "\n"

		ref = registeredServices[@name]

		users = @\getUsers!

		-- This would have been a lot easier with à getUser(provider).
		if #ref.provides > 0
			for _ = 1, indent
				io.write "  "

			for p in *ref.provides
				io.write "  \027[32m+", p.name, "\027[00m"

				providesUsers = {}
				for user in *users
					id = user.depends[p.name]

					alreadyInUsers = false
					for u in *providesUsers
						if u == user\getDomain! or u == user.name
							alreadyInUsers = true
							break

					if id and user\getServiceById(id) == self and not alreadyInUsers
						table.insert providesUsers, user\getDomain! or user.name

				if #providesUsers > 0
					io.write " (", table.concat(providesUsers, ", "), ")"

				io.write "\n"

		for d in *ref.depends
			for _ = 1, indent+1
				io.write "  "

			io.write "\027[33m-", d.name, "\027[00m  "

			for i = d.name\len!, 17 - indent * 2
				io.write "·"

			-- A mandatory option is missing.
			unless @depends[d.name]
				io.write "  UNSET\n"
				continue

			service = @\getServiceById @depends[d.name]

			if service
				io.write "  "
				io.write service.name
				io.write " "
				io.write "(#{service\getDomain! or "---"})"
			else
				io.write "  INVALID SERVICE ID"

			io.write "\n"

	getDomain: =>
		@parent\getDomain!

	__tostring: =>
		"<Service: #{@name}, #{@\getDomain!}>"

_M.root =      (...) -> Root ...
_M.domain =    (...) -> Domain ...
_M.service =   (...) -> Service ...

_M.Root = Root

_M

