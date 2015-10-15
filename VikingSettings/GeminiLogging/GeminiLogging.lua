-------------------------------------------------------------------------------
-- GeminiLogging
-- Copyright (c) NCsoft. All rights reserved
-- Author: draftomatic
-- Logging library (loosely) based on LuaLogging.
-- Comes with appenders for GeminiConsole and Print() Debug Channel.
-------------------------------------------------------------------------------
local MAJOR,MINOR = "Gemini:Logging-1.2", 3
-- Get a reference to the package information if any
local APkg = Apollo.GetPackage(MAJOR)
-- If there was an older version loaded we need to see if this is newer
if APkg and (APkg.nVersion or 0) >= MINOR then
	return -- no upgrade needed
end
-- Set a reference to the actual package or create an empty table
local GeminiLogging = APkg and APkg.tPackage or {}

local strformat = string.format
local defaultOpts = {
	level = "INFO",
	pattern = "%d %n %c %l - %m",
	appender = "GeminiConsole",
}

local inspect
do
	local INSPECT_MAJOR, INSPECT_MINOR = "Drafto:Lib:inspect-1.2", 1
	-- Get a reference to the package information if any
	local APkg = Apollo.GetPackage(INSPECT_MAJOR)
	-- Set a reference to the actual package or create an empty table
	local inspect = APkg and APkg.tPackage or {}
	-- If there was an older version loaded we need to see if this is newer
	if not APkg or (APkg.nVersion or 0) < INSPECT_MINOR then
		-----------------------------------------------------------------------------------------------------------------------
		-- inspect.lua - v2.0.0 (2013-01)
		-- Enrique García Cota - enrique.garcia.cota [AT] gmail [DOT] com
		-- human-readable representations of tables.
		-- inspired by http://lua-users.org/wiki/TableSerialization
		-- Edited for WildStar by draftomatic
		-----------------------------------------------------------------------------------------------------------------------

		local inspect ={
		  _VERSION = 'inspect.lua 2.0.0',
		  _URL     = 'http://github.com/kikito/inspect.lua',
		  _DESCRIPTION = 'human-readable representations of tables',
		  _LICENSE = [[
		    MIT LICENSE

		    Copyright (c) 2013 Enrique García Cota

		    Permission is hereby granted, free of charge, to any person obtaining a
		    copy of this software and associated documentation files (the
		    "Software"), to deal in the Software without restriction, including
		    without limitation the rights to use, copy, modify, merge, publish,
		    distribute, sublicense, and/or sell copies of the Software, and to
		    permit persons to whom the Software is furnished to do so, subject to
		    the following conditions:

		    The above copyright notice and this permission notice shall be included
		    in all copies or substantial portions of the Software.

		    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
		    OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
		    MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
		    IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
		    CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
		    TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
		    SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
		  ]]
		}

		-- Apostrophizes the string if it has quotes, but not aphostrophes
		-- Otherwise, it returns a regular quoted string
		local function smartQuote(str)
		  if str:match('"') and not str:match("'") then
		    return "'" .. str .. "'"
		  end
		  return '"' .. str:gsub('"', '\\"') .. '"'
		end

		local controlCharsTranslation = {
		  ["\a"] = "\\a",  ["\b"] = "\\b", ["\f"] = "\\f",  ["\n"] = "\\n",
		  ["\r"] = "\\r",  ["\t"] = "\\t", ["\v"] = "\\v"
		}

		local function escapeChar(c) return controlCharsTranslation[c] end

		local function escape(str)
		  local result = str:gsub("\\", "\\\\"):gsub("(%c)", escapeChar)
		  return result
		end

		local function isIdentifier(str)
		  return type(str) == 'string' and str:match( "^[_%a][_%a%d]*$" )
		end

		local function isArrayKey(k, length)
		  return type(k) == 'number' and 1 <= k and k <= length
		end

		local function isDictionaryKey(k, length)
		  return not isArrayKey(k, length)
		end

		local defaultTypeOrders = {
		  ['number']   = 1, ['boolean']  = 2, ['string'] = 3, ['table'] = 4,
		  ['function'] = 5, ['userdata'] = 6, ['thread'] = 7
		}

		local function sortKeys(a, b)
		  local ta, tb = type(a), type(b)

		  -- strings and numbers are sorted numerically/alphabetically
		  if ta == tb and (ta == 'string' or ta == 'number') then return a < b end

		  local dta, dtb = defaultTypeOrders[ta], defaultTypeOrders[tb]
		  -- Two default types are compared according to the defaultTypeOrders table
		  if dta and dtb then return defaultTypeOrders[ta] < defaultTypeOrders[tb]
		  elseif dta     then return true  -- default types before custom ones
		  elseif dtb     then return false -- custom types after default ones
		  end

		  -- custom types are sorted out alphabetically
		  return ta < tb
		end

		local function getDictionaryKeys(t)
		  local keys, length = {}, #t
		  for k,_ in pairs(t) do
		    if isDictionaryKey(k, length) then table.insert(keys, k) end
		  end
		  table.sort(keys, sortKeys)
		  return keys
		end

		local function getToStringResultSafely(t, mt)
		  local __tostring = type(mt) == 'table' and rawget(mt, '__tostring')
		  local str, ok
		  if type(__tostring) == 'function' then
		    ok, str = pcall(__tostring, t)
		    str = ok and str or 'error: ' .. tostring(str)
		  end
		  if type(str) == 'string' and #str > 0 then return str end
		end

		local maxIdsMetaTable = {
		  __index = function(self, typeName)
		    rawset(self, typeName, 0)
		    return 0
		  end
		}

		local idsMetaTable = {
		  __index = function (self, typeName)
		    local col = setmetatable({}, {__mode = "kv"})
		    rawset(self, typeName, col)
		    return col
		  end
		}

		local function countTableAppearances(t, tableAppearances)
		  tableAppearances = tableAppearances or setmetatable({}, {__mode = "k"})

		  if type(t) == 'table' then
		    if not tableAppearances[t] then
		      tableAppearances[t] = 1
		      for k,v in pairs(t) do
		        countTableAppearances(k, tableAppearances)
		        countTableAppearances(v, tableAppearances)
		      end
		      countTableAppearances(getmetatable(t), tableAppearances)
		    else
		      tableAppearances[t] = tableAppearances[t] + 1
		    end
		  end

		  return tableAppearances
		end

		local function parse_filter(filter)
		  if type(filter) == 'function' then return filter end
		  -- not a function, so it must be a table or table-like
		  filter = type(filter) == 'table' and filter or {filter}
		  local dictionary = {}
		  for _,v in pairs(filter) do dictionary[v] = true end
		  return function(x) return dictionary[x] end
		end

		-------------------------------------------------------------------
		function inspect.inspect(rootObject, options)
		  options       = options or {}
		  local depth   = options.depth or math.huge
		  local filter  = parse_filter(options.filter or {})

		  local tableAppearances = countTableAppearances(rootObject)

		  local buffer = {}
		  local maxIds = setmetatable({}, maxIdsMetaTable)
		  local ids    = setmetatable({}, idsMetaTable)
		  local level  = 0
		  local blen   = 0 -- buffer length

		  local function puts(...)
		    local args = {...}
		    for i=1, #args do
		      blen = blen + 1
		      buffer[blen] = tostring(args[i])
		    end
		  end

		  local function down(f)
		    level = level + 1
		    f()
		    level = level - 1
		  end

		  local function tabify()
		    puts("\n", string.rep("  ", level))
		  end

		  local function commaControl(needsComma)
		    if needsComma then puts(',') end
		    return true
		  end

		  local function alreadyVisited(v)
		    return ids[type(v)][v] ~= nil
		  end

		  local function getId(v)
		    local tv = type(v)
		    local id = ids[tv][v]
		    if not id then
		      id         = maxIds[tv] + 1
		      maxIds[tv] = id
		      ids[tv][v] = id
		    end
		    return id
		  end

		  local putValue -- forward declaration that needs to go before putTable & putKey

		  local function putKey(k)
		    if isIdentifier(k) then return puts(k) end
		    puts( "[" )
		    putValue(k)
		    puts("]")
		  end

		  local function putTable(t)
		    if alreadyVisited(t) then
		      puts('<table ', getId(t), '>')
		    elseif level >= depth then
		      puts('{...}')
		    else
		      if tableAppearances[t] > 1 then puts('<', getId(t), '>') end

		      local dictKeys          = getDictionaryKeys(t)
		      local length            = #t
		      local mt                = getmetatable(t)
		      local to_string_result  = getToStringResultSafely(t, mt)

		      puts('{')
		      down(function()
		        if to_string_result then
		          puts(' -- ', escape(to_string_result))
		          if length >= 1 then tabify() end -- tabify the array values
		        end

		        local needsComma = false
		        for i=1, length do
		          needsComma = commaControl(needsComma)
		          puts(' ')
		          putValue(t[i])
		        end

		        for _,k in ipairs(dictKeys) do
		          needsComma = commaControl(needsComma)
		          tabify()
		          putKey(k)
		          puts(' = ')
		          putValue(t[k])
		        end

		        if mt then
		          needsComma = commaControl(needsComma)
		          tabify()
		          puts('<metatable> = ')
		          putValue(mt)
		        end
		      end)

		      if #dictKeys > 0 or mt then -- dictionary table. Justify closing }
		        tabify()
		      elseif length > 0 then -- array tables have one extra space before closing }
		        puts(' ')
		      end

		      puts('}')
		    end

		  end

		  -- putvalue is forward-declared before putTable & putKey
		  putValue = function(v)
		    if filter(v) then
		      puts('<filtered>')
		    else
		      local tv = type(v)

		      if tv == 'string' then
		        puts(smartQuote(escape(v)))
		      elseif tv == 'number' or tv == 'boolean' or tv == 'nil' then
		        puts(tostring(v))
		      elseif tv == 'table' then
		        putTable(v)
		      else
		        puts('<',tv,' ',getId(v),'>')
		      end
		    end
		  end

		  putValue(rootObject)

		  return table.concat(buffer)
		end

		setmetatable(inspect, { __call = function(_, ...) return inspect.inspect(...) end })

		Apollo.RegisterPackage(inspect, INSPECT_MAJOR, INSPECT_MINOR, {})
	end
end

function GeminiLogging:OnLoad()
	
	inspect = Apollo.GetPackage("Drafto:Lib:inspect-1.2").tPackage
	self.console = Apollo.GetAddon("GeminiConsole")
	
	-- The GeminiLogging.DEBUG Level designates fine-grained informational events that are most useful to debug an application
	-- The GeminiLogging.INFO level designates informational messages that highlight the progress of the application at coarse-grained level
	-- The GeminiLogging.WARN level designates potentially harmful situations
	-- The GeminiLogging.ERROR level designates error events that might still allow the application to continue running
	-- The GeminiLogging.FATAL level designates very severe error events that will presumably lead the application to abort

	-- Data structures for levels
	self.LEVEL = {"DEBUG", "INFO", "WARN", "ERROR", "FATAL"}
	self.MAX_LEVELS = #self.LEVEL
	-- Enumerate levels and build Lookups
	for i=1,self.MAX_LEVELS do
		self[self.LEVEL[i]] = self.LEVEL[i]
		self.LEVEL[self.LEVEL[i]] = i
	end

end

function GeminiLogging:OnDependencyError(strDep, strError)
	if strDep == "GeminiConsole" then return true end
	Print("GeminiLogging couldn't load " .. strDep .. ". Fatal error: " .. strError)
	return false
end

-- Factory method for loggers
function GeminiLogging:GetLogger(optSettings)
	local opt

	-- Default options
	if not optSettings or type(optSettings) ~= "table" then 
		opt = defaultOpts
	else
		-- Create table and populate with defaults if no override present
		opt = {}
		for k,v in pairs(defaultOpts) do
			opt[k] = optSettings[k] or v
		end
	end

	-- Initialize logger object
	local logger = {}
	
	-- Set appender
	if not opt.appender or type(opt.appender) == "string" then
		logger.append = self:GetAppender(opt.appender)
		if not logger.append then
			Print("Invalid appender")
			return nil
		end
	elseif type(opt.appender) == "function" then
		logger.append = opt.appender
	else
		Print("Invalid appender")
		return nil
	end
	
	-- Set pattern
	logger.pattern = opt.pattern
	
	-- Set level
	logger.level = self.LEVEL[opt.level]
	local order = self.LEVEL[logger.level]
	
	-- Set logger functions (debug, info, etc.) based on level option
	for i=1,self.MAX_LEVELS do
		local currentLevel = i
		local upperName = self.LEVEL[i]
		local name = upperName:lower()
		logger[name] = function(self, fmt, ...)
			-- Only output if the level is correct.
			if logger.level > currentLevel then return end
			local debugInfo = debug.getinfo(2)		-- Get debug info for caller of log function
			--Print(inspect(debug.getinfo(3)))
			--local caller = debugInfo.name or ""
			local dir, file, ext = string.match(debugInfo.short_src, "(.-)([^\\]-([^%.]+))$")
			local caller = file or ""
			local message = type(fmt) == "string" and strformat(fmt, ...) or fmt
			caller = string.gsub(caller, "." .. ext, "")
			local line = debugInfo.currentline or "-"
			logger:append(GeminiLogging.PrepareLogMessage(logger, message, upperName, caller, line))		-- Give the appender the level string
		end
	end

	logger.SetLevel = function(self, level)
		local newLevel = GeminiLogging.LEVEL[level]
		if newLevel then
			logger.level = newLevel
		else
			Print("Invalid Logging Level: " .. level)
		end
	end

	return logger
end

function GeminiLogging:PrepareLogMessage(message, level, caller, line)
	
	if type(message) ~= "string" then
		if type(message) == "userdata" then
			message = inspect(getmetatable(message))
		else
			message = inspect(message)
		end
	end
	
	local logMsg = self.pattern
	message = string.gsub(message, "%%", "%%%%")
	logMsg = string.gsub(logMsg, "%%d", os.date("%I:%M:%S%p"))		-- only time, in 12-hour AM/PM format. This could be configurable...
	logMsg = string.gsub(logMsg, "%%l", level)
	logMsg = string.gsub(logMsg, "%%c", caller)
	logMsg = string.gsub(logMsg, "%%n", line)
	logMsg = string.gsub(logMsg, "%%m", message)
	
	return logMsg
end


-------------------------------------------------------------------------------
-- Default Appenders
-------------------------------------------------------------------------------
--[[local tLevelColors = {
	DEBUG = "FF4DDEFF",
	INFO = "FF52FF4D",
	WARN = "FFFFF04D",
	ERROR = "FFFFA04D",
	FATAL = "FFFF4D4D"
}--]]
function GeminiLogging:GetAppender(name)
	if name == "GeminiConsole" then
		return function(self, message, level)
			if GeminiLogging.console ~= nil then
				GeminiLogging.console:Append(message)
			else
				Print(message)
			end
		end
	else
		return function(self, message, level)
			Print(message)
		end
	end
	return nil
end

Apollo.RegisterPackage(GeminiLogging, MAJOR, MINOR, {"Drafto:Lib:inspect-1.2", "GeminiConsole"})