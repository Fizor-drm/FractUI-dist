local __DARKLUA_BUNDLE_MODULES={cache={}::any}do do local function __modImpl()--// Theme tokens: the semantic colors of the library.
--// The dark palette keeps the nine public tokens. Accent is the solid blue
--// that carries white text at 5.33:1; the lighter blue does not. Placeholder
--// stays quieter than Muted and still clears 4.5:1 on the dark control fill.
local Defaults = {
	Background = Color3.fromRGB(30, 30, 32),
	Surface = Color3.fromRGB(44, 44, 46),
	Highlight = Color3.fromRGB(255, 255, 255),
	Text = Color3.fromRGB(245, 245, 247),
	Muted = Color3.fromRGB(184, 184, 192),
	Placeholder = Color3.fromRGB(170, 170, 180),
	Outline = Color3.fromRGB(255, 255, 255),
	Accent = Color3.fromRGB(0, 103, 217),
	Border = Color3.fromRGB(66, 66, 71),
}

--// The order the theme editor lists the tokens in.
local Order = {
	"Background",
	"Surface",
	"Highlight",
	"Text",
	"Muted",
	"Placeholder",
	"Outline",
	"Accent",
	"Border",
}

local Current = {}
for name, color in pairs(Defaults) do
	Current[name] = color
end

--// instance -> { Property = Token }. Weak keys so a destroyed widget leaves nothing behind.
local Registry = setmetatable({}, { __mode = "k" })

local Theme = {}

--// The color of a token, or nil when the token does not exist.
function Theme.Get(Token)
	return Current[Token]
end

--// Paints an instance with a token and remembers the pair so a theme change can repaint it.
function Theme.Set(Instance, Property, Token)
	local color = Current[Token]
	if not color then return end

	Instance[Property] = color

	local properties = Registry[Instance]
	if not properties then
		properties = {}
		Registry[Instance] = properties
	end
	properties[Property] = Token
end

--// Repaints every registered instance with the current token colors.
function Theme.Apply()
	for instance, properties in pairs(Registry) do
		for property, token in pairs(properties) do
			local color = Current[token]
			if color then
				pcall(function()
					instance[property] = color
				end)
			end
		end
	end
end

--// The current token colors, as a copy.
function Theme.Snapshot()
	local snapshot = {}
	for _, name in ipairs(Order) do
		snapshot[name] = Current[name]
	end
	return snapshot
end

--// Replaces the given tokens and repaints the interface.
--// Every token is validated first, so a broken theme never reaches the interface.
function Theme.Update(Tokens)
	if type(Tokens) ~= "table" then
		return false, "Invalid theme data"
	end

	for name, color in pairs(Tokens) do
		if not Defaults[name] then
			return false, string.format("Unknown theme token %q", tostring(name))
		end
		if typeof(color) ~= "Color3" then
			return false, string.format("Theme token %q is not a color", name)
		end
	end

	for name, color in pairs(Tokens) do
		Current[name] = color
	end

	Theme.Apply()
	return true
end

--// Restores the built-in theme.
function Theme.Reset()
	for name, color in pairs(Defaults) do
		Current[name] = color
	end

	Theme.Apply()
	return true
end

Theme.Defaults = Defaults
Theme.Order = Order
Theme.Current = Current

return Theme
end function __DARKLUA_BUNDLE_MODULES.a():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.a if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.a=v end return v.c end end do local function __modImpl()--// Shared helpers of the library.
--// The addons use them through FractUI.Util, so a rule like "a config name
--// may not contain a path separator" is written down exactly once.

local Util = {}

--// The modes of the inline key picker.
local KeyPickerModes = {
	Toggle = true,
	Hold = true,
	Press = true,
	Always = true,
}

--// The names of the devices of Windows. A file with such a name cannot be
--// written on a Windows machine.
local reservedNames = {
	CON = true, PRN = true, AUX = true, NUL = true,
	COM1 = true, COM2 = true, COM3 = true, COM4 = true, COM5 = true,
	COM6 = true, COM7 = true, COM8 = true, COM9 = true,
	LPT1 = true, LPT2 = true, LPT3 = true, LPT4 = true, LPT5 = true,
	LPT6 = true, LPT7 = true, LPT8 = true, LPT9 = true,
}

--// Checks one part of a name. The same rules hold for a file name and for a
--// part of a folder path.
local function isValidPart(part)
	if part == "" then
		return false
	end
	-- a control character, a NUL or a delete
	if part:find("[%z\1-\31\127]") then
		return false
	end
	-- Windows drops a trailing dot and a trailing space
	local last = part:sub(-1)
	if last == "." or last == " " then
		return false
	end
	-- a leading space is not shown in a list of the files
	if part:sub(1, 1) == " " then
		return false
	end
	-- a device name is reserved with every extension and in every case
	local stem = part:match("^([^.]*)") or ""
	if reservedNames[stem:upper()] then
		return false
	end
	return true
end

--// A name of a config file. It is one file name, never a path.
function Util.IsValidName(Name)
	if type(Name) ~= "string" then
		return false
	end

	if Name == "" then
		return false
	end
	-- a separator would turn the name into a path
	if Name:find("[/\\]") then
		return false
	end
	-- characters a file name may not hold
	if Name:find('[<>:"|%?*]') then
		return false
	end
	-- The name is used as it is written, so it is checked as it is written.
	if not isValidPart(Name) then
		return false
	end
	return true
end

--// A folder of the config tree. It may hold separators, but never walks up
--// and never leaves the workspace.
function Util.IsValidFolderPath(Folder)
	if type(Folder) ~= "string" then
		return false
	end

	if Folder == "" then
		return false
	end
	if Folder:find("%.%.") then
		return false
	end
	if Folder:find('[<>:"|%?*]') then
		return false
	end
	-- the separator of a folder path is the slash, a backslash would name
	-- another folder on a Windows machine
	if Folder:find("\\") then
		return false
	end
	-- an absolute path would leave the workspace
	if Folder:sub(1, 1) == "/" then
		return false
	end
	-- an empty part would name another folder
	if Folder:find("//") or Folder:sub(-1) == "/" then
		return false
	end
	-- every part of the path is a name of its own
	for part in Folder:gmatch("[^/]+") do
		if not isValidPart(part) then
			return false
		end
	end
	return true
end

--// True when the number is a real number, not an infinity and not a nan.
function Util.IsFinite(value)
	if type(value) ~= "number" then
		return false
	end
	return value == value and value ~= math.huge and value ~= -math.huge
end

--// The enums a key bind can come from. The enum type of an item is an object
--// in Roblox, so the library compares it with the enums it can bind.
local BindTypes = {
	KeyCode = Enum.KeyCode,
	UserInputType = Enum.UserInputType,
}

--// The name of the enum an item belongs to. It is nil when the item belongs
--// to an enum the library cannot bind.
function Util.BindTypeName(item)
	-- The items of an enum are userdata in Roblox, so "type" never tells that
	-- one of them is a table.
	if typeof(item) ~= "EnumItem" then
		return nil
	end
	for name, enumType in pairs(BindTypes) do
		if item.EnumType == enumType then
			return name
		end
	end
	return nil
end

--// Looks a bind up. A wrong name throws in Roblox, so the lookup is guarded.
function Util.FindBind(bindType, bind)
	local enumType = BindTypes[bindType]
	if not enumType or type(bind) ~= "string" then
		return nil
	end
	local ok, item = pcall(function()
		return enumType[bind]
	end)
	if not ok then
		return nil
	end
	-- A name of a method of the enum is a function and not a member of it.
	if typeof(item) ~= "EnumItem" then
		return nil
	end
	-- The member has to belong to the enum that was asked for.
	if item.EnumType ~= enumType then
		return nil
	end
	return item
end

--// The shape a saved widget entry has to follow.
--// A bind that is missing is the old format, it means the widget was not
--// bound. An alpha of false means the color picker has no alpha.
local function isBind(value)
	return value == nil or value == false or type(value) == "string"
end

local function isColorValue(value)
	return type(value) == "string" and value:match("^#?%x%x%x%x%x%x$") ~= nil
end

local function isAlpha(value)
	if value == false then
		return true
	end
	if not Util.IsFinite(value) then
		return false
	end
	return value >= 0 and value <= 1
end

--// The methods a widget needs so an entry of its class can be applied.
local RequiredMethods = {
	Toggle = { "UpdateState" },
	Slider = { "UpdateValue" },
	Input = { "UpdateText" },
	Keybind = { "Bind", "Unbind" },
	KeyPicker = { "Bind", "Unbind", "SetMode", "SetState" },
	Dropdown = { "UpdateSelection" },
	Colorpicker = { "SetColor" },
	ColorPicker = { "SetColor" },
}

local function requiredMethods(object)
	if object.type == "Colorpicker" or object.type == "ColorPicker" then
		if object.alpha ~= nil and object.alpha ~= false then
			return { "SetColor", "SetAlpha" }
		end
		return { "SetColor" }
	end
	return RequiredMethods[object.type] or {}
end

local ConfigShapes = {
	Toggle = {
		validate = function(object)
			if type(object.state) ~= "boolean" then
				return false, "A toggle entry has no boolean state."
			end
			return true
		end,
	},
	Slider = {
		validate = function(object, widget)
			if object.value == false then
				return true
			end
			if type(object.value) ~= "string" then
				return false, "A slider entry has no value."
			end

			local value = tonumber(object.value)
			if not value then
				return false, "A slider entry has a value that is not a number."
			end
			if not Util.IsFinite(value) then
				return false, "A slider entry has a value that is not a real number."
			end

			local settings = widget and widget.Settings
			if type(settings) == "table" and type(settings.Minimum) == "number" and type(settings.Maximum) == "number" then
				if value < settings.Minimum or value > settings.Maximum then
					return false, "A slider entry is outside the range of its widget."
				end
			end

			return true
		end,
	},
	Input = {
		validate = function(object)
			-- a field that was never written holds no text
			if object.text ~= nil and type(object.text) ~= "string" then
				return false, "An input entry has no text."
			end
			return true
		end,
	},
	Keybind = {
		validate = function(object)
			if not isBind(object.bind) then
				return false, "A keybind entry has no bind."
			end
			if object.bindType ~= nil and type(object.bindType) ~= "string" then
				return false, "A keybind entry has no bind type."
			end
			if type(object.bind) == "string" and not Util.FindBind(object.bindType or "KeyCode", object.bind) then
				return false, "A keybind entry has a bind that does not exist."
			end
			return true
		end,
	},
	KeyPicker = {
		validate = function(object)
			if not isBind(object.bind) then
				return false, "A key picker entry has no bind."
			end
			if object.bindType ~= nil and type(object.bindType) ~= "string" then
				return false, "A key picker entry has no bind type."
			end
			if type(object.bind) == "string" and not Util.FindBind(object.bindType or "KeyCode", object.bind) then
				return false, "A key picker entry has a bind that does not exist."
			end
			if object.mode ~= nil and not KeyPickerModes[object.mode] then
				return false, "A key picker entry has an unknown mode."
			end
			if object.state ~= nil and type(object.state) ~= "boolean" then
				return false, "A key picker entry has no boolean state."
			end
			return true
		end,
	},
	Dropdown = {
		validate = function(object)
			local value = object.value
			-- a dropdown that was never used holds no selection
			if value == nil or value == false then
				return true
			end
			if type(value) == "table" then
				for _, item in ipairs(value) do
					if type(item) ~= "string" then
						return false, "A dropdown entry has a selection that is not a name."
					end
				end
				return true
			end
			if type(value) ~= "string" then
				return false, "A dropdown entry has no selection."
			end
			return true
		end,
	},
	Colorpicker = {
		validate = function(object)
			if object.color ~= nil and not isColorValue(object.color) then
				return false, "A colorpicker entry has no hex color."
			end
			if object.alpha ~= nil and not isAlpha(object.alpha) then
				return false, "A colorpicker entry has an alpha that is not a number."
			end
			return true
		end,
	},
	ColorPicker = {
		validate = function(object)
			if object.color ~= nil and not isColorValue(object.color) then
				return false, "A color picker entry has no hex color."
			end
			if object.alpha ~= nil and not isAlpha(object.alpha) then
				return false, "A color picker entry has an alpha that is not a number."
			end
			return true
		end,
	},
}

--// True when the table is a plain list. A table with other keys or a hole in
--// it would hide entries from the check.
local function isList(value)
	local count = 0
	for key in pairs(value) do
		if type(key) ~= "number" then
			return false
		end
		count += 1
	end
	for index = 1, count do
		if value[index] == nil then
			return false
		end
	end
	return true
end

--// Checks a decoded config before a single widget is touched.
--// A broken config is rejected as a whole, so a half applied config can never
--// happen. The checked entries are returned, so the same ones are applied.
function Util.ValidateConfigData(Data, Options)
	if type(Data) ~= "table" then
		return false, "The config data is not a table."
	end

	local objects = Data.objects
	if type(objects) ~= "table" then
		return false, "The config data holds no objects."
	end
	if not isList(objects) then
		return false, "The config data holds no list of entries."
	end

	local flags = {}
	local entries = {}

	for _, object in ipairs(objects) do
		if type(object) ~= "table" then
			return false, "A config entry is not a table."
		end

		local shape = ConfigShapes[object.type]
		if not shape then
			return false, string.format("A config entry has the unknown class %q.", tostring(object.type))
		end

		if type(object.flag) ~= "string" or object.flag == "" then
			return false, "A config entry has no flag."
		end

		if flags[object.flag] then
			return false, string.format("The config holds the flag %q twice.", object.flag)
		end
		flags[object.flag] = true

		local widget = type(Options) == "table" and Options[object.flag] or nil

		-- The widget has to be the one the entry was written for.
		if widget then
			if widget.Class ~= object.type then
				return false, string.format(
					"The widget %q is a %s and not a %s.",
					object.flag,
					tostring(widget.Class),
					object.type
				)
			end
			for _, method in ipairs(requiredMethods(object)) do
				if type(widget[method]) ~= "function" then
					return false, string.format("The widget %q has no %s method.", object.flag, method)
				end
			end
		end

		local valid, reason = shape.validate(object, widget)
		if not valid then
			return false, reason
		end

		table.insert(entries, object)
	end

	return true, nil, entries
end

--// The file system of the executor. Every helper reports what went wrong.
function Util.IsFile(Path)
	if type(isfile) ~= "function" then
		return false
	end
	local ok, result = pcall(isfile, Path)
	return ok and result and true or false
end

function Util.IsFolder(Path)
	if type(isfolder) ~= "function" then
		return false
	end
	local ok, result = pcall(isfolder, Path)
	return ok and result and true or false
end

function Util.MakeFolder(Path)
	if type(makefolder) ~= "function" then
		return false, "File system unavailable."
	end
	local ok, err = pcall(makefolder, Path)
	if not ok then
		return false, tostring(err)
	end
	return true
end

function Util.ReadFile(Path)
	if type(readfile) ~= "function" then
		return false, "File system unavailable."
	end
	local ok, content = pcall(readfile, Path)
	if not ok then
		return false, tostring(content)
	end
	return true, content
end

function Util.WriteFile(Path, Content)
	if type(writefile) ~= "function" then
		return false, "File system unavailable."
	end
	local ok, err = pcall(writefile, Path, Content)
	if not ok then
		return false, tostring(err)
	end
	return true
end

function Util.DeleteFile(Path)
	if type(delfile) ~= "function" then
		return false, "File system unavailable."
	end
	local ok, err = pcall(delfile, Path)
	if not ok then
		return false, tostring(err)
	end
	return true
end

function Util.ListFiles(Path)
	if type(listfiles) ~= "function" then
		return false, "File system unavailable."
	end
	local ok, list = pcall(listfiles, Path)
	if not ok then
		return false, tostring(list)
	end
	if type(list) ~= "table" then
		return false, "The file list is not a table."
	end
	return true, list
end

--// Creates a folder and every folder above it.
function Util.BuildFolderTree(Path)
	if type(Path) ~= "string" or Path == "" then
		return false, "Invalid path provided."
	end

	local current = ""
	for part in Path:gmatch("[^/]+") do
		current = current == "" and part or (current .. "/" .. part)
		if not Util.IsFolder(current) then
			local ok, err = Util.MakeFolder(current)
			if not ok then
				return false, err
			end
		end
	end

	return true
end

Util.KeyPickerModes = KeyPickerModes

return Util
end function __DARKLUA_BUNDLE_MODULES.b():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.b if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.b=v end return v.c end end do local function __modImpl()
local theme = __DARKLUA_BUNDLE_MODULES.a()
local util = __DARKLUA_BUNDLE_MODULES.b()

local FractUI = {
	Options = {},
	Theme = theme,
	Util = util,
	Folder = "Maclib",
	GetService = function(service)
		return cloneref and cloneref(game:GetService(service)) or game:GetService(service)
	end
}

--// Services
local TweenService = FractUI.GetService("TweenService")
local RunService = FractUI.GetService("RunService")
local HttpService = FractUI.GetService("HttpService")
local ContentProvider = FractUI.GetService("ContentProvider")
local UserInputService = FractUI.GetService("UserInputService")
local Lighting = FractUI.GetService("Lighting")
local Players = FractUI.GetService("Players")

--// Variables
local isStudio = RunService:IsStudio()
local LocalPlayer = Players.LocalPlayer

local assets = {
	interFont = "rbxassetid://12187365364",
	userInfoBlurred = "rbxassetid://18824089198",
	toggleBackground = "rbxassetid://18772190202",
	togglerHead = "rbxassetid://18772309008",
	buttonImage = "rbxassetid://10709791437",
	searchIcon = "rbxassetid://86737463322606",
	colorWheel = "rbxassetid://2849458409",
	colorTarget = "rbxassetid://73265255323268",
	grid = "rbxassetid://121484455191370",
	globe = "rbxassetid://108952102602834",
	transform = "rbxassetid://90336395745819",
	dropdown = "rbxassetid://18865373378",
	sliderbar = "rbxassetid://18772615246",
	sliderhead = "rbxassetid://18772834246",
}

local function GetGui()
	local newGui = Instance.new("ScreenGui")
	newGui.ScreenInsets = Enum.ScreenInsets.None
	newGui.ResetOnSpawn = false
	newGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	newGui.DisplayOrder = 2147483647

	local parent = RunService:IsStudio()
		and LocalPlayer:FindFirstChild("PlayerGui")
		or (gethui and gethui())
		or (cloneref and cloneref(FractUI.GetService("CoreGui")) or FractUI.GetService("CoreGui"))

	newGui.Parent = parent
	return newGui
end

local function Tween(instance, tweeninfo, propertytable)
	return TweenService:Create(instance, tweeninfo, propertytable)
end

--// Lightweight signal used by widgets that let other widgets observe their value.
local function NewSignal()
	local handlers = {}
	local signal = {}

	function signal:Connect(handler)
		local entry = { handler = handler }
		table.insert(handlers, entry)
		return {
			Disconnect = function()
				for index, existing in ipairs(handlers) do
					if existing == entry then
						table.remove(handlers, index)
						break
					end
				end
			end,
		}
	end

	function signal:Fire(...)
		local snapshot = table.clone(handlers)
		for _, entry in ipairs(snapshot) do
			-- A handler that fails does not stop the others, and the failure
			-- is reported.
			local ok, err = pcall(entry.handler, ...)
			if not ok then
				warn("FractUI: a handler of a signal failed: " .. tostring(err))
			end
		end
	end

	-- Releases every handler, so a destroyed widget stops notifying its listeners.
	function signal:Clear()
		table.clear(handlers)
	end

	return signal
end

--// GuiService.ReducedMotionEnabled is hidden from the normal property list
--// but has read security None, so a script can read it. Read per transition
--// through pcall: a platform that blocks the read gets the safe fade-only
--// behavior instead of a hard error.
local function ReducedMotion()
	local ok, value = pcall(function()
		return FractUI.GetService("GuiService").ReducedMotionEnabled
	end)
	return not ok or value == true
end

return {
	FractUI = FractUI,
	assets = assets,
	GetGui = GetGui,
	Tween = Tween,
	NewSignal = NewSignal,
	ReducedMotion = ReducedMotion,
	TweenService = TweenService,
	RunService = RunService,
	HttpService = HttpService,
	ContentProvider = ContentProvider,
	UserInputService = UserInputService,
	Lighting = Lighting,
	Players = Players,
	isStudio = isStudio,
	LocalPlayer = LocalPlayer,
}
end function __DARKLUA_BUNDLE_MODULES.c():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.c if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.c=v end return v.c end end do local function __modImpl()--[[
Lucide icons

The asset ids below are copied from the generated `.icons` map of
frappedevs/lucideblox at commit 8d4915489e9c4c6c0a1bcfb1b91b1261d791899f
(src/modules/util/icons.json). That port follows Lucide's 2022 catalog, so a
Lucide icon added after it is not in this map. Nothing here is fetched, loaded
or executed at runtime.

The map has 565 names. The chevron used by this library and a sample of the
catalog were checked in a live client; a map entry is not a claim that every
asset id still renders.

Lucide is ISC licensed, the Feather-derived icons keep their MIT notice, and
the Roblox port is MIT licensed by nanako. The notices follow.

Lucide ISC:

ISC License

Copyright (c) 2026 Lucide Icons and Contributors

Permission to use, copy, modify, and/or distribute this software for any
purpose with or without fee is hereby granted, provided that the above
copyright notice and this permission notice appear in all copies.

THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

---

The following Lucide icons are derived from the Feather project:

airplay, alert-circle, alert-octagon, alert-triangle, aperture, arrow-down-circle, arrow-down-left, arrow-down-right, arrow-down, arrow-left-circle, arrow-left, arrow-right-circle, arrow-right, arrow-up-circle, arrow-up-left, arrow-up-right, arrow-up, at-sign, calendar, cast, check, chevron-down, chevron-left, chevron-right, chevron-up, chevrons-down, chevrons-left, chevrons-right, chevrons-up, circle, clipboard, clock, code, columns, command, compass, corner-down-left, corner-down-right, corner-left-down, corner-left-up, corner-right-down, corner-right-up, corner-up-left, corner-up-right, crosshair, database, divide-circle, divide-square, dollar-sign, download, external-link, feather, frown, hash, headphones, help-circle, info, italic, key, layout, life-buoy, link-2, link, loader, lock, log-in, log-out, maximize, meh, minimize, minimize-2, minus-circle, minus-square, minus, monitor, moon, more-horizontal, more-vertical, move, music, navigation-2, navigation, octagon, pause-circle, percent, plus-circle, plus-square, plus, power, radio, rss, search, server, share, shopping-bag, sidebar, smartphone, smile, square, table-2, tablet, target, terminal, trash-2, trash, triangle, tv, type, upload, x-circle, x-octagon, x-square, x, zoom-in, zoom-out

The MIT License (MIT) (for the icons listed above)

Copyright (c) 2013-present Cole Bemis

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

Feather MIT:

The MIT License (MIT)

Copyright (c) 2013-2023 Cole Bemis

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

lucideblox MIT:

MIT License

Copyright (c) 2021 nanako

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]]


local Icons = {}

--// The static catalog. A name absent here is not a Lucide name of this port.
Icons.Map = {
	["CD"] = "rbxassetid://7734110220",
	["activity"] = "rbxassetid://7733655755",
	["airplay"] = "rbxassetid://7733655834",
	["alarm-check"] = "rbxassetid://7733655912",
	["alarm-clock"] = "rbxassetid://7733656100",
	["alarm-clock-off"] = "rbxassetid://7733656003",
	["alarm-minus"] = "rbxassetid://7733656164",
	["alarm-plus"] = "rbxassetid://7733658066",
	["album"] = "rbxassetid://7733658133",
	["alert-circle"] = "rbxassetid://7733658271",
	["alert-octagon"] = "rbxassetid://7733658335",
	["alert-triangle"] = "rbxassetid://7733658504",
	["align-center"] = "rbxassetid://7733909776",
	["align-center-horizontal"] = "rbxassetid://8997380477",
	["align-center-vertical"] = "rbxassetid://8997380737",
	["align-end-horizontal"] = "rbxassetid://8997380820",
	["align-end-vertical"] = "rbxassetid://8997380907",
	["align-horizonal-distribute-center"] = "rbxassetid://8997381028",
	["align-horizonal-distribute-end"] = "rbxassetid://8997381144",
	["align-horizonal-distribute-start"] = "rbxassetid://8997381290",
	["align-horizontal-justify-center"] = "rbxassetid://8997381461",
	["align-horizontal-justify-end"] = "rbxassetid://8997381549",
	["align-horizontal-justify-start"] = "rbxassetid://8997381652",
	["align-horizontal-space-around"] = "rbxassetid://8997381738",
	["align-horizontal-space-between"] = "rbxassetid://8997381854",
	["align-justify"] = "rbxassetid://7733661326",
	["align-left"] = "rbxassetid://7733911357",
	["align-right"] = "rbxassetid://7733663582",
	["align-start-horizontal"] = "rbxassetid://8997381965",
	["align-start-vertical"] = "rbxassetid://8997382085",
	["align-vertical-distribute-center"] = "rbxassetid://8997382212",
	["align-vertical-distribute-end"] = "rbxassetid://8997382326",
	["align-vertical-distribute-start"] = "rbxassetid://8997382428",
	["align-vertical-justify-center"] = "rbxassetid://8997382502",
	["align-vertical-justify-end"] = "rbxassetid://8997382584",
	["align-vertical-justify-start"] = "rbxassetid://8997382639",
	["align-vertical-space-around"] = "rbxassetid://8997382708",
	["align-vertical-space-between"] = "rbxassetid://8997382793",
	["anchor"] = "rbxassetid://7733911490",
	["aperture"] = "rbxassetid://7733666258",
	["archive"] = "rbxassetid://7733911621",
	["arrow-big-down"] = "rbxassetid://7733668653",
	["arrow-big-left"] = "rbxassetid://7733911731",
	["arrow-big-right"] = "rbxassetid://7733671493",
	["arrow-big-up"] = "rbxassetid://7733671663",
	["arrow-down"] = "rbxassetid://7733672933",
	["arrow-down-circle"] = "rbxassetid://7733671763",
	["arrow-down-left"] = "rbxassetid://7733672282",
	["arrow-down-right"] = "rbxassetid://7733672831",
	["arrow-left"] = "rbxassetid://7733673136",
	["arrow-left-circle"] = "rbxassetid://7733673056",
	["arrow-left-right"] = "rbxassetid://8997382869",
	["arrow-right"] = "rbxassetid://7733673345",
	["arrow-right-circle"] = "rbxassetid://7733673229",
	["arrow-up"] = "rbxassetid://7733673717",
	["arrow-up-circle"] = "rbxassetid://7733673466",
	["arrow-up-left"] = "rbxassetid://7733673539",
	["arrow-up-right"] = "rbxassetid://7733673646",
	["asterisk"] = "rbxassetid://7733673800",
	["at-sign"] = "rbxassetid://7733673907",
	["award"] = "rbxassetid://7733673987",
	["axe"] = "rbxassetid://7733674079",
	["banknote"] = "rbxassetid://7733674153",
	["bar-chart"] = "rbxassetid://7733674319",
	["bar-chart-2"] = "rbxassetid://7733674239",
	["battery"] = "rbxassetid://7733674820",
	["battery-charging"] = "rbxassetid://7733674402",
	["battery-full"] = "rbxassetid://7733674503",
	["battery-low"] = "rbxassetid://7733674589",
	["battery-medium"] = "rbxassetid://7733674731",
	["beaker"] = "rbxassetid://7733674922",
	["bell"] = "rbxassetid://7733911828",
	["bell-minus"] = "rbxassetid://7733675028",
	["bell-off"] = "rbxassetid://7733675107",
	["bell-plus"] = "rbxassetid://7733675181",
	["bell-ring"] = "rbxassetid://7733675275",
	["bike"] = "rbxassetid://7733678330",
	["binary"] = "rbxassetid://7733678388",
	["bluetooth"] = "rbxassetid://7733687147",
	["bluetooth-connected"] = "rbxassetid://7734110952",
	["bluetooth-off"] = "rbxassetid://7733914252",
	["bluetooth-searching"] = "rbxassetid://7733914320",
	["bold"] = "rbxassetid://7733687211",
	["book"] = "rbxassetid://7733914390",
	["book-open"] = "rbxassetid://7733687281",
	["bookmark"] = "rbxassetid://7733692043",
	["bookmark-minus"] = "rbxassetid://7733689754",
	["bookmark-plus"] = "rbxassetid://7734111084",
	["bot"] = "rbxassetid://7733916988",
	["box"] = "rbxassetid://7733917120",
	["box-select"] = "rbxassetid://7733696665",
	["briefcase"] = "rbxassetid://7733919017",
	["brush"] = "rbxassetid://7733701455",
	["bug"] = "rbxassetid://7733701545",
	["building"] = "rbxassetid://7733701625",
	["bus"] = "rbxassetid://7733701715",
	["calculator"] = "rbxassetid://7733919105",
	["calendar"] = "rbxassetid://7733919198",
	["camera"] = "rbxassetid://7733708692",
	["camera-off"] = "rbxassetid://7733919260",
	["car"] = "rbxassetid://7733708835",
	["carrot"] = "rbxassetid://8997382987",
	["cast"] = "rbxassetid://7733919326",
	["charge"] = "rbxassetid://8997383136",
	["check"] = "rbxassetid://7733715400",
	["check-circle"] = "rbxassetid://7733919427",
	["check-circle-2"] = "rbxassetid://7733710700",
	["check-square"] = "rbxassetid://7733919526",
	["chevron-down"] = "rbxassetid://7733717447",
	["chevron-first"] = "rbxassetid://8997383275",
	["chevron-last"] = "rbxassetid://8997383390",
	["chevron-left"] = "rbxassetid://7733717651",
	["chevron-right"] = "rbxassetid://7733717755",
	["chevron-up"] = "rbxassetid://7733919605",
	["chevrons-down"] = "rbxassetid://7733720604",
	["chevrons-down-up"] = "rbxassetid://7733720483",
	["chevrons-left"] = "rbxassetid://7733720701",
	["chevrons-right"] = "rbxassetid://7733919682",
	["chevrons-up"] = "rbxassetid://7733723433",
	["chevrons-up-down"] = "rbxassetid://7733723321",
	["chrome"] = "rbxassetid://7733919783",
	["circle"] = "rbxassetid://7733919881",
	["circle-slashed"] = "rbxassetid://8997383530",
	["clipboard"] = "rbxassetid://7733734762",
	["clipboard-check"] = "rbxassetid://7733919947",
	["clipboard-copy"] = "rbxassetid://7733920037",
	["clipboard-list"] = "rbxassetid://7733920117",
	["clipboard-x"] = "rbxassetid://7733734668",
	["clock"] = "rbxassetid://7733734848",
	["clock-1"] = "rbxassetid://8997383694",
	["clock-10"] = "rbxassetid://8997383876",
	["clock-11"] = "rbxassetid://8997384034",
	["clock-12"] = "rbxassetid://8997384150",
	["clock-2"] = "rbxassetid://8997384295",
	["clock-3"] = "rbxassetid://8997384456",
	["clock-4"] = "rbxassetid://8997384603",
	["clock-5"] = "rbxassetid://8997384798",
	["clock-6"] = "rbxassetid://8997384977",
	["clock-7"] = "rbxassetid://8997385147",
	["clock-8"] = "rbxassetid://8997385352",
	["clock-9"] = "rbxassetid://8997385485",
	["cloud"] = "rbxassetid://7733746980",
	["cloud-drizzle"] = "rbxassetid://7733920226",
	["cloud-fog"] = "rbxassetid://7733920317",
	["cloud-hail"] = "rbxassetid://7733920444",
	["cloud-lightning"] = "rbxassetid://7733741741",
	["cloud-moon"] = "rbxassetid://7733920519",
	["cloud-off"] = "rbxassetid://7733745572",
	["cloud-rain"] = "rbxassetid://7733746651",
	["cloud-rain-wind"] = "rbxassetid://7733746456",
	["cloud-snow"] = "rbxassetid://7733746798",
	["cloud-sun"] = "rbxassetid://7733746880",
	["cloudy"] = "rbxassetid://7733747106",
	["clover"] = "rbxassetid://7733747233",
	["code"] = "rbxassetid://7733749837",
	["code-2"] = "rbxassetid://7733920644",
	["codepen"] = "rbxassetid://7733920768",
	["codesandbox"] = "rbxassetid://7733752575",
	["coffee"] = "rbxassetid://7733752630",
	["coins"] = "rbxassetid://7743866529",
	["columns"] = "rbxassetid://7733757178",
	["command"] = "rbxassetid://7733924046",
	["compass"] = "rbxassetid://7733924216",
	["contact"] = "rbxassetid://7743866666",
	["contrast"] = "rbxassetid://7733764005",
	["cookie"] = "rbxassetid://8997385628",
	["copy"] = "rbxassetid://7733764083",
	["copyleft"] = "rbxassetid://7733764196",
	["copyright"] = "rbxassetid://7733764275",
	["corner-down-left"] = "rbxassetid://7733764327",
	["corner-down-right"] = "rbxassetid://7733764385",
	["corner-left-down"] = "rbxassetid://7733764448",
	["corner-left-up"] = "rbxassetid://7733764536",
	["corner-right-down"] = "rbxassetid://7733764605",
	["corner-right-up"] = "rbxassetid://7733764680",
	["corner-up-left"] = "rbxassetid://7733764800",
	["corner-up-right"] = "rbxassetid://7733764915",
	["cpu"] = "rbxassetid://7733765045",
	["crop"] = "rbxassetid://7733765140",
	["cross"] = "rbxassetid://7733765224",
	["crosshair"] = "rbxassetid://7733765307",
	["crown"] = "rbxassetid://7733765398",
	["currency"] = "rbxassetid://7733765592",
	["database"] = "rbxassetid://7743866778",
	["delete"] = "rbxassetid://7733768142",
	["divide"] = "rbxassetid://7733769365",
	["divide-circle"] = "rbxassetid://7733769152",
	["divide-square"] = "rbxassetid://7733769261",
	["dollar-sign"] = "rbxassetid://7733770599",
	["download"] = "rbxassetid://7733770755",
	["download-cloud"] = "rbxassetid://7733770689",
	["dribbble"] = "rbxassetid://7733770843",
	["droplet"] = "rbxassetid://7733770982",
	["droplets"] = "rbxassetid://7733771078",
	["drumstick"] = "rbxassetid://8997385789",
	["edit"] = "rbxassetid://7733771472",
	["edit-2"] = "rbxassetid://7733771217",
	["edit-3"] = "rbxassetid://7733771361",
	["egg"] = "rbxassetid://8997385940",
	["electricity"] = "rbxassetid://7733771628",
	["electricity-off"] = "rbxassetid://7733771563",
	["equal"] = "rbxassetid://7733771811",
	["equal-not"] = "rbxassetid://7733771726",
	["euro"] = "rbxassetid://7733771891",
	["expand"] = "rbxassetid://7733771982",
	["external-link"] = "rbxassetid://7743866903",
	["eye"] = "rbxassetid://7733774602",
	["eye-off"] = "rbxassetid://7733774495",
	["fast-forward"] = "rbxassetid://7743867090",
	["feather"] = "rbxassetid://7733777166",
	["figma"] = "rbxassetid://7743867310",
	["file"] = "rbxassetid://7733793319",
	["file-check"] = "rbxassetid://7733779668",
	["file-check-2"] = "rbxassetid://7733779610",
	["file-code"] = "rbxassetid://7733779730",
	["file-digit"] = "rbxassetid://7733935829",
	["file-input"] = "rbxassetid://7733935917",
	["file-minus"] = "rbxassetid://7733936115",
	["file-minus-2"] = "rbxassetid://7733936010",
	["file-output"] = "rbxassetid://7733788742",
	["file-plus"] = "rbxassetid://7733788885",
	["file-plus-2"] = "rbxassetid://7733788816",
	["file-search"] = "rbxassetid://7733788966",
	["file-text"] = "rbxassetid://7733789088",
	["file-x"] = "rbxassetid://7733938136",
	["file-x-2"] = "rbxassetid://7743867554",
	["files"] = "rbxassetid://7743867811",
	["film"] = "rbxassetid://7733942579",
	["filter"] = "rbxassetid://7733798407",
	["flag"] = "rbxassetid://7733798691",
	["flag-triangle-left"] = "rbxassetid://7733798509",
	["flag-triangle-right"] = "rbxassetid://7733798634",
	["flame"] = "rbxassetid://7733798747",
	["flashlight"] = "rbxassetid://7733798851",
	["flashlight-off"] = "rbxassetid://7733798799",
	["flask-conical"] = "rbxassetid://7733798901",
	["flask-round"] = "rbxassetid://7733798957",
	["folder"] = "rbxassetid://7733799185",
	["folder-minus"] = "rbxassetid://7733799022",
	["folder-open"] = "rbxassetid://8997386062",
	["folder-plus"] = "rbxassetid://7733799092",
	["form-input"] = "rbxassetid://7733799275",
	["forward"] = "rbxassetid://7733799371",
	["framer"] = "rbxassetid://7733799486",
	["frown"] = "rbxassetid://7733799591",
	["function-square"] = "rbxassetid://7733799682",
	["gamepad"] = "rbxassetid://7733799901",
	["gamepad-2"] = "rbxassetid://7733799795",
	["gauge"] = "rbxassetid://7733799969",
	["gavel"] = "rbxassetid://7733800044",
	["gem"] = "rbxassetid://7733942651",
	["ghost"] = "rbxassetid://7743868000",
	["gift"] = "rbxassetid://7733946818",
	["gift-card"] = "rbxassetid://7733945018",
	["git-branch"] = "rbxassetid://7733949149",
	["git-branch-plus"] = "rbxassetid://7743868200",
	["git-commit"] = "rbxassetid://7743868360",
	["git-merge"] = "rbxassetid://7733952195",
	["git-pull-request"] = "rbxassetid://7733952287",
	["github"] = "rbxassetid://7733954058",
	["gitlab"] = "rbxassetid://7733954246",
	["glasses"] = "rbxassetid://7733954403",
	["globe"] = "rbxassetid://7733954760",
	["globe-2"] = "rbxassetid://7733954611",
	["grab"] = "rbxassetid://7733954884",
	["graduation-cap"] = "rbxassetid://7733955058",
	["grid"] = "rbxassetid://7733955179",
	["grip-horizontal"] = "rbxassetid://7733955302",
	["grip-vertical"] = "rbxassetid://7733955410",
	["hammer"] = "rbxassetid://7733955511",
	["hand"] = "rbxassetid://7733955740",
	["hand-metal"] = "rbxassetid://7733955664",
	["hard-drive"] = "rbxassetid://7733955793",
	["hard-hat"] = "rbxassetid://7733955850",
	["hash"] = "rbxassetid://7733955906",
	["haze"] = "rbxassetid://7733955969",
	["headphones"] = "rbxassetid://7733956063",
	["heart"] = "rbxassetid://7733956134",
	["help-circle"] = "rbxassetid://7733956210",
	["hexagon"] = "rbxassetid://7743868527",
	["highlighter"] = "rbxassetid://7743868648",
	["history"] = "rbxassetid://7733960880",
	["home"] = "rbxassetid://7733960981",
	["image"] = "rbxassetid://7733964126",
	["image-minus"] = "rbxassetid://7733963797",
	["image-off"] = "rbxassetid://7733963907",
	["image-plus"] = "rbxassetid://7733964016",
	["import"] = "rbxassetid://7733964240",
	["inbox"] = "rbxassetid://7733964370",
	["indent"] = "rbxassetid://7733964452",
	["indian-rupee"] = "rbxassetid://7733964536",
	["infinity"] = "rbxassetid://7733964640",
	["info"] = "rbxassetid://7733964719",
	["inspect"] = "rbxassetid://7733964808",
	["italic"] = "rbxassetid://7733964917",
	["jersey-pound"] = "rbxassetid://7733965029",
	["key"] = "rbxassetid://7733965118",
	["landmark"] = "rbxassetid://7733965184",
	["languages"] = "rbxassetid://7733965249",
	["laptop"] = "rbxassetid://7733965386",
	["laptop-2"] = "rbxassetid://7733965313",
	["lasso"] = "rbxassetid://7733967892",
	["lasso-select"] = "rbxassetid://7743868832",
	["layers"] = "rbxassetid://7743868936",
	["layout"] = "rbxassetid://7733970543",
	["layout-dashboard"] = "rbxassetid://7733970318",
	["layout-grid"] = "rbxassetid://7733970390",
	["layout-list"] = "rbxassetid://7733970442",
	["layout-template"] = "rbxassetid://7733970494",
	["library"] = "rbxassetid://7743869054",
	["life-buoy"] = "rbxassetid://7733973479",
	["lightbulb"] = "rbxassetid://7733975185",
	["lightbulb-off"] = "rbxassetid://7733975123",
	["link"] = "rbxassetid://7733978098",
	["link-2"] = "rbxassetid://7743869163",
	["link-2-off"] = "rbxassetid://7733975283",
	["list"] = "rbxassetid://7743869612",
	["list-checks"] = "rbxassetid://7743869317",
	["list-minus"] = "rbxassetid://7733980795",
	["list-ordered"] = "rbxassetid://7743869411",
	["list-plus"] = "rbxassetid://7733984995",
	["list-x"] = "rbxassetid://7743869517",
	["loader"] = "rbxassetid://7733992358",
	["loader-2"] = "rbxassetid://7733989869",
	["locate"] = "rbxassetid://7733992469",
	["locate-fixed"] = "rbxassetid://7733992424",
	["lock"] = "rbxassetid://7733992528",
	["log-in"] = "rbxassetid://7733992604",
	["log-out"] = "rbxassetid://7733992677",
	["mail"] = "rbxassetid://7733992732",
	["map"] = "rbxassetid://7733992829",
	["map-pin"] = "rbxassetid://7733992789",
	["maximize"] = "rbxassetid://7733992982",
	["maximize-2"] = "rbxassetid://7733992901",
	["megaphone"] = "rbxassetid://7733993049",
	["meh"] = "rbxassetid://7733993147",
	["menu"] = "rbxassetid://7733993211",
	["message-circle"] = "rbxassetid://7733993311",
	["message-square"] = "rbxassetid://7733993369",
	["mic"] = "rbxassetid://7743869805",
	["mic-off"] = "rbxassetid://7743869714",
	["minimize"] = "rbxassetid://7733997941",
	["minimize-2"] = "rbxassetid://7733997870",
	["minus"] = "rbxassetid://7734000129",
	["minus-circle"] = "rbxassetid://7733998053",
	["minus-square"] = "rbxassetid://7743869899",
	["monitor"] = "rbxassetid://7734002839",
	["monitor-off"] = "rbxassetid://7734000184",
	["monitor-speaker"] = "rbxassetid://7743869988",
	["moon"] = "rbxassetid://7743870134",
	["more-horizontal"] = "rbxassetid://7734006080",
	["more-vertical"] = "rbxassetid://7734006187",
	["mountain"] = "rbxassetid://7734008868",
	["mountain-snow"] = "rbxassetid://7743870286",
	["mouse-pointer"] = "rbxassetid://7743870392",
	["mouse-pointer-2"] = "rbxassetid://7734010405",
	["mouse-pointer-click"] = "rbxassetid://7734010488",
	["move"] = "rbxassetid://7743870731",
	["move-diagonal"] = "rbxassetid://7743870505",
	["move-diagonal-2"] = "rbxassetid://7734013178",
	["move-horizontal"] = "rbxassetid://7734016210",
	["move-vertical"] = "rbxassetid://7743870608",
	["music"] = "rbxassetid://7734020554",
	["navigation"] = "rbxassetid://7734020989",
	["navigation-2"] = "rbxassetid://7734020942",
	["network"] = "rbxassetid://7734021047",
	["no_entry"] = "rbxassetid://7734021118",
	["octagon"] = "rbxassetid://7734021165",
	["on-charge"] = "rbxassetid://7734021231",
	["option"] = "rbxassetid://7734021300",
	["outdent"] = "rbxassetid://7734021384",
	["package"] = "rbxassetid://7734021469",
	["package-check"] = "rbxassetid://8997386143",
	["package-minus"] = "rbxassetid://8997386266",
	["package-plus"] = "rbxassetid://8997386355",
	["package-search"] = "rbxassetid://8997386448",
	["package-x"] = "rbxassetid://8997386545",
	["palette"] = "rbxassetid://7734021595",
	["paperclip"] = "rbxassetid://7734021680",
	["pause"] = "rbxassetid://7734021897",
	["pause-circle"] = "rbxassetid://7734021767",
	["pause-octagon"] = "rbxassetid://7734021827",
	["pen-tool"] = "rbxassetid://7734022041",
	["pencil"] = "rbxassetid://7734022107",
	["percent"] = "rbxassetid://7743870852",
	["person-standing"] = "rbxassetid://7743871002",
	["phone"] = "rbxassetid://7734032056",
	["phone-call"] = "rbxassetid://7734027264",
	["phone-forwarded"] = "rbxassetid://7734027345",
	["phone-incoming"] = "rbxassetid://7743871120",
	["phone-missed"] = "rbxassetid://7734029465",
	["phone-off"] = "rbxassetid://7734029534",
	["phone-outgoing"] = "rbxassetid://7743871253",
	["pie-chart"] = "rbxassetid://7734034378",
	["piggy-bank"] = "rbxassetid://7734034513",
	["pin"] = "rbxassetid://8997386648",
	["pipette"] = "rbxassetid://7743871384",
	["plane"] = "rbxassetid://7734037723",
	["play"] = "rbxassetid://7743871480",
	["play-circle"] = "rbxassetid://7734037784",
	["plus"] = "rbxassetid://7734042071",
	["plus-circle"] = "rbxassetid://7734040271",
	["plus-square"] = "rbxassetid://7734040369",
	["pocket"] = "rbxassetid://7734042139",
	["podcast"] = "rbxassetid://7734042234",
	["pointer"] = "rbxassetid://7734042307",
	["pound-sterling"] = "rbxassetid://7734042354",
	["power"] = "rbxassetid://7734042493",
	["power-off"] = "rbxassetid://7734042423",
	["printer"] = "rbxassetid://7734042580",
	["qr-code"] = "rbxassetid://7743871575",
	["quote"] = "rbxassetid://7734045100",
	["radio"] = "rbxassetid://7743871662",
	["radio-receiver"] = "rbxassetid://7734045155",
	["redo"] = "rbxassetid://7743871739",
	["refresh-ccw"] = "rbxassetid://7734050715",
	["refresh-cw"] = "rbxassetid://7734051052",
	["regex"] = "rbxassetid://7734051188",
	["repeat"] = "rbxassetid://7734051454",
	["repeat-1"] = "rbxassetid://7734051342",
	["reply"] = "rbxassetid://7734051594",
	["reply-all"] = "rbxassetid://7734051524",
	["rewind"] = "rbxassetid://7734051670",
	["rocking-chair"] = "rbxassetid://7734051769",
	["rotate-ccw"] = "rbxassetid://7734051861",
	["rotate-cw"] = "rbxassetid://7734051957",
	["rss"] = "rbxassetid://7734052075",
	["ruler"] = "rbxassetid://7734052157",
	["russian-ruble"] = "rbxassetid://7734052248",
	["save"] = "rbxassetid://7734052335",
	["scale"] = "rbxassetid://7734052454",
	["scan"] = "rbxassetid://8997386861",
	["scan-line"] = "rbxassetid://8997386772",
	["scissors"] = "rbxassetid://7734052570",
	["screen-share"] = "rbxassetid://7734052814",
	["screen-share-off"] = "rbxassetid://7734052653",
	["search"] = "rbxassetid://7734052925",
	["send"] = "rbxassetid://7734053039",
	["separator-horizontal"] = "rbxassetid://7734053146",
	["separator-vertical"] = "rbxassetid://7734053213",
	["server"] = "rbxassetid://7734053426",
	["server-crash"] = "rbxassetid://7734053281",
	["server-off"] = "rbxassetid://7734053361",
	["settings"] = "rbxassetid://7734053495",
	["settings-2"] = "rbxassetid://8997386997",
	["share"] = "rbxassetid://7734053697",
	["share-2"] = "rbxassetid://7734053595",
	["sheet"] = "rbxassetid://7743871876",
	["shield"] = "rbxassetid://7734056608",
	["shield-alert"] = "rbxassetid://7734056326",
	["shield-check"] = "rbxassetid://7734056411",
	["shield-close"] = "rbxassetid://7734056470",
	["shield-off"] = "rbxassetid://7734056540",
	["shirt"] = "rbxassetid://7734056672",
	["shopping-bag"] = "rbxassetid://7734056747",
	["shopping-cart"] = "rbxassetid://7734056813",
	["shovel"] = "rbxassetid://7734056878",
	["shrink"] = "rbxassetid://7734056971",
	["shuffle"] = "rbxassetid://7734057059",
	["sidebar"] = "rbxassetid://7734058260",
	["sidebar-close"] = "rbxassetid://7734058092",
	["sidebar-open"] = "rbxassetid://7734058165",
	["sigma"] = "rbxassetid://7734058345",
	["signal"] = "rbxassetid://8997387546",
	["signal-high"] = "rbxassetid://8997387110",
	["signal-low"] = "rbxassetid://8997387189",
	["signal-medium"] = "rbxassetid://8997387319",
	["signal-zero"] = "rbxassetid://8997387434",
	["skip-back"] = "rbxassetid://7734058404",
	["skip-forward"] = "rbxassetid://7734058495",
	["skull"] = "rbxassetid://7734058599",
	["slash"] = "rbxassetid://8997387644",
	["sliders"] = "rbxassetid://7734058803",
	["smartphone"] = "rbxassetid://7734058979",
	["smartphone-charging"] = "rbxassetid://7734058894",
	["smile"] = "rbxassetid://7734059095",
	["snowflake"] = "rbxassetid://7734059180",
	["sort-asc"] = "rbxassetid://7734060715",
	["sort-desc"] = "rbxassetid://7743871973",
	["speaker"] = "rbxassetid://7734063416",
	["sprout"] = "rbxassetid://7743872071",
	["square"] = "rbxassetid://7743872181",
	["star"] = "rbxassetid://7734068321",
	["star-half"] = "rbxassetid://7734068258",
	["stop-circle"] = "rbxassetid://7734068379",
	["stretch-horizontal"] = "rbxassetid://8997387754",
	["stretch-vertical"] = "rbxassetid://8997387862",
	["strikethrough"] = "rbxassetid://7734068425",
	["subscript"] = "rbxassetid://8997387937",
	["sun"] = "rbxassetid://7734068495",
	["sunrise"] = "rbxassetid://7743872365",
	["sunset"] = "rbxassetid://7734070982",
	["superscript"] = "rbxassetid://8997388036",
	["swiss-franc"] = "rbxassetid://7734071038",
	["switch-camera"] = "rbxassetid://7743872492",
	["table"] = "rbxassetid://7734073253",
	["tablet"] = "rbxassetid://7743872620",
	["tag"] = "rbxassetid://7734075797",
	["target"] = "rbxassetid://7743872758",
	["tent"] = "rbxassetid://7734078943",
	["terminal"] = "rbxassetid://7743872929",
	["terminal-square"] = "rbxassetid://7734079055",
	["text-cursor"] = "rbxassetid://8997388195",
	["text-cursor-input"] = "rbxassetid://8997388094",
	["thermometer"] = "rbxassetid://7734084149",
	["thermometer-snowflake"] = "rbxassetid://7743873074",
	["thermometer-sun"] = "rbxassetid://7734084018",
	["thumbs-down"] = "rbxassetid://7734084236",
	["thumbs-up"] = "rbxassetid://7743873212",
	["ticket"] = "rbxassetid://7734086558",
	["timer"] = "rbxassetid://7743873443",
	["timer-off"] = "rbxassetid://8997388325",
	["timer-reset"] = "rbxassetid://7743873336",
	["toggle-left"] = "rbxassetid://7734091286",
	["toggle-right"] = "rbxassetid://7743873539",
	["tornado"] = "rbxassetid://7743873633",
	["trash"] = "rbxassetid://7743873871",
	["trash-2"] = "rbxassetid://7743873772",
	["trello"] = "rbxassetid://7743873996",
	["trending-down"] = "rbxassetid://7743874143",
	["trending-up"] = "rbxassetid://7743874262",
	["triangle"] = "rbxassetid://7743874367",
	["truck"] = "rbxassetid://7743874482",
	["tv"] = "rbxassetid://7743874674",
	["tv-2"] = "rbxassetid://7743874599",
	["type"] = "rbxassetid://7743874740",
	["umbrella"] = "rbxassetid://7743874820",
	["underline"] = "rbxassetid://7743874904",
	["undo"] = "rbxassetid://7743874974",
	["unlink"] = "rbxassetid://7743875149",
	["unlink-2"] = "rbxassetid://7743875069",
	["unlock"] = "rbxassetid://7743875263",
	["upload"] = "rbxassetid://7743875428",
	["upload-cloud"] = "rbxassetid://7743875358",
	["user"] = "rbxassetid://7743875962",
	["user-check"] = "rbxassetid://7743875503",
	["user-minus"] = "rbxassetid://7743875629",
	["user-plus"] = "rbxassetid://7743875759",
	["user-x"] = "rbxassetid://7743875879",
	["users"] = "rbxassetid://7743876054",
	["verified"] = "rbxassetid://7743876142",
	["vibrate"] = "rbxassetid://7743876302",
	["video"] = "rbxassetid://7743876610",
	["video-off"] = "rbxassetid://7743876466",
	["view"] = "rbxassetid://7743876754",
	["voicemail"] = "rbxassetid://7743876916",
	["volume"] = "rbxassetid://7743877487",
	["volume-1"] = "rbxassetid://7743877081",
	["volume-2"] = "rbxassetid://7743877250",
	["volume-x"] = "rbxassetid://7743877381",
	["wallet"] = "rbxassetid://7743877573",
	["wand"] = "rbxassetid://8997388430",
	["watch"] = "rbxassetid://7743877668",
	["webcam"] = "rbxassetid://7743877896",
	["wifi"] = "rbxassetid://7743878148",
	["wifi-off"] = "rbxassetid://7743878056",
	["wind"] = "rbxassetid://7743878264",
	["wrap-text"] = "rbxassetid://8997388548",
	["wrench"] = "rbxassetid://7743878358",
	["x"] = "rbxassetid://7743878857",
	["x-circle"] = "rbxassetid://7743878496",
	["x-octagon"] = "rbxassetid://7743878618",
	["x-square"] = "rbxassetid://7743878737",
	["zoom-in"] = "rbxassetid://7743878977",
	["zoom-out"] = "rbxassetid://7743879082",

}

--// Resolves an icon reference. A raw asset URI passes through unchanged, a
--// known kebab name (with or without the lucide: prefix) becomes its pinned
--// asset, and an unknown explicit lucide name becomes "" so the caller can
--// hide the icon instead of drawing a broken image.
function Icons.Get(Name)
	if type(Name) ~= "string" or Name == "" then
		return ""
	end
	if Name:sub(1, 7) == "lucide:" then
		return Icons.Map[Name:sub(8)] or ""
	end
	return Icons.Map[Name] or Name
end

return Icons
end function __DARKLUA_BUNDLE_MODULES.d():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.d if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.d=v end return v.c end end do local function __modImpl()
local core = __DARKLUA_BUNDLE_MODULES.c()
local util = __DARKLUA_BUNDLE_MODULES.b()

local HttpService = core.HttpService
local isStudio = core.isStudio

return function(FractUI, WindowFunctions)
	--// A hex color of a config. The number sign is optional, so both forms
	--// lead to the same color.
	local function HexToColor3(hex)
		local digits = hex:gsub("#", "")
		local r = tonumber(digits:sub(1, 2), 16) / 255
		local g = tonumber(digits:sub(3, 4), 16) / 255
		local b = tonumber(digits:sub(5, 6), 16) / 255
		return Color3.new(r, g, b)
	end

	local function Color3ToHex(color)
		return string.format("#%02X%02X%02X", math.floor(color.R * 255), math.floor(color.G * 255), math.floor(color.B * 255))
	end

	local ClassParser = {
		["Toggle"] = {
			Save = function(Flag, data)
				return {
					type = "Toggle",
					flag = Flag,
					state = data.State and true or false
				}
			end,
			Load = function(Flag, data)
				if FractUI.Options[Flag] and data.state ~= nil then
					FractUI.Options[Flag]:UpdateState(data.state)
				end
			end
		},
		["Slider"] = {
			Save = function(Flag, data)
				return {
					type = "Slider",
					flag = Flag,
					value = (data.Value ~= nil and tostring(data.Value)) or false
				}
			end,
			Load = function(Flag, data)
				if FractUI.Options[Flag] and data.value ~= nil and data.value ~= false then
					FractUI.Options[Flag]:UpdateValue(data.value)
				end
			end
		},
		["Input"] = {
			Save = function(Flag, data)
				return {
					type = "Input",
					flag = Flag,
					text = data.Text
				}
			end,
			Load = function(Flag, data)
				if FractUI.Options[Flag] and data.text ~= nil and type(data.text) == "string" then
					FractUI.Options[Flag]:UpdateText(data.text)
				end
			end
		},
		["Keybind"] = {
			Save = function(Flag, data)
				-- The enum type of a key is an object, so the name of the enum
				-- is written into the config.
				local bindType = util.BindTypeName(data.Key)
				if bindType then
					return {
						type = "Keybind",
						flag = Flag,
						bind = data.Key.Name,
						bindType = bindType
					}
				end
				return {
					type = "Keybind",
					flag = Flag,
					bind = false
				}
			end,
			Load = function(Flag, data)
				if not FractUI.Options[Flag] then return end
				-- A bind that is missing is the old format, it means the widget
				-- was not bound.
				if data.bind == false or data.bind == nil then
					FractUI.Options[Flag]:Unbind()
					return
				end
				local bind = util.FindBind(data.bindType or "KeyCode", data.bind)
				if bind then
					FractUI.Options[Flag]:Bind(bind)
				end
			end
		},
		["KeyPicker"] = {
			Save = function(Flag, data)
				-- A picker that follows a toggle shares the state of that toggle.
				-- Only a toggle holds a state that is worth keeping, the other
				-- modes hold a moment of the key and not a state of the widget.
				local state = nil
				if data.Mode == "Toggle" and not data.SyncToggleState then
					state = data.State and true or false
				end

				local entry = {
					type = "KeyPicker",
					flag = Flag,
					mode = data.Mode,
					state = state,
				}
				local bindType = util.BindTypeName(data.Key)
				if bindType then
					entry.bind = data.Key.Name
					entry.bindType = bindType
				else
					entry.bind = false
				end
				return entry
			end,
			Load = function(Flag, data)
				local target = FractUI.Options[Flag]
				if not target then return end
				if data.bind == false or data.bind == nil then
					target:Unbind()
				else
					local bind = util.FindBind(data.bindType or "KeyCode", data.bind)
					if bind then
						target:Bind(bind)
					end
				end
				if data.mode then
					target:SetMode(data.mode)
				end
				-- A state that belongs to a moment of the key is not a state of
				-- the widget, so it is not restored. A picker that follows a
				-- toggle takes the state of its host.
				local mode = data.mode or target.Mode
				if data.state ~= nil and mode == "Toggle" and not target.SyncToggleState then
					target:SetState(data.state)
				end
			end
		},
		["Dropdown"] = {
			Save = function(Flag, data)
				return {
					type = "Dropdown",
					flag = Flag,
					value = data.Value
				}
			end,
			Load = function(Flag, data)
				if FractUI.Options[Flag] and data.value then
					FractUI.Options[Flag]:UpdateSelection(data.value)
				end
			end
		},
		["Colorpicker"] = {
			Save = function(Flag, data)
				return {
					type = "Colorpicker",
					flag = Flag,
					color = (data.Color and Color3ToHex(data.Color)) or nil,
					alpha = data.Alpha
				}
			end,
			Load = function(Flag, data)
				if FractUI.Options[Flag] and data.color then
					FractUI.Options[Flag]:SetColor(HexToColor3(data.color))
					if data.alpha ~= nil and data.alpha ~= false then
						FractUI.Options[Flag]:SetAlpha(data.alpha)
					end
				end
			end
		},
		["ColorPicker"] = {
			Save = function(Flag, data)
				return {
					type = "ColorPicker",
					flag = Flag,
					color = (data.Color and Color3ToHex(data.Color)) or nil,
					alpha = data.Alpha
				}
			end,
			Load = function(Flag, data)
				if not FractUI.Options[Flag] then return end
				if data.color then
					FractUI.Options[Flag]:SetColor(HexToColor3(data.color))
				end
				if data.alpha ~= nil and data.alpha ~= false then
					FractUI.Options[Flag]:SetAlpha(data.alpha)
				end
			end
		}
	}

	local function BuildFolderTree()
		if isStudio or not (isfolder and makefolder) then
			return false, "Config system unavailable."
		end

		return util.BuildFolderTree(FractUI.Folder .. "/settings")
	end

	function FractUI:LoadAutoLoadConfig()
		if isStudio or not (isfile and readfile) then return "Config system unavailable." end

		local autoloadPath = FractUI.Folder .. "/settings/autoload.txt"
		if not util.IsFile(autoloadPath) then return end

		local read, name = util.ReadFile(autoloadPath)
		if not read or type(name) ~= "string" then return end

		local suc, err = FractUI:LoadConfig(name)
		if not suc then
			WindowFunctions:Notify({
				Title = "Interface",
				Description = "Error loading autoload config: " .. err
			})
			return false, err
		end

		WindowFunctions:Notify({
			Title = "Interface",
			Description = string.format("Autoloaded config: %q", name),
		})
		return true
	end

	function FractUI:SetFolder(Folder)
		if isStudio then return false, "Config system unavailable." end

		if not util.IsValidFolderPath(Folder) then
			return false, "Invalid folder path provided."
		end

		local previous = FractUI.Folder
		FractUI.Folder = Folder

		local built, buildMessage = BuildFolderTree()
		if not built then
			-- The folder stays the old one, so the configs of the user are
			-- still reachable.
			FractUI.Folder = previous
			return false, buildMessage
		end

		return true
	end

	--// The data of every widget that belongs to a config.
	function FractUI:BuildConfigData()
		local data = {
			objects = {}
		}

		for flag, option in next, FractUI.Options do
			if not ClassParser[option.Class] then continue end
			if option.IgnoreConfig then continue end

			table.insert(data.objects, ClassParser[option.Class].Save(flag, option))
		end

		return data
	end

	--// The order of the entries of a config. A key picker that follows a
	--// host ends the press that is running when it is bound, and the press
	--// releases the host. The state of the host belongs to the entry of the
	--// host, so the entry of the host is applied after the entry of the
	--// picker.
	local function applyOrder(entries)
		local ordered, owners = {}, {}
		for _, entry in ipairs(entries) do
			if entry.type == "KeyPicker" then
				table.insert(ordered, entry)
			else
				table.insert(owners, entry)
			end
		end
		for _, entry in ipairs(owners) do
			table.insert(ordered, entry)
		end
		return ordered
	end

	--// Applies a decoded config. The whole config is checked before a single
	--// widget is touched, so a broken config never leaves the interface half
	--// applied.
	function FractUI:ApplyConfigData(Data)
		local valid, reason, entries = util.ValidateConfigData(Data, FractUI.Options)
		if not valid then return false, reason end

		for _, entry in ipairs(applyOrder(entries)) do
			local parser = ClassParser[entry.type]
			if parser then
				local target = FractUI.Options[entry.flag]
				if target and not target.IgnoreConfig then
					-- The widget is applied right here, so a failure of a
					-- callback is reported instead of vanishing in a thread.
					local ok, err = pcall(parser.Load, entry.flag, entry)
					if not ok then
						return false, "The config could not be applied: " .. tostring(err)
					end
				end
			end
		end

		return true
	end

	function FractUI:SaveConfig(Path)
		if isStudio or not writefile then return false, "Config system unavailable." end

		if not util.IsValidName(Path) then
			return false, "Invalid config name provided."
		end

		-- The folder of the configs is made before the first file is written.
		local built, buildMessage = BuildFolderTree()
		if not built then
			return false, buildMessage
		end

		local fullPath = FractUI.Folder .. "/settings/" .. Path .. ".json"

		local success, encoded = pcall(HttpService.JSONEncode, HttpService, FractUI:BuildConfigData())
		if not success then
			return false, "Unable to encode into JSON data"
		end

		local written, writeError = util.WriteFile(fullPath, encoded)
		if not written then
			return false, "Unable to write the config file: " .. tostring(writeError)
		end

		return true
	end

	function FractUI:LoadConfig(Path)
		if isStudio or not (isfile and readfile) then return false, "Config system unavailable." end

		if not util.IsValidName(Path) then
			return false, "Invalid config name provided."
		end

		local file = FractUI.Folder .. "/settings/" .. Path .. ".json"
		if not util.IsFile(file) then return false, "Invalid file" end

		local read, content = util.ReadFile(file)
		if not read then return false, "Unable to read the config file." end

		local success, decoded = pcall(HttpService.JSONDecode, HttpService, content)
		if not success then return false, "Unable to decode JSON data." end

		return FractUI:ApplyConfigData(decoded)
	end

	function FractUI:RefreshConfigList()
		if isStudio then return "Config system unavailable." end

		local settingsPath = FractUI.Folder .. "/settings"
		if not (util.IsFolder(FractUI.Folder) and util.IsFolder(settingsPath)) then
			return {}
		end

		local listed, list = util.ListFiles(settingsPath)
		if not listed then
			return "Config system unavailable."
		end

		local out = {}
		for i = 1, #list do
			local file = list[i]
			if file:sub(-5) == ".json" then
				local pos = file:find(".json", 1, true)
				local start = pos

				local char = file:sub(pos, pos)
				while char ~= "/" and char ~= "\\" and char ~= "" do
					pos = pos - 1
					char = file:sub(pos, pos)
				end

				if char == "/" or char == "\\" then
					local name = file:sub(pos + 1, start - 1)
					if name ~= "options" then
						table.insert(out, name)
					end
				end
			end
		end

		return out
	end
end
end function __DARKLUA_BUNDLE_MODULES.e():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.e if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.e=v end return v.c end end do local function __modImpl()--// Internal layout scale of the window chrome. These values are not part of
--// the public theme; the nine color tokens stay the only public style API.

local Style = {
	Spacing = {
		Tiny = 4,
		Small = 8,
		Medium = 12,
		Large = 16,
		XLarge = 20,
		XXLarge = 24,
	},
	Radius = {
		Window = 12,
		Group = 8,
		Control = 6,
		Small = 4,
	},
	Type = {
		Body = 13,
		Control = 13,
		Heading = 16,
		Caption = 12,
	},
	Motion = {
		Fast = 0.12,
		Control = 0.15,
		Slow = 0.18,
	},
	Control = {
		Row = 38,
		RowTouch = 44,
		Option = 32,
		OptionTouch = 44,
		Track = 32,
		TrackTouch = 44,
	},
	Header = 44,
	Subtitle = 20,
	Nav = {
		Row = 32,
		RowTouch = 44,
		Icon = 16,
		Gap = 8,
		Padding = 12,
	},
	Traffic = {
		Paint = 12,
		HitWidth = 24,
		HitHeight = 28,
		TouchWidth = 44,
		TouchHeight = 44,
		Padding = 16,
	},
	Sidebar = 220,
}

return Style
end function __DARKLUA_BUNDLE_MODULES.f():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.f if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.f=v end return v.c end end do local function __modImpl()
local core = __DARKLUA_BUNDLE_MODULES.c()

local UserInputService = core.UserInputService

--// Focus belongs to every open dialog in the library, not to one window. The
--// first dialog holds the text box it took and the last close gives it back;
--// a close in another window must not steal the focus early. The owner travels
--// with the box, so unloading another window cannot drop the held focus.
local openModals = 0
local heldTextbox = nil
local heldOwner = nil
local tokens = {}

local function heldFocusIsLive()
	return heldTextbox ~= nil
		and heldOwner ~= nil
		and not heldOwner.unloaded
		and heldTextbox.Parent ~= nil
end

local function releaseFocus()
	local textbox = heldTextbox
	local owner = heldOwner
	heldTextbox = nil
	heldOwner = nil
	--// An unloaded owner has no live box to return to. A box that took focus
	--// while the dialog was open also keeps it; the close must not pull focus
	--// across a window boundary.
	if not textbox or (owner and owner.unloaded) or not textbox.Parent then
		return
	end
	local current = UserInputService:GetFocusedTextBox()
	if current and current ~= textbox then
		return
	end
	if textbox.CaptureFocus then
		pcall(function()
			textbox:CaptureFocus()
		end)
	end
end

--// One modal owner per window. Every open dialog holds a token; the window
--// gets its drag, its resize and its keybind back only when the last token is
--// released, so overlapping dialogs cannot restore input early. The token list
--// is shared, so only the last dialog in the library answers Enter and Escape.
return function(gui)
	local stack = {}
	local state = { unloaded = false }
	local generation = 0
	local Modal = {}

	function Modal:IsBlocked()
		return #stack > 0
	end

	function Modal:GetGeneration()
		return generation
	end

	function Modal:Push()
		local token = {}
		stack[#stack + 1] = token
		tokens[#tokens + 1] = token
		openModals += 1
		generation += 1

		--// The dialog releases the focus only after its canvas exists. A
		--// synchronous FocusLost callback can open another dialog, and the
		--// canvas and key order must both put that dialog on top.
		local activated = false
		local function activate()
			if activated or state.unloaded then
				return
			end
			activated = true

			local focused = UserInputService:GetFocusedTextBox()
			--// A dialog only takes the focus of its own window. A text box in
			--// another window keeps it, so opening here cannot steal it.
			if focused and (not gui or focused:IsDescendantOf(gui)) then
				if heldTextbox and not heldFocusIsLive() then
					heldTextbox = nil
					heldOwner = nil
				end
				if not heldTextbox then
					heldTextbox = focused
					heldOwner = state
				end
				if focused.ReleaseFocus then
					pcall(function()
						focused:ReleaseFocus()
					end)
				end
			end
		end

		local released = false
		local function release()
			if released then return end
			released = true
			for index = #stack, 1, -1 do
				if stack[index] == token then
					table.remove(stack, index)
					break
				end
			end
			for index = #tokens, 1, -1 do
				if tokens[index] == token then
					table.remove(tokens, index)
					break
				end
			end
			openModals = math.max(openModals - 1, 0)
			if openModals == 0 then
				releaseFocus()
			end
		end

		local function isTop()
			return tokens[#tokens] == token
		end

		return release, isTop, activate
	end

	function Modal:Unload()
		state.unloaded = true
	end

	return Modal
end
end function __DARKLUA_BUNDLE_MODULES.g():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.g if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.g=v end return v.c end end do local function __modImpl()
local core = __DARKLUA_BUNDLE_MODULES.c()
local theme = __DARKLUA_BUNDLE_MODULES.a()
local style = __DARKLUA_BUNDLE_MODULES.f()
local modalModule = __DARKLUA_BUNDLE_MODULES.g()

local assets = core.assets
local Tween = core.Tween
local UserInputService = core.UserInputService
local LocalPlayer = core.LocalPlayer
local Players = core.Players

return function(Settings, state)
	local gui = core.GetGui()
	local modal = modalModule(gui)

	local connections = {}
	local function connect(signal, handler)
		table.insert(connections, signal:Connect(handler))
	end

	local function disconnect()
		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end
		table.clear(connections)
	end

	local notifications = Instance.new("Frame")
	notifications.Name = "Notifications"
	notifications.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	notifications.BackgroundTransparency = 1
	notifications.BorderColor3 = Color3.fromRGB(0, 0, 0)
	notifications.BorderSizePixel = 0
	notifications.Size = UDim2.fromScale(1, 1)
	notifications.Parent = gui
	notifications.ZIndex = 2

	local notificationsUIListLayout = Instance.new("UIListLayout")
	notificationsUIListLayout.Name = "NotificationsUIListLayout"
	notificationsUIListLayout.Padding = UDim.new(0, 10)
	notificationsUIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	notificationsUIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	notificationsUIListLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	notificationsUIListLayout.Parent = notifications

	local notificationsUIPadding = Instance.new("UIPadding")
	notificationsUIPadding.Name = "NotificationsUIPadding"
	notificationsUIPadding.PaddingBottom = UDim.new(0, 10)
	notificationsUIPadding.PaddingLeft = UDim.new(0, 10)
	notificationsUIPadding.PaddingRight = UDim.new(0, 10)
	notificationsUIPadding.PaddingTop = UDim.new(0, 10)
	notificationsUIPadding.Parent = notifications

	local base = Instance.new("Frame")
	base.Name = "Base"
	base.AnchorPoint = Vector2.new(0.5, 0.5)
	theme.Set(base, "BackgroundColor3", "Background")
	base.BorderColor3 = Color3.fromRGB(0, 0, 0)
	base.BorderSizePixel = 0
	base.Position = UDim2.fromScale(0.5, 0.5)
	base.Size = Settings.Size or UDim2.fromOffset(868, 650)

	local baseUIScale = Instance.new("UIScale")
	baseUIScale.Name = "BaseUIScale"
	baseUIScale.Parent = base

	local baseUICorner = Instance.new("UICorner")
	baseUICorner.Name = "BaseUICorner"
	baseUICorner.CornerRadius = UDim.new(0, style.Radius.Window)
	baseUICorner.Parent = base

	local baseUIStroke = Instance.new("UIStroke")
	baseUIStroke.Name = "BaseUIStroke"
	baseUIStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	theme.Set(baseUIStroke, "Color", "Outline")
	baseUIStroke.Transparency = 0.9
	baseUIStroke.Parent = base

	local sidebar = Instance.new("Frame")
	sidebar.Name = "Sidebar"
	theme.Set(sidebar, "BackgroundColor3", "Surface")
	sidebar.BackgroundTransparency = 1
	sidebar.BorderColor3 = Color3.fromRGB(0, 0, 0)
	sidebar.BorderSizePixel = 0
	sidebar.Position = UDim2.fromScale(-3.52e-08, 4.69e-08)
	sidebar.Size = UDim2.new(0, style.Sidebar, 1, 0)

	--// Only a window with the blur on separates the chrome from the body by
	--// one quiet tint. The body stays an opaque surface, so no text is drawn
	--// on glass.
	local function updateAcrylic(On)
		base.BackgroundTransparency = On and 0.05 or 0
		sidebar.BackgroundTransparency = On and 0.7 or 1
		baseUIStroke.Transparency = On and 0.85 or 0.9
	end

	updateAcrylic(state.acrylicBlur)

	local divider = Instance.new("Frame")
	divider.Name = "Divider"
	divider.AnchorPoint = Vector2.new(1, 0)
	theme.Set(divider, "BackgroundColor3", "Outline")
	divider.BackgroundTransparency = 0.9
	divider.BorderColor3 = Color3.fromRGB(0, 0, 0)
	divider.BorderSizePixel = 0
	divider.Position = UDim2.fromScale(1, 0)
	divider.Size = UDim2.new(0, 1, 1, 0)
	divider.Parent = sidebar

	local dividerInteract = Instance.new("TextButton")
	dividerInteract.Name = "DividerInteract"
	dividerInteract.AnchorPoint = Vector2.new(0.5, 0)
	dividerInteract.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	dividerInteract.BackgroundTransparency = 1
	dividerInteract.BorderColor3 = Color3.fromRGB(0, 0, 0)
	dividerInteract.BorderSizePixel = 0
	dividerInteract.FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json")
	dividerInteract.Position = UDim2.fromScale(0.5, 0)
	dividerInteract.Size = UDim2.new(1, 6, 1, 0)
	dividerInteract.Text = ""
	dividerInteract.TextColor3 = Color3.fromRGB(0, 0, 0)
	dividerInteract.TextSize = 14
	dividerInteract.Parent = divider

	local windowControls = Instance.new("Frame")
	windowControls.Name = "WindowControls"
	windowControls.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	windowControls.BackgroundTransparency = 1
	windowControls.BorderColor3 = Color3.fromRGB(0, 0, 0)
	windowControls.BorderSizePixel = 0
	windowControls.Size = UDim2.new(1, 0, 0, style.Header)

	local controls = Instance.new("Frame")
	controls.Name = "Controls"
	controls.BackgroundColor3 = Color3.fromRGB(119, 174, 94)
	controls.BackgroundTransparency = 1
	controls.BorderColor3 = Color3.fromRGB(0, 0, 0)
	controls.BorderSizePixel = 0
	controls.Size = UDim2.new(1, 0, 0, style.Header)

	local touchLayout = UserInputService.TouchEnabled == true
	local trafficGap = touchLayout and style.Spacing.Tiny or 0
	local trafficHitWidth = touchLayout and style.Traffic.TouchWidth or style.Traffic.HitWidth
	local trafficHitHeight = touchLayout and style.Traffic.TouchHeight or style.Traffic.HitHeight

	local trafficHitSize = UDim2.fromOffset(trafficHitWidth, trafficHitHeight)
	local trafficPaintSize = UDim2.fromOffset(style.Traffic.Paint, style.Traffic.Paint)
	local strokeTransparency = 0.9

	local stroke = Instance.new("UIStroke")
	stroke.Name = "BaseUIStroke"
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	theme.Set(stroke, "Color", "Outline")
	stroke.Transparency = strokeTransparency

	--// The paint is 12 pixels but the hit is 24 by 28. Three hits sit next to
	--// each other, so the pointer areas never overlap. A touch layout is not
	--// faked with a larger transparent hit; it needs its own row sizes.
	local function newTrafficButton(name, color, layoutOrder)
		local button = Instance.new("TextButton")
		button.Name = name
		button.FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json")
		button.Text = ""
		button.TextColor3 = Color3.fromRGB(0, 0, 0)
		button.TextSize = 14
		button.AutoButtonColor = false
		button.BackgroundTransparency = 1
		button.BorderColor3 = Color3.fromRGB(0, 0, 0)
		button.BorderSizePixel = 0
		button.Size = trafficHitSize
		button.LayoutOrder = layoutOrder

		local paint = Instance.new("Frame")
		paint.Name = "Paint"
		paint.AnchorPoint = Vector2.new(0.5, 0.5)
		paint.BackgroundColor3 = color
		paint.BackgroundTransparency = 0
		paint.BorderColor3 = Color3.fromRGB(0, 0, 0)
		paint.BorderSizePixel = 0
		paint.Position = UDim2.fromScale(0.5, 0.5)
		paint.Size = trafficPaintSize
		paint.Parent = button

		local paintCorner = Instance.new("UICorner")
		paintCorner.Name = "UICorner"
		paintCorner.CornerRadius = UDim.new(1, 0)
		paintCorner.Parent = paint

		button.Parent = controls
		return button
	end

	local exit = newTrafficButton("Exit", Color3.fromRGB(250, 93, 86), 0)
	local minimize = newTrafficButton("Minimize", Color3.fromRGB(252, 190, 57), 1)
	local maximize = newTrafficButton("Maximize", Color3.fromRGB(119, 174, 94), 2)
	local trafficButtons = { exit, minimize, maximize }

	local function applyState(button, enabled)
		button.Active = enabled
		button.Interactable = enabled

		local paint = button:FindFirstChild("Paint")
		if paint then
			paint.BackgroundTransparency = enabled and 0 or 1
		end

		if not enabled then
			--// A rectangle stroke around the 24 by 28 hit would paint the wrong
			--// shape. The 12 pixel paint owns the circle outline.
			local disabledStroke = stroke:Clone()
			disabledStroke.Parent = paint or button
			theme.Set(disabledStroke, "Color", "Outline")
		end
	end

	applyState(maximize, false)

	local controlsList = {exit, minimize}
	for _, button in pairs(controlsList) do
		local buttonName = button.Name
		local isEnabled = true

		if Settings.DisabledWindowControls and table.find(Settings.DisabledWindowControls, buttonName) then
			isEnabled = false
		end

		applyState(button, isEnabled)
	end

	controls.Parent = windowControls

	local divider1 = Instance.new("Frame")
	divider1.Name = "Divider"
	divider1.AnchorPoint = Vector2.new(0, 1)
	theme.Set(divider1, "BackgroundColor3", "Outline")
	divider1.BackgroundTransparency = 0.9
	divider1.BorderColor3 = Color3.fromRGB(0, 0, 0)
	divider1.BorderSizePixel = 0
	divider1.Position = UDim2.fromScale(0, 1)
	divider1.Size = UDim2.new(1, 0, 0, 1)
	divider1.Parent = windowControls

	windowControls.Parent = sidebar

	local globalSettingsButton = Instance.new("ImageButton")
	globalSettingsButton.Name = "GlobalSettingsButton"
	globalSettingsButton.Image = assets.globe
	globalSettingsButton.ImageTransparency = 0.5
	globalSettingsButton.AnchorPoint = Vector2.new(1, 0.5)
	globalSettingsButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	globalSettingsButton.BackgroundTransparency = 1
	globalSettingsButton.BorderColor3 = Color3.fromRGB(0, 0, 0)
	globalSettingsButton.BorderSizePixel = 0
	globalSettingsButton.Position = UDim2.new(1, -style.Spacing.Small, 0, style.Header / 2)
	globalSettingsButton.Size = UDim2.fromOffset(style.Nav.Icon, style.Nav.Icon)
	globalSettingsButton.Parent = windowControls

	local function ChangeGlobalSettingsButtonState(State)
		if State == "Default" then
			Tween(globalSettingsButton, TweenInfo.new(style.Motion.Fast, Enum.EasingStyle.Sine), {
				ImageTransparency = 0.5
			}):Play()
		elseif State == "Hover" then
			Tween(globalSettingsButton, TweenInfo.new(style.Motion.Fast, Enum.EasingStyle.Sine), {
				ImageTransparency = 0.3
			}):Play()
		end
	end

	globalSettingsButton.MouseEnter:Connect(function()
		ChangeGlobalSettingsButtonState("Hover")
	end)
	globalSettingsButton.MouseLeave:Connect(function()
		ChangeGlobalSettingsButtonState("Default")
	end)

	--// The title ends before the 16 pixel globe and its 8 pixel right inset.
	--// layoutHeader moves it to its own row when the sidebar leaves no room.
	local titleLine = 20
	local titleGap = style.Spacing.Tiny
	local titleRight = titleGap + style.Nav.Icon + style.Spacing.Small
	local titleInset = style.Traffic.Padding
		+ trafficHitWidth * #trafficButtons
		+ trafficGap * (#trafficButtons - 1)
		+ titleGap

	local minSidebarWidth = 107
	local snapRange = 20

	--// An offset size is already in the sidebar's units. While the base is
	--// unparented, the ScreenGui supplies the Scale and the result stays in
	--// local units. A parented base is read back through the UIScale.
	local function baseWidth()
		local size = base.Size.X
		if base.Parent == nil then
			return gui.AbsoluteSize.X * size.Scale + size.Offset
		end
		if size.Scale == 0 then
			return size.Offset
		end
		local scale = baseUIScale.Scale
		if scale > 0 then
			return base.AbsoluteSize.X / scale
		end
		return size.Offset
	end

	--// The sidebar stops one content minimum before the window edge. A window
	--// below twice the minimum still gets a minimum sidebar instead of a
	--// negative range.
	local function maxSidebarWidth()
		return math.max(minSidebarWidth, baseWidth() - minSidebarWidth)
	end

	local sidebarWidth = math.clamp(style.Sidebar, minSidebarWidth, maxSidebarWidth())
	sidebar.Size = UDim2.new(0, sidebarWidth, 1, 0)

	local titleFrame = Instance.new("Frame")
	titleFrame.Name = "TitleFrame"
	titleFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	titleFrame.BackgroundTransparency = 1
	titleFrame.BorderColor3 = Color3.fromRGB(0, 0, 0)
	titleFrame.BorderSizePixel = 0
	titleFrame.Position = UDim2.fromOffset(titleInset, 0)
	titleFrame.Size = UDim2.new(1, 0, 0, style.Header)

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.FontFace = Font.new(
		assets.interFont,
		Enum.FontWeight.SemiBold,
		Enum.FontStyle.Normal
	)
	title.Text = Settings.Title
	theme.Set(title, "TextColor3", "Text")
	title.RichText = true
	title.TextSize = style.Type.Heading
	title.TextTransparency = 0
	title.TextTruncate = Enum.TextTruncate.SplitWord
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextYAlignment = Enum.TextYAlignment.Center
	title.TextWrapped = false
	title.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	title.BackgroundTransparency = 1
	title.BorderColor3 = Color3.fromRGB(0, 0, 0)
	title.BorderSizePixel = 0
	title.Position = UDim2.fromOffset(0, (style.Header - titleLine) / 2)
	title.Size = UDim2.new(1, 0, 0, titleLine)
	title.Parent = titleFrame

	local subtitle = Instance.new("TextLabel")
	subtitle.Name = "Subtitle"
	subtitle.FontFace = Font.new(
		assets.interFont,
		Enum.FontWeight.Medium,
		Enum.FontStyle.Normal
	)
	subtitle.RichText = true
	subtitle.Text = Settings.Subtitle or ""
	theme.Set(subtitle, "TextColor3", "Muted")
	subtitle.TextSize = style.Type.Caption
	subtitle.TextTransparency = 0.1
	subtitle.TextTruncate = Enum.TextTruncate.SplitWord
	subtitle.TextXAlignment = Enum.TextXAlignment.Left
	subtitle.TextYAlignment = Enum.TextYAlignment.Center
	subtitle.TextWrapped = false
	subtitle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	subtitle.BackgroundTransparency = 1
	subtitle.BorderColor3 = Color3.fromRGB(0, 0, 0)
	subtitle.BorderSizePixel = 0
	subtitle.Position = UDim2.fromOffset(titleInset, style.Header)
	subtitle.Size = UDim2.new(1, -(titleInset + style.Spacing.Small), 0, style.Subtitle)
	subtitle.Visible = subtitle.Text ~= ""
	subtitle.Parent = windowControls

	titleFrame.Parent = windowControls

	local sidebarGroup = Instance.new("Frame")
	sidebarGroup.Name = "SidebarGroup"
	sidebarGroup.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	sidebarGroup.BackgroundTransparency = 1
	sidebarGroup.BorderColor3 = Color3.fromRGB(0, 0, 0)
	sidebarGroup.BorderSizePixel = 0
	sidebarGroup.Position = UDim2.fromOffset(0, style.Header)
	sidebarGroup.Size = UDim2.new(1, 0, 1, -style.Header)

	local userInfo = Instance.new("Frame")
	userInfo.Name = "UserInfo"
	userInfo.AnchorPoint = Vector2.new(0, 1)
	userInfo.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	userInfo.BackgroundTransparency = 1
	userInfo.BorderColor3 = Color3.fromRGB(0, 0, 0)
	userInfo.BorderSizePixel = 0
	userInfo.Position = UDim2.fromScale(0, 1)
	userInfo.Size = UDim2.new(1, 0, 0, 107)

	local informationGroup = Instance.new("Frame")
	informationGroup.Name = "InformationGroup"
	informationGroup.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	informationGroup.BackgroundTransparency = 1
	informationGroup.BorderColor3 = Color3.fromRGB(0, 0, 0)
	informationGroup.BorderSizePixel = 0
	informationGroup.Size = UDim2.fromScale(1, 1)

	local informationGroupUIPadding = Instance.new("UIPadding")
	informationGroupUIPadding.Name = "InformationGroupUIPadding"
	informationGroupUIPadding.PaddingBottom = UDim.new(0, 16)
	informationGroupUIPadding.PaddingLeft = UDim.new(0, 0)
	informationGroupUIPadding.Parent = informationGroup

	local informationGroupUIListLayout = Instance.new("UIListLayout")
	informationGroupUIListLayout.Name = "InformationGroupUIListLayout"
	informationGroupUIListLayout.FillDirection = Enum.FillDirection.Horizontal
	informationGroupUIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	informationGroupUIListLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	informationGroupUIListLayout.Parent = informationGroup

	local userId = LocalPlayer.UserId
	local thumbType = Enum.ThumbnailType.AvatarBust
	local thumbSize = Enum.ThumbnailSize.Size48x48
	local headshotImage, isReady = Players:GetUserThumbnailAsync(userId, thumbType, thumbSize)

	local headshot = Instance.new("ImageLabel")
	headshot.Name = "Headshot"
	headshot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	headshot.BackgroundTransparency = 1
	headshot.BorderColor3 = Color3.fromRGB(0, 0, 0)
	headshot.BorderSizePixel = 0
	headshot.Size = UDim2.fromOffset(32, 32)
	headshot.Image = (isReady and headshotImage) or "rbxassetid://0"

	local uICorner3 = Instance.new("UICorner")
	uICorner3.Name = "UICorner"
	uICorner3.CornerRadius = UDim.new(1, 0)
	uICorner3.Parent = headshot

	local baseUIStroke2 = Instance.new("UIStroke")
	baseUIStroke2.Name = "BaseUIStroke"
	baseUIStroke2.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	theme.Set(baseUIStroke2, "Color", "Outline")
	baseUIStroke2.Transparency = 0.9
	baseUIStroke2.Parent = headshot

	headshot.Parent = informationGroup

	local userAndDisplayFrame = Instance.new("Frame")
	userAndDisplayFrame.Name = "UserAndDisplayFrame"
	userAndDisplayFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	userAndDisplayFrame.BackgroundTransparency = 1
	userAndDisplayFrame.BorderColor3 = Color3.fromRGB(0, 0, 0)
	userAndDisplayFrame.BorderSizePixel = 0
	userAndDisplayFrame.LayoutOrder = 1
	userAndDisplayFrame.Size = UDim2.new(1, -42, 0, 32)

	local displayName = Instance.new("TextLabel")
	displayName.Name = "DisplayName"
	displayName.FontFace = Font.new(
		assets.interFont,
		Enum.FontWeight.SemiBold,
		Enum.FontStyle.Normal
	)
	displayName.Text = LocalPlayer.DisplayName
	theme.Set(displayName, "TextColor3", "Text")
	displayName.TextSize = 13
	displayName.TextTransparency = 0.1
	displayName.TextTruncate = Enum.TextTruncate.SplitWord
	displayName.TextXAlignment = Enum.TextXAlignment.Left
	displayName.TextYAlignment = Enum.TextYAlignment.Top
	displayName.AutomaticSize = Enum.AutomaticSize.XY
	displayName.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	displayName.BackgroundTransparency = 1
	displayName.BorderColor3 = Color3.fromRGB(0, 0, 0)
	displayName.BorderSizePixel = 0
	displayName.Parent = userAndDisplayFrame
	displayName.Size = UDim2.fromScale(1,0)

	local userAndDisplayFrameUIPadding = Instance.new("UIPadding")
	userAndDisplayFrameUIPadding.Name = "UserAndDisplayFrameUIPadding"
	userAndDisplayFrameUIPadding.PaddingLeft = UDim.new(0, 8)
	userAndDisplayFrameUIPadding.PaddingTop = UDim.new(0, 3)
	userAndDisplayFrameUIPadding.Parent = userAndDisplayFrame

	local userAndDisplayFrameUIListLayout = Instance.new("UIListLayout")
	userAndDisplayFrameUIListLayout.Name = "UserAndDisplayFrameUIListLayout"
	userAndDisplayFrameUIListLayout.Padding = UDim.new(0, 1)
	userAndDisplayFrameUIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	userAndDisplayFrameUIListLayout.Parent = userAndDisplayFrame

	local username = Instance.new("TextLabel")
	username.Name = "Username"
	username.FontFace = Font.new(
		assets.interFont,
		Enum.FontWeight.SemiBold,
		Enum.FontStyle.Normal
	)
	username.Text = "@" .. LocalPlayer.Name
	theme.Set(username, "TextColor3", "Text")
	username.TextSize = 12
	username.TextTransparency = 0.7
	username.TextTruncate = Enum.TextTruncate.SplitWord
	username.TextXAlignment = Enum.TextXAlignment.Left
	username.TextYAlignment = Enum.TextYAlignment.Top
	username.AutomaticSize = Enum.AutomaticSize.XY
	username.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	username.BackgroundTransparency = 1
	username.BorderColor3 = Color3.fromRGB(0, 0, 0)
	username.BorderSizePixel = 0
	username.LayoutOrder = 1
	username.Parent = userAndDisplayFrame
	username.Size = UDim2.fromScale(1,0)

	userAndDisplayFrame.Parent = informationGroup

	informationGroup.Parent = userInfo

	local userInfoUIPadding = Instance.new("UIPadding")
	userInfoUIPadding.Name = "UserInfoUIPadding"
	userInfoUIPadding.PaddingLeft = UDim.new(0, 10)
	userInfoUIPadding.PaddingRight = UDim.new(0, 10)
	userInfoUIPadding.Parent = userInfo

	userInfo.Parent = sidebarGroup

	local sidebarGroupUIPadding = Instance.new("UIPadding")
	sidebarGroupUIPadding.Name = "SidebarGroupUIPadding"
	sidebarGroupUIPadding.PaddingLeft = UDim.new(0, 10)
	sidebarGroupUIPadding.PaddingRight = UDim.new(0, 10)
	sidebarGroupUIPadding.PaddingTop = UDim.new(0, style.Spacing.Small)
	sidebarGroupUIPadding.Parent = sidebarGroup

	local tabSwitchers = Instance.new("Frame")
	tabSwitchers.Name = "TabSwitchers"
	tabSwitchers.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	tabSwitchers.BackgroundTransparency = 1
	tabSwitchers.BorderColor3 = Color3.fromRGB(0, 0, 0)
	tabSwitchers.BorderSizePixel = 0
	tabSwitchers.Size = UDim2.new(1, 0, 1, -107)

	local tabSwitchersScrollingFrame = Instance.new("ScrollingFrame")
	tabSwitchersScrollingFrame.Name = "TabSwitchersScrollingFrame"
	tabSwitchersScrollingFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	tabSwitchersScrollingFrame.BottomImage = ""
	tabSwitchersScrollingFrame.CanvasSize = UDim2.new()
	tabSwitchersScrollingFrame.ScrollBarImageTransparency = 0.8
	tabSwitchersScrollingFrame.ScrollBarThickness = 1
	tabSwitchersScrollingFrame.TopImage = ""
	tabSwitchersScrollingFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	tabSwitchersScrollingFrame.BackgroundTransparency = 1
	tabSwitchersScrollingFrame.BorderColor3 = Color3.fromRGB(0, 0, 0)
	tabSwitchersScrollingFrame.BorderSizePixel = 0
	tabSwitchersScrollingFrame.Size = UDim2.fromScale(1, 1)

	local tabSwitchersScrollingFrameUIListLayout = Instance.new("UIListLayout")
	tabSwitchersScrollingFrameUIListLayout.Name = "TabSwitchersScrollingFrameUIListLayout"
	tabSwitchersScrollingFrameUIListLayout.Padding = UDim.new(0, style.Spacing.Large)
	tabSwitchersScrollingFrameUIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabSwitchersScrollingFrameUIListLayout.Parent = tabSwitchersScrollingFrame

	local tabSwitchersScrollingFrameUIPadding = Instance.new("UIPadding")
	tabSwitchersScrollingFrameUIPadding.Name = "TabSwitchersScrollingFrameUIPadding"
	tabSwitchersScrollingFrameUIPadding.PaddingTop = UDim.new(0, style.Spacing.Tiny)
	tabSwitchersScrollingFrameUIPadding.Parent = tabSwitchersScrollingFrame

	tabSwitchersScrollingFrame.Parent = tabSwitchers

	tabSwitchers.Parent = sidebarGroup

	sidebarGroup.Parent = sidebar

	local function columnsFor(width, inset)
		return math.max(1, math.floor((width - inset + trafficGap) / (trafficHitWidth + trafficGap)))
	end

	local function layoutHeader(width)
		local count = #trafficButtons
		local inset = style.Traffic.Padding
		local columns = math.min(count, columnsFor(width, inset))

		--// 16 + two 44 pixel hits + one 4 pixel gap is 108, so the 107
		--// minimum needs the 12 pixel inset to keep two full touch hits.
		if touchLayout and columns < 2 then
			local compactColumns = math.min(count, columnsFor(width, style.Spacing.Medium))
			if compactColumns > columns then
				inset = style.Spacing.Medium
				columns = compactColumns
			end
		end

		local rows = math.ceil(count / columns)
		local trafficHeight = math.max(style.Header, rows * trafficHitHeight + (rows - 1) * trafficGap)

		controls.Size = UDim2.new(1, 0, 0, trafficHeight)

		for index, button in ipairs(trafficButtons) do
			local column = (index - 1) % columns
			local row = math.floor((index - 1) / columns)
			local y = rows == 1 and (trafficHeight - trafficHitHeight) / 2
				or row * (trafficHitHeight + trafficGap)
			button.Size = UDim2.fromOffset(trafficHitWidth, trafficHitHeight)
			button.Position = UDim2.fromOffset(
				inset + column * (trafficHitWidth + trafficGap),
				y
			)
		end

		local usedColumns = math.min(count, columns)
		local trafficRight = inset + usedColumns * trafficHitWidth + (usedColumns - 1) * trafficGap
		local rowInset = trafficRight + titleGap
		local globeLeft = width - style.Spacing.Small - style.Nav.Icon
		local stacked = rows > 1 or globeLeft - titleGap - rowInset <= 0
		local subtitleShown = subtitle.Text ~= ""

		if stacked then
			local titleTop = trafficHeight
			windowControls.Size = UDim2.new(
				1,
				0,
				0,
				titleTop + titleLine + (subtitleShown and style.Subtitle or 0)
			)
			titleFrame.Position = UDim2.fromOffset(inset, titleTop)
			titleFrame.Size = UDim2.fromOffset(math.max(0, width - inset - titleRight), titleLine)
			title.Position = UDim2.fromOffset(0, 0)
			subtitle.Position = UDim2.fromOffset(inset, titleTop + titleLine)
			subtitle.Size = UDim2.fromOffset(
				math.max(0, width - inset - style.Spacing.Small),
				style.Subtitle
			)
			globalSettingsButton.Position = UDim2.new(1, -style.Spacing.Small, 0, titleTop + titleLine / 2)
		else
			windowControls.Size = UDim2.new(1, 0, 0, style.Header + (subtitleShown and style.Subtitle or 0))
			titleFrame.Position = UDim2.fromOffset(rowInset, 0)
			titleFrame.Size = UDim2.fromOffset(
				math.max(0, globeLeft - titleGap - rowInset),
				style.Header
			)
			title.Position = UDim2.fromOffset(0, (style.Header - titleLine) / 2)
			subtitle.Position = UDim2.fromOffset(rowInset, style.Header)
			subtitle.Size = UDim2.fromOffset(
				math.max(0, width - rowInset - style.Spacing.Small),
				style.Subtitle
			)
			globalSettingsButton.Position = UDim2.new(1, -style.Spacing.Small, 0, style.Header / 2)
		end

		sidebarGroup.Position = UDim2.fromOffset(0, windowControls.Size.Y.Offset)
		sidebarGroup.Size = UDim2.new(1, 0, 1, -windowControls.Size.Y.Offset)
		subtitle.Visible = subtitleShown
	end

	layoutHeader(sidebarWidth)

	sidebar.Parent = base

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.AnchorPoint = Vector2.new(1, 0)
	content.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	content.BackgroundTransparency = 1
	content.BorderColor3 = Color3.fromRGB(0, 0, 0)
	content.BorderSizePixel = 0
	content.Position = UDim2.fromScale(1, 4.69e-08)
	content.Size = UDim2.new(1, -sidebarWidth, 1, 0)

	local function applySidebarWidth(width)
		sidebarWidth = math.clamp(width, minSidebarWidth, maxSidebarWidth())
		sidebar.Size = UDim2.new(0, sidebarWidth, 1, 0)
		content.Size = UDim2.new(1, -sidebarWidth, 1, 0)
		layoutHeader(sidebarWidth)
	end

	local function updateSize()
		applySidebarWidth(sidebarWidth)
	end

	connect(base:GetPropertyChangedSignal("AbsoluteSize"), updateSize)

	local resizingContent = false
	local defaultSidebarWidth = style.Sidebar
	local initialMouseX, initialSidebarWidth

	local TweenSettings = {
		DefaultTransparency = 0.9,
		HoverTransparency = 0.85,

		EasingStyle = Enum.EasingStyle.Sine
	}

	local function ChangeState(State)
		Tween(divider, TweenInfo.new(style.Motion.Fast, TweenSettings.EasingStyle), {
			BackgroundTransparency = State == "Idle" and TweenSettings.DefaultTransparency or TweenSettings.HoverTransparency
		}):Play()  
	end

	dividerInteract.MouseEnter:Connect(function()
		ChangeState("Hover")
	end)
	dividerInteract.MouseLeave:Connect(function()
		ChangeState("Idle")
	end)

	dividerInteract.MouseButton1Down:Connect(function()
		if modal:IsBlocked() then return end
		resizingContent = true
		initialMouseX = UserInputService:GetMouseLocation().X
		initialSidebarWidth = sidebar.AbsoluteSize.X
	end)

	connect(UserInputService.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			resizingContent = false
		end
	end)

	connect(UserInputService.InputChanged, function(input)
		if modal:IsBlocked() then
			resizingContent = false
			return
		end
		if resizingContent and input.UserInputType == Enum.UserInputType.MouseMovement then
			local deltaX = UserInputService:GetMouseLocation().X - initialMouseX
			local newSidebarWidth = initialSidebarWidth + deltaX

			if math.abs(newSidebarWidth - defaultSidebarWidth) < snapRange then
				newSidebarWidth = defaultSidebarWidth
			end
			applySidebarWidth(newSidebarWidth)
		end
	end)

	local topbar = Instance.new("Frame")
	topbar.Name = "Topbar"
	topbar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	topbar.BackgroundTransparency = 1
	topbar.BorderColor3 = Color3.fromRGB(0, 0, 0)
	topbar.BorderSizePixel = 0
	topbar.Size = UDim2.new(1, 0, 0, style.Header)

	local divider4 = Instance.new("Frame")
	divider4.Name = "Divider"
	divider4.AnchorPoint = Vector2.new(0, 1)
	theme.Set(divider4, "BackgroundColor3", "Outline")
	divider4.BackgroundTransparency = 0.9
	divider4.BorderColor3 = Color3.fromRGB(0, 0, 0)
	divider4.BorderSizePixel = 0
	divider4.Position = UDim2.fromScale(0, 1)
	divider4.Size = UDim2.new(1, 0, 0, 1)
	divider4.Parent = topbar

	local elements = Instance.new("Frame")
	elements.Name = "Elements"
	elements.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	elements.BackgroundTransparency = 1
	elements.BorderColor3 = Color3.fromRGB(0, 0, 0)
	elements.BorderSizePixel = 0
	elements.Size = UDim2.fromScale(1, 1)

	local uIPadding2 = Instance.new("UIPadding")
	uIPadding2.Name = "UIPadding"
	uIPadding2.PaddingLeft = UDim.new(0, 20)
	uIPadding2.PaddingRight = UDim.new(0, 20)
	uIPadding2.Parent = elements

	local moveIcon = Instance.new("ImageButton")
	moveIcon.Name = "MoveIcon"
	moveIcon.Image = assets.transform
	moveIcon.ImageTransparency = 0.55
	moveIcon.AnchorPoint = Vector2.new(1, 0.5)
	moveIcon.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	moveIcon.BackgroundTransparency = 1
	moveIcon.BorderColor3 = Color3.fromRGB(0, 0, 0)
	moveIcon.BorderSizePixel = 0
	moveIcon.Position = UDim2.fromScale(1, 0.5)
	moveIcon.Size = UDim2.fromOffset(style.Nav.Icon, style.Nav.Icon)
	moveIcon.Parent = elements
	moveIcon.Visible = not Settings.DragStyle or Settings.DragStyle == 1

	local interact = Instance.new("TextButton")
	interact.Name = "Interact"
	interact.FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json")
	interact.Text = ""
	interact.TextColor3 = Color3.fromRGB(0, 0, 0)
	interact.TextSize = 14
	interact.AnchorPoint = Vector2.new(0.5, 0.5)
	interact.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	interact.BackgroundTransparency = 1
	interact.BorderColor3 = Color3.fromRGB(0, 0, 0)
	interact.BorderSizePixel = 0
	interact.Position = UDim2.fromScale(0.5, 0.5)
	interact.Size = UDim2.fromOffset(40, 40)
	interact.Parent = moveIcon

	local function ChangemoveIconState(State)
		if State == "Default" then
			Tween(moveIcon, TweenInfo.new(style.Motion.Fast, Enum.EasingStyle.Sine), {
				ImageTransparency = 0.55
			}):Play()
		elseif State == "Hover" then
			Tween(moveIcon, TweenInfo.new(style.Motion.Fast, Enum.EasingStyle.Sine), {
				ImageTransparency = 0.3
			}):Play()
		end
	end

	interact.MouseEnter:Connect(function()
		ChangemoveIconState("Hover")
	end)
	interact.MouseLeave:Connect(function()
		ChangemoveIconState("Default")
	end)

	local dragging_ = false
	local dragTouch
	local dragStart
	local startPos

	local function update(input)
		-- The base owns the UIScale, which scales its size but not its position.
		local delta = input.Position - dragStart
		base.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
	end

	local function onDragStart(input)
		if modal:IsBlocked() then
			return
		end
		if dragging_ then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging_ = true
			dragTouch = nil
			dragStart = input.Position
			startPos = base.Position
		elseif input.UserInputType == Enum.UserInputType.Touch then
			dragging_ = true
			dragTouch = input
			dragStart = input.Position
			startPos = base.Position
		end
	end

	local function onDragUpdate(input)
		if modal:IsBlocked() then
			dragging_ = false
			dragTouch = nil
			return
		end
		if not dragging_ then
			return
		end
		if input.UserInputType == Enum.UserInputType.Touch then
			-- Only the finger that started the drag moves the window.
			if input == dragTouch then
				update(input)
			end
		elseif input.UserInputType == Enum.UserInputType.MouseMovement and dragTouch == nil then
			-- The mouse move is its own InputObject, so it cannot match the press.
			update(input)
		end
	end

	local function onDragEnd(input)
		if modal:IsBlocked() then
			dragging_ = false
			dragTouch = nil
			return
		end
		if not dragging_ then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			if dragTouch == nil then
				dragging_ = false
			end
		elseif input.UserInputType == Enum.UserInputType.Touch and input == dragTouch then
			dragging_ = false
			dragTouch = nil
		end
	end

	--// A dialog that opens in the middle of a drag or a resize stops that
	--// gesture. The user starts a new one after the dialog is gone.
	local function cancelInteractions()
		dragging_ = false
		dragTouch = nil
		resizingContent = false
	end

	if not Settings.DragStyle or Settings.DragStyle == 1 then
		interact.InputBegan:Connect(onDragStart)
		topbar.InputBegan:Connect(onDragStart)
		titleFrame.InputBegan:Connect(onDragStart)
		subtitle.InputBegan:Connect(onDragStart)

		connect(UserInputService.InputChanged, onDragUpdate)
		connect(UserInputService.InputEnded, onDragEnd)
	elseif Settings.DragStyle == 2 then
		base.InputBegan:Connect(onDragStart)

		connect(UserInputService.InputChanged, onDragUpdate)
		connect(UserInputService.InputEnded, onDragEnd)
	end

	local currentTab = Instance.new("TextLabel")
	currentTab.Name = "CurrentTab"
	currentTab.FontFace = Font.new(assets.interFont)
	currentTab.RichText = true
	currentTab.Text = ""
	currentTab.RichText = true
	theme.Set(currentTab, "TextColor3", "Muted")
	currentTab.TextSize = style.Type.Body
	currentTab.TextTransparency = 0.1
	currentTab.TextTruncate = Enum.TextTruncate.SplitWord
	currentTab.TextXAlignment = Enum.TextXAlignment.Left
	currentTab.TextYAlignment = Enum.TextYAlignment.Center
	currentTab.TextWrapped = false
	currentTab.AnchorPoint = Vector2.new(0, 0.5)
	currentTab.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	currentTab.BackgroundTransparency = 1
	currentTab.BorderColor3 = Color3.fromRGB(0, 0, 0)
	currentTab.BorderSizePixel = 0
	currentTab.Position = UDim2.fromScale(0, 0.5)
	currentTab.Size = UDim2.new(1, -40, 1, 0)
	currentTab.Parent = elements

	elements.Parent = topbar

	topbar.Parent = content

	content.Parent = base

	local globalSettings = Instance.new("CanvasGroup")
	globalSettings.Name = "GlobalSettings"
	globalSettings.AutomaticSize = Enum.AutomaticSize.XY
	theme.Set(globalSettings, "BackgroundColor3", "Background")
	globalSettings.BorderColor3 = Color3.fromRGB(0, 0, 0)
	globalSettings.BorderSizePixel = 0
	globalSettings.GroupTransparency = 1
	globalSettings.Position = UDim2.fromScale(0.298, 0.104)
	globalSettings.Visible = false

	local globalSettingsUIStroke = Instance.new("UIStroke")
	globalSettingsUIStroke.Name = "GlobalSettingsUIStroke"
	globalSettingsUIStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	theme.Set(globalSettingsUIStroke, "Color", "Outline")
	globalSettingsUIStroke.Transparency = 0.9
	globalSettingsUIStroke.Parent = globalSettings

	local globalSettingsUICorner = Instance.new("UICorner")
	globalSettingsUICorner.Name = "GlobalSettingsUICorner"
	globalSettingsUICorner.CornerRadius = UDim.new(0, style.Radius.Group)
	globalSettingsUICorner.Parent = globalSettings

	local globalSettingsUIPadding = Instance.new("UIPadding")
	globalSettingsUIPadding.Name = "GlobalSettingsUIPadding"
	globalSettingsUIPadding.PaddingBottom = UDim.new(0, 10)
	globalSettingsUIPadding.PaddingTop = UDim.new(0, 10)
	globalSettingsUIPadding.Parent = globalSettings

	local globalSettingsUIListLayout = Instance.new("UIListLayout")
	globalSettingsUIListLayout.Name = "GlobalSettingsUIListLayout"
	globalSettingsUIListLayout.Padding = UDim.new(0, 5)
	globalSettingsUIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	globalSettingsUIListLayout.Parent = globalSettings

	local globalSettingsUIScale = Instance.new("UIScale")
	globalSettingsUIScale.Name = "GlobalSettingsUIScale"
	globalSettingsUIScale.Scale = 0.96
	globalSettingsUIScale.Parent = globalSettings
	globalSettings.Parent = base
	base.Parent = gui

	local hovering = false
	local globeHovering = false
	local toggled = false
	local fadeTween
	local scaleTween
	local motionId = 0

	local function animatePopup(open)
		motionId += 1
		local id = motionId
		local reduced = core.ReducedMotion()
		--// The next direction starts from the values the last one reached,
		--// so a rapid second click never snaps the popup. Reduced motion
		--// keeps the scale at 1 and fades only.
		if fadeTween then
			fadeTween:Cancel()
		end
		if scaleTween then
			scaleTween:Cancel()
			scaleTween = nil
		end
		if reduced then
			globalSettingsUIScale.Scale = 1
		elseif open and not globalSettings.Visible then
			globalSettingsUIScale.Scale = 0.96
		end
		if open then
			globalSettings.Visible = true
		end
		fadeTween = Tween(globalSettings, TweenInfo.new(style.Motion.Slow, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
			GroupTransparency = open and 0 or 1
		})
		if not reduced then
			scaleTween = Tween(globalSettingsUIScale, TweenInfo.new(style.Motion.Slow, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
				Scale = open and 1 or 0.96
			})
		end
		fadeTween:Play()
		if scaleTween then
			scaleTween:Play()
		end
		if not open then
			fadeTween.Completed:Connect(function(playbackState)
				--// A close that was overtaken by a reopen must not hide the
				--// popup it no longer represents.
				if id ~= motionId or playbackState ~= Enum.PlaybackState.Completed then
					return
				end
				globalSettings.Visible = false
			end)
		end
	end

	local function toggle()
		toggled = not toggled
		animatePopup(toggled)
	end
	globalSettings.Destroying:Connect(function()
		motionId += 1
		if fadeTween then
			fadeTween:Cancel()
		end
		if scaleTween then
			scaleTween:Cancel()
		end
	end)
	globalSettingsButton.MouseButton1Click:Connect(function()
		if not state.hasGlobalSetting then return end
		toggle()
	end)
	globalSettingsButton.MouseEnter:Connect(function()
		globeHovering = true
	end)
	globalSettingsButton.MouseLeave:Connect(function()
		globeHovering = false
	end)
	globalSettings.MouseEnter:Connect(function()
		hovering = true
	end)
	globalSettings.MouseLeave:Connect(function()
		hovering = false
	end)
	connect(UserInputService.InputEnded, function(inp)
		if inp.UserInputType == Enum.UserInputType.MouseButton1 and toggled and not hovering and not globeHovering then
			toggle()
		end
	end)

	return {
		gui = gui,
		disconnect = disconnect,
		modal = modal,
		cancelInteractions = cancelInteractions,
		notifications = notifications,
		base = base,
		baseUIScale = baseUIScale,
		content = content,
		updateSize = updateSize,
		updateAcrylic = updateAcrylic,
		currentTab = currentTab,
		tabSwitcherParent = tabSwitchersScrollingFrame,
		globalSettings = globalSettings,
		minimize = minimize,
		exit = exit,
		title = title,
		subtitle = subtitle,
		updateTitle = function(NewTitle)
			title.Text = NewTitle
		end,
		updateSubtitle = function(NewSubtitle)
			subtitle.Text = NewSubtitle or ""
			layoutHeader(sidebarWidth)
		end,
		headshot = headshot,
		username = username,
		displayName = displayName,
		headshotImage = headshotImage,
		userInfoReady = isReady,
	}
end
end function __DARKLUA_BUNDLE_MODULES.h():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.h if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.h=v end return v.c end end do local function __modImpl()
local core = __DARKLUA_BUNDLE_MODULES.c()

local HttpService = core.HttpService
local Lighting = core.Lighting
local RunService = core.RunService

return function(base, state)
	local BlurTarget = base

	local HS = HttpService
	local camera = workspace.CurrentCamera
	local MTREL = "Glass"
	local wedgeguid = HS:GenerateGUID(true)
	local stopped = false
	local shown = false
	local renderConnection

	--// The window owns the effect of its own glass. An effect that already
	--// lives in Lighting belongs to another window or to another script and is
	--// never taken over, shared or destroyed from here.
	local DepthOfField = Instance.new('DepthOfFieldEffect')
	DepthOfField.FarIntensity = 0
	DepthOfField.FocusDistance = 51.6
	DepthOfField.InFocusRadius = 50
	DepthOfField.NearIntensity = 1
	DepthOfField.Enabled = false
	DepthOfField.Name = HS:GenerateGUID(true)
	DepthOfField:AddTag(".")

	local frame = Instance.new('Frame')
	frame.Parent = BlurTarget
	frame.Size = UDim2.new(0.97, 0, 0.97, 0)
	frame.Position = UDim2.new(0.5, 0, 0.5, 0)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundTransparency = 1
	frame.Name = HS:GenerateGUID(true)

	local DrawQuad; do
		local acos, clamp, max, pi, sqrt = math.acos, math.clamp, math.max, math.pi, math.sqrt
		local sz = 0.2

		local function DrawTriangle(v1, v2, v3, p0, p1)
			local s1 = (v1 - v2).magnitude
			local s2 = (v2 - v3).magnitude
			local s3 = (v3 - v1).magnitude
			local smax = max(s1, s2, s3)
			local A, B, C
			if s1 == smax then
				A, B, C = v1, v2, v3
			elseif s2 == smax then
				A, B, C = v2, v3, v1
			elseif s3 == smax then
				A, B, C = v3, v1, v2
			end

			local para = ( (B-A).x*(C-A).x + (B-A).y*(C-A).y + (B-A).z*(C-A).z ) / (A-B).magnitude
			local perp = sqrt(max(0, (C-A).magnitude^2 - para*para))
			local dif_para = (A - B).magnitude - para

			local st = CFrame.new(B, A)
			local za = CFrame.Angles(pi/2,0,0)

			local cf0 = st

			local Top_Look = (cf0 * za).lookVector
			local Mid_Point = A + CFrame.new(A, B).lookVector * para
			local Needed_Look = CFrame.new(Mid_Point, C).lookVector
			local dot = Top_Look.x*Needed_Look.x + Top_Look.y*Needed_Look.y + Top_Look.z*Needed_Look.z

			local ac = CFrame.Angles(0, 0, acos(clamp(dot, -1, 1)))

			cf0 = cf0 * ac
			if ((cf0 * za).lookVector - Needed_Look).magnitude > 0.01 then
				cf0 = cf0 * CFrame.Angles(0, 0, -2*acos(clamp(dot, -1, 1)))
			end
			cf0 = cf0 * CFrame.new(0, perp/2, -(dif_para + para/2))

			local cf1 = st * ac * CFrame.Angles(0, pi, 0)
			if ((cf1 * za).lookVector - Needed_Look).magnitude > 0.01 then
				cf1 = cf1 * CFrame.Angles(0, 0, 2*acos(clamp(dot, -1, 1)))
			end
			cf1 = cf1 * CFrame.new(0, perp/2, dif_para/2)

			if not p0 then
				p0 = Instance.new('Part')
				p0.FormFactor = 'Custom'
				p0.TopSurface = 0
				p0.BottomSurface = 0
				p0.Anchored = true
				p0.CanCollide = false
				p0.CastShadow = false
				p0.Material = MTREL
				p0.Size = Vector3.new(sz, sz, sz)
				p0.Name = HS:GenerateGUID(true)
				local mesh = Instance.new('SpecialMesh', p0)
				mesh.MeshType = 2
				mesh.Name = wedgeguid
			end
			p0[wedgeguid].Scale = Vector3.new(0, perp/sz, para/sz)
			p0.CFrame = cf0

			if not p1 then
				p1 = p0:clone()
			end
			p1[wedgeguid].Scale = Vector3.new(0, perp/sz, dif_para/sz)
			p1.CFrame = cf1

			return p0, p1
		end

		function DrawQuad(v1, v2, v3, v4, parts)
			parts[1], parts[2] = DrawTriangle(v1, v2, v3, parts[1], parts[2])
			parts[3], parts[4] = DrawTriangle(v3, v2, v4, parts[3], parts[4])
		end
	end

	local parts = {}

	local parents = {}
	do
		local function add(child)
			if child:IsA'GuiObject' then
				parents[#parents + 1] = child
				add(child.Parent)
			end
		end
		add(frame)
	end

	local function IsVisible(instance)
		while instance do
			if instance:IsA("GuiObject") then
				if not instance.Visible then
					return false
				end
			elseif instance:IsA("ScreenGui") then
				if not instance.Enabled then
					return false
				end
				break
			end
			instance = instance.Parent
		end
		return true
	end

	local function hide()
		shown = false
		for _, pt in pairs(parts) do
			if pt.Parent then
				pt.Parent = nil
			end
		end
		if DepthOfField.Parent then
			DepthOfField.Enabled = false
			DepthOfField.Parent = nil
		end
	end

	--// A camera that is replaced takes its parts with it, so the next frame
	--// builds a new set for the new camera instead of keeping a stale one.
	local function releaseParts()
		for _, pt in pairs(parts) do
			pt:Destroy()
		end
		table.clear(parts)
		shown = false
	end

	local function isFinite(vector)
		return vector.x == vector.x and vector.y == vector.y and vector.z == vector.z
	end

	local function UpdateOrientation()
		if stopped then
			return
		end

		local activeCamera = workspace.CurrentCamera
		if activeCamera ~= camera then
			camera = activeCamera
			releaseParts()
		end

		if not camera or not state.acrylicBlur or not IsVisible(frame) then
			hide()
			return
		end

		--// A frame that the layout has not measured yet has no glass.
		local size = frame.AbsoluteSize
		if size.x <= 0 or size.y <= 0 then
			hide()
			return
		end

		local zIndex = 1 - 0.05*frame.ZIndex

		local tl, br = frame.AbsolutePosition, frame.AbsolutePosition + size
		local tr, bl = Vector2.new(br.x, tl.y), Vector2.new(tl.x, br.y)
		do
			local rot = 0;
			for _, v in ipairs(parents) do
				rot = rot + v.Rotation
			end
			if rot ~= 0 and rot%180 ~= 0 then
				local mid = tl:lerp(br, 0.5)
				local s, c = math.sin(math.rad(rot)), math.cos(math.rad(rot))
				local vec = tl
				tl = Vector2.new(c*(tl.x - mid.x) - s*(tl.y - mid.y), s*(tl.x - mid.x) + c*(tl.y - mid.y)) + mid
				tr = Vector2.new(c*(tr.x - mid.x) - s*(tr.y - mid.y), s*(tr.x - mid.x) + c*(tr.y - mid.y)) + mid
				bl = Vector2.new(c*(bl.x - mid.x) - s*(bl.y - mid.y), s*(bl.x - mid.x) + c*(bl.y - mid.y)) + mid
				br = Vector2.new(c*(br.x - mid.x) - s*(br.y - mid.y), s*(br.x - mid.x) + c*(br.y - mid.y)) + mid
			end
		end

		local o1 = camera:ScreenPointToRay(tl.x, tl.y, zIndex).Origin
		local o2 = camera:ScreenPointToRay(tr.x, tr.y, zIndex).Origin
		local o3 = camera:ScreenPointToRay(bl.x, bl.y, zIndex).Origin
		local o4 = camera:ScreenPointToRay(br.x, br.y, zIndex).Origin
		--// A camera that is not ready reports a ray that is not a number.
		--// The parts are not drawn from it and the effect stays off.
		if not (isFinite(o1) and isFinite(o2) and isFinite(o3) and isFinite(o4)) then
			hide()
			return
		end

		DrawQuad(o1, o2, o3, o4, parts)

		if not shown then
			shown = true
			DepthOfField.Parent = Lighting
			DepthOfField.Enabled = true
			for _, pt in pairs(parts) do
				pt.Transparency = 0.98
				pt.BrickColor = BrickColor.new('Institutional white')
				pt.Parent = camera
			end
		end
	end

	renderConnection = RunService.RenderStepped:Connect(UpdateOrientation)

	return function()
		if stopped then
			return
		end
		stopped = true
		if renderConnection then
			renderConnection:Disconnect()
			renderConnection = nil
		end
		hide()
		releaseParts()
		DepthOfField.Enabled = false
		DepthOfField.Parent = nil
		DepthOfField:Destroy()
		frame:Destroy()
	end
end
end function __DARKLUA_BUNDLE_MODULES.i():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.i if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.i=v end return v.c end end do local function __modImpl()
local core = __DARKLUA_BUNDLE_MODULES.c()
local theme = __DARKLUA_BUNDLE_MODULES.a()

local assets = core.assets
local Tween = core.Tween

return function(Settings, globalSettings, state)
	state.hasGlobalSetting = true
	local GlobalSettingFunctions = {}
	local globalSetting = Instance.new("TextButton")
	globalSetting.Name = "GlobalSetting"
	globalSetting.FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json")
	globalSetting.Text = ""
	globalSetting.TextColor3 = Color3.fromRGB(0, 0, 0)
	globalSetting.TextSize = 14
	globalSetting.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	globalSetting.BackgroundTransparency = 1
	globalSetting.BorderColor3 = Color3.fromRGB(0, 0, 0)
	globalSetting.BorderSizePixel = 0
	globalSetting.Size = UDim2.fromOffset(200, 30)

	local globalSettingToggleUIPadding = Instance.new("UIPadding")
	globalSettingToggleUIPadding.Name = "GlobalSettingToggleUIPadding"
	globalSettingToggleUIPadding.PaddingLeft = UDim.new(0, 15)
	globalSettingToggleUIPadding.Parent = globalSetting

	local settingName = Instance.new("TextLabel")
	settingName.Name = "SettingName"
	settingName.FontFace = Font.new(assets.interFont)
	settingName.Text = Settings.Name
	settingName.RichText = true
	theme.Set(settingName, "TextColor3", "Text")
	settingName.TextSize = 13
	settingName.TextTransparency = 0.5
	settingName.TextTruncate = Enum.TextTruncate.SplitWord
	settingName.TextXAlignment = Enum.TextXAlignment.Left
	settingName.TextYAlignment = Enum.TextYAlignment.Top
	settingName.AnchorPoint = Vector2.new(0, 0.5)
	settingName.AutomaticSize = Enum.AutomaticSize.Y
	settingName.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	settingName.BackgroundTransparency = 1
	settingName.BorderColor3 = Color3.fromRGB(0, 0, 0)
	settingName.BorderSizePixel = 0
	settingName.Position = UDim2.fromScale(1.3e-07, 0.5)
	settingName.Size = UDim2.new(1,-40,0,0)
	settingName.Parent = globalSetting

	local globalSettingToggleUIListLayout = Instance.new("UIListLayout")
	globalSettingToggleUIListLayout.Name = "GlobalSettingToggleUIListLayout"
	globalSettingToggleUIListLayout.Padding = UDim.new(0, 10)
	globalSettingToggleUIListLayout.FillDirection = Enum.FillDirection.Horizontal
	globalSettingToggleUIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	globalSettingToggleUIListLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	globalSettingToggleUIListLayout.Parent = globalSetting

	local checkmark = Instance.new("TextLabel")
	checkmark.Name = "Checkmark"
	checkmark.FontFace = Font.new(
		assets.interFont,
		Enum.FontWeight.Medium,
		Enum.FontStyle.Normal
	)
	checkmark.Text = "✓"
	theme.Set(checkmark, "TextColor3", "Text")
	checkmark.TextSize = 13
	checkmark.TextTransparency = 1
	checkmark.TextXAlignment = Enum.TextXAlignment.Left
	checkmark.TextYAlignment = Enum.TextYAlignment.Top
	checkmark.AnchorPoint = Vector2.new(0, 0.5)
	checkmark.AutomaticSize = Enum.AutomaticSize.Y
	checkmark.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	checkmark.BackgroundTransparency = 1
	checkmark.BorderColor3 = Color3.fromRGB(0, 0, 0)
	checkmark.BorderSizePixel = 0
	checkmark.LayoutOrder = -1
	checkmark.Position = UDim2.fromScale(1.3e-07, 0.5)
	checkmark.Size = UDim2.fromOffset(-10, 0)
	checkmark.Parent = globalSetting

	globalSetting.Parent = globalSettings

	local tweensettings = {
		duration = 0.2,
		easingStyle = Enum.EasingStyle.Quint,
		transparencyIn = 0.2,
		transparencyOut = 0.5,
		checkSizeIncrease = 12,
		checkSizeDecrease = -globalSettingToggleUIListLayout.Padding.Offset,
		waitTime = 1
	}

	local tweens = {
		checkIn = Tween(checkmark, TweenInfo.new(tweensettings.duration, tweensettings.easingStyle), {
			Size = UDim2.new(checkmark.Size.X.Scale, tweensettings.checkSizeIncrease, checkmark.Size.Y.Scale, checkmark.Size.Y.Offset)
		}),
		checkOut = Tween(checkmark, TweenInfo.new(tweensettings.duration, tweensettings.easingStyle),{
			Size = UDim2.new(checkmark.Size.X.Scale, tweensettings.checkSizeDecrease, checkmark.Size.Y.Scale, checkmark.Size.Y.Offset)
		}),
		nameIn = Tween(settingName, TweenInfo.new(tweensettings.duration, tweensettings.easingStyle),{
			TextTransparency = tweensettings.transparencyIn
		}),
		nameOut = Tween(settingName, TweenInfo.new(tweensettings.duration, tweensettings.easingStyle),{
			TextTransparency = tweensettings.transparencyOut
		})
	}

	local function Toggle(State)
		if not State then
			tweens.checkOut:Play()
			tweens.nameOut:Play()
			checkmark:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
				if checkmark.AbsoluteSize.X <= 0 then
					checkmark.TextTransparency = 1
				end
			end)
		else
			tweens.checkIn:Play()
			tweens.nameIn:Play()
			checkmark:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
				if checkmark.AbsoluteSize.X > 0 then
					checkmark.TextTransparency = 0
				end
			end)
		end
	end

	local toggled = Settings.Default
	Toggle(toggled)

	globalSetting.MouseButton1Click:Connect(function()
		toggled = not toggled
		Toggle(toggled)

		task.spawn(function()
			if Settings.Callback then
				Settings.Callback(toggled)
			end
		end)
	end)

	function GlobalSettingFunctions:UpdateName(NewName)
		settingName.Text = NewName
	end

	function GlobalSettingFunctions:UpdateState(NewState)
		Toggle(NewState)
		toggled = NewState
	end

	return GlobalSettingFunctions
end
end function __DARKLUA_BUNDLE_MODULES.j():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.j if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.j=v end return v.c end end do local function __modImpl()
local core = __DARKLUA_BUNDLE_MODULES.c()
local theme = __DARKLUA_BUNDLE_MODULES.a()

local assets = core.assets
local Tween = core.Tween

return function(Settings, notifications)
	local NotificationFunctions = {}

	local notification = Instance.new("Frame")
	notification.Name = "Notification"
	notification.AnchorPoint = Vector2.new(0.5, 0.5)
	notification.AutomaticSize = Enum.AutomaticSize.Y
	theme.Set(notification, "BackgroundColor3", "Background")
	notification.BorderColor3 = Color3.fromRGB(0, 0, 0)
	notification.BorderSizePixel = 0
	notification.Position = UDim2.fromScale(0.5, 0.5)
	notification.Size = UDim2.fromOffset(Settings.SizeX or 250, 0)

	notification.Parent = notifications

	local notificationUIStroke = Instance.new("UIStroke")
	notificationUIStroke.Name = "NotificationUIStroke"
	notificationUIStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	theme.Set(notificationUIStroke, "Color", "Outline")
	notificationUIStroke.Transparency = 0.9
	notificationUIStroke.Parent = notification

	local notificationUICorner = Instance.new("UICorner")
	notificationUICorner.Name = "NotificationUICorner"
	notificationUICorner.CornerRadius = UDim.new(0, 10)
	notificationUICorner.Parent = notification

	local notificationUIScale = Instance.new("UIScale")
	notificationUIScale.Name = "NotificationUIScale"
	notificationUIScale.Parent = notification
	notificationUIScale.Scale = 0

	local notificationInformation = Instance.new("Frame")
	notificationInformation.Name = "NotificationInformation"
	notificationInformation.AutomaticSize = Enum.AutomaticSize.Y
	notificationInformation.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	notificationInformation.BackgroundTransparency = 1
	notificationInformation.BorderColor3 = Color3.fromRGB(0, 0, 0)
	notificationInformation.BorderSizePixel = 0
	notificationInformation.Size = UDim2.fromScale(1, 1)

	local notificationTitle = Instance.new("TextLabel")
	notificationTitle.Name = "NotificationTitle"
	notificationTitle.FontFace = Font.new(
		assets.interFont,
		Enum.FontWeight.SemiBold,
		Enum.FontStyle.Normal
	)
	notificationTitle.RichText = true
	notificationTitle.Text = Settings.Title
	theme.Set(notificationTitle, "TextColor3", "Text")
	notificationTitle.TextSize = 13
	notificationTitle.TextTransparency = 0.2
	notificationTitle.TextTruncate = Enum.TextTruncate.SplitWord
	notificationTitle.TextXAlignment = Enum.TextXAlignment.Left
	notificationTitle.TextYAlignment = Enum.TextYAlignment.Top
	notificationTitle.AutomaticSize = Enum.AutomaticSize.XY
	notificationTitle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	notificationTitle.BackgroundTransparency = 1
	notificationTitle.BorderColor3 = Color3.fromRGB(0, 0, 0)
	notificationTitle.BorderSizePixel = 0
	notificationTitle.Size = UDim2.new(1, -12, 0, 0)

	local notificationTitleUIPadding = Instance.new("UIPadding")
	notificationTitleUIPadding.Name = "NotificationTitleUIPadding"
	notificationTitleUIPadding.PaddingRight = UDim.new(0, 25)
	notificationTitleUIPadding.Parent = notificationTitle

	notificationTitle.Parent = notificationInformation

	local notificationDescription = Instance.new("TextLabel")
	notificationDescription.Name = "NotificationDescription"
	notificationDescription.FontFace = Font.new(
		assets.interFont,
		Enum.FontWeight.Medium,
		Enum.FontStyle.Normal
	)
	notificationDescription.Text = Settings.Description
	theme.Set(notificationDescription, "TextColor3", "Text")
	notificationDescription.TextSize = 11
	notificationDescription.TextTransparency = 0.5
	notificationDescription.TextWrapped = true
	notificationDescription.RichText = true
	notificationDescription.TextXAlignment = Enum.TextXAlignment.Left
	notificationDescription.TextYAlignment = Enum.TextYAlignment.Top
	notificationDescription.AutomaticSize = Enum.AutomaticSize.XY
	notificationDescription.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	notificationDescription.BackgroundTransparency = 1
	notificationDescription.BorderColor3 = Color3.fromRGB(0, 0, 0)
	notificationDescription.BorderSizePixel = 0
	notificationDescription.Size = UDim2.new(1, -12, 0, 0)

	local notificationDescriptionUIPadding = Instance.new("UIPadding")
	notificationDescriptionUIPadding.Name = "NotificationDescriptionUIPadding"
	notificationDescriptionUIPadding.PaddingRight = UDim.new(0, 25)
	notificationDescriptionUIPadding.PaddingTop = UDim.new(0, 17)
	notificationDescriptionUIPadding.Parent = notificationDescription

	notificationDescription.Parent = notificationInformation

	local notificationUIPadding = Instance.new("UIPadding")
	notificationUIPadding.Name = "NotificationUIPadding"
	notificationUIPadding.PaddingBottom = UDim.new(0, 12)
	notificationUIPadding.PaddingLeft = UDim.new(0, 10)
	notificationUIPadding.PaddingRight = UDim.new(0, 10)
	notificationUIPadding.PaddingTop = UDim.new(0, 10)
	notificationUIPadding.Parent = notificationInformation

	notificationInformation.Parent = notification

	local notificationControls = Instance.new("Frame")
	notificationControls.Name = "NotificationControls"
	notificationControls.AutomaticSize = Enum.AutomaticSize.Y
	notificationControls.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	notificationControls.BackgroundTransparency = 1
	notificationControls.BorderColor3 = Color3.fromRGB(0, 0, 0)
	notificationControls.BorderSizePixel = 0
	notificationControls.Size = UDim2.fromScale(1, 1)

	local interactable = Instance.new("TextButton")
	interactable.Name = "Interactable"
	interactable.FontFace = Font.new(assets.interFont)
	interactable.Text = "✓"
	theme.Set(interactable, "TextColor3", "Text")
	interactable.TextSize = 17
	interactable.TextTransparency = 0.2
	interactable.AnchorPoint = Vector2.new(1, 0.5)
	interactable.AutomaticSize = Enum.AutomaticSize.XY
	interactable.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	interactable.BackgroundTransparency = 1
	interactable.BorderColor3 = Color3.fromRGB(0, 0, 0)
	interactable.BorderSizePixel = 0
	interactable.LayoutOrder = 1
	interactable.Position = UDim2.fromScale(1, 0.5)
	interactable.Parent = notificationControls

	local uIPadding = Instance.new("UIPadding")
	uIPadding.Name = "UIPadding"
	uIPadding.PaddingBottom = UDim.new(0, 6)
	uIPadding.PaddingRight = UDim.new(0, 13)
	uIPadding.PaddingTop = UDim.new(0, 6)
	uIPadding.Parent = notificationControls

	notificationControls.Parent = notification

	local tweens = {
		In = Tween(notificationUIScale, TweenInfo.new(0.2, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
			Scale = Settings.Scale or 1
		}),
		Out = Tween(notificationUIScale, TweenInfo.new(0.2, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
			Scale = 0
		}),
	}

	local styles = {
		None = function() interactable:Destroy() end,
		Confirm = function() interactable.Text = "✓" end,
		Cancel = function() interactable.Text = "✗" end
	}

	local style = styles[Settings.Style] or function() interactable:Destroy() end
	style()

	if interactable then
		interactable.MouseButton1Click:Connect(function()
			NotificationFunctions:Cancel()
			if Settings.Callback then
				task.spawn(Settings.Callback)
			end
		end)
	end

	local AnimateNotification = task.spawn(function()
		tweens.In:Play()

		Settings.Lifetime = Settings.Lifetime or 3

		if Settings.Lifetime ~= 0 then
			task.wait(Settings.Lifetime)

			local out = tweens.Out
			out:Play()
			out.Completed:Wait()
			notification:Destroy()
		end
	end)

	function NotificationFunctions:UpdateTitle(New)
		notificationTitle.Text = New
	end

	function NotificationFunctions:UpdateDescription(New)
		notificationDescription.Text = New
	end

	function NotificationFunctions:Resize(X)
		local targ = X or 250
		notification.Size = UDim2.fromOffset(targ, 0)
	end

	function NotificationFunctions:Cancel()
		task.cancel(AnimateNotification)

		local out = tweens.Out
		out:Play()
		out.Completed:Wait()
		notification:Destroy()
	end

	return NotificationFunctions
end
end function __DARKLUA_BUNDLE_MODULES.k():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.k if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.k=v end return v.c end end do local function __modImpl()
local theme = __DARKLUA_BUNDLE_MODULES.a()

--// Roblox has no Tab traversal. The supported keyboard path is the selection
--// of a GuiButton (gamepad or GuiService.SelectedObject), so every selectable
--// control paints the same ring when the engine selects it.
return function(button)
	button.Selectable = true

	local stroke = Instance.new("UIStroke")
	stroke.Name = "FocusUIStroke"
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	theme.Set(stroke, "Color", "Accent")
	stroke.Thickness = 2
	stroke.Transparency = 1
	stroke.Parent = button

	button.SelectionGained:Connect(function()
		stroke.Transparency = 0
	end)
	button.SelectionLost:Connect(function()
		stroke.Transparency = 1
	end)

	return stroke
end
end function __DARKLUA_BUNDLE_MODULES.l():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.l if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.l=v end return v.c end end do local function __modImpl()
local core = __DARKLUA_BUNDLE_MODULES.c()
local theme = __DARKLUA_BUNDLE_MODULES.a()
local style = __DARKLUA_BUNDLE_MODULES.f()
local focus = __DARKLUA_BUNDLE_MODULES.l()

local assets = core.assets
local Tween = core.Tween
local UserInputService = core.UserInputService

return function(Settings, base, modal)
	local DialogFunctions = {}
	--// The dialog holds the input of its window until it is destroyed, so
	--// overlapping dialogs release it only with the last one and only the top
	--// one answers Enter and Escape. The focus is released after the canvas
	--// exists, so a FocusLost callback opens its dialog above this one.
	local releaseInput = function() end
	local isTop = function()
		return true
	end
	local activateInput = function() end
	if modal then
		releaseInput, isTop, activateInput = modal:Push()
	end
	local keyboardConnection
	local actions = {}

	local dialogCanvas = Instance.new("CanvasGroup")
	dialogCanvas.Name = "DialogCanvas"
	dialogCanvas.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	dialogCanvas.BackgroundTransparency = 1
	dialogCanvas.BorderColor3 = Color3.fromRGB(0, 0, 0)
	dialogCanvas.BorderSizePixel = 0
	dialogCanvas.Size = UDim2.fromScale(1, 1)
	dialogCanvas.GroupTransparency = 1
	dialogCanvas.Parent = base

	local dialog = Instance.new("Frame")
	dialog.Name = "Dialog"
	dialog.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	dialog.BackgroundTransparency = 0.5
	dialog.BorderColor3 = Color3.fromRGB(0, 0, 0)
	dialog.BorderSizePixel = 0
	dialog.Size = UDim2.fromScale(1, 1)

	local dialogUICorner = Instance.new("UICorner")
	dialogUICorner.Name = "BaseUICorner"
	dialogUICorner.CornerRadius = UDim.new(0, 10)
	dialogUICorner.Parent = dialog

	--// The invisible full-size button sinks every pointer and touch that is
	--// not on the prompt. The chrome guards the keyboard actions, and the
	--// prompt sits above the blocker so its own buttons still work.
	local blocker = Instance.new("TextButton")
	blocker.Name = "DialogBlocker"
	blocker.Text = ""
	blocker.AutoButtonColor = false
	blocker.Active = true
	blocker.Modal = true
	blocker.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	blocker.BackgroundTransparency = 1
	blocker.BorderSizePixel = 0
	blocker.Size = UDim2.fromScale(1, 1)
	blocker.ZIndex = 1
	blocker.Parent = dialog

	local prompt = Instance.new("Frame")
	prompt.Name = "Prompt"
	prompt.AnchorPoint = Vector2.new(0.5, 0.5)
	prompt.AutomaticSize = Enum.AutomaticSize.Y
	theme.Set(prompt, "BackgroundColor3", "Background")
	prompt.BorderColor3 = Color3.fromRGB(0, 0, 0)
	prompt.BorderSizePixel = 0
	prompt.Position = UDim2.fromScale(0.5, 0.5)
	prompt.Size = UDim2.fromOffset(280, 0)
	prompt.ZIndex = 2

	local promptUIScale = Instance.new("UIScale")
	promptUIScale.Name = "BaseUIScale"
	promptUIScale.Parent = prompt
	promptUIScale.Scale = 0.96

	local globalSettingsUIStroke = Instance.new("UIStroke")
	globalSettingsUIStroke.Name = "GlobalSettingsUIStroke"
	globalSettingsUIStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	theme.Set(globalSettingsUIStroke, "Color", "Outline")
	globalSettingsUIStroke.Transparency = 0.9
	globalSettingsUIStroke.Parent = prompt

	local globalSettingsUICorner = Instance.new("UICorner")
	globalSettingsUICorner.Name = "GlobalSettingsUICorner"
	globalSettingsUICorner.CornerRadius = UDim.new(0, 10)
	globalSettingsUICorner.Parent = prompt

	local globalSettingsUIPadding = Instance.new("UIPadding")
	globalSettingsUIPadding.Name = "GlobalSettingsUIPadding"
	globalSettingsUIPadding.PaddingBottom = UDim.new(0, 20)
	globalSettingsUIPadding.PaddingLeft = UDim.new(0, 20)
	globalSettingsUIPadding.PaddingRight = UDim.new(0, 20)
	globalSettingsUIPadding.PaddingTop = UDim.new(0, 20)
	globalSettingsUIPadding.Parent = prompt

	local paragraph = Instance.new("Frame")
	paragraph.Name = "Paragraph"
	paragraph.AutomaticSize = Enum.AutomaticSize.Y
	paragraph.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	paragraph.BackgroundTransparency = 1
	paragraph.BorderColor3 = Color3.fromRGB(0, 0, 0)
	paragraph.BorderSizePixel = 0
	paragraph.Size = UDim2.new(1, 0, 0, 38)

	local paragraphHeader = Instance.new("TextLabel")
	paragraphHeader.Name = "ParagraphHeader"
	paragraphHeader.FontFace = Font.new(
		assets.interFont,
		Enum.FontWeight.Medium,
		Enum.FontStyle.Normal
	)
	paragraphHeader.RichText = true
	paragraphHeader.Text = Settings.Title
	theme.Set(paragraphHeader, "TextColor3", "Text")
	paragraphHeader.TextSize = 18
	paragraphHeader.TextTransparency = 0.4
	paragraphHeader.TextWrapped = true
	paragraphHeader.AutomaticSize = Enum.AutomaticSize.Y
	paragraphHeader.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	paragraphHeader.BackgroundTransparency = 1
	paragraphHeader.BorderColor3 = Color3.fromRGB(0, 0, 0)
	paragraphHeader.BorderSizePixel = 0
	paragraphHeader.Size = UDim2.fromScale(1, 0)
	paragraphHeader.Parent = paragraph

	local uIListLayout = Instance.new("UIListLayout")
	uIListLayout.Name = "UIListLayout"
	uIListLayout.Padding = UDim.new(0, 15)
	uIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	uIListLayout.Parent = paragraph

	local paragraphBody = Instance.new("TextLabel")
	paragraphBody.Name = "ParagraphBody"
	paragraphBody.FontFace = Font.new(assets.interFont)
	paragraphBody.RichText = true
	paragraphBody.Text = Settings.Description
	theme.Set(paragraphBody, "TextColor3", "Text")
	paragraphBody.TextSize = 14
	paragraphBody.TextTransparency = 0.5
	paragraphBody.TextWrapped = true
	paragraphBody.AutomaticSize = Enum.AutomaticSize.Y
	paragraphBody.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	paragraphBody.BackgroundTransparency = 1
	paragraphBody.BorderColor3 = Color3.fromRGB(0, 0, 0)
	paragraphBody.BorderSizePixel = 0
	paragraphBody.LayoutOrder = 1
	paragraphBody.Size = UDim2.fromScale(1, 0)
	paragraphBody.Parent = paragraph

	paragraph.Parent = prompt

	local interactions = Instance.new("Frame")
	interactions.Name = "Interactions"
	interactions.AutomaticSize = Enum.AutomaticSize.Y
	interactions.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	interactions.BackgroundTransparency = 1
	interactions.BorderColor3 = Color3.fromRGB(0, 0, 0)
	interactions.BorderSizePixel = 0
	interactions.LayoutOrder = 1
	interactions.Size = UDim2.fromScale(1, 0)

	local uIListLayout1 = Instance.new("UIListLayout")
	uIListLayout1.Name = "UIListLayout"
	uIListLayout1.Padding = UDim.new(0, 10)
	uIListLayout1.SortOrder = Enum.SortOrder.LayoutOrder
	uIListLayout1.Parent = interactions

	local uIPadding = Instance.new("UIPadding")
	uIPadding.Name = "UIPadding"
	uIPadding.PaddingTop = UDim.new(0, 20)
	uIPadding.Parent = interactions

	interactions.Parent = prompt

	local uIListLayout2 = Instance.new("UIListLayout")
	uIListLayout2.Name = "UIListLayout"
	uIListLayout2.SortOrder = Enum.SortOrder.LayoutOrder
	uIListLayout2.Parent = prompt

	prompt.Parent = dialog

	dialog.Parent = dialogCanvas

	local canvasTween
	local scaleTween
	local closed = false
	local accepted = false

	local function stopTweens()
		if canvasTween then
			canvasTween:Cancel()
		end
		if scaleTween then
			scaleTween:Cancel()
		end
	end

	local function animate(canvasTransparency, scale)
		--// A new direction cancels the old one and starts from the values it
		--// reached, so an interrupted dialog never jumps. Reduced motion
		--// keeps the scale at 1 and fades only.
		stopTweens()
		canvasTween = Tween(dialogCanvas, TweenInfo.new(style.Motion.Slow, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
			GroupTransparency = canvasTransparency
		})
		if core.ReducedMotion() then
			promptUIScale.Scale = 1
			scaleTween = nil
		else
			scaleTween = Tween(promptUIScale, TweenInfo.new(style.Motion.Slow, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
				Scale = scale
			})
		end
		canvasTween:Play()
		if scaleTween then
			scaleTween:Play()
		end
		return canvasTween
	end

	local function dialogIn()
		closed = false
		animate(0, 1)
	end

	local function dialogOut()
		if closed then return end
		closed = true
		local tween = animate(1, 0.96)
		--// A close that is interrupted by the unload is cancelled by the
		--// Destroying handler, which also completes this wait.
		tween.Completed:Wait()
		dialogCanvas:Destroy()
	end

	--// The modal owner keeps the input of the window and the focus it held.
	--// Both are released when the canvas goes, including a window unload.
	dialogCanvas.Destroying:Connect(function()
		closed = true
		stopTweens()
		if keyboardConnection then
			keyboardConnection:Disconnect()
			keyboardConnection = nil
		end
		releaseInput()
	end)

	--// A click and a key share one path. Escape may close while the dialog
	--// is still fading in; a pointer click keeps the fully open rule.
	local function activate(v, allowBeforeOpen)
		if closed or accepted then return end
		if not allowBeforeOpen and dialogCanvas.GroupTransparency ~= 0 then return end
		--// The action is accepted before the callback runs. A callback that
		--// waits leaves the dialog open, so a second key or click must not
		--// run the action again.
		accepted = true
		if v.Callback then
			--// A failure leaves the dialog usable, as it did before the
			--// one-shot guard, and still reaches the caller.
			local ok, err = pcall(v.Callback)
			if not ok then
				accepted = false
				error(err, 0)
			end
		end
		task.spawn(dialogOut)
	end

	for _, v in pairs(Settings.Buttons) do
		local isDefault = v.Default == true
		local isCancel = v.Cancel == true

		local button = Instance.new("TextButton")
		button.Name = "Button"
		button.FontFace = Font.new(assets.interFont)
		button.Text = v.Name
		theme.Set(button, "TextColor3", isDefault and "Highlight" or "Text")
		button.TextSize = 15
		button.TextTransparency = isDefault and 0 or 0.1
		button.TextTruncate = Enum.TextTruncate.AtEnd
		button.AutoButtonColor = false
		button.AutomaticSize = Enum.AutomaticSize.Y
		theme.Set(button, "BackgroundColor3", isDefault and "Accent" or "Surface")
		button.BorderColor3 = Color3.fromRGB(0, 0, 0)
		button.BorderSizePixel = 0
		button.Size = UDim2.fromScale(1, 0)

		local uIPadding1 = Instance.new("UIPadding")
		uIPadding1.Name = "UIPadding"
		uIPadding1.PaddingBottom = UDim.new(0, 9)
		uIPadding1.PaddingLeft = UDim.new(0, 10)
		uIPadding1.PaddingRight = UDim.new(0, 10)
		uIPadding1.PaddingTop = UDim.new(0, 9)
		uIPadding1.Parent = button

		local baseUICorner1 = Instance.new("UICorner")
		baseUICorner1.Name = "BaseUICorner"
		baseUICorner1.CornerRadius = UDim.new(0, 10)
		baseUICorner1.Parent = button

		button.Parent = interactions
		focus(button)

		local TweenSettings = {
			DefaultTransparency = 0,
			DefaultTransparency2 = isDefault and 0 or 0.1,
			HoverTransparency = isDefault and 0.12 or 0.3,
			HoverTransparency2 = 0,

			EasingStyle = Enum.EasingStyle.Sine
		}

		local function ChangeState(State)
			if State == "Idle" then
				Tween(button, TweenInfo.new(0.2, TweenSettings.EasingStyle), {
					BackgroundTransparency = TweenSettings.DefaultTransparency,
					TextTransparency = TweenSettings.DefaultTransparency2
				}):Play()
			elseif State == "Hover" then
				Tween(button, TweenInfo.new(0.2, TweenSettings.EasingStyle), {
					BackgroundTransparency = TweenSettings.HoverTransparency,
					TextTransparency = TweenSettings.HoverTransparency2
				}):Play()
			end
		end

		button.MouseButton1Click:Connect(function()
			activate(v, false)
		end)

		button.MouseEnter:Connect(function()
			ChangeState("Hover")
		end)
		button.MouseLeave:Connect(function()
			ChangeState("Idle")
		end)

		if isDefault and not actions.Default then
			actions.Default = v
		end
		if isCancel and not actions.Cancel then
			actions.Cancel = v
		end
	end

	keyboardConnection = UserInputService.InputBegan:Connect(function(input)
		if closed or not isTop() then return end
		if input.UserInputType ~= Enum.UserInputType.Keyboard then return end

		if input.KeyCode == Enum.KeyCode.Return then
			--// A focused text box owns Return, so typing never confirms.
			if UserInputService:GetFocusedTextBox() then return end
			if actions.Default then
				activate(actions.Default, false)
			end
		elseif input.KeyCode == Enum.KeyCode.Escape then
			if actions.Cancel then
				activate(actions.Cancel, true)
			else
				task.spawn(dialogOut)
			end
		end
	end)

	dialogIn()
	activateInput()

	function DialogFunctions:UpdateTitle(New)
		paragraphHeader.Text = New
	end
	function DialogFunctions:UpdateDescription(New)
		paragraphBody.Text = New
	end

	function DialogFunctions:Cancel()
		task.spawn(dialogOut)
	end

	return DialogFunctions
end
end function __DARKLUA_BUNDLE_MODULES.m():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.m if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.m=v end return v.c end end do local function __modImpl()
local core = __DARKLUA_BUNDLE_MODULES.c()

local FractUI = core.FractUI

--// Connects the release of a widget to the three ways it can end: an explicit
--// Destroy, the destruction of the container and the unload of the window.
--// The release runs once, so a widget that ends twice stays safe.
--// options: { functions, instance, env, flag, release }
return function(options)
	local functions = options.functions
	local released = false

	-- The connections of the widget. They are let go when the widget ends, so
	-- a released widget does not keep the window and its settings alive.
	local destroyingConnection = nil
	local unloadConnection = nil

	local function release()
		if released then
			return
		end
		released = true

		-- The connections go first, so they are let go even when the release
		-- of the widget fails.
		if destroyingConnection then
			destroyingConnection:Disconnect()
			destroyingConnection = nil
		end
		if unloadConnection then
			unloadConnection:Disconnect()
			unloadConnection = nil
		end

		-- The release of the widget may fail. The flag of the widget is let
		-- go anyway, so the widget does not stay in the options.
		local ok, err = true, nil
		if options.release then
			ok, err = pcall(options.release)
		end

		if options.flag and FractUI.Options[options.flag] == functions then
			FractUI.Options[options.flag] = nil
		end

		if not ok then
			warn("FractUI: a widget could not be released: " .. tostring(err))
		end
	end

	-- The container of the widget can take it away at any time.
	destroyingConnection = options.instance.Destroying:Connect(release)

	-- The window releases the widget when it unloads.
	if options.env and options.env.unloaded then
		unloadConnection = options.env.unloaded:Connect(release)
	end

	return release
end
end function __DARKLUA_BUNDLE_MODULES.n():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.n if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.n=v end return v.c end end do local function __modImpl()
local core = __DARKLUA_BUNDLE_MODULES.c()
local theme = __DARKLUA_BUNDLE_MODULES.a()
local cleanup = __DARKLUA_BUNDLE_MODULES.n()

local FractUI = core.FractUI
local assets = core.assets
local Tween = core.Tween
local UserInputService = core.UserInputService

local MODES = {
	Toggle = true,
	Hold = true,
	Press = true,
	Always = true,
}

--// Inline key picker: a small key badge on the right edge of a widget.
--// options: { parent, position, width, height, settings, host, flag, onRelease }
return function(options)
	local settings = options.settings or {}
	local KeyPickerFunctions = { Settings = settings, IgnoreConfig = false, Class = "KeyPicker" }

	local badge = Instance.new("TextButton")
	badge.Name = "KeyPickerBadge"
	badge.FontFace = Font.new(assets.interFont)
	badge.Text = ""
	theme.Set(badge, "TextColor3", "Text")
	badge.TextSize = 12
	badge.TextTransparency = 0.1
	badge.TextTruncate = Enum.TextTruncate.AtEnd
	badge.AnchorPoint = Vector2.new(1, 0.5)
	badge.AutoButtonColor = false
	badge.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	badge.BackgroundTransparency = 0.95
	badge.BorderColor3 = Color3.fromRGB(0, 0, 0)
	badge.BorderSizePixel = 0
	badge.Position = options.position
	badge.Size = UDim2.fromOffset(options.width, options.height)
	badge.Parent = options.parent

	local badgeUICorner = Instance.new("UICorner")
	badgeUICorner.Name = "KeyPickerBadgeUICorner"
	badgeUICorner.CornerRadius = UDim.new(0, 4)
	badgeUICorner.Parent = badge

	local badgeUIStroke = Instance.new("UIStroke")
	badgeUIStroke.Name = "KeyPickerBadgeUIStroke"
	badgeUIStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	theme.Set(badgeUIStroke, "Color", "Outline")
	badgeUIStroke.Transparency = 0.9
	badgeUIStroke.Parent = badge

	local badgeUIPadding = Instance.new("UIPadding")
	badgeUIPadding.Name = "KeyPickerBadgeUIPadding"
	badgeUIPadding.PaddingLeft = UDim.new(0, 5)
	badgeUIPadding.PaddingRight = UDim.new(0, 5)
	badgeUIPadding.Parent = badge

	local binded = settings.Default
	local mode = MODES[settings.Mode] and settings.Mode or "Toggle"
	local toggled = false
	local picking = false
	local destroyed = false
	-- The press that was accepted. Only its release is handled.
	local held = false
	-- The picker holds the host while the key of a hold is held.
	local holding = false

	local function display()
		if picking or not binded then
			badge.Text = "..."
		else
			badge.Text = binded.Name
		end
	end

	local function displayState(active)
		Tween(badge, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
			TextTransparency = active and 0 or 0.1,
		}):Play()

		Tween(badge, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
			BackgroundTransparency = active and 0.85 or 0.95,
		}):Play()
	end

	local function setState(newState)
		if toggled == newState then
			return
		end
		toggled = newState
		KeyPickerFunctions.State = toggled
		displayState(toggled)
	end

	--// The state that belongs to the mode and to the bind. A picker that is
	--// rebound or that changes its mode is not in the middle of a press.
	local function expectedState()
		if mode == "Always" then
			return true
		end
		if mode == "Toggle" and settings.SyncToggleState and options.host and options.host.GetState then
			return options.host:GetState() == true
		end
		return false
	end

	local function reconcile()
		setState(expectedState())
	end

	--// The user is told about the state of the picker. The callback of the
	--// user may fail, so the failure is reported and the picker keeps
	--// working.
	local function fire(value)
		if settings.Callback then
			local ok, err = pcall(settings.Callback, value, binded)
			if not ok then
				warn("FractUI: the callback of the key picker failed: " .. tostring(err))
			end
		end
	end

	local function captureKey(input)
		if input.UserInputType == Enum.UserInputType.Keyboard then
			return input.KeyCode
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.MouseButton2 then
			return input.UserInputType
		end
		return nil
	end

	local function isAllowed(input)
		local blacklist = settings.Blacklist
		if type(blacklist) ~= "table" then
			return true
		end
		return not (table.find(blacklist, input.KeyCode) or table.find(blacklist, input.UserInputType))
	end

	local function matches(input)
		if not binded then
			return false
		end
		return input.KeyCode == binded or input.UserInputType == binded
	end

	--// The state of the host is written. The host may fail, so the failure
	--// is reported and the picker keeps the ownership of the host, so the
	--// host is released when the press ends.
	local function applyHostState(newState)
		if settings.SyncToggleState and options.host and options.host.UpdateState then
			local ok, err = pcall(options.host.UpdateState, options.host, newState)
			if not ok then
				warn("FractUI: the host of the key picker failed: " .. tostring(err))
			end
			return true
		end
		return false
	end

	--// The host is written when the press starts. The write is only done
	--// when the press still belongs to this picker, because the callback
	--// of the user may end the press.
	local function writeHost(newState)
		if not held or destroyed then
			return false
		end
		return applyHostState(newState)
	end

	--// The press is over. The state of the mode is left and the host is
	--// released when the picker holds it. Only a press that was accepted is
	--// ended here, so the user is never told about a press that never was.
	local function endPress()
		if not held then
			return
		end
		local wasHolding = holding
		held = false
		holding = false
		if mode == "Hold" then
			setState(false)
			fire(false)
		elseif mode == "Press" then
			setState(false)
		end
		if wasHolding then
			applyHostState(false)
		end
	end

	local inputConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if destroyed then
			return
		end
		--// A dialog owns the keys of its window, so a bound action does not
		--// run behind it. The release is still handled, so a hold that began
		--// before the dialog ends with its key.
		if options.env and options.env.modal and options.env.modal:IsBlocked() then
			return
		end

		if picking then
			if not isAllowed(input) then
				return
			end
			local captured = captureKey(input)
			if not captured then
				return
			end
			picking = false
			-- The capture is a rebind, so a press that is running ends here.
			endPress()
			binded = captured
			KeyPickerFunctions.Key = captured
			display()
			reconcile()
			if settings.onBinded then
				settings.onBinded(binded)
			end
			return
		end

		if gameProcessed then
			return
		end
		if UserInputService:GetFocusedTextBox() then
			return
		end
		if mode == "Always" then
			return
		end
		if not matches(input) then
			return
		end

		-- The press is accepted, so its release belongs to this picker.
		held = true

		if mode == "Toggle" then
			local newState = not toggled
			setState(newState)
			fire(newState)
			writeHost(newState)
		else
			setState(true)
			fire(true)
			if mode == "Hold" then
				-- The ownership of the host is taken before the host is
				-- written, so a callback of the host that ends the press
				-- releases the host at once.
				holding = true
				if not writeHost(true) then
					-- The host was not written, so the picker does not own it.
					holding = false
				end
			end
		end
	end)

	local endedConnection = UserInputService.InputEnded:Connect(function(input)
		if destroyed or picking then
			return
		end
		-- Only the release of an accepted press is handled.
		if not held then
			return
		end
		-- Only the release of the bound key ends the press, another key may
		-- be released while the bound one is still held.
		if not matches(input) then
			return
		end
		endPress()
	end)

	badge.MouseButton1Click:Connect(function()
		if destroyed or picking then
			return
		end
		-- The capture starts, so a press that is running ends here. The
		-- host is released at once and not when the next key comes.
		endPress()
		picking = true
		display()
	end)

	KeyPickerFunctions.Key = binded
	KeyPickerFunctions.Mode = mode
	KeyPickerFunctions.State = toggled
	KeyPickerFunctions.SyncToggleState = settings.SyncToggleState and true or false

	display()

	-- The state follows the mode and the host from the start.
	reconcile()

	function KeyPickerFunctions:Bind(key)
		-- A rebind ends a press that is running.
		endPress()
		binded = key
		KeyPickerFunctions.Key = key
		display()
		reconcile()
	end

	function KeyPickerFunctions:Unbind()
		-- An unbind ends a press that is running.
		endPress()
		binded = nil
		KeyPickerFunctions.Key = nil
		display()
		reconcile()
	end

	function KeyPickerFunctions:GetBind()
		return binded
	end

	function KeyPickerFunctions:SetMode(NewMode)
		if not MODES[NewMode] then
			return
		end
		-- The mode changes, so a press that is running ends here.
		endPress()
		mode = NewMode
		KeyPickerFunctions.Mode = NewMode
		reconcile()
	end

	function KeyPickerFunctions:GetMode()
		return mode
	end

	function KeyPickerFunctions:SetState(Value)
		setState(Value)
	end

	function KeyPickerFunctions:GetState()
		return toggled
	end

	function KeyPickerFunctions:SyncState(Value)
		if not settings.SyncToggleState then
			return
		end
		setState(Value)
	end

	function KeyPickerFunctions:SetVisibility(State)
		badge.Visible = State
	end

	function KeyPickerFunctions:SetPosition(Position)
		badge.Position = Position
	end

	-- The picker releases its connections when it ends, no matter how it ends.
	local release = cleanup({
		functions = KeyPickerFunctions,
		instance = badge,
		env = options.env,
		flag = options.flag,
		release = function()
			-- The connections go first, so they are let go even when the
			-- callback of the user fails.
			destroyed = true
			inputConnection:Disconnect()
			endedConnection:Disconnect()
			-- A press that is running ends with the picker.
			endPress()
			-- The picker leaves the host, so the host does not keep it and
			-- its settings alive.
			if options.onRelease then
				options.onRelease()
			end
		end,
	})

	function KeyPickerFunctions:Destroy()
		release()
		badge:Destroy()
	end

	if options.flag then
		FractUI.Options[options.flag] = KeyPickerFunctions
	end

	return KeyPickerFunctions
end
end function __DARKLUA_BUNDLE_MODULES.o():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.o if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.o=v end return v.c end end do local function __modImpl()
local core = __DARKLUA_BUNDLE_MODULES.c()
local theme = __DARKLUA_BUNDLE_MODULES.a()

local assets = core.assets
local Tween = core.Tween
local UserInputService = core.UserInputService
local LocalPlayer = core.LocalPlayer

--// The HSV/alpha popover shared by the colorpicker widget and the inline color swatch.
--// options: { base, name, alpha (boolean), color, alphaValue, onConfirm(color, alpha) }
return function(options)
	local base = options.base
	local isAlpha = options.alpha and true or false

	local CurrentColor = options.color or Color3.fromRGB(255, 255, 255)
	local CurrentAlpha = options.alphaValue or 0

	local colorPicker = Instance.new("Frame")
	colorPicker.Name = "ColorPicker"
	colorPicker.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	colorPicker.BackgroundTransparency = 0.5
	colorPicker.BorderColor3 = Color3.fromRGB(0, 0, 0)
	colorPicker.BorderSizePixel = 0
	colorPicker.Size = UDim2.fromScale(1, 1)
	colorPicker.Visible = false

	local baseUICorner = Instance.new("UICorner")
	baseUICorner.Name = "BaseUICorner"
	baseUICorner.CornerRadius = UDim.new(0, 10)
	baseUICorner.Parent = colorPicker

	local prompt = Instance.new("Frame")
	prompt.Name = "Prompt"
	prompt.AnchorPoint = Vector2.new(0.5, 0.5)
	prompt.AutomaticSize = Enum.AutomaticSize.Y
	theme.Set(prompt, "BackgroundColor3", "Background")
	prompt.BorderColor3 = Color3.fromRGB(0, 0, 0)
	prompt.BorderSizePixel = 0
	prompt.Position = UDim2.fromScale(0.5, 0.5)
	prompt.Size = UDim2.fromOffset(420, 0)

	local promptUIScale = Instance.new("UIScale")
	promptUIScale.Name = "BaseUIScale"
	promptUIScale.Parent = prompt
	promptUIScale.Scale = 0.95

	local globalSettingsUIStroke = Instance.new("UIStroke")
	globalSettingsUIStroke.Name = "GlobalSettingsUIStroke"
	globalSettingsUIStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	theme.Set(globalSettingsUIStroke, "Color", "Outline")
	globalSettingsUIStroke.Transparency = 0.9
	globalSettingsUIStroke.Parent = prompt

	local globalSettingsUICorner = Instance.new("UICorner")
	globalSettingsUICorner.Name = "GlobalSettingsUICorner"
	globalSettingsUICorner.CornerRadius = UDim.new(0, 10)
	globalSettingsUICorner.Parent = prompt

	local uIListLayout = Instance.new("UIListLayout")
	uIListLayout.Name = "UIListLayout"
	uIListLayout.Padding = UDim.new(0, 10)
	uIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	uIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	uIListLayout.Parent = prompt

	local colorOptions = Instance.new("Frame")
	colorOptions.Name = "ColorOptions"
	colorOptions.AutomaticSize = Enum.AutomaticSize.XY
	colorOptions.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	colorOptions.BackgroundTransparency = 1
	colorOptions.BorderColor3 = Color3.fromRGB(0, 0, 0)
	colorOptions.BorderSizePixel = 0
	colorOptions.LayoutOrder = 1
	colorOptions.Size = UDim2.fromScale(1, 0)

	local value = Instance.new("TextButton")
	value.Name = "Value"
	value.FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json")
	value.Text = ""
	value.TextColor3 = Color3.fromRGB(0, 0, 0)
	value.TextSize = 14
	value.AutoButtonColor = false
	value.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	value.BorderColor3 = Color3.fromRGB(0, 0, 0)
	value.BorderSizePixel = 0
	value.LayoutOrder = 1
	value.Position = UDim2.fromScale(0.092, 0.886)
	value.Size = UDim2.new(1, 0, 0, 15)

	local uIGradient = Instance.new("UIGradient")
	uIGradient.Name = "UIGradient"
	uIGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
	})
	uIGradient.Parent = value

	local slide = Instance.new("Frame")
	slide.Name = "Slide"
	slide.AnchorPoint = Vector2.new(0, 0.5)
	slide.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	theme.Set(slide, "BorderColor3", "Border")
	slide.BorderSizePixel = 0
	slide.Position = UDim2.fromScale(0, 0.5)
	slide.Size = UDim2.new(0, 13, 1, 8)

	local uICorner = Instance.new("UICorner")
	uICorner.Name = "UICorner"
	uICorner.CornerRadius = UDim.new(1, 0)
	uICorner.Parent = slide

	local uIStroke = Instance.new("UIStroke")
	uIStroke.Name = "UIStroke"
	uIStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	uIStroke.Transparency = 0.5
	uIStroke.Parent = slide

	slide.Parent = value

	local uICorner1 = Instance.new("UICorner")
	uICorner1.Name = "UICorner"
	uICorner1.CornerRadius = UDim.new(0, 6)
	uICorner1.Parent = value

	local uIStroke1 = Instance.new("UIStroke")
	uIStroke1.Name = "UIStroke"
	uIStroke1.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	theme.Set(uIStroke1, "Color", "Outline")
	uIStroke1.Transparency = 0.9

	local uIGradient1 = Instance.new("UIGradient")
	uIGradient1.Name = "UIGradient"
	uIGradient1.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0)),
	})
	uIGradient1.Rotation = 180
	uIGradient1.Parent = uIStroke1

	uIStroke1.Parent = value

	value.Parent = colorOptions

	local uIListLayout1 = Instance.new("UIListLayout")
	uIListLayout1.Name = "UIListLayout"
	uIListLayout1.Padding = UDim.new(0, 25)
	uIListLayout1.SortOrder = Enum.SortOrder.LayoutOrder
	uIListLayout1.Parent = colorOptions

	local wheel = Instance.new("Frame")
	wheel.Name = "Wheel"
	wheel.AutomaticSize = Enum.AutomaticSize.Y
	wheel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	wheel.BackgroundTransparency = 1
	wheel.BorderColor3 = Color3.fromRGB(0, 0, 0)
	wheel.BorderSizePixel = 0
	wheel.Size = UDim2.new(1, 0, 0, 100)

	local wheel1 = Instance.new("ImageButton")
	wheel1.Name = "Wheel"
	wheel1.Image = assets.colorWheel
	wheel1.AutoButtonColor = false
	wheel1.Active = false
	wheel1.BackgroundColor3 = Color3.fromRGB(248, 248, 248)
	wheel1.BackgroundTransparency = 1
	theme.Set(wheel1, "BorderColor3", "Border")
	wheel1.Selectable = false
	wheel1.Size = UDim2.fromOffset(220, 220)
	wheel1.SizeConstraint = Enum.SizeConstraint.RelativeYY

	local target = Instance.new("ImageLabel")
	target.Name = "Target"
	target.Image = assets.colorTarget
	target.ImageColor3 = Color3.fromRGB(0, 0, 0)
	target.AnchorPoint = Vector2.new(0.5, 0.5)
	target.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	target.BackgroundTransparency = 1
	theme.Set(target, "BorderColor3", "Border")
	target.Position = UDim2.fromScale(0.5, 0.5)
	target.Size = UDim2.fromOffset(22, 22)
	target.SizeConstraint = Enum.SizeConstraint.RelativeYY
	target.Parent = wheel1

	wheel1.Parent = wheel

	local inputs = Instance.new("Frame")
	inputs.Name = "Inputs"
	inputs.AnchorPoint = Vector2.new(1, 0.5)
	inputs.AutomaticSize = Enum.AutomaticSize.XY
	inputs.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	inputs.BackgroundTransparency = 1
	inputs.BorderColor3 = Color3.fromRGB(0, 0, 0)
	inputs.BorderSizePixel = 0
	inputs.LayoutOrder = 1
	inputs.Position = UDim2.fromScale(1, 0.5)

	local uIListLayout2 = Instance.new("UIListLayout")
	uIListLayout2.Name = "UIListLayout"
	uIListLayout2.Padding = UDim.new(0, 5)
	uIListLayout2.SortOrder = Enum.SortOrder.LayoutOrder
	uIListLayout2.Parent = inputs

	local red = Instance.new("Frame")
	red.Name = "Red"
	red.AutomaticSize = Enum.AutomaticSize.XY
	red.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	red.BackgroundTransparency = 1
	red.BorderColor3 = Color3.fromRGB(0, 0, 0)
	red.BorderSizePixel = 0
	red.LayoutOrder = 1
	red.Size = UDim2.fromOffset(0, 38)

	local inputName = Instance.new("TextLabel")
	inputName.Name = "InputName"
	inputName.FontFace = Font.new(assets.interFont)
	inputName.Text = "Red"
	theme.Set(inputName, "TextColor3", "Text")
	inputName.TextSize = 13
	inputName.TextTransparency = 0.5
	inputName.TextTruncate = Enum.TextTruncate.AtEnd
	inputName.TextXAlignment = Enum.TextXAlignment.Left
	inputName.TextYAlignment = Enum.TextYAlignment.Top
	inputName.AnchorPoint = Vector2.new(0, 0.5)
	inputName.AutomaticSize = Enum.AutomaticSize.XY
	inputName.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	inputName.BackgroundTransparency = 1
	inputName.BorderColor3 = Color3.fromRGB(0, 0, 0)
	inputName.BorderSizePixel = 0
	inputName.LayoutOrder = 2
	inputName.Position = UDim2.fromScale(0, 0.5)
	inputName.Parent = red

	local uIListLayout3 = Instance.new("UIListLayout")
	uIListLayout3.Name = "UIListLayout"
	uIListLayout3.Padding = UDim.new(0, 15)
	uIListLayout3.FillDirection = Enum.FillDirection.Horizontal
	uIListLayout3.SortOrder = Enum.SortOrder.LayoutOrder
	uIListLayout3.VerticalAlignment = Enum.VerticalAlignment.Center
	uIListLayout3.Parent = red

	local inputBox = Instance.new("TextBox")
	inputBox.Name = "InputBox"
	inputBox.ClearTextOnFocus = false
	inputBox.CursorPosition = -1
	inputBox.FontFace = Font.new(assets.interFont)
	inputBox.Text = "255"
	theme.Set(inputBox, "TextColor3", "Text")
	inputBox.TextSize = 12
	inputBox.TextTransparency = 0.1
	inputBox.TextXAlignment = Enum.TextXAlignment.Left
	inputBox.AnchorPoint = Vector2.new(1, 0.5)
	inputBox.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	inputBox.BackgroundTransparency = 0.95
	inputBox.BorderColor3 = Color3.fromRGB(0, 0, 0)
	inputBox.BorderSizePixel = 0
	inputBox.ClipsDescendants = true
	inputBox.LayoutOrder = 1
	inputBox.Position = UDim2.fromScale(1, 0.5)
	inputBox.Size = UDim2.fromOffset(75, 25)

	local inputBoxUICorner = Instance.new("UICorner")
	inputBoxUICorner.Name = "InputBoxUICorner"
	inputBoxUICorner.CornerRadius = UDim.new(0, 4)
	inputBoxUICorner.Parent = inputBox

	local inputBoxUIStroke = Instance.new("UIStroke")
	inputBoxUIStroke.Name = "InputBoxUIStroke"
	inputBoxUIStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	theme.Set(inputBoxUIStroke, "Color", "Outline")
	inputBoxUIStroke.Transparency = 0.9
	inputBoxUIStroke.Parent = inputBox

	local inputBoxUISizeConstraint = Instance.new("UISizeConstraint")
	inputBoxUISizeConstraint.Name = "InputBoxUISizeConstraint"
	inputBoxUISizeConstraint.Parent = inputBox

	local inputBoxUIPadding = Instance.new("UIPadding")
	inputBoxUIPadding.Name = "InputBoxUIPadding"
	inputBoxUIPadding.PaddingLeft = UDim.new(0, 8)
	inputBoxUIPadding.PaddingRight = UDim.new(0, 10)
	inputBoxUIPadding.Parent = inputBox

	inputBox.Parent = red

	red.Parent = inputs

	local green = Instance.new("Frame")
	green.Name = "Green"
	green.AutomaticSize = Enum.AutomaticSize.XY
	green.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	green.BackgroundTransparency = 1
	green.BorderColor3 = Color3.fromRGB(0, 0, 0)
	green.BorderSizePixel = 0
	green.LayoutOrder = 2
	green.Size = UDim2.fromOffset(0, 38)

	local inputName1 = Instance.new("TextLabel")
	inputName1.Name = "InputName"
	inputName1.FontFace = Font.new(assets.interFont)
	inputName1.Text = "Green"
	theme.Set(inputName1, "TextColor3", "Text")
	inputName1.TextSize = 13
	inputName1.TextTransparency = 0.5
	inputName1.TextTruncate = Enum.TextTruncate.AtEnd
	inputName1.TextXAlignment = Enum.TextXAlignment.Left
	inputName1.TextYAlignment = Enum.TextYAlignment.Top
	inputName1.AnchorPoint = Vector2.new(0, 0.5)
	inputName1.AutomaticSize = Enum.AutomaticSize.XY
	inputName1.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	inputName1.BackgroundTransparency = 1
	inputName1.BorderColor3 = Color3.fromRGB(0, 0, 0)
	inputName1.BorderSizePixel = 0
	inputName1.LayoutOrder = 2
	inputName1.Position = UDim2.fromScale(0, 0.5)
	inputName1.Parent = green

	local uIListLayout4 = Instance.new("UIListLayout")
	uIListLayout4.Name = "UIListLayout"
	uIListLayout4.Padding = UDim.new(0, 15)
	uIListLayout4.FillDirection = Enum.FillDirection.Horizontal
	uIListLayout4.SortOrder = Enum.SortOrder.LayoutOrder
	uIListLayout4.VerticalAlignment = Enum.VerticalAlignment.Center
	uIListLayout4.Parent = green

	local inputBox1 = Instance.new("TextBox")
	inputBox1.Name = "InputBox"
	inputBox1.ClearTextOnFocus = false
	inputBox1.FontFace = Font.new(assets.interFont)
	inputBox1.Text = "255"
	theme.Set(inputBox1, "TextColor3", "Text")
	inputBox1.TextSize = 12
	inputBox1.TextTransparency = 0.1
	inputBox1.TextXAlignment = Enum.TextXAlignment.Left
	inputBox1.AnchorPoint = Vector2.new(1, 0.5)
	inputBox1.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	inputBox1.BackgroundTransparency = 0.95
	inputBox1.BorderColor3 = Color3.fromRGB(0, 0, 0)
	inputBox1.BorderSizePixel = 0
	inputBox1.ClipsDescendants = true
	inputBox1.LayoutOrder = 1
	inputBox1.Position = UDim2.fromScale(1, 0.5)
	inputBox1.Size = UDim2.fromOffset(75, 25)

	local inputBoxUICorner1 = Instance.new("UICorner")
	inputBoxUICorner1.Name = "InputBoxUICorner"
	inputBoxUICorner1.CornerRadius = UDim.new(0, 4)
	inputBoxUICorner1.Parent = inputBox1

	local inputBoxUIStroke1 = Instance.new("UIStroke")
	inputBoxUIStroke1.Name = "InputBoxUIStroke"
	inputBoxUIStroke1.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	theme.Set(inputBoxUIStroke1, "Color", "Outline")
	inputBoxUIStroke1.Transparency = 0.9
	inputBoxUIStroke1.Parent = inputBox1

	local inputBoxUISizeConstraint1 = Instance.new("UISizeConstraint")
	inputBoxUISizeConstraint1.Name = "InputBoxUISizeConstraint"
	inputBoxUISizeConstraint1.Parent = inputBox1

	local inputBoxUIPadding1 = Instance.new("UIPadding")
	inputBoxUIPadding1.Name = "InputBoxUIPadding"
	inputBoxUIPadding1.PaddingLeft = UDim.new(0, 8)
	inputBoxUIPadding1.PaddingRight = UDim.new(0, 10)
	inputBoxUIPadding1.Parent = inputBox1

	inputBox1.Parent = green

	green.Parent = inputs

	local blue = Instance.new("Frame")
	blue.Name = "Blue"
	blue.AutomaticSize = Enum.AutomaticSize.XY
	blue.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	blue.BackgroundTransparency = 1
	blue.BorderColor3 = Color3.fromRGB(0, 0, 0)
	blue.BorderSizePixel = 0
	blue.LayoutOrder = 3
	blue.Size = UDim2.fromOffset(0, 38)

	local inputName2 = Instance.new("TextLabel")
	inputName2.Name = "InputName"
	inputName2.FontFace = Font.new(assets.interFont)
	inputName2.Text = "Blue"
	theme.Set(inputName2, "TextColor3", "Text")
	inputName2.TextSize = 13
	inputName2.TextTransparency = 0.5
	inputName2.TextTruncate = Enum.TextTruncate.AtEnd
	inputName2.TextXAlignment = Enum.TextXAlignment.Left
	inputName2.TextYAlignment = Enum.TextYAlignment.Top
	inputName2.AnchorPoint = Vector2.new(0, 0.5)
	inputName2.AutomaticSize = Enum.AutomaticSize.XY
	inputName2.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	inputName2.BackgroundTransparency = 1
	inputName2.BorderColor3 = Color3.fromRGB(0, 0, 0)
	inputName2.BorderSizePixel = 0
	inputName2.LayoutOrder = 2
	inputName2.Position = UDim2.fromScale(0, 0.5)
	inputName2.Parent = blue

	local uIListLayout5 = Instance.new("UIListLayout")
	uIListLayout5.Name = "UIListLayout"
	uIListLayout5.Padding = UDim.new(0, 15)
	uIListLayout5.FillDirection = Enum.FillDirection.Horizontal
	uIListLayout5.SortOrder = Enum.SortOrder.LayoutOrder
	uIListLayout5.VerticalAlignment = Enum.VerticalAlignment.Center
	uIListLayout5.Parent = blue

	local inputBox2 = Instance.new("TextBox")
	inputBox2.Name = "InputBox"
	inputBox2.ClearTextOnFocus = false
	inputBox2.FontFace = Font.new(assets.interFont)
	inputBox2.Text = "255"
	theme.Set(inputBox2, "TextColor3", "Text")
	inputBox2.TextSize = 12
	inputBox2.TextTransparency = 0.1
	inputBox2.TextXAlignment = Enum.TextXAlignment.Left
	inputBox2.AnchorPoint = Vector2.new(1, 0.5)
	inputBox2.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	inputBox2.BackgroundTransparency = 0.95
	inputBox2.BorderColor3 = Color3.fromRGB(0, 0, 0)
	inputBox2.BorderSizePixel = 0
	inputBox2.ClipsDescendants = true
	inputBox2.LayoutOrder = 1
	inputBox2.Position = UDim2.fromScale(1, 0.5)
	inputBox2.Size = UDim2.fromOffset(75, 25)

	local inputBoxUICorner2 = Instance.new("UICorner")
	inputBoxUICorner2.Name = "InputBoxUICorner"
	inputBoxUICorner2.CornerRadius = UDim.new(0, 4)
	inputBoxUICorner2.Parent = inputBox2

	local inputBoxUIStroke2 = Instance.new("UIStroke")
	inputBoxUIStroke2.Name = "InputBoxUIStroke"
	inputBoxUIStroke2.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	theme.Set(inputBoxUIStroke2, "Color", "Outline")
	inputBoxUIStroke2.Transparency = 0.9
	inputBoxUIStroke2.Parent = inputBox2

	local inputBoxUISizeConstraint2 = Instance.new("UISizeConstraint")
	inputBoxUISizeConstraint2.Name = "InputBoxUISizeConstraint"
	inputBoxUISizeConstraint2.Parent = inputBox2

	local inputBoxUIPadding2 = Instance.new("UIPadding")
	inputBoxUIPadding2.Name = "InputBoxUIPadding"
	inputBoxUIPadding2.PaddingLeft = UDim.new(0, 8)
	inputBoxUIPadding2.PaddingRight = UDim.new(0, 10)
	inputBoxUIPadding2.Parent = inputBox2

	inputBox2.Parent = blue

	blue.Parent = inputs

	local alpha = Instance.new("Frame")
	alpha.Name = "Alpha"
	alpha.AutomaticSize = Enum.AutomaticSize.XY
	alpha.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	alpha.BackgroundTransparency = 1
	alpha.BorderColor3 = Color3.fromRGB(0, 0, 0)
	alpha.BorderSizePixel = 0
	alpha.LayoutOrder = 4
	alpha.Size = UDim2.fromOffset(0, 38)
	alpha.Visible = isAlpha

	local inputName3 = Instance.new("TextLabel")
	inputName3.Name = "InputName"
	inputName3.FontFace = Font.new(assets.interFont)
	inputName3.Text = "Alpha"
	theme.Set(inputName3, "TextColor3", "Text")
	inputName3.TextSize = 13
	inputName3.TextTransparency = 0.5
	inputName3.TextTruncate = Enum.TextTruncate.AtEnd
	inputName3.TextXAlignment = Enum.TextXAlignment.Left
	inputName3.TextYAlignment = Enum.TextYAlignment.Top
	inputName3.AnchorPoint = Vector2.new(0, 0.5)
	inputName3.AutomaticSize = Enum.AutomaticSize.XY
	inputName3.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	inputName3.BackgroundTransparency = 1
	inputName3.BorderColor3 = Color3.fromRGB(0, 0, 0)
	inputName3.BorderSizePixel = 0
	inputName3.LayoutOrder = 2
	inputName3.Position = UDim2.fromScale(0, 0.5)
	inputName3.Parent = alpha

	local uIListLayout6 = Instance.new("UIListLayout")
	uIListLayout6.Name = "UIListLayout"
	uIListLayout6.Padding = UDim.new(0, 15)
	uIListLayout6.FillDirection = Enum.FillDirection.Horizontal
	uIListLayout6.SortOrder = Enum.SortOrder.LayoutOrder
	uIListLayout6.VerticalAlignment = Enum.VerticalAlignment.Center
	uIListLayout6.Parent = alpha

	local inputBox3 = Instance.new("TextBox")
	inputBox3.Name = "InputBox"
	inputBox3.ClearTextOnFocus = false
	inputBox3.FontFace = Font.new(assets.interFont)
	inputBox3.Text = "0"
	theme.Set(inputBox3, "TextColor3", "Text")
	inputBox3.TextSize = 12
	inputBox3.TextTransparency = 0.1
	inputBox3.TextXAlignment = Enum.TextXAlignment.Left
	inputBox3.AnchorPoint = Vector2.new(1, 0.5)
	inputBox3.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	inputBox3.BackgroundTransparency = 0.95
	inputBox3.BorderColor3 = Color3.fromRGB(0, 0, 0)
	inputBox3.BorderSizePixel = 0
	inputBox3.ClipsDescendants = true
	inputBox3.LayoutOrder = 1
	inputBox3.Position = UDim2.fromScale(1, 0.5)
	inputBox3.Size = UDim2.fromOffset(75, 25)

	local inputBoxUICorner3 = Instance.new("UICorner")
	inputBoxUICorner3.Name = "InputBoxUICorner"
	inputBoxUICorner3.CornerRadius = UDim.new(0, 4)
	inputBoxUICorner3.Parent = inputBox3

	local inputBoxUIStroke3 = Instance.new("UIStroke")
	inputBoxUIStroke3.Name = "InputBoxUIStroke"
	inputBoxUIStroke3.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	theme.Set(inputBoxUIStroke3, "Color", "Outline")
	inputBoxUIStroke3.Transparency = 0.9
	inputBoxUIStroke3.Parent = inputBox3

	local inputBoxUISizeConstraint3 = Instance.new("UISizeConstraint")
	inputBoxUISizeConstraint3.Name = "InputBoxUISizeConstraint"
	inputBoxUISizeConstraint3.Parent = inputBox3

	local inputBoxUIPadding3 = Instance.new("UIPadding")
	inputBoxUIPadding3.Name = "InputBoxUIPadding"
	inputBoxUIPadding3.PaddingLeft = UDim.new(0, 8)
	inputBoxUIPadding3.PaddingRight = UDim.new(0, 10)
	inputBoxUIPadding3.Parent = inputBox3

	inputBox3.Parent = alpha

	alpha.Parent = inputs

	local hex = Instance.new("Frame")
	hex.Name = "Hex"
	hex.AutomaticSize = Enum.AutomaticSize.XY
	hex.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	hex.BackgroundTransparency = 1
	hex.BorderColor3 = Color3.fromRGB(0, 0, 0)
	hex.BorderSizePixel = 0
	hex.Size = UDim2.fromOffset(0, 38)

	local inputName4 = Instance.new("TextLabel")
	inputName4.Name = "InputName"
	inputName4.FontFace = Font.new(assets.interFont)
	inputName4.Text = "Hex"
	theme.Set(inputName4, "TextColor3", "Text")
	inputName4.TextSize = 13
	inputName4.TextTransparency = 0.5
	inputName4.TextTruncate = Enum.TextTruncate.AtEnd
	inputName4.TextXAlignment = Enum.TextXAlignment.Left
	inputName4.TextYAlignment = Enum.TextYAlignment.Top
	inputName4.AnchorPoint = Vector2.new(0, 0.5)
	inputName4.AutomaticSize = Enum.AutomaticSize.XY
	inputName4.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	inputName4.BackgroundTransparency = 1
	inputName4.BorderColor3 = Color3.fromRGB(0, 0, 0)
	inputName4.BorderSizePixel = 0
	inputName4.LayoutOrder = 2
	inputName4.Position = UDim2.fromScale(0, 0.5)
	inputName4.Parent = hex

	local uIListLayout7 = Instance.new("UIListLayout")
	uIListLayout7.Name = "UIListLayout"
	uIListLayout7.Padding = UDim.new(0, 15)
	uIListLayout7.FillDirection = Enum.FillDirection.Horizontal
	uIListLayout7.SortOrder = Enum.SortOrder.LayoutOrder
	uIListLayout7.VerticalAlignment = Enum.VerticalAlignment.Center
	uIListLayout7.Parent = hex

	local inputBox4 = Instance.new("TextBox")
	inputBox4.Name = "InputBox"
	inputBox4.ClearTextOnFocus = false
	inputBox4.CursorPosition = -1
	inputBox4.FontFace = Font.new(assets.interFont)
	inputBox4.Text = "255"
	theme.Set(inputBox4, "TextColor3", "Text")
	inputBox4.TextSize = 12
	inputBox4.TextTransparency = 0.1
	inputBox4.TextXAlignment = Enum.TextXAlignment.Left
	inputBox4.AnchorPoint = Vector2.new(1, 0.5)
	inputBox4.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	inputBox4.BackgroundTransparency = 0.95
	inputBox4.BorderColor3 = Color3.fromRGB(0, 0, 0)
	inputBox4.BorderSizePixel = 0
	inputBox4.ClipsDescendants = true
	inputBox4.LayoutOrder = 1
	inputBox4.Position = UDim2.fromScale(1, 0.5)
	inputBox4.Size = UDim2.fromOffset(75, 25)

	local inputBoxUICorner4 = Instance.new("UICorner")
	inputBoxUICorner4.Name = "InputBoxUICorner"
	inputBoxUICorner4.CornerRadius = UDim.new(0, 4)
	inputBoxUICorner4.Parent = inputBox4

	local inputBoxUIStroke4 = Instance.new("UIStroke")
	inputBoxUIStroke4.Name = "InputBoxUIStroke"
	inputBoxUIStroke4.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	theme.Set(inputBoxUIStroke4, "Color", "Outline")
	inputBoxUIStroke4.Transparency = 0.9
	inputBoxUIStroke4.Parent = inputBox4

	local inputBoxUISizeConstraint4 = Instance.new("UISizeConstraint")
	inputBoxUISizeConstraint4.Name = "InputBoxUISizeConstraint"
	inputBoxUISizeConstraint4.Parent = inputBox4

	local inputBoxUIPadding4 = Instance.new("UIPadding")
	inputBoxUIPadding4.Name = "InputBoxUIPadding"
	inputBoxUIPadding4.PaddingLeft = UDim.new(0, 8)
	inputBoxUIPadding4.PaddingRight = UDim.new(0, 10)
	inputBoxUIPadding4.Parent = inputBox4

	inputBox4.Parent = hex

	hex.Parent = inputs

	inputs.Parent = wheel

	local uIPadding = Instance.new("UIPadding")
	uIPadding.Name = "UIPadding"
	uIPadding.PaddingRight = UDim.new(0, 5)
	uIPadding.Parent = wheel

	wheel.Parent = colorOptions

	local colorWells = Instance.new("Frame")
	colorWells.Name = "ColorWells"
	colorWells.AutomaticSize = Enum.AutomaticSize.Y
	colorWells.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	colorWells.BackgroundTransparency = 1
	colorWells.BorderColor3 = Color3.fromRGB(0, 0, 0)
	colorWells.BorderSizePixel = 0
	colorWells.LayoutOrder = 2
	colorWells.Size = UDim2.fromScale(1, 0)

	local uIGridLayout = Instance.new("UIGridLayout")
	uIGridLayout.Name = "UIGridLayout"
	uIGridLayout.CellPadding = UDim2.fromOffset(10, 0)
	uIGridLayout.CellSize = UDim2.new(0.5, -5, 0, 30)
	uIGridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	uIGridLayout.Parent = colorWells

	local newColor = Instance.new("ImageLabel")
	newColor.Name = "NewColor"
	newColor.Image = assets.grid
	newColor.ScaleType = Enum.ScaleType.Tile
	newColor.TileSize = UDim2.fromOffset(500, 500)
	newColor.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	newColor.BackgroundTransparency = 1
	newColor.BorderColor3 = Color3.fromRGB(0, 0, 0)
	newColor.BorderSizePixel = 0
	newColor.Size = UDim2.fromOffset(100, 100)

	local uICorner2 = Instance.new("UICorner")
	uICorner2.Name = "UICorner"
	uICorner2.Parent = newColor

	local color = Instance.new("Frame")
	color.Name = "Color"
	color.AnchorPoint = Vector2.new(0.5, 0.5)
	theme.Set(color, "BorderColor3", "Border")
	color.BorderSizePixel = 0
	color.Position = UDim2.fromScale(0.5, 0.5)
	color.Size = UDim2.new(1, 1, 1, 1)

	local uICorner3 = Instance.new("UICorner")
	uICorner3.Name = "UICorner"
	uICorner3.Parent = color

	color.Parent = newColor

	newColor.Parent = colorWells

	local oldColor = Instance.new("ImageLabel")
	oldColor.Name = "OldColor"
	oldColor.Image = assets.grid
	oldColor.ScaleType = Enum.ScaleType.Tile
	oldColor.TileSize = UDim2.fromOffset(500, 500)
	oldColor.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	oldColor.BackgroundTransparency = 1
	oldColor.BorderColor3 = Color3.fromRGB(0, 0, 0)
	oldColor.BorderSizePixel = 0
	oldColor.LayoutOrder = 1
	oldColor.Size = UDim2.fromOffset(100, 100)

	local uICorner4 = Instance.new("UICorner")
	uICorner4.Name = "UICorner"
	uICorner4.Parent = oldColor

	local color1 = Instance.new("Frame")
	color1.Name = "Color"
	color1.AnchorPoint = Vector2.new(0.5, 0.5)
	theme.Set(color1, "BorderColor3", "Border")
	color1.BorderSizePixel = 0
	color1.Position = UDim2.fromScale(0.5, 0.5)
	color1.Size = UDim2.new(1, 1, 1, 1)

	local uICorner5 = Instance.new("UICorner")
	uICorner5.Name = "UICorner"
	uICorner5.Parent = color1

	color1.Parent = oldColor

	oldColor.Parent = colorWells

	colorWells.Parent = colorOptions

	colorOptions.Parent = prompt

	local interactions = Instance.new("Frame")
	interactions.Name = "Interactions"
	interactions.AutomaticSize = Enum.AutomaticSize.Y
	interactions.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	interactions.BackgroundTransparency = 1
	interactions.BorderColor3 = Color3.fromRGB(0, 0, 0)
	interactions.BorderSizePixel = 0
	interactions.LayoutOrder = 2
	interactions.Size = UDim2.fromScale(1, 0)

	local uIListLayout8 = Instance.new("UIListLayout")
	uIListLayout8.Name = "UIListLayout"
	uIListLayout8.Padding = UDim.new(0, 10)
	uIListLayout8.SortOrder = Enum.SortOrder.LayoutOrder
	uIListLayout8.Parent = interactions

	local confirm = Instance.new("TextButton")
	confirm.Name = "Confirm"
	confirm.FontFace = Font.new(
		"rbxassetid://12187365364",
		Enum.FontWeight.Medium,
		Enum.FontStyle.Normal
	)
	confirm.Text = "Confirm"
	theme.Set(confirm, "TextColor3", "Text")
	confirm.TextSize = 15
	confirm.TextTransparency = 0.5
	confirm.TextTruncate = Enum.TextTruncate.AtEnd
	confirm.AutoButtonColor = false
	confirm.AutomaticSize = Enum.AutomaticSize.Y
	theme.Set(confirm, "BackgroundColor3", "Surface")
	confirm.BorderColor3 = Color3.fromRGB(0, 0, 0)
	confirm.BorderSizePixel = 0
	confirm.Size = UDim2.fromScale(1, 0)

	local uIPadding1 = Instance.new("UIPadding")
	uIPadding1.Name = "UIPadding"
	uIPadding1.PaddingBottom = UDim.new(0, 9)
	uIPadding1.PaddingLeft = UDim.new(0, 10)
	uIPadding1.PaddingRight = UDim.new(0, 10)
	uIPadding1.PaddingTop = UDim.new(0, 9)
	uIPadding1.Parent = confirm

	local baseUICorner = Instance.new("UICorner")
	baseUICorner.Name = "BaseUICorner"
	baseUICorner.CornerRadius = UDim.new(0, 10)
	baseUICorner.Parent = confirm

	confirm.Parent = interactions

	local cancel = Instance.new("TextButton")
	cancel.Name = "Cancel"
	cancel.FontFace = Font.new(
		"rbxassetid://12187365364",
		Enum.FontWeight.Medium,
		Enum.FontStyle.Normal
	)
	cancel.Text = "Cancel"
	theme.Set(cancel, "TextColor3", "Text")
	cancel.TextSize = 15
	cancel.TextTransparency = 0.5
	cancel.TextTruncate = Enum.TextTruncate.AtEnd
	cancel.AutoButtonColor = false
	cancel.AutomaticSize = Enum.AutomaticSize.Y
	theme.Set(cancel, "BackgroundColor3", "Surface")
	cancel.BorderColor3 = Color3.fromRGB(0, 0, 0)
	cancel.BorderSizePixel = 0
	cancel.Size = UDim2.fromScale(1, 0)

	local baseUICorner1 = Instance.new("UICorner")
	baseUICorner1.Name = "BaseUICorner"
	baseUICorner1.CornerRadius = UDim.new(0, 10)
	baseUICorner1.Parent = cancel

	local uIPadding2 = Instance.new("UIPadding")
	uIPadding2.Name = "UIPadding"
	uIPadding2.PaddingBottom = UDim.new(0, 9)
	uIPadding2.PaddingLeft = UDim.new(0, 10)
	uIPadding2.PaddingRight = UDim.new(0, 10)
	uIPadding2.PaddingTop = UDim.new(0, 9)
	uIPadding2.Parent = cancel

	cancel.Parent = interactions

	local uIPadding3 = Instance.new("UIPadding")
	uIPadding3.Name = "UIPadding"
	uIPadding3.PaddingTop = UDim.new(0, 10)
	uIPadding3.Parent = interactions

	interactions.Parent = prompt

	local globalSettingsUIPadding = Instance.new("UIPadding")
	globalSettingsUIPadding.Name = "GlobalSettingsUIPadding"
	globalSettingsUIPadding.PaddingBottom = UDim.new(0, 20)
	globalSettingsUIPadding.PaddingLeft = UDim.new(0, 20)
	globalSettingsUIPadding.PaddingRight = UDim.new(0, 20)
	globalSettingsUIPadding.PaddingTop = UDim.new(0, 20)
	globalSettingsUIPadding.Parent = prompt

	local paragraph = Instance.new("Frame")
	paragraph.Name = "Paragraph"
	paragraph.AutomaticSize = Enum.AutomaticSize.Y
	paragraph.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	paragraph.BackgroundTransparency = 1
	paragraph.BorderColor3 = Color3.fromRGB(0, 0, 0)
	paragraph.BorderSizePixel = 0
	paragraph.Size = UDim2.fromScale(1, 0)

	local paragraphHeader = Instance.new("TextLabel")
	paragraphHeader.Name = "ParagraphHeader"
	paragraphHeader.FontFace = Font.new(
		"rbxassetid://12187365364",
		Enum.FontWeight.SemiBold,
		Enum.FontStyle.Normal
	)
	paragraphHeader.RichText = true
	paragraphHeader.Text = options.name
	theme.Set(paragraphHeader, "TextColor3", "Text")
	paragraphHeader.TextSize = 18
	paragraphHeader.TextTransparency = 0.4
	paragraphHeader.TextWrapped = true
	paragraphHeader.TextYAlignment = Enum.TextYAlignment.Top
	paragraphHeader.AutomaticSize = Enum.AutomaticSize.XY
	paragraphHeader.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	paragraphHeader.BackgroundTransparency = 1
	paragraphHeader.BorderColor3 = Color3.fromRGB(0, 0, 0)
	paragraphHeader.BorderSizePixel = 0
	paragraphHeader.Size = UDim2.fromScale(1, 0)
	paragraphHeader.Parent = paragraph

	local uIListLayout9 = Instance.new("UIListLayout")
	uIListLayout9.Name = "UIListLayout"
	uIListLayout9.Padding = UDim.new(0, 15)
	uIListLayout9.HorizontalAlignment = Enum.HorizontalAlignment.Center
	uIListLayout9.SortOrder = Enum.SortOrder.LayoutOrder
	uIListLayout9.Parent = paragraph

	local uIPadding4 = Instance.new("UIPadding")
	uIPadding4.Name = "UIPadding"
	uIPadding4.PaddingBottom = UDim.new(0, 15)
	uIPadding4.Parent = paragraph

	local line = Instance.new("Frame")
	line.Name = "Line"
	theme.Set(line, "BackgroundColor3", "Outline")
	line.BackgroundTransparency = 0.9
	line.BorderColor3 = Color3.fromRGB(0, 0, 0)
	line.BorderSizePixel = 0
	line.LayoutOrder = 1
	line.Size = UDim2.new(1, 0, 0, 1)
	line.Parent = paragraph

	paragraph.Parent = prompt

	prompt.Parent = colorPicker

	colorPicker.Parent = base

	local fromHSV, fromRGB, v2, udim2 = Color3.fromHSV, Color3.fromRGB, Vector2.new, UDim2.new

	local ring = target
	local slider = value
	local colour = color

	local modifierInputs = {
		Hex = hex.InputBox,
		Red = red.InputBox,
		Green = green.InputBox,
		Blue = blue.InputBox,
		Alpha = alpha.InputBox
	}

	local Mouse = LocalPlayer:GetMouse()

	local WheelDown, SlideDown = false, false
	local hue, saturation, valueBrightness = 0, 0, 1

	local function toPolar(v)
		return math.atan2(v.y, v.x), v.magnitude
	end

	local function radToDeg(x)
		return ((x + math.pi) / (2 * math.pi)) * 360
	end

	local function degToRad(degrees)
		return degrees * (math.pi / 180)
	end

	local function hexToRGB(hex)
		hex = hex:gsub("#","")
		if #hex ~= 6 then return 0, 0, 0 end
		local r = tonumber(hex:sub(1, 2), 16) or 0
		local g = tonumber(hex:sub(3, 4), 16) or 0
		local b = tonumber(hex:sub(5, 6), 16) or 0
		return r, g, b
	end

	local function clampInput(input, min, max)
		local num = tonumber(input)
		if num then
			return math.clamp(num, min, max)
		end
		return min
	end

	local function update()
		local c = fromHSV(hue, saturation, valueBrightness)
		colour.BackgroundColor3 = c
		colour.BackgroundTransparency = clampInput(modifierInputs.Alpha.Text, 0, 1)

		modifierInputs.Red.Text = tostring(math.floor(c.r * 255 + 0.5))
		modifierInputs.Green.Text = tostring(math.floor(c.g * 255 + 0.5))
		modifierInputs.Blue.Text = tostring(math.floor(c.b * 255 + 0.5))
		modifierInputs.Alpha.Text = clampInput(modifierInputs.Alpha.Text, 0, 1)

		local hexColor = string.format("#%02X%02X%02X",
			math.floor(c.r * 255 + 0.5),
			math.floor(c.g * 255 + 0.5),
			math.floor(c.b * 255 + 0.5))
		modifierInputs.Hex.Text = hexColor
	end

	local function UpdateSlide(iX)
		local rY = iX - slider.AbsolutePosition.X
		local cY = math.clamp(rY, 0, slider.AbsoluteSize.X - slide.AbsoluteSize.X)
		slide.Position = udim2(0, cY, 0.5, 0)
		valueBrightness = 1 - (cY / (slider.AbsoluteSize.X - slide.AbsoluteSize.X))
		update()
	end

	local function UpdateRing(iX, iY)
		local r = wheel1.AbsoluteSize.x / 2
		local d = v2(iX, iY) - wheel1.AbsolutePosition - wheel1.AbsoluteSize / 2

		if d:Dot(d) > r * r then
			d = d.unit * r
		end

		ring.Position = udim2(0.5, d.x, 0.5, d.y)
		local phi, len = toPolar(d * v2(1, -1))
		hue, saturation = radToDeg(phi) / 360, math.clamp(len / r, 0, 1)
		slider.BackgroundColor3 = fromHSV(hue, saturation, 1)
		update()
	end

	local function UpdateSlideFromValue(brightness)
		local cY = (1 - brightness) * (slider.AbsoluteSize.X - slide.AbsoluteSize.X)
		slide.Position = UDim2.new(0, cY, 0.5, 0)
	end

	local function UpdateRingFromHSV(hueValue, saturationValue)
		local r = wheel1.AbsoluteSize.X / 2
		local phi = degToRad(hueValue * 360)
		local len = saturationValue * r
		local x = len * math.cos(phi)
		local y = len * math.sin(phi)

		ring.Position = UDim2.new(0.5, -x, 0.5, y)
		slider.BackgroundColor3 = fromHSV(hueValue, saturationValue, 1)
	end

	local function updateFromRGB()
		local r = clampInput(modifierInputs.Red.Text, 0, 255)
		local g = clampInput(modifierInputs.Green.Text, 0, 255)
		local b = clampInput(modifierInputs.Blue.Text, 0, 255)
		modifierInputs.Red.Text = r
		modifierInputs.Green.Text = g
		modifierInputs.Blue.Text = b

		hue, saturation, valueBrightness = fromRGB(r, g, b):ToHSV()

		UpdateSlideFromValue(valueBrightness)
		UpdateRingFromHSV(hue, saturation)
		update()
	end

	local function updateFromHex()
		local hexValue = modifierInputs.Hex.Text
		local r, g, b = hexToRGB(hexValue)

		r = clampInput(r, 0, 255)
		g = clampInput(g, 0, 255)
		b = clampInput(b, 0, 255)

		modifierInputs.Red.Text = r
		modifierInputs.Green.Text = g
		modifierInputs.Blue.Text = b

		hue, saturation, valueBrightness = fromRGB(r, g, b):ToHSV()
		UpdateSlideFromValue(valueBrightness)
		UpdateRingFromHSV(hue, saturation)
		update()
	end

	local function updateFromSettings()
		local r = math.floor(CurrentColor.R * 255 + 0.5)
		local g = math.floor(CurrentColor.G * 255 + 0.5)
		local b = math.floor(CurrentColor.B * 255 + 0.5)
		modifierInputs.Red.Text = r
		modifierInputs.Green.Text = g
		modifierInputs.Blue.Text = b
		modifierInputs.Alpha.Text = isAlpha and CurrentAlpha or 0

		local hexColor = string.format("#%02X%02X%02X", r,g,b)
		modifierInputs.Hex.Text = hexColor

		hue, saturation, valueBrightness = fromRGB(r, g, b):ToHSV()

		color1.BackgroundColor3 = CurrentColor
		color1.BackgroundTransparency = isAlpha and CurrentAlpha or 0

		colour.BackgroundColor3 = fromRGB(r,g,b)
		colour.BackgroundTransparency = isAlpha and CurrentAlpha or 0

		UpdateSlideFromValue(valueBrightness)
		UpdateRingFromHSV(hue, saturation)
	end

	wheel1.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			WheelDown = true
			UpdateRing(Mouse.X, Mouse.Y)
		end
	end)

	slider.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			SlideDown = true
			UpdateSlide(Mouse.X)
		end
	end)

	slider.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			SlideDown = false
		end
	end)

	wheel1.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			WheelDown = false
		end
	end)

	local inputConnection = UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			if SlideDown then
				UpdateSlide(Mouse.X)
			elseif WheelDown then
				UpdateRing(Mouse.X, Mouse.Y)
			end
		end
	end)

	local function onFocusEnter(instance)
		local placeholder = instance.Text
		instance.Text = ""
		instance.PlaceholderText = placeholder
	end

	modifierInputs.Hex.FocusLost:Connect(updateFromHex)
	modifierInputs.Red.FocusLost:Connect(updateFromRGB)
	modifierInputs.Green.FocusLost:Connect(updateFromRGB)
	modifierInputs.Blue.FocusLost:Connect(updateFromRGB)
	modifierInputs.Alpha.FocusLost:Connect(update)

	modifierInputs.Hex.Focused:Connect(function()
		onFocusEnter(modifierInputs.Hex)
	end)
	modifierInputs.Red.Focused:Connect(function()
		onFocusEnter(modifierInputs.Red)
	end)
	modifierInputs.Green.Focused:Connect(function()
		onFocusEnter(modifierInputs.Green)
	end)
	modifierInputs.Blue.Focused:Connect(function()
		onFocusEnter(modifierInputs.Blue)
	end)
	modifierInputs.Alpha.Focused:Connect(function()
		onFocusEnter(modifierInputs.Alpha)
	end)

	local function makeCanvas()
		local ColorPickerCanvas = Instance.new("CanvasGroup")
		ColorPickerCanvas.Name = "ColorPickerCanvas"
		ColorPickerCanvas.BackgroundTransparency = 1
		ColorPickerCanvas.BorderSizePixel = 0
		ColorPickerCanvas.Size = UDim2.fromScale(1, 1)
		ColorPickerCanvas.ZIndex = 5
		ColorPickerCanvas.GroupTransparency = 1
		ColorPickerCanvas.Parent = base
		ColorPickerCanvas.Visible = false
		return ColorPickerCanvas
	end

	local function transition(isIn)
		local canvas = makeCanvas()
		local tweenTransparency = isIn and 0 or 1
		local tweenScale = isIn and 1 or 0.95
		local stateTransparency = isIn and 1 or 0
		local tweenInfo = TweenInfo.new(0.1, Enum.EasingStyle.Sine)
		local canvasTween = Tween(canvas, tweenInfo, { GroupTransparency = tweenTransparency })
		local scaleTween = Tween(promptUIScale, tweenInfo, { Scale = tweenScale })

		colorPicker.Visible = true
		colorPicker.Parent = canvas
		canvas.Visible = true
		canvas.GroupTransparency = stateTransparency
		canvasTween:Play()
		scaleTween:Play()
		canvasTween.Completed:Wait()

		if not isIn then
			colorPicker.Visible = false
			canvas.Visible = false
		end

		colorPicker.Parent = base
		canvas:Destroy()
	end

	local function colorpickerIn()
		transition(true)
	end

	local function colorpickerOut()
		transition(false)
	end

	cancel.MouseButton1Click:Connect(colorpickerOut)
	confirm.MouseButton1Click:Connect(function()
		colorpickerOut()
		local c = fromHSV(hue, saturation, valueBrightness)
		CurrentColor = Color3.fromRGB(c.r * 255, c.g * 255, c.b * 255)
		CurrentAlpha = isAlpha and clampInput(modifierInputs.Alpha.Text, 0, 1) or 0

		color1.BackgroundColor3 = CurrentColor
		color1.BackgroundTransparency = isAlpha and CurrentAlpha or 0

		if options.onConfirm then
			options.onConfirm(CurrentColor, CurrentAlpha)
		end
	end)

	updateFromSettings()

	local Body = {
		Frame = colorPicker,
		Prompt = prompt,
	}

	function Body:Open()
		colorpickerIn()
	end

	function Body:Close()
		colorpickerOut()
	end

	function Body:GetColor()
		return CurrentColor
	end

	function Body:GetAlpha()
		return CurrentAlpha
	end

	function Body:SetColor(newColor)
		CurrentColor = newColor
		updateFromSettings()
	end

	function Body:SetAlpha(newAlpha)
		CurrentAlpha = newAlpha
		updateFromSettings()
	end

	function Body:Destroy()
		inputConnection:Disconnect()
		colorPicker:Destroy()
	end

	return Body
end
end function __DARKLUA_BUNDLE_MODULES.p():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.p if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.p=v end return v.c end end do local function __modImpl()
local core = __DARKLUA_BUNDLE_MODULES.c()
local createColorPickerBody = __DARKLUA_BUNDLE_MODULES.p()
local cleanup = __DARKLUA_BUNDLE_MODULES.n()

local FractUI = core.FractUI
local assets = core.assets

--// Inline color picker: a small swatch on the right edge of a widget that opens
--// the shared HSV/alpha popover.
--// options: { parent, position, width, height, settings, env, flag, onRelease }
return function(options)
	local settings = options.settings or {}
	local ColorPickerFunctions = { Settings = settings, IgnoreConfig = false, Class = "ColorPicker" }

	local isAlpha = settings.Alpha ~= nil
	local color = settings.Default or Color3.fromRGB(255, 255, 255)
	local alpha = isAlpha and settings.Alpha or 0

	local swatch = Instance.new("TextButton")
	swatch.Name = "ColorSwatch"
	swatch.Text = ""
	swatch.AutoButtonColor = false
	swatch.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	swatch.BackgroundTransparency = 1
	swatch.BorderColor3 = Color3.fromRGB(0, 0, 0)
	swatch.BorderSizePixel = 0
	swatch.AnchorPoint = Vector2.new(1, 0.5)
	swatch.Position = options.position
	swatch.Size = UDim2.fromOffset(options.width, options.height)
	swatch.Parent = options.parent

	local grid = Instance.new("ImageLabel")
	grid.Name = "ColorGrid"
	grid.Image = assets.grid
	grid.ScaleType = Enum.ScaleType.Tile
	grid.TileSize = UDim2.fromOffset(500, 500)
	grid.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	grid.BackgroundTransparency = 1
	grid.BorderColor3 = Color3.fromRGB(0, 0, 0)
	grid.BorderSizePixel = 0
	grid.Size = UDim2.fromScale(1, 1)
	grid.Parent = swatch

	local gridUICorner = Instance.new("UICorner")
	gridUICorner.Name = "ColorGridUICorner"
	gridUICorner.CornerRadius = UDim.new(0, 4)
	gridUICorner.Parent = grid

	local colorFrame = Instance.new("Frame")
	colorFrame.Name = "Color"
	colorFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	colorFrame.BackgroundColor3 = color
	colorFrame.BackgroundTransparency = alpha
	colorFrame.BorderColor3 = Color3.fromRGB(0, 0, 0)
	colorFrame.BorderSizePixel = 0
	colorFrame.Position = UDim2.fromScale(0.5, 0.5)
	colorFrame.Size = UDim2.fromScale(1, 1)
	colorFrame.Parent = grid

	local colorUICorner = Instance.new("UICorner")
	colorUICorner.Name = "ColorUICorner"
	colorUICorner.CornerRadius = UDim.new(0, 4)
	colorUICorner.Parent = colorFrame

	local body = createColorPickerBody({
		base = options.env.base,
		name = settings.Name or "Colorpicker",
		alpha = isAlpha,
		color = color,
		alphaValue = alpha,
		onConfirm = function(newColor, newAlpha)
			color = newColor
			alpha = isAlpha and newAlpha or 0

			colorFrame.BackgroundColor3 = newColor
			colorFrame.BackgroundTransparency = alpha

			ColorPickerFunctions.Color = newColor
			ColorPickerFunctions.Alpha = isAlpha and newAlpha or nil

			if settings.Callback then
				task.spawn(function()
					settings.Callback(newColor, isAlpha and newAlpha or nil)
				end)
			end
		end,
	})

	swatch.MouseButton1Click:Connect(function()
		body:Open()
	end)

	ColorPickerFunctions.Color = color
	ColorPickerFunctions.Alpha = isAlpha and alpha or nil

	function ColorPickerFunctions:SetColor(color3)
		color = color3
		ColorPickerFunctions.Color = color3
		colorFrame.BackgroundColor3 = color3
		body:SetColor(color3)

		if settings.Callback then
			task.spawn(function()
				settings.Callback(color3, isAlpha and ColorPickerFunctions.Alpha or nil)
			end)
		end
	end

	function ColorPickerFunctions:GetColor()
		return color
	end

	function ColorPickerFunctions:SetAlpha(value)
		alpha = value
		ColorPickerFunctions.Alpha = isAlpha and value or nil
		colorFrame.BackgroundTransparency = isAlpha and value or 0
		body:SetAlpha(value)
	end

	function ColorPickerFunctions:GetAlpha()
		return alpha
	end

	function ColorPickerFunctions:Open()
		body:Open()
	end

	function ColorPickerFunctions:Close()
		body:Close()
	end

	function ColorPickerFunctions:SetVisibility(State)
		swatch.Visible = State
	end

	function ColorPickerFunctions:SetPosition(Position)
		swatch.Position = Position
	end

	-- The swatch releases the popover it opened when it ends, no matter how it
	-- ends. The popover lives outside of the section, so it would survive
	-- otherwise.
	local release = cleanup({
		functions = ColorPickerFunctions,
		instance = swatch,
		env = options.env,
		flag = options.flag,
		release = function()
			body:Destroy()
			-- The swatch leaves the host, so the host does not keep it and
			-- its settings alive.
			if options.onRelease then
				options.onRelease()
			end
		end,
	})

	function ColorPickerFunctions:Destroy()
		release()
		swatch:Destroy()
	end

	if options.flag then
		FractUI.Options[options.flag] = ColorPickerFunctions
	end

	return ColorPickerFunctions
end
end function __DARKLUA_BUNDLE_MODULES.q():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.q if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.q=v end return v.c end end do local function __modImpl()
local createKeyPicker = __DARKLUA_BUNDLE_MODULES.o()
local createColorPicker = __DARKLUA_BUNDLE_MODULES.q()

--// Distance kept between the right edge of a widget and its inline controls.
local GAP = 9
local KEY_BADGE_WIDTH = 40
local COLOR_SWATCH_WIDTH = 21
local CONTROL_HEIGHT = 21

--// Attaches the inline key picker and color picker to a widget.
--// Host: { Functions, env, parent, rail = { Cursor, Reserved }, Resize(reserved) }
return function(Host)
	local rail = Host.rail

	local addons = Host.Functions.Addons
	if not addons then
		addons = { KeyPickers = {}, ColorPickers = {} }
		Host.Functions.Addons = addons
	end

	-- The controls of the host, in the order they were added. Every control
	-- keeps the room it needs, so a control that is gone leaves the room to
	-- the ones that are left.
	local controls = {}
	local startCursor = rail.Cursor
	local startReserved = rail.Reserved

	-- Lays the controls out from the right edge of the widget and gives the
	-- room they need to the label of the widget.
	local function layout()
		local cursor = startCursor
		local reserved = startReserved
		for _, control in ipairs(controls) do
			control.widget:SetPosition(UDim2.new(1, -cursor, 0.5, 0))
			reserved = cursor + control.width
			cursor = reserved + GAP
		end
		rail.Cursor = cursor
		rail.Reserved = reserved
		Host.Resize(reserved)
	end

	-- A control that is gone leaves the list of the host and the room it
	-- had, so the host does not keep it and its settings alive.
	local function removeControl(list, widget)
		local gone = false
		for index, existing in ipairs(list) do
			if existing == widget then
				table.remove(list, index)
				gone = true
				break
			end
		end
		for index, control in ipairs(controls) do
			if control.widget == widget then
				table.remove(controls, index)
				gone = true
				break
			end
		end
		if gone then
			layout()
		end
		return gone
	end

	Host.Functions.AddKeyPicker = function(_, Flag, Settings)
		-- The picker is named before it is made, so the release of the picker
		-- can hand it back to the host.
		local picker
		picker = createKeyPicker({
			parent = Host.parent,
			position = UDim2.new(1, -rail.Cursor, 0.5, 0),
			width = KEY_BADGE_WIDTH,
			height = CONTROL_HEIGHT,
			settings = Settings,
			host = Host.Functions,
			env = Host.env,
			flag = Flag,
			onRelease = function()
				removeControl(addons.KeyPickers, picker)
			end,
		})

		table.insert(addons.KeyPickers, picker)
		table.insert(controls, { widget = picker, width = KEY_BADGE_WIDTH })
		layout()
		return picker
	end

	Host.Functions.AddColorPicker = function(_, Flag, Settings)
		-- The swatch is named before it is made, so the release of the swatch
		-- can hand it back to the host.
		local swatch
		swatch = createColorPicker({
			parent = Host.parent,
			position = UDim2.new(1, -rail.Cursor, 0.5, 0),
			width = COLOR_SWATCH_WIDTH,
			height = CONTROL_HEIGHT,
			settings = Settings,
			env = Host.env,
			flag = Flag,
			onRelease = function()
				removeControl(addons.ColorPickers, swatch)
			end,
		})

		table.insert(addons.ColorPickers, swatch)
		table.insert(controls, { widget = swatch, width = COLOR_SWATCH_WIDTH })
		layout()
		return swatch
	end

	-- Releases the inline controls of the host widget.
	Host.Functions.DestroyAddons = function()
		-- The lists are copies, so a control that leaves the list of the host
		-- while it is destroyed does not skip the control that comes after it.
		for _, picker in ipairs(table.clone(addons.KeyPickers)) do
			if picker.Destroy then
				picker:Destroy()
			end
		end
		for _, picker in ipairs(table.clone(addons.ColorPickers)) do
			if picker.Destroy then
				picker:Destroy()
			end
		end
		addons.KeyPickers = {}
		addons.ColorPickers = {}
		controls = {}
	end
end
end function __DARKLUA_BUNDLE_MODULES.r():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.r if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.r=v end return v.c end end do local function __modImpl()
local core = __DARKLUA_BUNDLE_MODULES.c()
local theme = __DARKLUA_BUNDLE_MODULES.a()
local style = __DARKLUA_BUNDLE_MODULES.f()
local icons = __DARKLUA_BUNDLE_MODULES.d()

local inlineAddons = __DARKLUA_BUNDLE_MODULES.r()
local focus = __DARKLUA_BUNDLE_MODULES.l()

local FractUI = core.FractUI
local assets = core.assets
local Tween = core.Tween
local UserInputService = core.UserInputService
local LocalPlayer = core.LocalPlayer

local function cancel(tween)
	if tween and tween.Cancel then
		tween:Cancel()
	end
end

return function(section, env)
	local Widgets = {}
	function Widgets:Button(Settings, Flag)
		local ButtonFunctions = {Settings = Settings}

		local touchLayout = UserInputService.TouchEnabled == true
		local rowHeight = touchLayout and style.Control.RowTouch or style.Control.Row

		-- An explicit action glyph owns the right edge, inline controls stack
		-- to its left. A button without a resolvable icon spends that width
		-- on its name.
		local icon = type(Settings.Icon) == "string" and icons.Get(Settings.Icon) or ""
		if icon == "" then
			icon = nil
		end
		local rail = { Cursor = icon and 24 or 0, Reserved = icon and 24 or 0 }

		local button = Instance.new("Frame")
		button.Name = "Button"
		button.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		button.BackgroundTransparency = 1
		button.BorderColor3 = Color3.fromRGB(0, 0, 0)
		button.BorderSizePixel = 0
		button.Size = UDim2.new(1, 0, 0, rowHeight)
		button.Parent = section

		local buttonInteract = Instance.new("TextButton")
		buttonInteract.Name = "ButtonInteract"
		buttonInteract.FontFace = Font.new(assets.interFont)
		buttonInteract.RichText = true
		theme.Set(buttonInteract, "TextColor3", "Text")
		buttonInteract.TextSize = style.Type.Body
		buttonInteract.TextTransparency = 0.1
		buttonInteract.TextTruncate = Enum.TextTruncate.AtEnd
		buttonInteract.TextXAlignment = Enum.TextXAlignment.Left
		buttonInteract.AutoButtonColor = false
		buttonInteract.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		buttonInteract.BackgroundTransparency = 1
		buttonInteract.BorderColor3 = Color3.fromRGB(0, 0, 0)
		buttonInteract.BorderSizePixel = 0
		buttonInteract.Size = UDim2.fromScale(1, 1)
		buttonInteract.Parent = button
		buttonInteract.Text = ""

		local buttonInteractUICorner = Instance.new("UICorner")
		buttonInteractUICorner.Name = "ButtonInteractUICorner"
		buttonInteractUICorner.CornerRadius = UDim.new(0, style.Radius.Control)
		buttonInteractUICorner.Parent = buttonInteract

		focus(buttonInteract)

		-- The name lives in its own label so inline controls can shorten it.
		local buttonText = Instance.new("TextLabel")
		buttonText.Name = "ButtonText"
		buttonText.FontFace = Font.new(assets.interFont)
		buttonText.RichText = true
		theme.Set(buttonText, "TextColor3", "Text")
		buttonText.TextSize = style.Type.Body
		buttonText.TextTransparency = 0.1
		buttonText.TextTruncate = Enum.TextTruncate.AtEnd
		buttonText.TextXAlignment = Enum.TextXAlignment.Left
		buttonText.TextYAlignment = Enum.TextYAlignment.Center
		buttonText.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		buttonText.BackgroundTransparency = 1
		buttonText.BorderColor3 = Color3.fromRGB(0, 0, 0)
		buttonText.BorderSizePixel = 0
		buttonText.Position = UDim2.fromScale(0, 0)
		buttonText.Size = UDim2.new(1, -rail.Reserved, 1, 0)
		buttonText.Parent = buttonInteract
		buttonText.Text = ButtonFunctions.Settings.Name

		local buttonImage = Instance.new("ImageLabel")
		buttonImage.Name = "ButtonImage"
		buttonImage.Image = icon or assets.buttonImage
		buttonImage.ImageTransparency = 0.1
		buttonImage.Visible = icon ~= nil
		if icon then
			theme.Set(buttonImage, "ImageColor3", "Text")
		end
		buttonImage.AnchorPoint = Vector2.new(1, 0.5)
		buttonImage.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		buttonImage.BackgroundTransparency = 1
		buttonImage.BorderColor3 = Color3.fromRGB(0, 0, 0)
		buttonImage.BorderSizePixel = 0
		buttonImage.Position = UDim2.fromScale(1, 0.5)
		buttonImage.Size = UDim2.fromOffset(15, 15)
		buttonImage.Parent = button

		local TweenSettings = {
			IdleTransparency = 0.1,
			HoverTransparency = 0,

			EasingStyle = Enum.EasingStyle.Sine
		}

		local hovered = false
		local pressed = false
		local textTween, imageTween, fillTween

		-- The label, the glyph and the fill carry the hover and the press.
		-- The last tween is cancelled, so a fast pointer never leaves two
		-- animations fighting over the same property.
		local function ChangeState()
			local state = pressed and "Pressed" or (hovered and "Hover" or "Idle")
			local target = state == "Idle" and TweenSettings.IdleTransparency or TweenSettings.HoverTransparency
			local fill = state == "Idle" and 1 or (state == "Pressed" and 0.9 or 0.94)
			local info = TweenInfo.new(style.Motion.Fast, TweenSettings.EasingStyle)

			cancel(textTween)
			textTween = Tween(buttonText, info, {
				TextTransparency = target
			})
			textTween:Play()

			cancel(imageTween)
			imageTween = Tween(buttonImage, info, {
				ImageTransparency = target
			})
			imageTween:Play()

			cancel(fillTween)
			fillTween = Tween(buttonInteract, info, {
				BackgroundTransparency = fill
			})
			fillTween:Play()
		end

		local function Callback()
			if ButtonFunctions.Settings.Callback then
				ButtonFunctions.Settings.Callback()
			end
		end

		buttonInteract.MouseEnter:Connect(function()
			hovered = true
			ChangeState()
		end)
		buttonInteract.MouseLeave:Connect(function()
			hovered = false
			pressed = false
			ChangeState()
		end)
		buttonInteract.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				pressed = true
				ChangeState()
			end
		end)
		buttonInteract.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				pressed = false
				ChangeState()
			end
		end)

		buttonInteract.MouseButton1Click:Connect(Callback)
		function ButtonFunctions:UpdateName(Name)
			buttonText.Text = Name
		end
		function ButtonFunctions:SetVisibility(State)
			button.Visible = State
		end

		function ButtonFunctions:Destroy()
			if ButtonFunctions.DestroyAddons then
				ButtonFunctions.DestroyAddons()
			end
			button:Destroy()
			if Flag and FractUI.Options[Flag] == ButtonFunctions then
				FractUI.Options[Flag] = nil
			end
		end

		inlineAddons({
			Functions = ButtonFunctions,
			env = env,
			parent = button,
			rail = rail,
			Resize = function(Reserved)
				buttonText.Size = UDim2.new(1, -Reserved, 1, 0)
			end,
		})

		if Flag then
			FractUI.Options[Flag] = ButtonFunctions
		end
		return ButtonFunctions
	end
	return Widgets
end
end function __DARKLUA_BUNDLE_MODULES.s():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.s if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.s=v end return v.c end end do local function __modImpl()
local core = __DARKLUA_BUNDLE_MODULES.c()
local theme = __DARKLUA_BUNDLE_MODULES.a()
local style = __DARKLUA_BUNDLE_MODULES.f()

local inlineAddons = __DARKLUA_BUNDLE_MODULES.r()
local focus = __DARKLUA_BUNDLE_MODULES.l()

local FractUI = core.FractUI
local assets = core.assets
local Tween = core.Tween
local UserInputService = core.UserInputService
local LocalPlayer = core.LocalPlayer

local function cancel(tween)
	if tween and tween.Cancel then
		tween:Cancel()
	end
end

return function(section, env)
	local Widgets = {}
	function Widgets:Toggle(Settings, Flag)
		local ToggleFunctions = { Settings = Settings, IgnoreConfig = false, Class = "Toggle" }
		ToggleFunctions.Changed = core.NewSignal()
		ToggleFunctions.Addons = { KeyPickers = {}, ColorPickers = {} }

		local touchLayout = UserInputService.TouchEnabled == true
		local rowHeight = touchLayout and style.Control.RowTouch or style.Control.Row

		-- The switch owns the right edge, inline controls stack to its left.
		local rail = { Cursor = 50, Reserved = 50 }
		local toggle = Instance.new("Frame")
		toggle.Name = "Toggle"
		toggle.AutomaticSize = Enum.AutomaticSize.Y
		toggle.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		toggle.BackgroundTransparency = 1
		toggle.BorderColor3 = Color3.fromRGB(0, 0, 0)
		toggle.BorderSizePixel = 0
		toggle.Size = UDim2.new(1, 0, 0, rowHeight)
		toggle.Parent = section

		local toggleName = Instance.new("TextLabel")
		toggleName.Name = "ToggleName"
		toggleName.FontFace = Font.new(assets.interFont)
		toggleName.Text = ToggleFunctions.Settings.Name
		toggleName.RichText = true
		theme.Set(toggleName, "TextColor3", "Text")
		toggleName.TextSize = style.Type.Body
		toggleName.TextTransparency = 0.1
		toggleName.TextTruncate = Enum.TextTruncate.AtEnd
		toggleName.TextXAlignment = Enum.TextXAlignment.Left
		toggleName.TextYAlignment = Enum.TextYAlignment.Top
		toggleName.AnchorPoint = Vector2.new(0, 0.5)
		toggleName.AutomaticSize = Enum.AutomaticSize.Y
		toggleName.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		toggleName.BackgroundTransparency = 1
		toggleName.BorderColor3 = Color3.fromRGB(0, 0, 0)
		toggleName.BorderSizePixel = 0
		toggleName.Position = UDim2.fromScale(0, 0.5)
		toggleName.Size = UDim2.new(1, -rail.Reserved, 0, 0)
		toggleName.Parent = toggle

		-- The hit owns the input, the paint stays the compact switch.
		local toggleHit = Instance.new("TextButton")
		toggleHit.Name = "ToggleHit"
		toggleHit.FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json")
		toggleHit.Text = ""
		toggleHit.TextColor3 = Color3.fromRGB(0, 0, 0)
		toggleHit.TextSize = 14
		toggleHit.AutoButtonColor = false
		toggleHit.AnchorPoint = Vector2.new(1, 0.5)
		toggleHit.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		toggleHit.BackgroundTransparency = 1
		toggleHit.BorderColor3 = Color3.fromRGB(0, 0, 0)
		toggleHit.BorderSizePixel = 0
		toggleHit.Position = UDim2.fromScale(1, 0.5)
		toggleHit.Size = UDim2.fromOffset(44, rowHeight)
		toggleHit.Parent = toggle

		focus(toggleHit)

		local toggle1 = Instance.new("ImageButton")
		toggle1.Name = "Toggle"
		toggle1.Image = assets.toggleBackground
		theme.Set(toggle1, "ImageColor3", "Accent")
		toggle1.AutoButtonColor = false
		toggle1.Interactable = false
		toggle1.AnchorPoint = Vector2.new(1, 0.5)
		toggle1.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		toggle1.BackgroundTransparency = 1
		toggle1.BorderColor3 = Color3.fromRGB(0, 0, 0)
		toggle1.BorderSizePixel = 0
		toggle1.Position = UDim2.fromScale(1, 0.5)
		toggle1.Size = UDim2.fromOffset(41, 21)
		toggle1.ImageTransparency = 0.5

		local toggleUIPadding = Instance.new("UIPadding")
		toggleUIPadding.Name = "ToggleUIPadding"
		toggleUIPadding.PaddingBottom = UDim.new(0, 1)
		toggleUIPadding.PaddingLeft = UDim.new(0, -2)
		toggleUIPadding.PaddingRight = UDim.new(0, 3)
		toggleUIPadding.PaddingTop = UDim.new(0, 1)
		toggleUIPadding.Parent = toggle1

		local togglerHead = Instance.new("ImageLabel")
		togglerHead.Name = "TogglerHead"
		togglerHead.Image = assets.togglerHead
		theme.Set(togglerHead, "ImageColor3", "Text")
		togglerHead.AnchorPoint = Vector2.new(1, 0.5)
		togglerHead.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		togglerHead.BackgroundTransparency = 1
		togglerHead.BorderColor3 = Color3.fromRGB(0, 0, 0)
		togglerHead.BorderSizePixel = 0
		togglerHead.Position = UDim2.fromScale(0.5, 0.5)
		togglerHead.Size = UDim2.fromOffset(15, 15)
		togglerHead.ZIndex = 2
		togglerHead.Parent = toggle1
		-- The knob of the off switch stays visible.
		togglerHead.ImageTransparency = 0.1

		toggle1.Parent = toggle

		local togglerHeadTransparency = {Enabled = 0, Disabled = 0.1}

		local TweenSettings = {
			Info = TweenInfo.new(style.Motion.Control, Enum.EasingStyle.Quad),

			EnabledPosition = UDim2.new(1, 0, 0.5, 0),
			DisabledPosition = UDim2.new(0.5, 0, 0.5, 0),
		}

		local togglebool = ToggleFunctions.Settings.Default
		local hovered = false
		local pressed = false
		local switchTween, labelTween, headTween, positionTween

		local function SyncAddons(State)
			for _, picker in ipairs(ToggleFunctions.Addons.KeyPickers) do
				picker:SyncState(State)
			end
		end

		-- The switch and the label carry the state, the hover and the press.
		-- An off switch is neutral, so the track is the muted token and not
		-- half of the accent.
		local function Paint()
			theme.Set(toggle1, "ImageColor3", togglebool and "Accent" or "Muted")
			local base = togglebool and 0 or 0.35
			local switch = base
			if hovered then
				switch = math.max(switch - 0.08, 0)
			end
			if pressed then
				switch = math.max(switch - 0.07, 0)
			end

			cancel(switchTween)
			switchTween = Tween(toggle1, TweenInfo.new(style.Motion.Fast, Enum.EasingStyle.Sine), {
				ImageTransparency = switch,
			})
			switchTween:Play()

			cancel(labelTween)
			labelTween = Tween(toggleName, TweenInfo.new(style.Motion.Fast, Enum.EasingStyle.Sine), {
				TextTransparency = (hovered or pressed) and 0 or 0.1,
			})
			labelTween:Play()
		end

		local function NewState(State, callback)
			local transparencyValues = State and {togglerHeadTransparency.Enabled} or {togglerHeadTransparency.Disabled}
			local position = State and TweenSettings.EnabledPosition or TweenSettings.DisabledPosition

			cancel(headTween)
			headTween = Tween(togglerHead, TweenSettings.Info, {
				ImageTransparency = transparencyValues[1]
			})
			headTween:Play()

			cancel(positionTween)
			positionTween = Tween(togglerHead, TweenSettings.Info, {
				Position = position
			})
			positionTween:Play()

			Paint()

			ToggleFunctions.State = State
			SyncAddons(State)
			ToggleFunctions.Changed:Fire(State)
			if callback then
				callback(togglebool)
			end
		end

		NewState(togglebool)

		local function Toggle()
			togglebool = not togglebool
			NewState(togglebool, ToggleFunctions.Settings.Callback)
		end

		toggleHit.MouseButton1Click:Connect(Toggle)

		toggleHit.MouseEnter:Connect(function()
			hovered = true
			Paint()
		end)
		toggleHit.MouseLeave:Connect(function()
			hovered = false
			pressed = false
			Paint()
		end)
		toggleHit.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				pressed = true
				Paint()
			end
		end)
		toggleHit.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				pressed = false
				Paint()
			end
		end)

		function ToggleFunctions:Toggle()
			Toggle()
		end
		function ToggleFunctions:UpdateState(State)
			togglebool = State
			NewState(togglebool, ToggleFunctions.Settings.Callback)
		end
		function ToggleFunctions:GetState()
			return togglebool
		end
		function ToggleFunctions:UpdateName(Name)
			toggleName.Text = Name
		end
		function ToggleFunctions:SetVisibility(State)
			toggle.Visible = State
		end

		function ToggleFunctions:Destroy()
			if ToggleFunctions.DestroyAddons then
				ToggleFunctions.DestroyAddons()
			end
			ToggleFunctions.Changed:Clear()
			toggle:Destroy()
			if Flag and FractUI.Options[Flag] == ToggleFunctions then
				FractUI.Options[Flag] = nil
			end
		end

		inlineAddons({
			Functions = ToggleFunctions,
			env = env,
			parent = toggle,
			rail = rail,
			Resize = function(Reserved)
				toggleName.Size = UDim2.new(1, -Reserved, 0, 0)
			end,
		})

		if Flag then
			FractUI.Options[Flag] = ToggleFunctions
		end
		return ToggleFunctions
	end
	return Widgets
end
end function __DARKLUA_BUNDLE_MODULES.t():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.t if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.t=v end return v.c end end do local function __modImpl()
local core = __DARKLUA_BUNDLE_MODULES.c()
local theme = __DARKLUA_BUNDLE_MODULES.a()
local style = __DARKLUA_BUNDLE_MODULES.f()
local cleanup = __DARKLUA_BUNDLE_MODULES.n()

local FractUI = core.FractUI
local assets = core.assets
local Tween = core.Tween
local UserInputService = core.UserInputService
local LocalPlayer = core.LocalPlayer

local function cancel(tween)
	if tween and tween.Cancel then
		tween:Cancel()
	end
end

--// A value the user reads stays short, the value the widget stores and the
--// callback receives is not touched.
local function compactNumber(value)
	if value == 0 then
		return "0"
	end
	return string.format("%.6g", value)
end

--// The text of the edit state keeps every digit of the stored value, so a
--// focused box can be read back exactly.
local function exactNumber(value)
	return string.format("%.17g", value)
end

return function(section, env)
	local Widgets = {}
	local baseUIScale = env.baseUIScale
	--// The value box may not grow without a bound and may not shrink below a
	--// usable input: the value minimum and a usable track are reserved first,
	--// then the label takes what is left and truncates with an ellipsis.
	local VALUE_GAP = 20
	local PADDING = 20
	local MIN_TRACK = 20
	local MIN_VALUE_WIDTH = 41
	local MIN_VALUE_WIDTH_TOUCH = 44
	local MAX_VALUE_WIDTH = 72
	local VALUE_INSET = 2
	function Widgets:Slider(Settings, Flag)
		local SliderFunctions = { Settings = Settings, IgnoreConfig = false, Class = "Slider" }
		SliderFunctions.Changed = core.NewSignal()

		local touchLayout = UserInputService.TouchEnabled == true
		local rowHeight = touchLayout and style.Control.RowTouch or style.Control.Row
		local minValueWidth = touchLayout and MIN_VALUE_WIDTH_TOUCH or MIN_VALUE_WIDTH

		local slider = Instance.new("Frame")
		slider.Name = "Slider"
		slider.AutomaticSize = Enum.AutomaticSize.Y
		slider.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		slider.BackgroundTransparency = 1
		slider.BorderColor3 = Color3.fromRGB(0, 0, 0)
		slider.BorderSizePixel = 0
		slider.Size = UDim2.new(1, 0, 0, rowHeight)
		slider.Parent = section

		local sliderName = Instance.new("TextLabel")
		sliderName.Name = "SliderName"
		sliderName.FontFace = Font.new(assets.interFont)
		sliderName.Text = SliderFunctions.Settings.Name
		sliderName.RichText = true
		theme.Set(sliderName, "TextColor3", "Text")
		sliderName.TextSize = style.Type.Body
		sliderName.TextTransparency = 0.1
		sliderName.TextTruncate = Enum.TextTruncate.AtEnd
		sliderName.TextXAlignment = Enum.TextXAlignment.Left
		sliderName.TextYAlignment = Enum.TextYAlignment.Center
		sliderName.AnchorPoint = Vector2.new(0, 0.5)
		--// The width is set from TextBounds in updateSliderBarSize. AutoSize
		--// plus a size constraint does not reliably clamp in the client.
		sliderName.AutomaticSize = Enum.AutomaticSize.None
		sliderName.Size = UDim2.new(0, 0, 1, 0)
		sliderName.ClipsDescendants = true
		sliderName.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		sliderName.BackgroundTransparency = 1
		sliderName.BorderColor3 = Color3.fromRGB(0, 0, 0)
		sliderName.BorderSizePixel = 0
		sliderName.Position = UDim2.fromScale(1.3e-07, 0.5)
		sliderName.Parent = slider

		--// AtEnd makes the visible label report its clipped width. A hidden
		--// label with the same text and font measures the natural width.
		local sliderNameMeasurement = Instance.new("TextLabel")
		sliderNameMeasurement.Name = "SliderNameMeasurement"
		sliderNameMeasurement.FontFace = sliderName.FontFace
		sliderNameMeasurement.Text = sliderName.Text
		sliderNameMeasurement.RichText = sliderName.RichText
		sliderNameMeasurement.TextSize = sliderName.TextSize
		sliderNameMeasurement.TextTruncate = Enum.TextTruncate.None
		sliderNameMeasurement.TextWrapped = false
		sliderNameMeasurement.AutomaticSize = Enum.AutomaticSize.None
		sliderNameMeasurement.Size = UDim2.fromOffset(0, rowHeight)
		sliderNameMeasurement.Visible = false
		sliderNameMeasurement.Parent = slider

		local function syncSliderNameMeasurement()
			sliderNameMeasurement.Text = sliderName.Text
			sliderNameMeasurement.FontFace = sliderName.FontFace
			sliderNameMeasurement.TextSize = sliderName.TextSize
			sliderNameMeasurement.RichText = sliderName.RichText
		end

		local sliderElements = Instance.new("Frame")
		sliderElements.Name = "SliderElements"
		sliderElements.AnchorPoint = Vector2.new(1, 0)
		sliderElements.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		sliderElements.BackgroundTransparency = 1
		sliderElements.BorderColor3 = Color3.fromRGB(0, 0, 0)
		sliderElements.BorderSizePixel = 0
		sliderElements.Position = UDim2.fromScale(1, 0)
		sliderElements.Size = UDim2.fromScale(1, 1)

		local sliderValue = Instance.new("TextBox")
		sliderValue.Name = "SliderValue"
		sliderValue.FontFace = Font.new(assets.interFont)
		theme.Set(sliderValue, "TextColor3", "Text")
		sliderValue.TextSize = style.Type.Caption
		sliderValue.TextTransparency = 0.1
		--sliderValue.TextTruncate = Enum.TextTruncate.AtEnd
		sliderValue.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		sliderValue.BackgroundTransparency = 0.95
		sliderValue.BorderColor3 = Color3.fromRGB(0, 0, 0)
		sliderValue.BorderSizePixel = 0
		sliderValue.LayoutOrder = 1
		sliderValue.Position = UDim2.fromScale(-0.0789, 0.171)
		sliderValue.Size = UDim2.fromOffset(minValueWidth, touchLayout and 28 or 24)
		--// The width is set from TextBounds in updateSliderBarSize. AutoSize
		--// plus a size constraint does not reliably clamp in the client; a
		--// focused exact value stays in the box and scrolls.
		sliderValue.AutomaticSize = Enum.AutomaticSize.None
		sliderValue.ClipsDescendants = true

		local sliderValueUICorner = Instance.new("UICorner")
		sliderValueUICorner.Name = "SliderValueUICorner"
		sliderValueUICorner.CornerRadius = UDim.new(0, style.Radius.Control)
		sliderValueUICorner.Parent = sliderValue

		local sliderValueUIStroke = Instance.new("UIStroke")
		sliderValueUIStroke.Name = "SliderValueUIStroke"
		sliderValueUIStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		theme.Set(sliderValueUIStroke, "Color", "Outline")
		sliderValueUIStroke.Transparency = 0.9
		sliderValueUIStroke.Parent = sliderValue

		local sliderValueUIPadding = Instance.new("UIPadding")
		sliderValueUIPadding.Name = "SliderValueUIPadding"
		sliderValueUIPadding.PaddingLeft = UDim.new(0, VALUE_INSET)
		sliderValueUIPadding.PaddingRight = UDim.new(0, VALUE_INSET)
		sliderValueUIPadding.Parent = sliderValue

		sliderValue.Parent = sliderElements

		local sliderElementsUIListLayout = Instance.new("UIListLayout")
		sliderElementsUIListLayout.Name = "SliderElementsUIListLayout"
		sliderElementsUIListLayout.Padding = UDim.new(0, 20)
		sliderElementsUIListLayout.FillDirection = Enum.FillDirection.Horizontal
		sliderElementsUIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
		sliderElementsUIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
		sliderElementsUIListLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		sliderElementsUIListLayout.Parent = sliderElements

		local sliderBar = Instance.new("ImageLabel")
		sliderBar.Name = "SliderBar"
		sliderBar.Image = assets.sliderbar
		theme.Set(sliderBar, "ImageColor3", "Accent")
		sliderBar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		sliderBar.BackgroundTransparency = 1
		sliderBar.BorderColor3 = Color3.fromRGB(0, 0, 0)
		sliderBar.BorderSizePixel = 0
		sliderBar.Position = UDim2.fromScale(0.219, 0.457)
		sliderBar.Size = UDim2.fromOffset(123, 3)

		-- The track owns the input, the head stays the compact paint.
		local sliderTrack = Instance.new("TextButton")
		sliderTrack.Name = "SliderTrack"
		sliderTrack.FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json")
		sliderTrack.Text = ""
		sliderTrack.TextColor3 = Color3.fromRGB(0, 0, 0)
		sliderTrack.TextSize = 14
		sliderTrack.AutoButtonColor = false
		sliderTrack.AnchorPoint = Vector2.new(0, 0.5)
		sliderTrack.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		sliderTrack.BackgroundTransparency = 1
		sliderTrack.BorderColor3 = Color3.fromRGB(0, 0, 0)
		sliderTrack.BorderSizePixel = 0
		sliderTrack.Position = UDim2.fromScale(0, 0.5)
		sliderTrack.Size = UDim2.new(1, 0, 0, touchLayout and style.Control.TrackTouch or style.Control.Track)
		sliderTrack.Parent = sliderBar

		local sliderHead = Instance.new("ImageButton")
		sliderHead.Name = "SliderHead"
		sliderHead.Image = assets.sliderhead
		sliderHead.AnchorPoint = Vector2.new(0.5, 0.5)
		sliderHead.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		sliderHead.BackgroundTransparency = 1
		sliderHead.BorderColor3 = Color3.fromRGB(0, 0, 0)
		sliderHead.BorderSizePixel = 0
		sliderHead.Position = UDim2.fromScale(1, 0.5)
		sliderHead.Size = UDim2.fromOffset(12, 12)
		sliderHead.Parent = sliderBar

		sliderBar.Parent = sliderElements

		local sliderElementsUIPadding = Instance.new("UIPadding")
		sliderElementsUIPadding.Name = "SliderElementsUIPadding"
		sliderElementsUIPadding.PaddingTop = UDim.new(0, 3)
		sliderElementsUIPadding.Parent = sliderElements

		sliderElements.Parent = slider

		local dragging = false
		local dragInputType = nil
		local dragTouch = nil

		local DisplayMethods = {
			Hundredths = function(sliderValue) -- Deprecated use Settings.Precision
				return string.format("%.2f", sliderValue)
			end,
			Tenths = function(sliderValue) -- Deprecated use Settings.Precision
				return string.format("%.1f", sliderValue)
			end,
			Round = function(sliderValue, precision)
				if precision then
					return string.format("%." .. precision .. "f", sliderValue)
				else
					return tostring(math.round(sliderValue))
				end
			end,
			Degrees = function(sliderValue, precision)
				local formattedValue = precision and string.format("%." .. precision .. "f", sliderValue) or compactNumber(sliderValue)
				return formattedValue .. "°"
			end,
			Percent = function(sliderValue, precision)
				local percentage = (sliderValue - SliderFunctions.Settings.Minimum) / (SliderFunctions.Settings.Maximum - SliderFunctions.Settings.Minimum) * 100
				return precision and string.format("%." .. precision .. "f", percentage) .. "%" or tostring(math.round(percentage)) .. "%"
			end,
			Value = function(sliderValue, precision)
				return precision and string.format("%." .. precision .. "f", sliderValue) or compactNumber(sliderValue)
			end
		}

		local ValueDisplayMethod = DisplayMethods[SliderFunctions.Settings.DisplayMethod] or DisplayMethods.Value
		local finalValue

		local function displayValue(value)
			return (Settings.Prefix or "") .. ValueDisplayMethod(value, SliderFunctions.Settings.Precision) .. (Settings.Suffix or "")
		end

		--// The edit text is the raw value in the unit of the parser, without a
		--// prefix or a degree sign that the parser would refuse.
		local function editValue(value)
			if SliderFunctions.Settings.DisplayMethod == "Percent" then
				local percentage = (value - SliderFunctions.Settings.Minimum) / (SliderFunctions.Settings.Maximum - SliderFunctions.Settings.Minimum) * 100
				return exactNumber(percentage) .. "%"
			end
			return exactNumber(value)
		end

		local editText = nil

		local function SetValue(val, ignorecallback)
			local posXScale

			if typeof(val) == "Instance" then
				local input = val
				posXScale = math.clamp((input.Position.X - sliderBar.AbsolutePosition.X) / sliderBar.AbsoluteSize.X, 0, 1)
			else
				local value = val
				posXScale = (value - SliderFunctions.Settings.Minimum) / (SliderFunctions.Settings.Maximum - Settings.Minimum)
			end

			local pos = UDim2.new(posXScale, 0, 0.5, 0)
			sliderHead.Position = pos

			finalValue = posXScale * (SliderFunctions.Settings.Maximum - SliderFunctions.Settings.Minimum) + Settings.Minimum

			if editText ~= nil then
				editText = editValue(finalValue)
				sliderValue.Text = editText
			else
				sliderValue.Text = displayValue(finalValue)
			end

			if not ignorecallback then
				task.spawn(function()
					if SliderFunctions.Settings.Callback then
						SliderFunctions.Settings.Callback(finalValue)
					end
				end)
			end

			SliderFunctions.Value = finalValue
			SliderFunctions.Changed:Fire(finalValue)
		end

		SetValue(SliderFunctions.Settings.Default, true)

		-- A drag belongs to the input that started it, so a second pointer
		-- never moves it and only that input ends it.
		local dragGeneration
		local function cancelDrag()
			dragging = false
			dragInputType = nil
			dragTouch = nil
			dragGeneration = nil
		end

		local function moveDrag(input)
			SetValue(input)
			-- A callback can open a dialog from inside this move.
			if env.modal and dragGeneration ~= env.modal:GetGeneration() then
				cancelDrag()
			end
		end

		local function beginDrag(input)
			if env.modal and env.modal:IsBlocked() then return end
			if dragging then return end
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
				return
			end
			dragging = true
			dragInputType = input.UserInputType
			dragTouch = input.UserInputType == Enum.UserInputType.Touch and input or nil
			dragGeneration = env.modal and env.modal:GetGeneration() or nil
			moveDrag(input)
		end

		local function endDrag()
			cancelDrag()
			if SliderFunctions.Settings.onInputComplete then
				SliderFunctions.Settings.onInputComplete(finalValue)
			end
		end

		sliderHead.InputBegan:Connect(beginDrag)
		sliderTrack.InputBegan:Connect(beginDrag)

		sliderValue.Focused:Connect(function()
			editText = editValue(finalValue)
			sliderValue.Text = editText
		end)

		sliderValue.FocusLost:Connect(function(enterPressed)
			local inputText = sliderValue.Text
			--// Leaving the box without a change restores the short display and
			--// does not fire the callback of a value that was not edited.
			if editText ~= nil and inputText == editText then
				editText = nil
				sliderValue.Text = displayValue(finalValue)
			else
				editText = nil
				local text = inputText:match("^%s*(.-)%s*$")
				local isPercent = text:sub(-1) == "%"
				if isPercent then
					text = text:sub(1, -2)
				end
				local value = tonumber(text)

				if value and value == value and value ~= math.huge and value ~= -math.huge then
					if isPercent then
						value = SliderFunctions.Settings.Minimum + (value / 100) * (SliderFunctions.Settings.Maximum - SliderFunctions.Settings.Minimum)
					end

					local newValue = math.clamp(value, SliderFunctions.Settings.Minimum, SliderFunctions.Settings.Maximum)
					SetValue(newValue)
				else
					sliderValue.Text = displayValue(finalValue)
				end
			end

			if SliderFunctions.Settings.onInputComplete then
				SliderFunctions.Settings.onInputComplete(finalValue)
			end
		end)

		local focusTween
		local function paintFocus(focused)
			theme.Set(sliderValueUIStroke, "Color", focused and "Accent" or "Outline")
			cancel(focusTween)
			focusTween = Tween(sliderValueUIStroke, TweenInfo.new(style.Motion.Fast, Enum.EasingStyle.Sine), {
				Transparency = focused and 0.35 or 0.9,
			})
			focusTween:Play()
		end

		sliderValue.Focused:Connect(function()
			paintFocus(true)
		end)
		sliderValue.FocusLost:Connect(function()
			paintFocus(false)
		end)

		local inputConnection = UserInputService.InputChanged:Connect(function(input)
			if env.modal and (env.modal:IsBlocked() or (dragging and dragGeneration ~= env.modal:GetGeneration())) then
				cancelDrag()
				return
			end
			if not dragging then return end
			if input.UserInputType == Enum.UserInputType.MouseMovement and dragInputType == Enum.UserInputType.MouseButton1 then
				moveDrag(input)
			elseif input.UserInputType == Enum.UserInputType.Touch and dragTouch == input then
				moveDrag(input)
			end
		end)

		local endedConnection = UserInputService.InputEnded:Connect(function(input)
			if env.modal and (env.modal:IsBlocked() or (dragging and dragGeneration ~= env.modal:GetGeneration())) then
				cancelDrag()
				return
			end
			if input.UserInputType == Enum.UserInputType.MouseButton1 and dragInputType == Enum.UserInputType.MouseButton1 then
				endDrag()
			elseif input.UserInputType == Enum.UserInputType.Touch and dragTouch == input then
				endDrag()
			end
		end)

		local function updateSliderBarSize()
			local scale = baseUIScale.Scale
			if scale <= 0 then
				scale = 1
			end
			local totalWidth = sliderElements.AbsoluteSize.X / scale

			--// The value and the track come first. The value width is set
			--// from its text, not from AutomaticSize: AutoSize plus a size
			--// constraint does not reliably clamp in the client.
			local maxValueForRow = math.max(minValueWidth, math.min(MAX_VALUE_WIDTH, totalWidth - MIN_TRACK))
			local valueWidth
			if editText ~= nil then
				--// A focused edit stays in the same box and scrolls; it
				--// never takes width from the label or the track.
				valueWidth = math.clamp(sliderValue.Size.X.Offset, minValueWidth, maxValueForRow)
			else
				local measured = math.ceil(sliderValue.TextBounds.X / scale) + VALUE_INSET * 2
				valueWidth = math.clamp(measured, minValueWidth, maxValueForRow)
			end
			sliderValue.Size = UDim2.fromOffset(valueWidth, touchLayout and 28 or 24)

			--// What is left goes to the label, then to the gaps; a label
			--// that does not fit truncates with an ellipsis.
			local available = totalWidth - valueWidth - MIN_TRACK
			local paddingWidth, gapWidth
			if available >= PADDING + VALUE_GAP then
				paddingWidth, gapWidth = PADDING, VALUE_GAP
			else
				paddingWidth = math.clamp(available, 0, PADDING)
				gapWidth = math.clamp(available - paddingWidth, 0, VALUE_GAP)
			end
			local maxNameWidth = math.max(0, available - paddingWidth - gapWidth)
			--// AtEnd reports the clipped bounds on the visible label, so the
			--// hidden label with no truncation supplies the natural width.
			local nameWidth = math.min(math.ceil(sliderNameMeasurement.TextBounds.X / scale), maxNameWidth)
			sliderElementsUIListLayout.Padding = UDim.new(0, paddingWidth)
			sliderName.Size = UDim2.new(0, nameWidth, 1, 0)

			local newBarWidth = math.max(
				0,
				totalWidth - (paddingWidth + valueWidth + nameWidth + gapWidth)
			)
			sliderBar.Size = UDim2.new(sliderBar.Size.X.Scale, newBarWidth, sliderBar.Size.Y.Scale, sliderBar.Size.Y.Offset)
		end

		updateSliderBarSize()

		sliderName:GetPropertyChangedSignal("Text"):Connect(syncSliderNameMeasurement)
		sliderName:GetPropertyChangedSignal("FontFace"):Connect(syncSliderNameMeasurement)
		sliderName:GetPropertyChangedSignal("TextSize"):Connect(syncSliderNameMeasurement)
		sliderName:GetPropertyChangedSignal("RichText"):Connect(syncSliderNameMeasurement)
		sliderNameMeasurement:GetPropertyChangedSignal("TextBounds"):Connect(updateSliderBarSize)
		sliderValue:GetPropertyChangedSignal("Text"):Connect(updateSliderBarSize)
		sliderValue:GetPropertyChangedSignal("TextBounds"):Connect(updateSliderBarSize)
		section:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateSliderBarSize)

		-- The listeners of the service belong to the widget, so the explicit
		-- Destroy, the container and the unload of the window release them
		-- once, no matter which of them comes first.
		local release = cleanup({
			functions = SliderFunctions,
			instance = slider,
			env = env,
			flag = Flag,
			release = function()
				inputConnection:Disconnect()
				endedConnection:Disconnect()
				SliderFunctions.Changed:Clear()
			end,
		})

		function SliderFunctions:UpdateName(Name)
			sliderName.Text = Name
			syncSliderNameMeasurement()
		end
		function SliderFunctions:SetVisibility(State)
			slider.Visible = State
		end

		function SliderFunctions:Destroy()
			release()
			slider:Destroy()
		end
		function SliderFunctions:UpdateValue(Value)
			SetValue(tonumber(Value), true)
		end
		function SliderFunctions:GetValue()
			return finalValue
		end

		if Flag then
			FractUI.Options[Flag] = SliderFunctions
		end
		return SliderFunctions
	end
	return Widgets
end
end function __DARKLUA_BUNDLE_MODULES.u():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.u if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.u=v end return v.c end end do local function __modImpl()
local core = __DARKLUA_BUNDLE_MODULES.c()
local theme = __DARKLUA_BUNDLE_MODULES.a()
local style = __DARKLUA_BUNDLE_MODULES.f()

local FractUI = core.FractUI
local assets = core.assets
local Tween = core.Tween
local UserInputService = core.UserInputService
local LocalPlayer = core.LocalPlayer

local function cancel(tween)
	if tween and tween.Cancel then
		tween:Cancel()
	end
end

return function(section, env)
	local Widgets = {}
	local baseUIScale = env.baseUIScale
	function Widgets:Input(Settings, Flag)
		local InputFunctions = { Settings = Settings, IgnoreConfig = false, Class = "Input" }
		InputFunctions.Changed = core.NewSignal()

		local touchLayout = UserInputService.TouchEnabled == true
		local rowHeight = touchLayout and style.Control.RowTouch or style.Control.Row

		local input = Instance.new("Frame")
		input.Name = "Input"
		input.AutomaticSize = Enum.AutomaticSize.Y
		input.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		input.BackgroundTransparency = 1
		input.BorderColor3 = Color3.fromRGB(0, 0, 0)
		input.BorderSizePixel = 0
		input.Size = UDim2.new(1, 0, 0, rowHeight)
		input.Parent = section

		local inputName = Instance.new("TextLabel")
		inputName.Name = "InputName"
		inputName.FontFace = Font.new(assets.interFont)
		inputName.Text = InputFunctions.Settings.Name
		inputName.RichText = true
		theme.Set(inputName, "TextColor3", "Text")
		inputName.TextSize = style.Type.Body
		inputName.TextTransparency = 0.1
		inputName.TextTruncate = Enum.TextTruncate.AtEnd
		inputName.TextXAlignment = Enum.TextXAlignment.Left
		inputName.TextYAlignment = Enum.TextYAlignment.Top
		inputName.AnchorPoint = Vector2.new(0, 0.5)
		inputName.AutomaticSize = Enum.AutomaticSize.XY
		inputName.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		inputName.BackgroundTransparency = 1
		inputName.BorderColor3 = Color3.fromRGB(0, 0, 0)
		inputName.BorderSizePixel = 0
		inputName.Position = UDim2.fromScale(0, 0.5)
		inputName.Parent = input

		local inputBox = Instance.new("TextBox")
		inputBox.Name = "InputBox"
		inputBox.FontFace = Font.new(assets.interFont)
		theme.Set(inputBox, "PlaceholderColor3", "Placeholder")
		theme.Set(inputBox, "TextColor3", "Text")
		inputBox.TextSize = style.Type.Caption
		inputBox.TextTransparency = 0.1
		inputBox.AnchorPoint = Vector2.new(1, 0.5)
		inputBox.AutomaticSize = Enum.AutomaticSize.X
		inputBox.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		inputBox.BackgroundTransparency = 0.95
		inputBox.BorderColor3 = Color3.fromRGB(0, 0, 0)
		inputBox.BorderSizePixel = 0
		inputBox.ClipsDescendants = true
		inputBox.LayoutOrder = 1
		inputBox.Position = UDim2.fromScale(1, 0.5)
		inputBox.Size = UDim2.fromOffset(21, touchLayout and 28 or 24)
		inputBox.TextXAlignment = Enum.TextXAlignment.Right

		local inputBoxUICorner = Instance.new("UICorner")
		inputBoxUICorner.Name = "InputBoxUICorner"
		inputBoxUICorner.CornerRadius = UDim.new(0, style.Radius.Control)
		inputBoxUICorner.Parent = inputBox

		local inputBoxUIStroke = Instance.new("UIStroke")
		inputBoxUIStroke.Name = "InputBoxUIStroke"
		inputBoxUIStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		theme.Set(inputBoxUIStroke, "Color", "Outline")
		inputBoxUIStroke.Transparency = 0.9
		inputBoxUIStroke.Parent = inputBox

		local inputBoxUIPadding = Instance.new("UIPadding")
		inputBoxUIPadding.Name = "InputBoxUIPadding"
		inputBoxUIPadding.PaddingLeft = UDim.new(0, 5)
		inputBoxUIPadding.PaddingRight = UDim.new(0, 5)
		inputBoxUIPadding.Parent = inputBox

		local inputBoxUISizeConstraint = Instance.new("UISizeConstraint")
		inputBoxUISizeConstraint.Name = "InputBoxUISizeConstraint"
		inputBoxUISizeConstraint.Parent = inputBox

		inputBox.Parent = input

		local Input = input
		local InputBox = inputBox
		local InputName = inputName
		local Constraint = inputBoxUISizeConstraint

		-- The focus is painted, and the last tween is cancelled so a fast
		-- focus change never leaves two animations fighting.
		local focusTween
		local function paintFocus(focused)
			theme.Set(inputBoxUIStroke, "Color", focused and "Accent" or "Outline")
			cancel(focusTween)
			focusTween = Tween(inputBoxUIStroke, TweenInfo.new(style.Motion.Fast, Enum.EasingStyle.Sine), {
				Transparency = focused and 0.35 or 0.9,
			})
			focusTween:Play()
		end

		inputBox.Focused:Connect(function()
			paintFocus(true)
		end)
		inputBox.FocusLost:Connect(function()
			paintFocus(false)
		end)

		local function applyCharacterLimit(value)
			if InputFunctions.Settings.CharacterLimit then
				return value:sub(1, InputFunctions.Settings.CharacterLimit)
			end
			return value
		end

		local CharacterSubs = {
			All = function(value)
				return applyCharacterLimit(value)
			end,
			Numeric = function(value)
				local result = value:match("^%-?%d*$") and value or value:gsub("[^%d-]", ""):gsub("(%-)", function(match, pos)
					return pos == 1 and match or ""
				end)
				return applyCharacterLimit(result)
			end,
			Alphabetic = function(value)
				return applyCharacterLimit(value:gsub("[^a-zA-Z ]", ""))
			end,
			AlphaNumeric = function(value)
				return applyCharacterLimit(value:gsub("[^a-zA-Z0-9]", ""))
			end,
		}

		local AcceptedCharacters

		if type(InputFunctions.Settings.AcceptedCharacters) == "function" then
			AcceptedCharacters = InputFunctions.Settings.AcceptedCharacters
		else
			AcceptedCharacters = CharacterSubs[InputFunctions.Settings.AcceptedCharacters] or CharacterSubs.All
		end

		InputBox.AutomaticSize = Enum.AutomaticSize.X

		local function checkSize()
			local nameWidth = InputName.AbsoluteSize.X
			local totalWidth = Input.AbsoluteSize.X

			local maxWidth = (totalWidth - nameWidth - 20) / baseUIScale.Scale
			Constraint.MaxSize = Vector2.new(maxWidth, 9e9)
		end

		checkSize()
		InputName:GetPropertyChangedSignal("AbsoluteSize"):Connect(checkSize)

		InputBox.FocusLost:Connect(function()
			local inputText = InputBox.Text
			local filteredText = AcceptedCharacters(inputText)
			InputBox.Text = filteredText
			task.spawn(function()
				if InputFunctions.Settings.Callback then
					InputFunctions.Settings.Callback(filteredText)
				end
			end)
		end)
		InputBox.Text = InputFunctions.Settings.Default or ""
		InputBox.PlaceholderText = InputFunctions.Settings.Placeholder or ""
		InputFunctions.Text = InputBox.Text

		InputBox:GetPropertyChangedSignal("Text"):Connect(function()
			InputBox.Text = AcceptedCharacters(InputBox.Text)
			if InputFunctions.Settings.onChanged then
				InputFunctions.Settings.onChanged(InputBox.Text)
			end
			InputFunctions.Text = InputBox.Text
			InputFunctions.Changed:Fire(InputBox.Text)
		end)

		function InputFunctions:UpdateName(Name)
			inputName.Text = Name
		end
		function InputFunctions:SetVisibility(State)
			input.Visible = State
		end

		function InputFunctions:Destroy()
			InputFunctions.Changed:Clear()
			input:Destroy()
			if Flag and FractUI.Options[Flag] == InputFunctions then
				FractUI.Options[Flag] = nil
			end
		end
		function InputFunctions:GetInput()
			return InputBox.Text
		end
		function InputFunctions:UpdatePlaceholder(Placeholder)
			inputBox.PlaceholderText = Placeholder
		end
		function InputFunctions:UpdateText(Text)
			local filteredText = AcceptedCharacters(Text)
			InputBox.Text = filteredText
			InputFunctions.Text = filteredText
			task.spawn(function()
				if InputFunctions.Settings.Callback then
					InputFunctions.Settings.Callback(filteredText)
				end
			end)
		end

		if Flag then
			FractUI.Options[Flag] = InputFunctions
		end
		return InputFunctions
	end
	return Widgets
end
end function __DARKLUA_BUNDLE_MODULES.v():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.v if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.v=v end return v.c end end do local function __modImpl()
local core = __DARKLUA_BUNDLE_MODULES.c()

local UserInputService = core.UserInputService

--// Shared key capture for the keybind widget and the inline key picker.
--// Owns nothing but the bound key and the "listening for the next key" state.
return function(options)
	local Binding = {}

	local binded = options.Default
	local capturing = false
	local connection

	local function isAllowed(input)
		local blacklist = options.Blacklist
		if type(blacklist) ~= "table" then
			return true
		end
		return not (table.find(blacklist, input.KeyCode) or table.find(blacklist, input.UserInputType))
	end

	local function captureKey(input)
		if input.UserInputType == Enum.UserInputType.Keyboard then
			return input.KeyCode
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.MouseButton2 then
			return input.UserInputType
		end
		return nil
	end

	function Binding:GetBind()
		return binded
	end

	function Binding:SetBind(key)
		binded = key
		Binding:StopCapture()
		if options.onBinded then
			options.onBinded(binded)
		end
	end

	function Binding:IsCapturing()
		return capturing
	end

	function Binding:IsAllowed(input)
		return isAllowed(input)
	end

	function Binding:StartCapture()
		if capturing then
			return
		end
		capturing = true

		connection = UserInputService.InputBegan:Connect(function(input)
			if not capturing then
				return
			end
			if not isAllowed(input) then
				-- The key is not allowed, so the capture ends here.
				Binding:StopCapture()
				if options.onRejected then
					options.onRejected()
				end
				return
			end

			local captured = captureKey(input)
			if not captured then
				return
			end

			Binding:StopCapture()
			binded = captured
			if options.onBinded then
				options.onBinded(binded)
			end
		end)
	end

	function Binding:StopCapture()
		capturing = false
		if connection then
			connection:Disconnect()
			connection = nil
		end
	end

	function Binding:Destroy()
		Binding:StopCapture()
	end

	return Binding
end
end function __DARKLUA_BUNDLE_MODULES.w():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.w if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.w=v end return v.c end end do local function __modImpl()
local core = __DARKLUA_BUNDLE_MODULES.c()
local theme = __DARKLUA_BUNDLE_MODULES.a()

local createBinding = __DARKLUA_BUNDLE_MODULES.w()

local FractUI = core.FractUI
local assets = core.assets
local Tween = core.Tween
local UserInputService = core.UserInputService
local LocalPlayer = core.LocalPlayer

return function(section, env)
	local Widgets = {}
	function Widgets:Keybind(Settings, Flag)
		local KeybindFunctions = { Settings = Settings, IgnoreConfig = false, Class = "Keybind" }
		local keybind = Instance.new("Frame")
		keybind.Name = "Keybind"
		keybind.AutomaticSize = Enum.AutomaticSize.Y
		keybind.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		keybind.BackgroundTransparency = 1
		keybind.BorderColor3 = Color3.fromRGB(0, 0, 0)
		keybind.BorderSizePixel = 0
		keybind.Size = UDim2.new(1, 0, 0, 38)
		keybind.Parent = section

		local keybindName = Instance.new("TextLabel")
		keybindName.Name = "KeybindName"
		keybindName.FontFace = Font.new(assets.interFont)
		keybindName.Text = KeybindFunctions.Settings.Name
		keybindName.RichText = true
		theme.Set(keybindName, "TextColor3", "Text")
		keybindName.TextSize = 13
		keybindName.TextTransparency = 0.5
		keybindName.TextTruncate = Enum.TextTruncate.AtEnd
		keybindName.TextXAlignment = Enum.TextXAlignment.Left
		keybindName.TextYAlignment = Enum.TextYAlignment.Top
		keybindName.AnchorPoint = Vector2.new(0, 0.5)
		keybindName.AutomaticSize = Enum.AutomaticSize.XY
		keybindName.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		keybindName.BackgroundTransparency = 1
		keybindName.BorderColor3 = Color3.fromRGB(0, 0, 0)
		keybindName.BorderSizePixel = 0
		keybindName.Position = UDim2.fromScale(0, 0.5)
		keybindName.Parent = keybind

		local binderBox = Instance.new("TextBox")
		binderBox.Name = "BinderBox"
		binderBox.CursorPosition = -1
		binderBox.FontFace = Font.new(assets.interFont)
		binderBox.PlaceholderText = "..."
		binderBox.Text = ""
		theme.Set(binderBox, "PlaceholderColor3", "Placeholder")
		theme.Set(binderBox, "TextColor3", "Text")
		binderBox.TextSize = 12
		binderBox.TextTransparency = 0.1
		binderBox.AnchorPoint = Vector2.new(1, 0.5)
		binderBox.AutomaticSize = Enum.AutomaticSize.X
		binderBox.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		binderBox.BackgroundTransparency = 0.95
		binderBox.BorderColor3 = Color3.fromRGB(0, 0, 0)
		binderBox.BorderSizePixel = 0
		binderBox.ClipsDescendants = true
		binderBox.LayoutOrder = 1
		binderBox.Position = UDim2.fromScale(1, 0.5)
		binderBox.Size = UDim2.fromOffset(21, 21)

		local binderBoxUICorner = Instance.new("UICorner")
		binderBoxUICorner.Name = "BinderBoxUICorner"
		binderBoxUICorner.CornerRadius = UDim.new(0, 4)
		binderBoxUICorner.Parent = binderBox

		local binderBoxUIStroke = Instance.new("UIStroke")
		binderBoxUIStroke.Name = "BinderBoxUIStroke"
		binderBoxUIStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		theme.Set(binderBoxUIStroke, "Color", "Outline")
		binderBoxUIStroke.Transparency = 0.9
		binderBoxUIStroke.Parent = binderBox

		local binderBoxUIPadding = Instance.new("UIPadding")
		binderBoxUIPadding.Name = "BinderBoxUIPadding"
		binderBoxUIPadding.PaddingLeft = UDim.new(0, 5)
		binderBoxUIPadding.PaddingRight = UDim.new(0, 5)
		binderBoxUIPadding.Parent = binderBox

		local binderBoxUISizeConstraint = Instance.new("UISizeConstraint")
		binderBoxUISizeConstraint.Name = "BinderBoxUISizeConstraint"
		binderBoxUISizeConstraint.Parent = binderBox

		binderBox.Parent = keybind

		local focused = false
		--// The press that was accepted. Only its release is reported.
		local held = false
		local heldBind = nil
		local heldNotified = false
		local heldPress = nil
		local pressSerial = 0

		local binding = createBinding({
			Default = KeybindFunctions.Settings.Default,
			Blacklist = KeybindFunctions.Settings.Blacklist,
			onBinded = function(binded)
				binderBox.Text = binded and binded.Name or ""
				KeybindFunctions.Key = binded
				if KeybindFunctions.Settings.onBinded then
					KeybindFunctions.Settings.onBinded(binded)
				end
				-- The capture is over, so the box gives the focus back. The
				-- bind can fire right away.
				binderBox:ReleaseFocus()
			end,
			onRejected = function()
				binderBox:ReleaseFocus()
			end,
		})

		KeybindFunctions.Key = binding:GetBind()

		if KeybindFunctions.Key then
			binderBox.Text = KeybindFunctions.Key.Name
		end

		--// Only a press that was accepted is released. The key is the one
		--// that was accepted, so a rebind cannot release the new key instead.
		local function endPress()
			if not held then
				return
			end
			local binded = heldBind
			local wasNotified = heldNotified
			held = false
			heldBind = nil
			heldNotified = false
			heldPress = nil
			if wasNotified and KeybindFunctions.Settings.onBindHeld then
				KeybindFunctions.Settings.onBindHeld(false, binded)
			end
		end

		binderBox.Focused:Connect(function()
			--// The capture starts, so a press that is running ends here.
			endPress()
			focused = true
			binding:StartCapture()
		end)

		binderBox.FocusLost:Connect(function()
			focused = false
			binding:StopCapture()
		end)

		local function isBound(input)
			local binded = binding:GetBind()
			if not binded then
				return false
			end
			return input.KeyCode == binded or input.UserInputType == binded
		end

		local function isHeldInput(input)
			return input.KeyCode == heldBind or input.UserInputType == heldBind
		end

		local beganConnection = UserInputService.InputBegan:Connect(function(inp, gameProcessed)
			if focused or binding:IsCapturing() then
				return
			end
			--// A dialog owns the keys of its window. Its release stays
			--// connected so a held callback ends with the key.
			if env and env.modal and env.modal:IsBlocked() then
				return
			end
			if gameProcessed then
				return
			end
			if UserInputService:GetFocusedTextBox() then
				return
			end
			if held then
				return
			end
			if not isBound(inp) then
				return
			end

			local binded = binding:GetBind()
			pressSerial += 1
			local press = pressSerial
			held = true
			heldBind = binded
			heldPress = press
			if KeybindFunctions.Settings.Callback then
				KeybindFunctions.Settings.Callback(binded)
			end
			--// A callback can rebind, focus the binder or destroy the widget.
			--// Only the press that is still accepted tells the user it is held.
			if held and heldPress == press then
				heldNotified = true
				if KeybindFunctions.Settings.onBindHeld then
					KeybindFunctions.Settings.onBindHeld(true, binded)
				end
			end
		end)

		local endedConnection = UserInputService.InputEnded:Connect(function(inp)
			if focused or binding:IsCapturing() then
				return
			end
			if not held then
				return
			end
			--// Only the release of the accepted press ends it. A release
			--// starts no press of its own, including one blocked by a dialog.
			if not isHeldInput(inp) then
				return
			end
			endPress()
		end)

		function KeybindFunctions:Bind(Key)
			--// A rebind ends a press that is running, so the accepted key is
			--// the one that is released.
			endPress()
			binding:SetBind(Key)
		end

		function KeybindFunctions:Unbind()
			endPress()
			binding:SetBind(nil)
			binderBox.Text = ""
		end

		function KeybindFunctions:GetBind()
			return binding:GetBind()
		end

		function KeybindFunctions:UpdateName(Name)
			keybindName.Text = Name
		end

		function KeybindFunctions:SetVisibility(State)
			keybind.Visible = State
		end

		function KeybindFunctions:Destroy()
			beganConnection:Disconnect()
			endedConnection:Disconnect()
			binding:Destroy()
			keybind:Destroy()
			if Flag and FractUI.Options[Flag] == KeybindFunctions then
				FractUI.Options[Flag] = nil
			end
			--// A press that is running ends with the widget.
			endPress()
		end

		if Flag then
			FractUI.Options[Flag] = KeybindFunctions
		end

		return KeybindFunctions
	end
	return Widgets
end
end function __DARKLUA_BUNDLE_MODULES.x():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.x if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.x=v end return v.c end end do local function __modImpl()
local core = __DARKLUA_BUNDLE_MODULES.c()
local theme = __DARKLUA_BUNDLE_MODULES.a()
local style = __DARKLUA_BUNDLE_MODULES.f()
local icons = __DARKLUA_BUNDLE_MODULES.d()
local cleanup = __DARKLUA_BUNDLE_MODULES.n()
local focus = __DARKLUA_BUNDLE_MODULES.l()

local FractUI = core.FractUI
local assets = core.assets
local Tween = core.Tween
local UserInputService = core.UserInputService
local LocalPlayer = core.LocalPlayer

local function cancel(tween)
	if tween and tween.Cancel then
		tween:Cancel()
	end
end

return function(section, env)
	local Widgets = {}
	function Widgets:Dropdown(Settings, Flag)
		local DropdownFunctions = { Settings = Settings, IgnoreConfig = false, Class = "Dropdown" }
		DropdownFunctions.Changed = core.NewSignal()
		local Selected = {}
		local OptionObjs = {}

		local touchLayout = UserInputService.TouchEnabled == true
		local rowHeight = touchLayout and style.Control.RowTouch or style.Control.Row
		local optionHeight = touchLayout and style.Control.OptionTouch or style.Control.Option

		local dropdown = Instance.new("Frame")
		dropdown.Name = "Dropdown"
		dropdown.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		dropdown.BackgroundTransparency = 0.985
		dropdown.BorderColor3 = Color3.fromRGB(0, 0, 0)
		dropdown.BorderSizePixel = 0
		dropdown.Size = UDim2.new(1, 0, 0, rowHeight)
		dropdown.Parent = section
		dropdown.ClipsDescendants = true

		local dropdownUIPadding = Instance.new("UIPadding")
		dropdownUIPadding.Name = "DropdownUIPadding"
		dropdownUIPadding.PaddingLeft = UDim.new(0, 15)
		dropdownUIPadding.PaddingRight = UDim.new(0, 15)
		dropdownUIPadding.Parent = dropdown

		local interact = Instance.new("TextButton")
		interact.Name = "Interact"
		interact.FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json")
		interact.Text = ""
		interact.TextColor3 = Color3.fromRGB(0, 0, 0)
		interact.TextSize = 14
		interact.AutoButtonColor = false
		interact.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		interact.BackgroundTransparency = 1
		interact.BorderColor3 = Color3.fromRGB(0, 0, 0)
		interact.BorderSizePixel = 0
		interact.Size = UDim2.new(1, 0, 0, rowHeight)
		interact.Parent = dropdown

		local interactUICorner = Instance.new("UICorner")
		interactUICorner.Name = "InteractUICorner"
		interactUICorner.CornerRadius = UDim.new(0, style.Radius.Control)
		interactUICorner.Parent = interact

		focus(interact)

		local dropdownName = Instance.new("TextLabel")
		dropdownName.Name = "DropdownName"
		dropdownName.FontFace = Font.new(assets.interFont)
		dropdownName.Text = Settings.Default and (DropdownFunctions.Settings.Name .. " • " .. table.concat(Selected, ", ")) or (DropdownFunctions.Settings.Name .. "...")
		dropdownName.RichText = true
		theme.Set(dropdownName, "TextColor3", "Text")
		dropdownName.TextSize = style.Type.Body
		dropdownName.TextTransparency = 0.1
		dropdownName.TextTruncate = Enum.TextTruncate.SplitWord
		dropdownName.TextXAlignment = Enum.TextXAlignment.Left
		dropdownName.AutomaticSize = Enum.AutomaticSize.Y
		dropdownName.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		dropdownName.BackgroundTransparency = 1
		dropdownName.BorderColor3 = Color3.fromRGB(0, 0, 0)
		dropdownName.BorderSizePixel = 0
		dropdownName.Size = UDim2.new(1, -20, 0, rowHeight)
		dropdownName.Parent = dropdown

		local dropdownUIStroke = Instance.new("UIStroke")
		dropdownUIStroke.Name = "DropdownUIStroke"
		dropdownUIStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		theme.Set(dropdownUIStroke, "Color", "Outline")
		dropdownUIStroke.Transparency = 0.95
		dropdownUIStroke.Parent = dropdown

		local dropdownUICorner = Instance.new("UICorner")
		dropdownUICorner.Name = "DropdownUICorner"
		dropdownUICorner.CornerRadius = UDim.new(0, style.Radius.Control)
		dropdownUICorner.Parent = dropdown

		local dropdownImage = Instance.new("ImageLabel")
		dropdownImage.Name = "DropdownImage"
		--// The port follows Lucide's 2022 catalog; chevron-down is in it and
		--// is rotated by 180 degrees for the open state. The verified id is
		--// the one the live fixture renders.
		dropdownImage.Image = icons.Get("lucide:chevron-down")
		theme.Set(dropdownImage, "ImageColor3", "Muted")
		dropdownImage.ImageTransparency = 0.1
		dropdownImage.AnchorPoint = Vector2.new(1, 0)
		dropdownImage.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		dropdownImage.BackgroundTransparency = 1
		dropdownImage.BorderColor3 = Color3.fromRGB(0, 0, 0)
		dropdownImage.BorderSizePixel = 0
		dropdownImage.Position = UDim2.new(1, 0, 0, (rowHeight - 14) / 2)
		dropdownImage.Size = UDim2.fromOffset(14, 14)
		dropdownImage.Parent = dropdown

		local dropdownFrame = Instance.new("Frame")
		dropdownFrame.Name = "DropdownFrame"
		dropdownFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		dropdownFrame.BackgroundTransparency = 1
		dropdownFrame.BorderColor3 = Color3.fromRGB(0, 0, 0)
		dropdownFrame.BorderSizePixel = 0
		dropdownFrame.ClipsDescendants = true
		dropdownFrame.Size = UDim2.fromScale(1, 1)
		dropdownFrame.Visible = false
		dropdownFrame.AutomaticSize = Enum.AutomaticSize.Y

		local dropdownFrameUIPadding = Instance.new("UIPadding")
		dropdownFrameUIPadding.Name = "DropdownFrameUIPadding"
		dropdownFrameUIPadding.PaddingTop = UDim.new(0, rowHeight)
		dropdownFrameUIPadding.PaddingBottom = UDim.new(0, 10)
		dropdownFrameUIPadding.Parent = dropdownFrame

		local dropdownFrameUIListLayout = Instance.new("UIListLayout")
		dropdownFrameUIListLayout.Name = "DropdownFrameUIListLayout"
		dropdownFrameUIListLayout.Padding = UDim.new(0, 5)
		dropdownFrameUIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
		dropdownFrameUIListLayout.Parent = dropdownFrame

		local search = Instance.new("Frame")
		search.Name = "Search"
		search.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		search.BackgroundTransparency = 0.95
		search.BorderColor3 = Color3.fromRGB(0, 0, 0)
		search.BorderSizePixel = 0
		search.LayoutOrder = -1
		search.Size = UDim2.new(1, 0, 0, 30)
		search.Parent = dropdownFrame
		search.Visible = DropdownFunctions.Settings.Search

		local sectionUICorner = Instance.new("UICorner")
		sectionUICorner.Name = "SectionUICorner"
		sectionUICorner.Parent = search

		local searchIcon = Instance.new("ImageLabel")
		searchIcon.Name = "SearchIcon"
		searchIcon.Image = assets.searchIcon
		theme.Set(searchIcon, "ImageColor3", "Muted")
		searchIcon.AnchorPoint = Vector2.new(0, 0.5)
		searchIcon.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		searchIcon.BackgroundTransparency = 1
		searchIcon.BorderColor3 = Color3.fromRGB(0, 0, 0)
		searchIcon.BorderSizePixel = 0
		searchIcon.Position = UDim2.fromScale(0, 0.5)
		searchIcon.Size = UDim2.fromOffset(12, 12)
		searchIcon.Parent = search

		local uIPadding = Instance.new("UIPadding")
		uIPadding.Name = "UIPadding"
		uIPadding.PaddingLeft = UDim.new(0, 15)
		uIPadding.Parent = search

		local searchBox = Instance.new("TextBox")
		searchBox.Name = "SearchBox"
		searchBox.CursorPosition = -1
		searchBox.FontFace = Font.new(
			assets.interFont,
			Enum.FontWeight.Medium,
			Enum.FontStyle.Normal
		)
		theme.Set(searchBox, "PlaceholderColor3", "Placeholder")
		searchBox.PlaceholderText = "Search..."
		searchBox.Text = ""
		theme.Set(searchBox, "TextColor3", "Muted")
		searchBox.TextSize = 14
		searchBox.TextXAlignment = Enum.TextXAlignment.Left
		searchBox.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		searchBox.BackgroundTransparency = 1
		searchBox.BorderColor3 = Color3.fromRGB(0, 0, 0)
		searchBox.BorderSizePixel = 0
		searchBox.Size = UDim2.fromScale(1, 1)

		local function CalculateDropdownSize()
			local totalHeight = 0
			local visibleChildrenCount = 0
			local padding = dropdownFrameUIPadding.PaddingTop.Offset + dropdownFrameUIPadding.PaddingBottom.Offset

			for _, v in pairs(dropdownFrame:GetChildren()) do
				if not v:IsA("UIComponent") and v.Visible then
					totalHeight += v.AbsoluteSize.Y
					visibleChildrenCount += 1
				end
			end

			local spacing = dropdownFrameUIListLayout.Padding.Offset * (visibleChildrenCount - 1)

			return totalHeight + spacing + padding
		end

		local resizeImmediate
		local dropped = false

		local function findOption()
			local searchTerm = searchBox.Text:lower()

			for _, v in pairs(OptionObjs) do
				local optionText = v.NameLabel.Text:lower()
				local isVisible = string.find(optionText, searchTerm) ~= nil

				if v.Button.Visible ~= isVisible then
					v.Button.Visible = isVisible
				end
			end

			-- A search while the list closes belongs to the next open; the
			-- closed state keeps its height and the close tween its target.
			if dropped then
				resizeImmediate()
			end
		end

		searchBox:GetPropertyChangedSignal("Text"):Connect(findOption)

		local uIPadding1 = Instance.new("UIPadding")
		uIPadding1.Name = "UIPadding"
		uIPadding1.PaddingLeft = UDim.new(0, 23)
		uIPadding1.Parent = searchBox

		searchBox.Parent = search

		local tweensettings = {
			duration = style.Motion.Control,
			easingStyle = Enum.EasingStyle.Quint,
			transparencyIn = 0,
			transparencyOut = 0.2,
			checkSizeIncrease = 12,
			checkSizeDecrease = -13,
		}

		-- A new selection replaces the tween of the same target, so the
		-- checkmark and the label of one option finish their own animation.
		local function playOptionTween(option, instance, properties)
			local tweens = option.Tweens
			if not tweens then
				tweens = {}
				option.Tweens = tweens
			end
			cancel(tweens[instance])

			local tween = Tween(instance, TweenInfo.new(tweensettings.duration, tweensettings.easingStyle), properties)
			tweens[instance] = tween
			tween:Play()
			return tween
		end

		local function Toggle(optionName, State)
			local option = OptionObjs[optionName]

			if not option then return end

			local checkmark = option.Checkmark
			local optionNameLabel = option.NameLabel

			if State then
				if DropdownFunctions.Settings.Multi then
					if not table.find(Selected, optionName) then
						table.insert(Selected, optionName)
						DropdownFunctions.Value = Selected
					end
				else
					for name, opt in pairs(OptionObjs) do
						if name ~= optionName then
							playOptionTween(opt, opt.Checkmark, {
								Size = UDim2.new(opt.Checkmark.Size.X.Scale, tweensettings.checkSizeDecrease, opt.Checkmark.Size.Y.Scale, opt.Checkmark.Size.Y.Offset)
							})
							playOptionTween(opt, opt.NameLabel, {
								TextTransparency = tweensettings.transparencyOut
							})
							opt.Checkmark.TextTransparency = 1
						end
					end
					Selected = {optionName}
					DropdownFunctions.Value = Selected[1]
				end
				playOptionTween(option, checkmark, {
					Size = UDim2.new(checkmark.Size.X.Scale, tweensettings.checkSizeIncrease, checkmark.Size.Y.Scale, checkmark.Size.Y.Offset)
				})
				playOptionTween(option, optionNameLabel, {
					TextTransparency = tweensettings.transparencyIn
				})
				checkmark.TextTransparency = 0
			else
				local selectedIndex
				if DropdownFunctions.Settings.Multi then
					selectedIndex = table.find(Selected, optionName)
				elseif Selected[1] == optionName then
					selectedIndex = 1
				end

				if selectedIndex then
					-- The last selection of a required dropdown stays.
					if DropdownFunctions.Settings.Required and #Selected <= 1 then
						return
					end

					if DropdownFunctions.Settings.Multi then
						table.remove(Selected, selectedIndex)
						DropdownFunctions.Value = Selected
					else
						Selected = {}
						DropdownFunctions.Value = nil
					end
				end

				playOptionTween(option, checkmark, {
					Size = UDim2.new(checkmark.Size.X.Scale, tweensettings.checkSizeDecrease, checkmark.Size.Y.Scale, checkmark.Size.Y.Offset)
				})
				playOptionTween(option, optionNameLabel, {
					TextTransparency = tweensettings.transparencyOut
				})
				checkmark.TextTransparency = 1
			end

			if #Selected > 0 then
				dropdownName.Text = DropdownFunctions.Settings.Name .. " • " .. table.concat(Selected, ", ")
			else
				dropdownName.Text = DropdownFunctions.Settings.Name .. "..."
			end

			DropdownFunctions.Changed:Fire()
		end

		local sizeTween
		local iconTween
		local strokeTween
		local sizeConnection
		local outsideConnection
		local headerFillTween
		local headerLabelTween
		local headerHovered = false
		local headerPressed = false

		-- The header carries the hover and the press of the open control.
		local function paintHeader()
			local fill = headerPressed and 0.88 or (headerHovered and 0.93 or 1)

			cancel(headerFillTween)
			headerFillTween = Tween(interact, TweenInfo.new(style.Motion.Fast, Enum.EasingStyle.Sine), {
				BackgroundTransparency = fill,
			})
			headerFillTween:Play()

			cancel(headerLabelTween)
			headerLabelTween = Tween(dropdownName, TweenInfo.new(style.Motion.Fast, Enum.EasingStyle.Sine), {
				TextTransparency = (headerHovered or headerPressed) and 0 or 0.1,
			})
			headerLabelTween:Play()
		end

		-- The focus stroke follows the open state and the theme.
		local function paintStroke(open)
			theme.Set(dropdownUIStroke, "Color", open and "Accent" or "Outline")
			cancel(strokeTween)
			strokeTween = Tween(dropdownUIStroke, TweenInfo.new(style.Motion.Fast, Enum.EasingStyle.Sine), {
				Transparency = open and 0.55 or 0.95,
			})
			strokeTween:Play()
		end

		-- A direct size is the new target of the open list, so the tween that
		-- still runs towards the old one is cancelled.
		resizeImmediate = function()
			cancel(sizeTween)
			sizeTween = nil
			if sizeConnection then
				sizeConnection:Disconnect()
				sizeConnection = nil
			end
			dropdown.Size = UDim2.new(1, 0, 0, CalculateDropdownSize())
		end

		local SetOpen

		local function listenOutside()
			if outsideConnection then return end
			outsideConnection = UserInputService.InputBegan:Connect(function(input)
				if not dropped then return end

				if input.UserInputType == Enum.UserInputType.Keyboard then
					if input.KeyCode == Enum.KeyCode.Escape then
						SetOpen(false)
					end
					return
				end

				if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
					return
				end

				local position = input.Position
				local origin = dropdown.AbsolutePosition
				local size = dropdown.AbsoluteSize
				local inside = position.X >= origin.X and position.X <= origin.X + size.X
					and position.Y >= origin.Y and position.Y <= origin.Y + size.Y
				if not inside then
					SetOpen(false)
				end
			end)
		end

		local function unlistenOutside()
			if outsideConnection then
				outsideConnection:Disconnect()
				outsideConnection = nil
			end
		end

		-- The listener outside belongs to the widget, so the explicit Destroy,
		-- the container and the unload of the window release it once.
		local release = cleanup({
			functions = DropdownFunctions,
			instance = dropdown,
			env = env,
			flag = Flag,
			release = function()
				unlistenOutside()
				if sizeConnection then
					sizeConnection:Disconnect()
					sizeConnection = nil
				end
				DropdownFunctions.Changed:Clear()
			end,
		})

		SetOpen = function(open)
			if open == dropped then return end
			dropped = open

			cancel(sizeTween)
			cancel(iconTween)

			if open then
				dropdownFrame.Visible = true
			end

			local targetSize = open and UDim2.new(1, 0, 0, CalculateDropdownSize()) or UDim2.new(1, 0, 0, rowHeight)
			local dropTween = Tween(dropdown, TweenInfo.new(style.Motion.Slow, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {
				Size = targetSize
			})
			sizeTween = dropTween

			if sizeConnection then
				sizeConnection:Disconnect()
				sizeConnection = nil
			end

			-- Only the close waits for its own tween. A tween that was
			-- cancelled or replaced never hides the open list.
			if not open then
				local closing = dropTween
				sizeConnection = closing.Completed:Connect(function(state)
					if state == Enum.PlaybackState.Cancelled then return end
					if dropped or sizeTween ~= closing then return end
					dropdownFrame.Visible = false
					sizeConnection:Disconnect()
					sizeConnection = nil
				end)
			end

			dropTween:Play()

			iconTween = Tween(dropdownImage, TweenInfo.new(style.Motion.Slow, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Rotation = open and 180 or 0
			})
			iconTween:Play()

			paintStroke(open)

			if open then
				listenOutside()
			else
				unlistenOutside()
			end
		end

		local function ToggleDropdown()
			SetOpen(not dropped)
		end

		interact.MouseButton1Click:Connect(ToggleDropdown)

		interact.MouseEnter:Connect(function()
			headerHovered = true
			paintHeader()
		end)
		interact.MouseLeave:Connect(function()
			headerHovered = false
			headerPressed = false
			paintHeader()
		end)
		interact.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				headerPressed = true
				paintHeader()
			end
		end)
		interact.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				headerPressed = false
				paintHeader()
			end
		end)

		local function addOption(i, v)
			local option = Instance.new("TextButton")
			option.Name = "Option"
			option.FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json")
			option.Text = ""
			option.TextColor3 = Color3.fromRGB(0, 0, 0)
			option.TextSize = 14
			option.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			option.BackgroundTransparency = 1
			option.BorderColor3 = Color3.fromRGB(0, 0, 0)
			option.BorderSizePixel = 0
			option.Size = UDim2.new(1, 0, 0, optionHeight)

			local optionUICorner = Instance.new("UICorner")
			optionUICorner.Name = "OptionUICorner"
			optionUICorner.CornerRadius = UDim.new(0, style.Radius.Control)
			optionUICorner.Parent = option

			local optionUIPadding = Instance.new("UIPadding")
			optionUIPadding.Name = "OptionUIPadding"
			optionUIPadding.PaddingLeft = UDim.new(0, 15)
			optionUIPadding.Parent = option

			local optionName = Instance.new("TextLabel")
			optionName.Name = "OptionName"
			optionName.FontFace = Font.new(assets.interFont)
			optionName.Text = v
			optionName.RichText = true
			theme.Set(optionName, "TextColor3", "Text")
			optionName.TextSize = style.Type.Body
			optionName.TextTransparency = 0.2
			optionName.TextTruncate = Enum.TextTruncate.AtEnd
			optionName.TextXAlignment = Enum.TextXAlignment.Left
			optionName.TextYAlignment = Enum.TextYAlignment.Top
			optionName.AnchorPoint = Vector2.new(0, 0.5)
			optionName.AutomaticSize = Enum.AutomaticSize.XY
			optionName.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			optionName.BackgroundTransparency = 1
			optionName.BorderColor3 = Color3.fromRGB(0, 0, 0)
			optionName.BorderSizePixel = 0
			optionName.Position = UDim2.fromScale(1.3e-07, 0.5)
			optionName.Parent = option

			local optionUIListLayout = Instance.new("UIListLayout")
			optionUIListLayout.Name = "OptionUIListLayout"
			optionUIListLayout.Padding = UDim.new(0, 10)
			optionUIListLayout.FillDirection = Enum.FillDirection.Horizontal
			optionUIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
			optionUIListLayout.VerticalAlignment = Enum.VerticalAlignment.Center
			optionUIListLayout.Parent = option

			local checkmark = Instance.new("TextLabel")
			checkmark.Name = "Checkmark"
			checkmark.FontFace = Font.new(assets.interFont)
			checkmark.Text = "✓"
			theme.Set(checkmark, "TextColor3", "Accent")
			checkmark.TextSize = style.Type.Body
			checkmark.TextTransparency = 1
			checkmark.TextXAlignment = Enum.TextXAlignment.Left
			checkmark.TextYAlignment = Enum.TextYAlignment.Top
			checkmark.AnchorPoint = Vector2.new(0, 0.5)
			checkmark.AutomaticSize = Enum.AutomaticSize.Y
			checkmark.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
			checkmark.BackgroundTransparency = 1
			checkmark.BorderColor3 = Color3.fromRGB(0, 0, 0)
			checkmark.BorderSizePixel = 0
			checkmark.LayoutOrder = -1
			checkmark.Position = UDim2.fromScale(1.3e-07, 0.5)
			checkmark.Size = UDim2.fromOffset(-10, 0)
			checkmark.Parent = option

			option.Parent = dropdownFrame

			dropdownFrame.Parent = dropdown
			OptionObjs[v] = {
				Index = i,
				Button = option,
				NameLabel = optionName,
				Checkmark = checkmark
			}

			local isSelected = false
			if DropdownFunctions.Settings.Default then
				if DropdownFunctions.Settings.Multi then
					isSelected = table.find(DropdownFunctions.Settings.Default, v) and true or false
				else
					isSelected = (DropdownFunctions.Settings.Default == i) and true or false
				end
			end
			Toggle(v, isSelected)

			local option = OptionObjs[v].Button

			-- The option carries its own hover and press fill.
			local optionHovered = false
			local optionPressed = false
			local optionFillTween

			local function paintOption()
				local fill = optionPressed and 0.88 or (optionHovered and 0.93 or 1)
				cancel(optionFillTween)
				optionFillTween = Tween(option, TweenInfo.new(style.Motion.Fast, Enum.EasingStyle.Sine), {
					BackgroundTransparency = fill,
				})
				optionFillTween:Play()
			end

			option.MouseEnter:Connect(function()
				optionHovered = true
				paintOption()
			end)
			option.MouseLeave:Connect(function()
				optionHovered = false
				optionPressed = false
				paintOption()
			end)
			option.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					optionPressed = true
					paintOption()
				end
			end)
			option.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
					optionPressed = false
					paintOption()
				end
			end)

			option.MouseButton1Click:Connect(function()
				local isSelected = table.find(Selected, v) and true or false
				local newSelected = not isSelected

				if DropdownFunctions.Settings.Required and not newSelected and #Selected <= 1 then
					return
				end

				Toggle(v, newSelected)

				task.spawn(function()
					if DropdownFunctions.Settings.Multi then
						local Return = {}
						for _, opt in ipairs(Selected) do
							Return[opt] = true
						end
						if DropdownFunctions.Settings.Callback then
							DropdownFunctions.Settings.Callback(Return)
						end

					else
						if newSelected and DropdownFunctions.Settings.Callback then
							DropdownFunctions.Settings.Callback(Selected[1] or nil)
						end
					end
				end)
			end)

			if dropped then
				resizeImmediate()
			end
		end

		if DropdownFunctions.Settings.Options then
			for i, v in pairs(DropdownFunctions.Settings.Options) do
				addOption(i, v)
			end
		end

		function DropdownFunctions:UpdateName(New)
			dropdownName.Text = New
		end
		function DropdownFunctions:SetVisibility(State)
			dropdown.Visible = State
		end
		function DropdownFunctions:UpdateSelection(newSelection)
			if not newSelection then return end

			for option, _ in pairs(OptionObjs) do
				Toggle(option, false)
			end

			local selectedOptions = {}
			if type(newSelection) == "number" then
				for option, data in pairs(OptionObjs) do
					local isSelected = data.Index == newSelection
					Toggle(option, isSelected)
					if isSelected then
						table.insert(selectedOptions, option)
					end
				end
			elseif type(newSelection) == "string" then
				for option, data in pairs(OptionObjs) do
					local isSelected = option == newSelection
					Toggle(option, isSelected)
					if isSelected then
						table.insert(selectedOptions, option)
					end
				end
			elseif type(newSelection) == "table" then
				for option, _ in pairs(OptionObjs) do
					local isSelected = table.find(newSelection, option) ~= nil
					Toggle(option, isSelected)
					if isSelected then
						table.insert(selectedOptions, option)
					end
				end
			end

			if DropdownFunctions.Settings.Callback then
				if DropdownFunctions.Settings.Multi then
					local Return = {}
					for _, opt in ipairs(selectedOptions) do
						Return[opt] = true
					end
					DropdownFunctions.Settings.Callback(Return)
				else
					DropdownFunctions.Settings.Callback(selectedOptions[1] or nil)
				end
			end
		end
		function DropdownFunctions:InsertOptions(newOptions)
			if not newOptions then return end
			DropdownFunctions.Settings.Options = newOptions
			for i, v in pairs(newOptions) do
				addOption(i, v)
			end
		end
		function DropdownFunctions:ClearOptions()
			for _, optionData in pairs(OptionObjs) do
				optionData.Button:Destroy()
			end
			OptionObjs = {}
			Selected = {}
			-- The value belongs to an option that is gone.
			DropdownFunctions.Value = nil
			DropdownFunctions.Changed:Fire()

			if dropped then
				resizeImmediate()
			end
		end
		function DropdownFunctions:GetOptions()
			local optionsStatus = {}

			for option, data in pairs(OptionObjs) do
				local isSelected = table.find(Selected, option) and true or false
				optionsStatus[option] = isSelected
			end

			return optionsStatus
		end

		function DropdownFunctions:RemoveOptions(remove)
			if not remove then return end
			for _, optionName in ipairs(remove) do
				local optionData = OptionObjs[optionName]

				if optionData then
					for i = #Selected, 1, -1 do
						if Selected[i] == optionName then
							table.remove(Selected, i)
						end
					end

					optionData.Button:Destroy()

					OptionObjs[optionName] = nil
				end
			end

			-- The value follows the options that are left.
			if DropdownFunctions.Settings.Multi then
				DropdownFunctions.Value = Selected
			else
				DropdownFunctions.Value = Selected[1]
			end
			DropdownFunctions.Changed:Fire()

			if dropped then
				resizeImmediate()
			end
		end
		function DropdownFunctions:IsOption(optionName)
			if not optionName then return end
			return OptionObjs[optionName] ~= nil
		end

		function DropdownFunctions:Destroy()
			release()
			dropdownFrame:Destroy()
			dropdown:Destroy()
		end

		if Flag then
			FractUI.Options[Flag] = DropdownFunctions
		end

		return DropdownFunctions
	end
	return Widgets
end
end function __DARKLUA_BUNDLE_MODULES.y():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.y if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.y=v end return v.c end end do local function __modImpl()
local core = __DARKLUA_BUNDLE_MODULES.c()
local theme = __DARKLUA_BUNDLE_MODULES.a()

local createColorPickerBody = __DARKLUA_BUNDLE_MODULES.p()

local FractUI = core.FractUI
local assets = core.assets
local Tween = core.Tween
local UserInputService = core.UserInputService
local LocalPlayer = core.LocalPlayer

return function(section, env)
	local Widgets = {}
	local base = env.base
	function Widgets:Colorpicker(Settings, Flag)
		local ColorpickerFunctions = { Settings = Settings, IgnoreConfig = false, Class = "Colorpicker" }
		local unloadConnection

		local isAlpha = ColorpickerFunctions.Settings.Alpha and true or false
		ColorpickerFunctions.Color = ColorpickerFunctions.Settings.Default
		ColorpickerFunctions.Alpha = isAlpha and ColorpickerFunctions.Settings.Alpha

		local colorpicker = Instance.new("Frame")
		colorpicker.Name = "Colorpicker"
		colorpicker.AutomaticSize = Enum.AutomaticSize.Y
		colorpicker.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		colorpicker.BackgroundTransparency = 1
		colorpicker.BorderColor3 = Color3.fromRGB(0, 0, 0)
		colorpicker.BorderSizePixel = 0
		colorpicker.Size = UDim2.new(1, 0, 0, 38)
		colorpicker.Parent = section

		local colorpickerName = Instance.new("TextLabel")
		colorpickerName.Name = "KeybindName"
		colorpickerName.FontFace = Font.new(assets.interFont)
		colorpickerName.Text = Settings.Name
		theme.Set(colorpickerName, "TextColor3", "Text")
		colorpickerName.TextSize = 13
		colorpickerName.TextTransparency = 0.5
		colorpickerName.RichText = true
		colorpickerName.TextTruncate = Enum.TextTruncate.AtEnd
		colorpickerName.TextXAlignment = Enum.TextXAlignment.Left
		colorpickerName.TextYAlignment = Enum.TextYAlignment.Top
		colorpickerName.AnchorPoint = Vector2.new(0, 0.5)
		colorpickerName.AutomaticSize = Enum.AutomaticSize.XY
		colorpickerName.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		colorpickerName.BackgroundTransparency = 1
		colorpickerName.BorderColor3 = Color3.fromRGB(0, 0, 0)
		colorpickerName.BorderSizePixel = 0
		colorpickerName.Position = UDim2.fromScale(0, 0.5)
		colorpickerName.Parent = colorpicker

		local colorCbg = Instance.new("ImageLabel")
		colorCbg.Name = "NewColor"
		colorCbg.Image = assets.grid
		colorCbg.ScaleType = Enum.ScaleType.Tile
		colorCbg.TileSize = UDim2.fromOffset(500, 500)
		colorCbg.AnchorPoint = Vector2.new(1, 0.5)
		colorCbg.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		colorCbg.BackgroundTransparency = 1
		colorCbg.BorderColor3 = Color3.fromRGB(0, 0, 0)
		colorCbg.BorderSizePixel = 0
		colorCbg.Position = UDim2.fromScale(1, 0.5)
		colorCbg.Size = UDim2.fromOffset(21, 21)

		local colorC = Instance.new("Frame")
		colorC.Name = "Color"
		colorC.AnchorPoint = Vector2.new(0.5, 0.5)
		colorC.BackgroundColor3 = ColorpickerFunctions.Color
		colorC.BorderSizePixel = 0
		colorC.Position = UDim2.fromScale(0.5, 0.5)
		colorC.Size = UDim2.fromScale(1, 1)
		colorC.BackgroundTransparency = ColorpickerFunctions.Alpha or 0

		local uICorner = Instance.new("UICorner")
		uICorner.Name = "UICorner"
		uICorner.CornerRadius = UDim.new(0, 6)
		uICorner.Parent = colorC

		local interact = Instance.new("TextButton")
		interact.Name = "Interact"
		interact.FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json")
		interact.Text = ""
		interact.TextColor3 = Color3.fromRGB(0, 0, 0)
		interact.TextSize = 14
		interact.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		interact.BackgroundTransparency = 1
		interact.BorderColor3 = Color3.fromRGB(0, 0, 0)
		interact.BorderSizePixel = 0
		interact.Size = UDim2.fromScale(1, 1)
		interact.Parent = colorC

		colorC.Parent = colorCbg

		local uICorner1 = Instance.new("UICorner")
		uICorner1.Name = "UICorner"
		uICorner1.CornerRadius = UDim.new(0, 8)
		uICorner1.Parent = colorCbg

		colorCbg.Parent = colorpicker

		local body = createColorPickerBody({
			base = base,
			name = Settings.Name,
			alpha = isAlpha,
			color = ColorpickerFunctions.Color,
			alphaValue = ColorpickerFunctions.Alpha or 0,
			onConfirm = function(newColor, newAlpha)
				ColorpickerFunctions.Color = newColor
				ColorpickerFunctions.Alpha = isAlpha and newAlpha or nil

				colorC.BackgroundColor3 = newColor
				colorC.BackgroundTransparency = isAlpha and newAlpha or 0

				if ColorpickerFunctions.Settings.Callback then
					task.spawn(function()
						ColorpickerFunctions.Settings.Callback(newColor, isAlpha and newAlpha or nil)
					end)
				end
			end,
		})

		interact.MouseButton1Click:Connect(function()
			body:Open()
		end)

		function ColorpickerFunctions:UpdateName(New)
			colorpickerName.Text = New
		end
		function ColorpickerFunctions:SetVisibility(State)
			colorpicker.Visible = State
		end

		function ColorpickerFunctions:SetColor(color3)
			ColorpickerFunctions.Color = color3
			colorC.BackgroundColor3 = color3

			body:SetColor(color3)

			if ColorpickerFunctions.Settings.Callback then
				task.spawn(function()
					ColorpickerFunctions.Settings.Callback(ColorpickerFunctions.Color, isAlpha and ColorpickerFunctions.Alpha or nil)
				end)
			end
		end

		function ColorpickerFunctions:SetAlpha(alpha)
			ColorpickerFunctions.Alpha = alpha
			colorC.Transparency = alpha
			body:SetAlpha(alpha)
		end

		function ColorpickerFunctions:Destroy()
			if unloadConnection then
				unloadConnection:Disconnect()
				unloadConnection = nil
			end
			body:Destroy()
			colorpicker:Destroy()
			if Flag and FractUI.Options[Flag] == ColorpickerFunctions then
				FractUI.Options[Flag] = nil
			end
		end

		-- The window releases the color picker when it unloads.
		if env and env.unloaded then
			unloadConnection = env.unloaded:Connect(function()
				ColorpickerFunctions:Destroy()
			end)
		end

		if Flag then
			FractUI.Options[Flag] = ColorpickerFunctions
		end
		return ColorpickerFunctions
	end
	return Widgets
end
end function __DARKLUA_BUNDLE_MODULES.z():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.z if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.z=v end return v.c end end do local function __modImpl()
local core = __DARKLUA_BUNDLE_MODULES.c()
local theme = __DARKLUA_BUNDLE_MODULES.a()

local FractUI = core.FractUI
local assets = core.assets
local Tween = core.Tween
local UserInputService = core.UserInputService
local LocalPlayer = core.LocalPlayer

return function(section, env)
	local Widgets = {}
	function Widgets:Header(Settings, Flag)
		local HeaderFunctions = {Settings = Settings}

		local header = Instance.new("Frame")
		header.Name = "Header"
		header.AutomaticSize = Enum.AutomaticSize.Y
		header.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		header.BackgroundTransparency = 1
		header.BorderColor3 = Color3.fromRGB(0, 0, 0)
		header.BorderSizePixel = 0
		header.LayoutOrder = 0
		header.Size = UDim2.fromScale(1, 0)
		header.Parent = section

		local uIPadding = Instance.new("UIPadding")
		uIPadding.Name = "UIPadding"
		uIPadding.PaddingBottom = UDim.new(0, 5)
		uIPadding.Parent = header

		local headerText = Instance.new("TextLabel")
		headerText.Name = "HeaderText"
		headerText.FontFace = Font.new(
			assets.interFont,
			Enum.FontWeight.Medium,
			Enum.FontStyle.Normal
		)
		headerText.RichText = true
		headerText.Text = HeaderFunctions.Settings.Text or HeaderFunctions.Settings.Name
		theme.Set(headerText, "TextColor3", "Text")
		headerText.TextSize = 16
		headerText.TextTransparency = 0.3
		headerText.TextWrapped = true
		headerText.TextXAlignment = Enum.TextXAlignment.Left
		headerText.AutomaticSize = Enum.AutomaticSize.Y
		headerText.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		headerText.BackgroundTransparency = 1
		headerText.BorderColor3 = Color3.fromRGB(0, 0, 0)
		headerText.BorderSizePixel = 0
		headerText.Size = UDim2.fromScale(1, 0)
		headerText.Parent = header

		function HeaderFunctions:UpdateName(New)
			headerText.Text = New
		end
		function HeaderFunctions:SetVisibility(State)
			header.Visible = State
		end

		if Flag then
			FractUI.Options[Flag] = HeaderFunctions
		end
		return HeaderFunctions
	end
	return Widgets
end
end function __DARKLUA_BUNDLE_MODULES.A():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.A if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.A=v end return v.c end end do local function __modImpl()
local core = __DARKLUA_BUNDLE_MODULES.c()
local theme = __DARKLUA_BUNDLE_MODULES.a()

local inlineAddons = __DARKLUA_BUNDLE_MODULES.r()

local FractUI = core.FractUI
local assets = core.assets
local Tween = core.Tween
local UserInputService = core.UserInputService
local LocalPlayer = core.LocalPlayer

return function(section, env)
	local Widgets = {}
	function Widgets:Label(Settings, Flag)
		local LabelFunctions = {Settings = Settings}

		local rail = { Cursor = 9, Reserved = 0 }

		local label = Instance.new("Frame")
		label.Name = "Label"
		label.AutomaticSize = Enum.AutomaticSize.Y
		label.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		label.BackgroundTransparency = 1
		label.BorderColor3 = Color3.fromRGB(0, 0, 0)
		label.BorderSizePixel = 0
		label.Size = UDim2.new(1, 0, 0, 38)
		label.Parent = section

		local labelText = Instance.new("TextLabel")
		labelText.Name = "LabelText"
		labelText.FontFace = Font.new(assets.interFont)
		labelText.RichText = true
		labelText.Text = LabelFunctions.Settings.Text or LabelFunctions.Settings.Name -- Settings.Name Deprecated use Settings.Text
		theme.Set(labelText, "TextColor3", "Text")
		labelText.TextSize = 13
		labelText.TextTransparency = 0.5
		labelText.TextWrapped = true
		labelText.TextXAlignment = Enum.TextXAlignment.Left
		labelText.AutomaticSize = Enum.AutomaticSize.Y
		labelText.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		labelText.BackgroundTransparency = 1
		labelText.BorderColor3 = Color3.fromRGB(0, 0, 0)
		labelText.BorderSizePixel = 0
		labelText.Size = UDim2.new(1, -rail.Reserved, 1, 0)
		labelText.Parent = label

		function LabelFunctions:UpdateName(New)
			labelText.Text = New
		end
		function LabelFunctions:SetVisibility(State)
			label.Visible = State
		end

		function LabelFunctions:Destroy()
			if LabelFunctions.DestroyAddons then
				LabelFunctions.DestroyAddons()
			end
			label:Destroy()
			if Flag and FractUI.Options[Flag] == LabelFunctions then
				FractUI.Options[Flag] = nil
			end
		end

		inlineAddons({
			Functions = LabelFunctions,
			env = env,
			parent = label,
			rail = rail,
			Resize = function(Reserved)
				labelText.Size = UDim2.new(1, -Reserved, 1, 0)
			end,
		})

		if Flag then
			FractUI.Options[Flag] = LabelFunctions
		end
		return LabelFunctions
	end
	return Widgets
end
end function __DARKLUA_BUNDLE_MODULES.B():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.B if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.B=v end return v.c end end do local function __modImpl()
local core = __DARKLUA_BUNDLE_MODULES.c()
local theme = __DARKLUA_BUNDLE_MODULES.a()

local FractUI = core.FractUI
local assets = core.assets
local Tween = core.Tween
local UserInputService = core.UserInputService
local LocalPlayer = core.LocalPlayer

return function(section, env)
	local Widgets = {}
	function Widgets:SubLabel(Settings, Flag)
		local SubLabelFunctions = {Settings = Settings}

		local subLabel = Instance.new("Frame")
		subLabel.Name = "SubLabel"
		subLabel.AutomaticSize = Enum.AutomaticSize.Y
		subLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		subLabel.BackgroundTransparency = 1
		subLabel.BorderColor3 = Color3.fromRGB(0, 0, 0)
		subLabel.BorderSizePixel = 0
		subLabel.Size = UDim2.new(1, 0, 0, 0)
		subLabel.Parent = section

		local subLabelText = Instance.new("TextLabel")
		subLabelText.Name = "SubLabelText"
		subLabelText.FontFace = Font.new(assets.interFont)
		subLabelText.RichText = true
		subLabelText.Text = SubLabelFunctions.Settings.Text or SubLabelFunctions.Settings.Name -- Settings.Name Deprecated use Settings.Text
		--// Muted at 0.1 keeps the 12 pixel caption above 4.5:1 on both the
		--// background and the surface of the default palettes.
		theme.Set(subLabelText, "TextColor3", "Muted")
		subLabelText.TextSize = 12
		subLabelText.TextTransparency = 0.1
		subLabelText.TextWrapped = true
		subLabelText.TextXAlignment = Enum.TextXAlignment.Left
		subLabelText.AutomaticSize = Enum.AutomaticSize.Y
		subLabelText.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		subLabelText.BackgroundTransparency = 1
		subLabelText.BorderColor3 = Color3.fromRGB(0, 0, 0)
		subLabelText.BorderSizePixel = 0
		subLabelText.Size = UDim2.fromScale(1, 1)
		subLabelText.Parent = subLabel

		function SubLabelFunctions:UpdateName(New)
			subLabelText.Text = New
		end
		function SubLabelFunctions:SetVisibility(State)
			subLabel.Visible = State
		end

		if Flag then
			FractUI.Options[Flag] = SubLabelFunctions
		end
		return SubLabelFunctions
	end
	return Widgets
end
end function __DARKLUA_BUNDLE_MODULES.C():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.C if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.C=v end return v.c end end do local function __modImpl()
local core = __DARKLUA_BUNDLE_MODULES.c()
local theme = __DARKLUA_BUNDLE_MODULES.a()

local FractUI = core.FractUI
local assets = core.assets
local Tween = core.Tween
local UserInputService = core.UserInputService
local LocalPlayer = core.LocalPlayer

return function(section, env)
	local Widgets = {}
	function Widgets:Paragraph(Settings, Flag)
		local ParagraphFunctions = {Settings = Settings}

		local paragraph = Instance.new("Frame")
		paragraph.Name = "Paragraph"
		paragraph.AutomaticSize = Enum.AutomaticSize.Y
		paragraph.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		paragraph.BackgroundTransparency = 1
		paragraph.BorderColor3 = Color3.fromRGB(0, 0, 0)
		paragraph.BorderSizePixel = 0
		paragraph.Size = UDim2.new(1, 0, 0, 38)
		paragraph.Parent = section

		local paragraphHeader = Instance.new("TextLabel")
		paragraphHeader.Name = "ParagraphHeader"
		paragraphHeader.FontFace = Font.new(
			assets.interFont,
			Enum.FontWeight.Medium,
			Enum.FontStyle.Normal
		)
		paragraphHeader.RichText = true
		paragraphHeader.Text = ParagraphFunctions.Settings.Header
		theme.Set(paragraphHeader, "TextColor3", "Text")
		paragraphHeader.TextSize = 15
		paragraphHeader.TextTransparency = 0.4
		paragraphHeader.TextWrapped = true
		paragraphHeader.TextXAlignment = Enum.TextXAlignment.Left
		paragraphHeader.AutomaticSize = Enum.AutomaticSize.Y
		paragraphHeader.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		paragraphHeader.BackgroundTransparency = 1
		paragraphHeader.BorderColor3 = Color3.fromRGB(0, 0, 0)
		paragraphHeader.BorderSizePixel = 0
		paragraphHeader.Size = UDim2.fromScale(1, 0)
		paragraphHeader.Parent = paragraph

		local uIListLayout = Instance.new("UIListLayout")
		uIListLayout.Name = "UIListLayout"
		uIListLayout.Padding = UDim.new(0, 5)
		uIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
		uIListLayout.Parent = paragraph

		local paragraphBody = Instance.new("TextLabel")
		paragraphBody.Name = "ParagraphBody"
		paragraphBody.FontFace = Font.new(assets.interFont)
		paragraphBody.RichText = true
		paragraphBody.Text = ParagraphFunctions.Settings.Body
		theme.Set(paragraphBody, "TextColor3", "Text")
		paragraphBody.TextSize = 13
		paragraphBody.TextTransparency = 0.5
		paragraphBody.TextWrapped = true
		paragraphBody.TextXAlignment = Enum.TextXAlignment.Left
		paragraphBody.AutomaticSize = Enum.AutomaticSize.Y
		paragraphBody.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		paragraphBody.BackgroundTransparency = 1
		paragraphBody.BorderColor3 = Color3.fromRGB(0, 0, 0)
		paragraphBody.BorderSizePixel = 0
		paragraphBody.LayoutOrder = 1
		paragraphBody.Size = UDim2.fromScale(1, 0)
		paragraphBody.Parent = paragraph

		function ParagraphFunctions:UpdateHeader(New)
			paragraphHeader.Text = New
		end
		function ParagraphFunctions:UpdateBody(New)
			paragraphBody.Text = New
		end
		function ParagraphFunctions:SetVisibility(State)
			paragraph.Visible = State
		end

		if Flag then
			FractUI.Options[Flag] = ParagraphFunctions
		end
		return ParagraphFunctions
	end
	return Widgets
end
end function __DARKLUA_BUNDLE_MODULES.D():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.D if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.D=v end return v.c end end do local function __modImpl()
local core = __DARKLUA_BUNDLE_MODULES.c()
local theme = __DARKLUA_BUNDLE_MODULES.a()

local FractUI = core.FractUI
local assets = core.assets
local Tween = core.Tween
local UserInputService = core.UserInputService
local LocalPlayer = core.LocalPlayer

return function(section, env)
	local Widgets = {}
	function Widgets:Divider()
		local DividerFunctions = {}

		local divider = Instance.new("Frame")
		divider.Name = "Divider"
		divider.AnchorPoint = Vector2.new(0, 1)
		divider.AutomaticSize = Enum.AutomaticSize.Y
		divider.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		divider.BackgroundTransparency = 1
		divider.BorderColor3 = Color3.fromRGB(0, 0, 0)
		divider.BorderSizePixel = 0
		divider.Position = UDim2.fromScale(0, 1)
		divider.Size = UDim2.new(1, 0, 0, 1)
		divider.Parent = section

		local uIPadding = Instance.new("UIPadding")
		uIPadding.Name = "UIPadding"
		uIPadding.PaddingBottom = UDim.new(0, 8)
		uIPadding.PaddingTop = UDim.new(0, 8)
		uIPadding.Parent = divider

		local uIListLayout = Instance.new("UIListLayout")
		uIListLayout.Name = "UIListLayout"
		uIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
		uIListLayout.Parent = divider

		local line = Instance.new("Frame")
		line.Name = "Line"
		theme.Set(line, "BackgroundColor3", "Outline")
		line.BackgroundTransparency = 0.9
		line.BorderColor3 = Color3.fromRGB(0, 0, 0)
		line.BorderSizePixel = 0
		line.Size = UDim2.new(1, 0, 0, 1)
		line.Parent = divider

		function DividerFunctions:Remove()
			divider:Destroy()
		end
		function DividerFunctions:SetVisibility(State)
			divider.Visible = State
		end

		return DividerFunctions
	end
	return Widgets
end
end function __DARKLUA_BUNDLE_MODULES.E():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.E if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.E=v end return v.c end end do local function __modImpl()
local core = __DARKLUA_BUNDLE_MODULES.c()

local FractUI = core.FractUI
local assets = core.assets
local Tween = core.Tween
local UserInputService = core.UserInputService
local LocalPlayer = core.LocalPlayer

return function(section, env)
	local Widgets = {}
	function Widgets:Spacer()
		local SpacerFunctions = {}

		local spacer = Instance.new("Frame")
		spacer.Name = "Spacer"
		spacer.AnchorPoint = Vector2.new(0, 1)
		spacer.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		spacer.BackgroundTransparency = 1
		spacer.BorderColor3 = Color3.fromRGB(0, 0, 0)
		spacer.BorderSizePixel = 0
		spacer.Position = UDim2.fromScale(0, 1)
		spacer.Parent = section

		function SpacerFunctions:Remove()
			spacer:Destroy()
		end
		function SpacerFunctions:SetVisibility(State)
			spacer.Visible = State
		end

		return SpacerFunctions
	end
	return Widgets
end
end function __DARKLUA_BUNDLE_MODULES.F():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.F if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.F=v end return v.c end end do local function __modImpl()
local core = __DARKLUA_BUNDLE_MODULES.c()
local theme = __DARKLUA_BUNDLE_MODULES.a()
local icons = __DARKLUA_BUNDLE_MODULES.d()
local cleanup = __DARKLUA_BUNDLE_MODULES.n()

local FractUI = core.FractUI
local assets = core.assets

return function(section, env)
	local Widgets = {}
	function Widgets:Image(Settings, Flag)
		local ImageFunctions = { Settings = Settings, IgnoreConfig = true, Class = "Image" }

		local Height = Settings.Height or 200
		local Image = Settings.Image or ""

		local image = Instance.new("Frame")
		image.Name = "Image"
		image.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		image.BackgroundTransparency = 1
		image.BorderColor3 = Color3.fromRGB(0, 0, 0)
		image.BorderSizePixel = 0
		image.ClipsDescendants = true
		image.Size = UDim2.new(1, 0, 0, Height)
		image.Parent = section

		local content = Instance.new("ImageLabel")
		content.Name = "ImageContent"
		content.Image = icons.Get(Image)
		content.ImageColor3 = Settings.Color or Color3.fromRGB(255, 255, 255)
		content.ImageTransparency = Settings.Transparency or 0
		content.ScaleType = Settings.ScaleType or Enum.ScaleType.Fit
		content.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		content.BackgroundTransparency = 1
		content.BorderColor3 = Color3.fromRGB(0, 0, 0)
		content.BorderSizePixel = 0
		content.Size = UDim2.fromScale(1, 1)
		content.Parent = image

		local contentUICorner = Instance.new("UICorner")
		contentUICorner.Name = "ImageContentUICorner"
		contentUICorner.CornerRadius = UDim.new(0, 4)
		contentUICorner.Parent = content

		local contentUIStroke = Instance.new("UIStroke")
		contentUIStroke.Name = "ImageContentUIStroke"
		contentUIStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		theme.Set(contentUIStroke, "Color", "Outline")
		contentUIStroke.Transparency = 0.9
		contentUIStroke.Parent = content

		-- The image releases its flag when it ends, no matter how it ends.
		local release = cleanup({
			functions = ImageFunctions,
			instance = image,
			env = env,
			flag = Flag,
		})

		function ImageFunctions:SetImage(NewImage)
			Image = NewImage
			content.Image = icons.Get(NewImage)
		end
		function ImageFunctions:GetImage()
			return Image
		end
		function ImageFunctions:SetHeight(NewHeight)
			Height = NewHeight
			image.Size = UDim2.new(1, 0, 0, NewHeight)
		end
		function ImageFunctions:GetHeight()
			return Height
		end
		function ImageFunctions:SetColor(NewColor)
			content.ImageColor3 = NewColor
		end
		function ImageFunctions:SetTransparency(NewTransparency)
			content.ImageTransparency = NewTransparency
		end
		function ImageFunctions:SetScaleType(NewScaleType)
			-- The engine only takes a member of its enum, so anything else is
			-- refused instead of breaking the label.
			if typeof(NewScaleType) ~= "EnumItem" or NewScaleType.EnumType ~= Enum.ScaleType then
				return false, "The scale type is not a member of Enum.ScaleType."
			end
			content.ScaleType = NewScaleType
			return true
		end
		function ImageFunctions:SetVisibility(State)
			image.Visible = State
		end
		function ImageFunctions:Destroy()
			release()
			image:Destroy()
		end

		if Flag then
			FractUI.Options[Flag] = ImageFunctions
		end
		return ImageFunctions
	end
	return Widgets
end
end function __DARKLUA_BUNDLE_MODULES.G():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.G if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.G=v end return v.c end end do local function __modImpl()
local core = __DARKLUA_BUNDLE_MODULES.c()
local theme = __DARKLUA_BUNDLE_MODULES.a()
local cleanup = __DARKLUA_BUNDLE_MODULES.n()

local FractUI = core.FractUI
local assets = core.assets

return function(section, env)
	local Widgets = {}
	function Widgets:Video(Settings, Flag)
		local VideoFunctions = { Settings = Settings, IgnoreConfig = true, Class = "Video" }

		local Height = Settings.Height or 200
		local Video = Settings.Video or ""
		local Looped = Settings.Looped and true or false
		local Playing = Settings.Playing and true or false
		local Volume = Settings.Volume or 1

		local video = Instance.new("Frame")
		video.Name = "Video"
		video.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		video.BackgroundTransparency = 1
		video.BorderColor3 = Color3.fromRGB(0, 0, 0)
		video.BorderSizePixel = 0
		video.ClipsDescendants = true
		video.Size = UDim2.new(1, 0, 0, Height)
		video.Parent = section

		local content = Instance.new("VideoFrame")
		content.Name = "VideoContent"
		content.Looped = Looped
		content.Volume = Volume
		content.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		content.BackgroundTransparency = 1
		content.BorderColor3 = Color3.fromRGB(0, 0, 0)
		content.BorderSizePixel = 0
		content.Size = UDim2.fromScale(1, 1)
		content.Parent = video

		local contentUICorner = Instance.new("UICorner")
		contentUICorner.Name = "VideoContentUICorner"
		contentUICorner.CornerRadius = UDim.new(0, 4)
		contentUICorner.Parent = content

		local contentUIStroke = Instance.new("UIStroke")
		contentUIStroke.Name = "VideoContentUIStroke"
		contentUIStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		theme.Set(contentUIStroke, "Color", "Outline")
		contentUIStroke.Transparency = 0.9
		contentUIStroke.Parent = content

		content.Video = Video
		content.Playing = Playing

		-- The video releases its flag when it ends, no matter how it ends.
		local release = cleanup({
			functions = VideoFunctions,
			instance = video,
			env = env,
			flag = Flag,
		})

		function VideoFunctions:Play()
			Playing = true
			content.Playing = true
		end
		function VideoFunctions:Pause()
			Playing = false
			content.Playing = false
		end
		function VideoFunctions:IsPlaying()
			return Playing
		end
		function VideoFunctions:SetVideo(NewVideo)
			Video = NewVideo
			content.Video = NewVideo
		end
		function VideoFunctions:GetVideo()
			return Video
		end
		function VideoFunctions:SetLooped(State)
			Looped = State and true or false
			content.Looped = Looped
		end
		function VideoFunctions:IsLooped()
			return Looped
		end
		function VideoFunctions:SetVolume(NewVolume)
			-- The engine only takes a volume of its own range, so anything
			-- else is refused instead of breaking the frame.
			if type(NewVolume) ~= "number" or NewVolume < 0 or NewVolume > 10 then
				return false, "The volume of a video is a number between 0 and 10."
			end
			Volume = NewVolume
			content.Volume = NewVolume
			return true
		end
		function VideoFunctions:GetVolume()
			return Volume
		end
		function VideoFunctions:SetHeight(NewHeight)
			Height = NewHeight
			video.Size = UDim2.new(1, 0, 0, NewHeight)
		end
		function VideoFunctions:GetHeight()
			return Height
		end
		function VideoFunctions:SetVisibility(State)
			video.Visible = State
		end
		function VideoFunctions:Destroy()
			release()
			video:Destroy()
		end

		if Flag then
			FractUI.Options[Flag] = VideoFunctions
		end
		return VideoFunctions
	end
	return Widgets
end
end function __DARKLUA_BUNDLE_MODULES.H():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.H if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.H=v end return v.c end end do local function __modImpl()
local core = __DARKLUA_BUNDLE_MODULES.c()
local theme = __DARKLUA_BUNDLE_MODULES.a()
local cleanup = __DARKLUA_BUNDLE_MODULES.n()

local FractUI = core.FractUI
local assets = core.assets
local UserInputService = core.UserInputService

return function(section, env)
	local Widgets = {}
	function Widgets:Viewport(Settings, Flag)
		local ViewportFunctions = { Settings = Settings, IgnoreConfig = true, Class = "Viewport" }

		local Height = Settings.Height or 200
		local Interactive = Settings.Interactive and true or false
		local AutoFocus = Settings.AutoFocus ~= false
		local Camera = Settings.Camera or Instance.new("Camera")

		local viewport = Instance.new("Frame")
		viewport.Name = "Viewport"
		viewport.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		viewport.BackgroundTransparency = 1
		viewport.BorderColor3 = Color3.fromRGB(0, 0, 0)
		viewport.BorderSizePixel = 0
		viewport.ClipsDescendants = true
		viewport.Size = UDim2.new(1, 0, 0, Height)
		viewport.Parent = section

		local content = Instance.new("ViewportFrame")
		content.Name = "ViewportContent"
		content.Active = Interactive
		content.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		content.BackgroundTransparency = 1
		content.BorderColor3 = Color3.fromRGB(0, 0, 0)
		content.BorderSizePixel = 0
		content.CurrentCamera = Camera
		content.Size = UDim2.fromScale(1, 1)
		content.Parent = viewport

		local contentUICorner = Instance.new("UICorner")
		contentUICorner.Name = "ViewportContentUICorner"
		contentUICorner.CornerRadius = UDim.new(0, 4)
		contentUICorner.Parent = content

		local contentUIStroke = Instance.new("UIStroke")
		contentUIStroke.Name = "ViewportContentUIStroke"
		contentUIStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		theme.Set(contentUIStroke, "Color", "Outline")
		contentUIStroke.Transparency = 0.9
		contentUIStroke.Parent = content

		local Object = nil
		-- The object of the caller. The viewport shows a copy of it, so the
		-- original never enters the tree of the interface and can never be
		-- destroyed with it.
		local SourceObject = nil

		local center = Vector3.new(0, 0, 0)
		local distance = 10
		local yaw = 0
		local pitch = 0

		local function applyCamera()
			local offset = Vector3.new(
				math.sin(yaw) * math.cos(pitch) * distance,
				math.sin(pitch) * distance,
				math.cos(yaw) * math.cos(pitch) * distance
			)
			Camera.CFrame = CFrame.new(center + offset, center)
		end

		local function getModelSize(model)
			if model:IsA("BasePart") then
				return model.Size
			end
			local _, boundingSize = model:GetBoundingBox()
			return boundingSize
		end

		--// The distance and the middle that the camera needs to look at an
		--// object. They are known before the object is shown.
		local function focusValues(ObjectToFocus)
			local size = getModelSize(ObjectToFocus)
			local maxExtent = math.max(size.X, size.Y, size.Z)
			return maxExtent * 2, ObjectToFocus:GetPivot().Position
		end

		local function focusCamera()
			if not Object then
				return
			end

			local ok, newDistance, newCenter = pcall(focusValues, Object)
			if not ok then
				return
			end

			distance = newDistance
			center = newCenter
			yaw = 0
			pitch = 0
			applyCamera()
		end

		--// Copies the object of the caller. The flag of the original belongs
		--// to the original, so it is put back even when the copy failed.
		local function cloneObject(NewObject)
			local wasArchivable = NewObject.Archivable
			local ok, clone = pcall(function()
				if not wasArchivable then
					NewObject.Archivable = true
				end
				return NewObject:Clone()
			end)
			NewObject.Archivable = wasArchivable
			if not ok then
				return nil, "The object could not be copied: " .. tostring(clone)
			end
			if typeof(clone) ~= "Instance" then
				return nil, "The object could not be copied."
			end
			return clone
		end

		local function releaseObject()
			if not Object then
				return
			end
			Object:Destroy()
			Object = nil
			SourceObject = nil
		end

		local function refuse(message)
			if env and env.window and env.window.Notify then
				env.window:Notify({ Title = "Viewport", Description = message })
			end
		end

		local function attachObject(NewObject, Clone)
			if typeof(NewObject) ~= "Instance" then
				refuse("The viewport shows a part or a model.")
				return false, "The viewport shows a part or a model."
			end
			if Clone == false then
				-- A caller owned object would be destroyed with the interface.
				refuse("The viewport shows a copy of the object, the original stays where it is.")
				return false, "The viewport shows a copy of the object, the original stays where it is."
			end
			if not (NewObject:IsA("BasePart") or NewObject:IsA("Model")) then
				refuse("The viewport shows a part or a model.")
				return false, "The viewport shows a part or a model."
			end

			local copy, message = cloneObject(NewObject)
			if not copy then
				refuse(message)
				return false, message
			end

			-- The copy is in the viewport now, the object that is shown is
			-- released when everything is ready.
			copy.Parent = content

			local newDistance, newCenter
			if AutoFocus then
				local ok, extent, middle = pcall(focusValues, copy)
				if not ok then
					copy:Destroy()
					refuse("The object has no size, so the camera cannot look at it.")
					return false, "The object has no size, so the camera cannot look at it."
				end
				newDistance = extent
				newCenter = middle
			end

			-- Everything is ready, so the object that is shown can go.
			releaseObject()
			Object = copy
			SourceObject = NewObject

			if AutoFocus then
				distance = newDistance
				center = newCenter
				yaw = 0
				pitch = 0
				applyCamera()
			end

			return true
		end

		if Settings.Object then
			attachObject(Settings.Object, Settings.Clone)
		else
			applyCamera()
		end

		local dragging = false
		local lastPosition = Vector2.new(0, 0)
		local dragGeneration

		local function cancelDrag()
			dragging = false
			dragGeneration = nil
		end

		content.InputBegan:Connect(function(input)
			if not Interactive then
				return
			end
			if env.modal and env.modal:IsBlocked() then
				return
			end
			if input.UserInputType == Enum.UserInputType.MouseButton2 or input.UserInputType == Enum.UserInputType.Touch then
				dragging = true
				lastPosition = input.Position
				dragGeneration = env.modal and env.modal:GetGeneration() or nil
			end
		end)

		content.InputEnded:Connect(function(input)
			if not Interactive then
				return
			end
			cancelDrag()
		end)

		content.InputChanged:Connect(function(input)
			if not Interactive then
				return
			end
			if input.UserInputType == Enum.UserInputType.MouseWheel then
				distance = math.clamp(distance + input.Position.Z * 2, 1, 1000)
				applyCamera()
			end
		end)

		local inputConnection = UserInputService.InputChanged:Connect(function(input)
			--// A dialog can open during this drag. The gesture is cancelled
			--// without moving the camera, and the old generation cannot start
			--// it again after the dialog closes.
			if env.modal and (env.modal:IsBlocked() or (dragging and dragGeneration ~= env.modal:GetGeneration())) then
				cancelDrag()
				return
			end
			if not Interactive or not dragging then
				return
			end
			if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
				local delta = input.Position - lastPosition
				lastPosition = input.Position

				yaw = yaw - delta.X * 0.01
				pitch = math.clamp(pitch + delta.Y * 0.01, -1.4, 1.4)
				applyCamera()
			end
		end)

		function ViewportFunctions:SetObject(NewObject, Clone)
			if typeof(NewObject) ~= "Instance" then
				return false
			end
			return attachObject(NewObject, Clone)
		end

		function ViewportFunctions:GetObject()
			return Object
		end

		-- The object of the caller. The viewport shows a copy of it.
		function ViewportFunctions:GetSourceObject()
			return SourceObject
		end

		function ViewportFunctions:SetCamera(NewCamera)
			-- The frame of the engine only takes a camera, so anything else is
			-- refused and the camera of the viewport stays.
			if typeof(NewCamera) ~= "Instance" or not NewCamera:IsA("Camera") then
				local message = "The viewport needs a camera."
				refuse(message)
				return false, message
			end
			Camera = NewCamera
			content.CurrentCamera = NewCamera
			return true
		end

		function ViewportFunctions:GetCamera()
			return Camera
		end

		function ViewportFunctions:Focus()
			focusCamera()
		end

		function ViewportFunctions:SetInteractive(State)
			Interactive = State and true or false
			content.Active = Interactive
		end

		function ViewportFunctions:IsInteractive()
			return Interactive
		end

		function ViewportFunctions:SetHeight(NewHeight)
			Height = NewHeight
			viewport.Size = UDim2.new(1, 0, 0, NewHeight)
		end

		function ViewportFunctions:GetHeight()
			return Height
		end

		function ViewportFunctions:SetVisibility(State)
			viewport.Visible = State
		end

		-- The viewport releases its connections and its copy when it ends, no
		-- matter how it ends.
		local release = cleanup({
			functions = ViewportFunctions,
			instance = viewport,
			env = env,
			flag = Flag,
			release = function()
				inputConnection:Disconnect()
				releaseObject()
			end,
		})

		function ViewportFunctions:Destroy()
			release()
			viewport:Destroy()
		end

		if Flag then
			FractUI.Options[Flag] = ViewportFunctions
		end
		return ViewportFunctions
	end
	return Widgets
end
end function __DARKLUA_BUNDLE_MODULES.I():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.I if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.I=v end return v.c end end do local function __modImpl()
local core = __DARKLUA_BUNDLE_MODULES.c()
local cleanup = __DARKLUA_BUNDLE_MODULES.n()

local FractUI = core.FractUI
local assets = core.assets

return function(section, env)
	local Widgets = {}
	function Widgets:UIPassthrough(Settings, Flag)
		local PassthroughFunctions = { Settings = Settings, IgnoreConfig = true, Class = "UIPassthrough" }

		local Height = Settings.Height or 24
		-- The instance of the caller and the copy the interface shows.
		local Passed = Settings.Instance
		local Display = nil

		local passthrough = Instance.new("Frame")
		passthrough.Name = "UIPassthrough"
		passthrough.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		passthrough.BackgroundTransparency = 1
		passthrough.BorderColor3 = Color3.fromRGB(0, 0, 0)
		passthrough.BorderSizePixel = 0
		passthrough.Size = UDim2.new(1, 0, 0, Height)
		passthrough.Parent = section

		local holder = Instance.new("Frame")
		holder.Name = "UIPassthroughHolder"
		holder.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		holder.BackgroundTransparency = 1
		holder.BorderColor3 = Color3.fromRGB(0, 0, 0)
		holder.BorderSizePixel = 0
		holder.ClipsDescendants = true
		holder.Size = UDim2.fromScale(1, 1)
		holder.Parent = passthrough

		-- The instance of the caller never enters the tree of the interface,
		-- so the interface can never destroy it. The holder shows a copy of
		-- it, so the copy has to be released with the passthrough.
		local function release()
			if not Display then
				return
			end
			Display:Destroy()
			Display = nil
		end

		local function refuse(message)
			if env and env.window and env.window.Notify then
				env.window:Notify({ Title = "UIPassthrough", Description = message })
			end
		end

		--// Copies the instance of the caller. An instance that cannot be
		--// copied has no copy, so the copy that is shown stays.
		local function copyOf(InstanceToCopy)
			local ok, copy = pcall(function()
				return InstanceToCopy:Clone()
			end)
			if not ok then
				return nil, "The instance could not be copied: " .. tostring(copy)
			end
			if typeof(copy) ~= "Instance" then
				return nil, "The instance could not be copied, it is not archivable."
			end
			if not copy:IsA("GuiObject") then
				copy:Destroy()
				return nil, "The instance is not an object of the interface."
			end
			return copy
		end

		--// Shows the copy of an instance. The copy that is shown stays when
		--// the new one cannot be made.
		local function show(NewInstance)
			if typeof(NewInstance) ~= "Instance" then
				return false, "The instance is not an object of Roblox."
			end
			local copy, message = copyOf(NewInstance)
			if not copy then
				return false, message
			end
			-- The copy is ready, so the copy that is shown can go.
			release()
			Display = copy
			Display.Parent = holder
			return true
		end

		if Passed then
			local shown, showMessage = show(Passed)
			if not shown then
				refuse(showMessage)
			end
		end

		function PassthroughFunctions:SetInstance(NewInstance)
			local shown, message = show(NewInstance)
			if not shown then
				return false, message
			end
			Passed = NewInstance
			return true
		end

		function PassthroughFunctions:GetInstance()
			return Passed
		end

		-- The copy the interface shows.
		function PassthroughFunctions:GetDisplayInstance()
			return Display
		end

		function PassthroughFunctions:SetHeight(NewHeight)
			Height = NewHeight
			passthrough.Size = UDim2.new(1, 0, 0, NewHeight)
		end

		function PassthroughFunctions:GetHeight()
			return Height
		end

		function PassthroughFunctions:SetVisibility(State)
			passthrough.Visible = State
		end

		-- The passthrough releases the copy it shows when it ends, no matter
		-- how it ends.
		local releasePassthrough = cleanup({
			functions = PassthroughFunctions,
			instance = passthrough,
			env = env,
			flag = Flag,
			release = release,
		})

		function PassthroughFunctions:Destroy()
			releasePassthrough()
			passthrough:Destroy()
		end

		if Flag then
			FractUI.Options[Flag] = PassthroughFunctions
		end
		return PassthroughFunctions
	end
	return Widgets
end
end function __DARKLUA_BUNDLE_MODULES.J():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.J if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.J=v end return v.c end end do local function __modImpl()
local core = __DARKLUA_BUNDLE_MODULES.c()
local cleanup = __DARKLUA_BUNDLE_MODULES.n()

local FractUI = core.FractUI
local assets = core.assets

--// A horizontal row of the normal widgets. The widgets share the width of the
--// section they live in, so a row never overflows its parent.
return function(section, env, factories)
	local Widgets = {}
	function Widgets:Row(Settings, Flag)
		local RowFunctions = { Settings = Settings, IgnoreConfig = true, Class = "Row" }

		local Height = Settings.Height or 38
		local Padding = Settings.Padding or 8
		local children = {}

		local row = Instance.new("Frame")
		row.Name = "Row"
		row.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		row.BackgroundTransparency = 1
		row.BorderColor3 = Color3.fromRGB(0, 0, 0)
		row.BorderSizePixel = 0
		row.Size = UDim2.new(1, 0, 0, Height)
		row.Parent = section

		local content = Instance.new("Frame")
		content.Name = "RowContent"
		content.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		content.BackgroundTransparency = 1
		content.BorderColor3 = Color3.fromRGB(0, 0, 0)
		content.BorderSizePixel = 0
		content.Size = UDim2.fromScale(1, 1)
		content.Parent = row

		local rowUIListLayout = Instance.new("UIListLayout")
		rowUIListLayout.Name = "RowUIListLayout"
		rowUIListLayout.FillDirection = Enum.FillDirection.Horizontal
		rowUIListLayout.HorizontalFlex = Enum.UIFlexAlignment.Fill
		rowUIListLayout.Padding = UDim.new(0, Padding)
		rowUIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
		rowUIListLayout.VerticalAlignment = Enum.VerticalAlignment.Center
		rowUIListLayout.Parent = content

		for _, factory in ipairs(factories) do
			for name, method in pairs(factory(content, env, factories)) do
				local widgetMethod = method
				-- The row owns the widgets it creates and releases them with itself.
				RowFunctions[name] = function(_, ...)
					local widget = widgetMethod(_, ...)
					table.insert(children, widget)
					return widget
				end
			end
		end

		-- The row releases its widgets when it ends, no matter how it ends.
		local release = cleanup({
			functions = RowFunctions,
			instance = row,
			env = env,
			flag = Flag,
			release = function()
				for _, widget in ipairs(children) do
					if type(widget) == "table" and widget.Destroy then
						widget:Destroy()
					end
				end
				children = {}
			end,
		})

		function RowFunctions:SetVisibility(State)
			row.Visible = State
		end
		function RowFunctions:SetHeight(NewHeight)
			Height = NewHeight
			row.Size = UDim2.new(1, 0, 0, NewHeight)
		end
		function RowFunctions:GetHeight()
			return Height
		end
		function RowFunctions:Destroy()
			release()
			row:Destroy()
		end

		if Flag then
			FractUI.Options[Flag] = RowFunctions
		end
		return RowFunctions
	end
	return Widgets
end
end function __DARKLUA_BUNDLE_MODULES.K():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.K if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.K=v end return v.c end end do local function __modImpl()
local core = __DARKLUA_BUNDLE_MODULES.c()
local cleanup = __DARKLUA_BUNDLE_MODULES.n()

local FractUI = core.FractUI
local assets = core.assets

--// A box that only shows its content while every dependency matches.
--// Dependencies are { widget, expectedValue } pairs; toggles, dropdowns, sliders
--// and inputs are supported.
return function(section, env, factories)
	local Widgets = {}
	function Widgets:DependencyBox(Settings, Flag)
		local BoxFunctions = { Settings = Settings, IgnoreConfig = true, Class = "DependencyBox" }

		local Dependencies = {}
		local connections = {}
		local children = {}
		local destroyed = false

		local box = Instance.new("Frame")
		box.Name = "DependencyBox"
		box.AutomaticSize = Enum.AutomaticSize.Y
		box.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		box.BackgroundTransparency = 1
		box.BorderColor3 = Color3.fromRGB(0, 0, 0)
		box.BorderSizePixel = 0
		box.Size = UDim2.new(1, 0, 0, 0)
		box.Visible = false
		box.Parent = section

		local boxUIListLayout = Instance.new("UIListLayout")
		boxUIListLayout.Name = "DependencyBoxUIListLayout"
		boxUIListLayout.Padding = UDim.new(0, 8)
		boxUIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
		boxUIListLayout.Parent = box

		for _, factory in ipairs(factories) do
			for name, method in pairs(factory(box, env, factories)) do
				local widgetMethod = method
				-- The box owns the widgets it creates and releases them with itself.
				BoxFunctions[name] = function(_, ...)
					local widget = widgetMethod(_, ...)
					table.insert(children, widget)
					return widget
				end
			end
		end

		local function matches(widget, expected)
			if widget.Class == "Toggle" then
				return widget:GetState() == expected
			elseif widget.Class == "Dropdown" then
				local value = widget.Value
				if type(value) == "table" then
					if value[expected] == true then
						return true
					end
					-- a multi dropdown keeps the selected names in a list
					for _, name in ipairs(value) do
						if name == expected then
							return true
						end
					end
					return false
				end
				return value == expected
			elseif widget.Class == "Slider" then
				return widget:GetValue() == expected
			elseif widget.Class == "Input" then
				return widget:GetInput() == expected
			end
			return true
		end

		local function evaluate()
			if destroyed then
				return
			end

			for _, dependency in ipairs(Dependencies) do
				local widget, expected = dependency[1], dependency[2]
				if widget and not matches(widget, expected) then
					BoxFunctions.Visible = false
					box.Visible = false
					return
				end
			end

			BoxFunctions.Visible = true
			box.Visible = true
		end

		local function setupDependencies(NewDependencies)
			for _, connection in ipairs(connections) do
				connection:Disconnect()
			end
			connections = {}

			Dependencies = NewDependencies or {}

			for _, dependency in ipairs(Dependencies) do
				local widget = dependency[1]
				if widget and widget.Changed then
					table.insert(connections, widget.Changed:Connect(evaluate))
				end
			end

			evaluate()
		end

		function BoxFunctions:SetupDependencies(NewDependencies)
			setupDependencies(NewDependencies)
		end

		function BoxFunctions:GetDependencies()
			return Dependencies
		end

		function BoxFunctions:IsVisible()
			if destroyed then
				return false
			end
			return BoxFunctions.Visible == true
		end

		-- The box releases what it owns when it ends, no matter how it ends.
		local release = cleanup({
			functions = BoxFunctions,
			instance = box,
			env = env,
			flag = Flag,
			release = function()
				destroyed = true
				for _, connection in ipairs(connections) do
					connection:Disconnect()
				end
				connections = {}
				for _, widget in ipairs(children) do
					if type(widget) == "table" and widget.Destroy then
						widget:Destroy()
					end
				end
				children = {}
			end,
		})

		function BoxFunctions:SetVisibility(State)
			BoxFunctions.Visible = State and true or false
			box.Visible = BoxFunctions.Visible
		end

		function BoxFunctions:Destroy()
			release()
			box:Destroy()
		end

		setupDependencies(Settings.Dependencies)

		if Flag then
			FractUI.Options[Flag] = BoxFunctions
		end
		return BoxFunctions
	end
	return Widgets
end
end function __DARKLUA_BUNDLE_MODULES.L():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.L if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.L=v end return v.c end end do local function __modImpl()--// Every widget factory. Sections, rows and dependency boxes all build their
--// widget list from this table so the same widget is available everywhere.

return {
__DARKLUA_BUNDLE_MODULES.s(),
__DARKLUA_BUNDLE_MODULES.t(),
__DARKLUA_BUNDLE_MODULES.u(),
__DARKLUA_BUNDLE_MODULES.v(),
__DARKLUA_BUNDLE_MODULES.x(),
__DARKLUA_BUNDLE_MODULES.y(),
__DARKLUA_BUNDLE_MODULES.z(),
__DARKLUA_BUNDLE_MODULES.A(),
__DARKLUA_BUNDLE_MODULES.B(),
__DARKLUA_BUNDLE_MODULES.C(),
__DARKLUA_BUNDLE_MODULES.D(),
__DARKLUA_BUNDLE_MODULES.E(),
__DARKLUA_BUNDLE_MODULES.F(),
__DARKLUA_BUNDLE_MODULES.G(),
__DARKLUA_BUNDLE_MODULES.H(),
__DARKLUA_BUNDLE_MODULES.I(),
__DARKLUA_BUNDLE_MODULES.J(),
__DARKLUA_BUNDLE_MODULES.K(),
__DARKLUA_BUNDLE_MODULES.L(),
}
end function __DARKLUA_BUNDLE_MODULES.M():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.M if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.M=v end return v.c end end do local function __modImpl()
local core = __DARKLUA_BUNDLE_MODULES.c()

local theme = __DARKLUA_BUNDLE_MODULES.a()
local style = __DARKLUA_BUNDLE_MODULES.f()

local widgetFactories = __DARKLUA_BUNDLE_MODULES.M()

return function(Settings, left, right, env)
	local SectionFunctions = {}
	local section = Instance.new("Frame")
	section.Name = "Section"
	section.AutomaticSize = Enum.AutomaticSize.Y
	theme.Set(section, "BackgroundColor3", "Surface")
	section.BackgroundTransparency = 0.5
	section.BorderColor3 = Color3.fromRGB(0, 0, 0)
	section.BorderSizePixel = 0
	section.Position = UDim2.fromScale(0, 6.78e-08)
	section.Size = UDim2.fromScale(1, 0)
	section.ClipsDescendants = true
	section.Parent = Settings.Side == "Left" and left or right

	local sectionUICorner = Instance.new("UICorner")
	sectionUICorner.Name = "SectionUICorner"
	sectionUICorner.CornerRadius = UDim.new(0, style.Radius.Group)
	sectionUICorner.Parent = section

	local sectionUIStroke = Instance.new("UIStroke")
	sectionUIStroke.Name = "SectionUIStroke"
	sectionUIStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	theme.Set(sectionUIStroke, "Color", "Outline")
	sectionUIStroke.Transparency = 0.95
	sectionUIStroke.Parent = section

	local sectionUIListLayout = Instance.new("UIListLayout")
	sectionUIListLayout.Name = "SectionUIListLayout"
	sectionUIListLayout.Padding = UDim.new(0, style.Spacing.Small)
	sectionUIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	sectionUIListLayout.Parent = section

	local sectionUIPadding = Instance.new("UIPadding")
	sectionUIPadding.Name = "SectionUIPadding"
	sectionUIPadding.PaddingBottom = UDim.new(0, style.Spacing.Large)
	sectionUIPadding.PaddingLeft = UDim.new(0, style.Spacing.Large)
	sectionUIPadding.PaddingRight = UDim.new(0, style.Spacing.Large)
	sectionUIPadding.PaddingTop = UDim.new(0, style.Spacing.Large)
	sectionUIPadding.Parent = section

	for _, factory in ipairs(widgetFactories) do
		for name, method in pairs(factory(section, env, widgetFactories)) do
			SectionFunctions[name] = method
		end
	end

	return SectionFunctions
end
end function __DARKLUA_BUNDLE_MODULES.N():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.N if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.N=v end return v.c end end do local function __modImpl()
local core = __DARKLUA_BUNDLE_MODULES.c()

local FractUI = core.FractUI
local isStudio = core.isStudio

return function(TabFunctions, WindowFunctions, Side)
	local configSection = TabFunctions:Section({ Side = "Left" })

	if isStudio then
		configSection:Label({Text = "Config system unavailable. (Environment isStudio)"})
		return "Config system unavailable." 
	end

	local inputPath = nil
	local selectedConfig = nil

	configSection:Input({
		Name = "Config Name",
		Placeholder = "Name",
		AcceptedCharacters = "All",
		Callback = function(input)
			inputPath = input
		end,
	})

	local configSelection = configSection:Dropdown({
		Name = "Select Config",
		Multi = false,
		Required = false,
		Options = FractUI:RefreshConfigList(),
		Callback = function(Value)
			selectedConfig = Value
		end,
	})

	configSection:Button({
		Name = "Create Config",
		Callback = function()
			if not inputPath or string.gsub(inputPath, " ", "") == "" then
				WindowFunctions:Notify({
					Title = "Interface",
					Description = "Config name cannot be empty."
				})
				return
			end

			local success, returned = FractUI:SaveConfig(inputPath)
			if not success then
				WindowFunctions:Notify({
					Title = "Interface",
					Description = "Unable to save config, return error: " .. returned
				})
			end

			WindowFunctions:Notify({
				Title = "Interface",
				Description = string.format("Created config %q", inputPath),
			})

			configSelection:ClearOptions()
			configSelection:InsertOptions(FractUI:RefreshConfigList())
		end,
	})

	configSection:Button({
		Name = "Load Config",
		Callback = function()
			local success, returned = FractUI:LoadConfig(configSelection.Value)
			if not success then
				WindowFunctions:Notify({
					Title = "Interface",
					Description = "Unable to load config, return error: " .. returned
				})
				return
			end

			WindowFunctions:Notify({
				Title = "Interface",
				Description = string.format("Loaded config %q", configSelection.Value),
			})
		end,
	})

	configSection:Button({
		Name = "Overwrite Config",
		Callback = function()
			local success, returned = FractUI:SaveConfig(configSelection.Value)
			if not success then
				WindowFunctions:Notify({
					Title = "Interface",
					Description = "Unable to overwrite config, return error: " .. returned
				})
				return
			end

			WindowFunctions:Notify({
				Title = "Interface",
				Description = string.format("Overwrote config %q", configSelection.Value),
			})
		end,
	})

	configSection:Button({
		Name = "Refresh Config List",
		Callback = function()
			configSelection:ClearOptions()
			configSelection:InsertOptions(FractUI:RefreshConfigList())
		end,
	})

	local autoloadLabel

	configSection:Button({
		Name = "Set as autoload",
		Callback = function()
			local name = configSelection.Value
			writefile(FractUI.Folder .. "/settings/autoload.txt", name)
			autoloadLabel:UpdateName("Autoload config: " .. name)
			WindowFunctions:Notify({
				Title = "Interface",
				Description = string.format("Set %q as autoload", name),
			})
		end,
	})

	autoloadLabel = configSection:Label({Text = "Autoload config: None"})

	if isfile(FractUI.Folder .. "/settings/autoload.txt") then
		local name = readfile(FractUI.Folder .. "/settings/autoload.txt")
		autoloadLabel:UpdateName("Autoload config: " .. name)
	end
end
end function __DARKLUA_BUNDLE_MODULES.O():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.O if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.O=v end return v.c end end do local function __modImpl()
local core = __DARKLUA_BUNDLE_MODULES.c()
local theme = __DARKLUA_BUNDLE_MODULES.a()
local style = __DARKLUA_BUNDLE_MODULES.f()
local icons = __DARKLUA_BUNDLE_MODULES.d()

local newSection = __DARKLUA_BUNDLE_MODULES.N()
local insertConfigSection = __DARKLUA_BUNDLE_MODULES.O()

local assets = core.assets

return function(Settings, tabSwitcherParent, ctx)
	local touchLayout = core.UserInputService.TouchEnabled == true
	local TabFunctions = {Settings = Settings, Window = ctx.window}
	local tabSwitcher = Instance.new("TextButton")
	tabSwitcher.Name = "TabSwitcher"
	tabSwitcher.FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json")
	tabSwitcher.Text = ""
	tabSwitcher.TextColor3 = Color3.fromRGB(0, 0, 0)
	tabSwitcher.TextSize = 14
	tabSwitcher.AutoButtonColor = false
	tabSwitcher.AnchorPoint = Vector2.new(0.5, 0)
	theme.Set(tabSwitcher, "BackgroundColor3", "Accent")
	tabSwitcher.BackgroundTransparency = 1
	tabSwitcher.BorderColor3 = Color3.fromRGB(0, 0, 0)
	tabSwitcher.BorderSizePixel = 0
	tabSwitcher.Position = UDim2.fromScale(0.5, 0)
	tabSwitcher.Size = UDim2.new(1, 0, 0, touchLayout and style.Nav.RowTouch or style.Nav.Row)

	tabSwitcher.LayoutOrder = ctx.navigation.nextIndex()

	local tabSwitcherUICorner = Instance.new("UICorner")
	tabSwitcherUICorner.Name = "TabSwitcherUICorner"
	tabSwitcherUICorner.CornerRadius = UDim.new(0, style.Radius.Control)
	tabSwitcherUICorner.Parent = tabSwitcher

	local tabSwitcherUIStroke = Instance.new("UIStroke")
	tabSwitcherUIStroke.Name = "TabSwitcherUIStroke"
	tabSwitcherUIStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	theme.Set(tabSwitcherUIStroke, "Color", "Outline")
	tabSwitcherUIStroke.Transparency = 1
	tabSwitcherUIStroke.Parent = tabSwitcher

	local tabSwitcherUIListLayout = Instance.new("UIListLayout")
	tabSwitcherUIListLayout.Name = "TabSwitcherUIListLayout"
	tabSwitcherUIListLayout.Padding = UDim.new(0, style.Nav.Gap)
	tabSwitcherUIListLayout.FillDirection = Enum.FillDirection.Horizontal
	tabSwitcherUIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabSwitcherUIListLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	tabSwitcherUIListLayout.Parent = tabSwitcher

	local tabImage

	local icon = Settings.Icon and icons.Get(Settings.Icon) or nil
	if icon == "" then
		icon = nil
	end
	local image = icon or Settings.Image
	if image then
		tabImage = Instance.new("ImageLabel")
		tabImage.Name = "TabImage"
		tabImage.Image = image
		theme.Set(tabImage, "ImageColor3", "Text")
		tabImage.ImageTransparency = 0.5
		tabImage.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		tabImage.BackgroundTransparency = 1
		tabImage.BorderColor3 = Color3.fromRGB(0, 0, 0)
		tabImage.BorderSizePixel = 0
		tabImage.LayoutOrder = 0
		tabImage.Size = UDim2.fromOffset(style.Nav.Icon, style.Nav.Icon)
		tabImage.Parent = tabSwitcher
	end

	local tabSwitcherName = Instance.new("TextLabel")
	tabSwitcherName.Name = "TabSwitcherName"
	tabSwitcherName.FontFace = Font.new(
		assets.interFont,
		Enum.FontWeight.Medium,
		Enum.FontStyle.Normal
	)
	tabSwitcherName.Text = Settings.Name
	tabSwitcherName.RichText = true
	theme.Set(tabSwitcherName, "TextColor3", "Text")
	tabSwitcherName.TextSize = style.Type.Control
	tabSwitcherName.TextTransparency = 0.35
	tabSwitcherName.TextTruncate = Enum.TextTruncate.SplitWord
	tabSwitcherName.TextWrapped = false
	tabSwitcherName.TextXAlignment = Enum.TextXAlignment.Left
	tabSwitcherName.TextYAlignment = Enum.TextYAlignment.Center
	tabSwitcherName.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	tabSwitcherName.BackgroundTransparency = 1
	tabSwitcherName.BorderColor3 = Color3.fromRGB(0, 0, 0)
	tabSwitcherName.BorderSizePixel = 0
	tabSwitcherName.Size = UDim2.new(1, image and -48 or -24, 0, 20)
	tabSwitcherName.Parent = tabSwitcher
	tabSwitcherName.LayoutOrder = 1

	local tabSwitcherUIPadding = Instance.new("UIPadding")
	tabSwitcherUIPadding.Name = "TabSwitcherUIPadding"
	tabSwitcherUIPadding.PaddingLeft = UDim.new(0, style.Nav.Padding)
	tabSwitcherUIPadding.PaddingRight = UDim.new(0, style.Nav.Padding)
	tabSwitcherUIPadding.Parent = tabSwitcher

	tabSwitcher.Parent = tabSwitcherParent

	local elements1 = Instance.new("Frame")
	elements1.Name = "Elements"
	elements1.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	elements1.BackgroundTransparency = 1
	elements1.BorderColor3 = Color3.fromRGB(0, 0, 0)
	elements1.BorderSizePixel = 0
	elements1.Position = UDim2.fromOffset(0, style.Header)
	elements1.Size = UDim2.new(1, 0, 1, -style.Header)
	elements1.ClipsDescendants = true

	local elementsUIPadding = Instance.new("UIPadding")
	elementsUIPadding.Name = "ElementsUIPadding"
	elementsUIPadding.PaddingRight = UDim.new(0, style.Spacing.Medium)
	elementsUIPadding.PaddingTop = UDim.new(0, style.Spacing.Small)
	elementsUIPadding.PaddingBottom = UDim.new(0, style.Spacing.Small)
	elementsUIPadding.Parent = elements1

	local elementsScrolling = Instance.new("ScrollingFrame")
	elementsScrolling.Name = "ElementsScrolling"
	elementsScrolling.AutomaticCanvasSize = Enum.AutomaticSize.Y
	elementsScrolling.BottomImage = ""
	elementsScrolling.CanvasSize = UDim2.new()
	elementsScrolling.ScrollBarImageTransparency = 0.5
	elementsScrolling.ScrollBarThickness = 1
	elementsScrolling.TopImage = ""
	elementsScrolling.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	elementsScrolling.BackgroundTransparency = 1
	elementsScrolling.BorderColor3 = Color3.fromRGB(0, 0, 0)
	elementsScrolling.BorderSizePixel = 0
	elementsScrolling.Size = UDim2.fromScale(1, 1)
	elementsScrolling.ClipsDescendants = false

	local elementsScrollingUIPadding = Instance.new("UIPadding")
	elementsScrollingUIPadding.Name = "ElementsScrollingUIPadding"
	elementsScrollingUIPadding.PaddingBottom = UDim.new(0, style.Spacing.Tiny)
	elementsScrollingUIPadding.PaddingLeft = UDim.new(0, style.Spacing.Medium)
	elementsScrollingUIPadding.PaddingRight = UDim.new(0, style.Spacing.Medium)
	elementsScrollingUIPadding.PaddingTop = UDim.new(0, style.Spacing.Tiny)
	elementsScrollingUIPadding.Parent = elementsScrolling

	local elementsScrollingUIListLayout = Instance.new("UIListLayout")
	elementsScrollingUIListLayout.Name = "ElementsScrollingUIListLayout"
	elementsScrollingUIListLayout.Padding = UDim.new(0, style.Spacing.Medium)
	elementsScrollingUIListLayout.FillDirection = Enum.FillDirection.Horizontal
	elementsScrollingUIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	elementsScrollingUIListLayout.Parent = elementsScrolling

	local left = Instance.new("Frame")
	left.Name = "Left"
	left.AutomaticSize = Enum.AutomaticSize.Y
	left.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	left.BackgroundTransparency = 1
	left.BorderColor3 = Color3.fromRGB(0, 0, 0)
	left.BorderSizePixel = 0
	left.Position = UDim2.fromScale(0, 0)
	left.Size = UDim2.new(0.5, -style.Spacing.Medium / 2, 0, 0)

	local leftUIListLayout = Instance.new("UIListLayout")
	leftUIListLayout.Name = "LeftUIListLayout"
	leftUIListLayout.Padding = UDim.new(0, style.Spacing.Medium)
	leftUIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	leftUIListLayout.Parent = left

	left.Parent = elementsScrolling

	local right = Instance.new("Frame")
	right.Name = "Right"
	right.AutomaticSize = Enum.AutomaticSize.Y
	right.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	right.BackgroundTransparency = 1
	right.BorderColor3 = Color3.fromRGB(0, 0, 0)
	right.BorderSizePixel = 0
	right.LayoutOrder = 1
	right.Position = UDim2.fromScale(0.5, 0)
	right.Size = UDim2.new(0.5, -style.Spacing.Medium / 2, 0, 0)

	local rightUIListLayout = Instance.new("UIListLayout")
	rightUIListLayout.Name = "RightUIListLayout"
	rightUIListLayout.Padding = UDim.new(0, style.Spacing.Medium)
	rightUIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rightUIListLayout.Parent = right

	right.Parent = elementsScrolling

	elementsScrolling.Parent = elements1

	function TabFunctions:Section(Settings)
		return newSection(Settings, left, right, ctx)
	end

	local function SelectCurrentTab()
		ctx.navigation.select(tabSwitcher, Settings.Name, ctx.content, ctx.currentTab)
	end

	tabSwitcher.MouseButton1Click:Connect(function()
		SelectCurrentTab()
	end)

	tabSwitcher.MouseEnter:Connect(function()
		ctx.navigation.hover(tabSwitcher, true)
	end)

	tabSwitcher.MouseLeave:Connect(function()
		ctx.navigation.hover(tabSwitcher, false)
	end)

	function TabFunctions:Select()
		SelectCurrentTab()
	end

	function TabFunctions:InsertConfigSection(Side)
		return insertConfigSection(TabFunctions, ctx.window, Side)
	end

	ctx.navigation.register(tabSwitcher, {
		tabContent = elements1,
		tabStroke = tabSwitcherUIStroke,
		switcherImage = tabImage,
		switcherName = tabSwitcherName,
	})

	return TabFunctions
end
end function __DARKLUA_BUNDLE_MODULES.P():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.P if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.P=v end return v.c end end do local function __modImpl()
local theme = __DARKLUA_BUNDLE_MODULES.a()
local style = __DARKLUA_BUNDLE_MODULES.f()

local newTab = __DARKLUA_BUNDLE_MODULES.P()

return function(ctx)
	local SectionFunctions = {}
	local tabSwitchersScrollingFrame = ctx.tabSwitcherParent

	local tabGroup = Instance.new("Frame")
	tabGroup.Name = "Section"
	tabGroup.AutomaticSize = Enum.AutomaticSize.Y
	tabGroup.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	tabGroup.BackgroundTransparency = 1
	tabGroup.BorderColor3 = Color3.fromRGB(0, 0, 0)
	tabGroup.BorderSizePixel = 0
	tabGroup.Size = UDim2.fromScale(1, 0)

	local divider3 = Instance.new("Frame")
	divider3.Name = "Divider"
	divider3.AnchorPoint = Vector2.new(0.5, 1)
	theme.Set(divider3, "BackgroundColor3", "Outline")
	divider3.BackgroundTransparency = 0.9
	divider3.BorderColor3 = Color3.fromRGB(0, 0, 0)
	divider3.BorderSizePixel = 0
	divider3.Position = UDim2.fromScale(0.5, 1)
	divider3.Size = UDim2.new(1, -style.Spacing.XXLarge, 0, 1)
	divider3.Parent = tabGroup

	local sectionTabSwitchers = Instance.new("Frame")
	sectionTabSwitchers.Name = "SectionTabSwitchers"
	sectionTabSwitchers.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	sectionTabSwitchers.BackgroundTransparency = 1
	sectionTabSwitchers.BorderColor3 = Color3.fromRGB(0, 0, 0)
	sectionTabSwitchers.BorderSizePixel = 0
	sectionTabSwitchers.Size = UDim2.fromScale(1, 1)

	local uIListLayout1 = Instance.new("UIListLayout")
	uIListLayout1.Name = "UIListLayout"
	uIListLayout1.Padding = UDim.new(0, style.Spacing.Small)
	uIListLayout1.HorizontalAlignment = Enum.HorizontalAlignment.Center
	uIListLayout1.SortOrder = Enum.SortOrder.LayoutOrder
	uIListLayout1.Parent = sectionTabSwitchers

	local uIPadding1 = Instance.new("UIPadding")
	uIPadding1.Name = "UIPadding"
	uIPadding1.PaddingBottom = UDim.new(0, style.Spacing.Small)
	uIPadding1.Parent = sectionTabSwitchers

	sectionTabSwitchers.Parent = tabGroup
	tabGroup.Parent = tabSwitchersScrollingFrame

	function SectionFunctions:Tab(Settings)
		return newTab(Settings, sectionTabSwitchers, ctx)
	end

	return SectionFunctions
end
end function __DARKLUA_BUNDLE_MODULES.Q():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.Q if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.Q=v end return v.c end end do local function __modImpl()
local core = __DARKLUA_BUNDLE_MODULES.c()
local theme = __DARKLUA_BUNDLE_MODULES.a()
local style = __DARKLUA_BUNDLE_MODULES.f()

local Tween = core.Tween

local tabs = {}
local currentTabInstance = nil
local tabIndex = 0

local function cancel(tween)
	if tween and tween.Cancel then
		tween:Cancel()
	end
end

--// The fill carries the state, the label and the icon carry the hierarchy.
--// Every state changes only these properties, so a live theme update keeps
--// the selected and hovered rows exactly where they are.
local function paint(tabSwitcher, info)
	local tweenInfo = TweenInfo.new(style.Motion.Fast, Enum.EasingStyle.Sine)
	local selected = info.selected
	local hovered = info.hovered

	local fill = selected and 0 or (hovered and 0.88 or 1)
	local label = selected and 0 or (hovered and 0.1 or 0.35)
	local icon = selected and 0 or (hovered and 0.2 or 0.5)

	cancel(info.fillTween)
	info.fillTween = Tween(tabSwitcher, tweenInfo, {
		BackgroundTransparency = fill,
	})
	info.fillTween:Play()

	if info.switcherName then
		theme.Set(info.switcherName, "TextColor3", selected and "Highlight" or "Text")
		cancel(info.labelTween)
		info.labelTween = Tween(info.switcherName, tweenInfo, {
			TextTransparency = label,
		})
		info.labelTween:Play()
	end

	if info.switcherImage then
		theme.Set(info.switcherImage, "ImageColor3", selected and "Highlight" or "Text")
		cancel(info.iconTween)
		info.iconTween = Tween(info.switcherImage, tweenInfo, {
			ImageTransparency = icon,
		})
		info.iconTween:Play()
	end
end

return {
	tabs = tabs,

	nextIndex = function()
		tabIndex += 1
		return tabIndex
	end,

	register = function(tabSwitcher, info)
		info.selected = false
		info.hovered = false
		tabs[tabSwitcher] = info
	end,

	hover = function(tabSwitcher, hovered)
		local info = tabs[tabSwitcher]
		if not info then return end

		info.hovered = hovered and true or false
		paint(tabSwitcher, info)
	end,

	select = function(tabSwitcher, name, content, currentTab)
		if currentTabInstance then
			currentTabInstance.Parent = nil
		end

		for i, tabInfo in pairs(tabs) do
			tabInfo.selected = i == tabSwitcher
			paint(i, tabInfo)
		end

		tabs[tabSwitcher].tabContent.Parent = content
		currentTabInstance = tabs[tabSwitcher].tabContent
		currentTab.Text = name
	end,
}
end function __DARKLUA_BUNDLE_MODULES.R():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.R if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.R=v end return v.c end end do local function __modImpl()
return {
	acrylicBlur = true,
	hasGlobalSetting = false,
	unloaded = false,
	windowState = true,
}
end function __DARKLUA_BUNDLE_MODULES.S():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.S if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.S=v end return v.c end end do local function __modImpl()
local core = __DARKLUA_BUNDLE_MODULES.c()
local configInstall = __DARKLUA_BUNDLE_MODULES.e()
local chromeModule = __DARKLUA_BUNDLE_MODULES.h()
local acrylicModule = __DARKLUA_BUNDLE_MODULES.i()
local globalSetting = __DARKLUA_BUNDLE_MODULES.j()
local notify = __DARKLUA_BUNDLE_MODULES.k()
local dialog = __DARKLUA_BUNDLE_MODULES.m()
local tabGroup = __DARKLUA_BUNDLE_MODULES.Q()
local navigation = __DARKLUA_BUNDLE_MODULES.R()
local state = __DARKLUA_BUNDLE_MODULES.S()

local FractUI = core.FractUI
local LocalPlayer = core.LocalPlayer
local UserInputService = core.UserInputService

return function(FractUI)
	function FractUI:Window(Settings)
		if Settings.AcrylicBlur ~= nil then
			state.acrylicBlur = Settings.AcrylicBlur
		else
			state.acrylicBlur = true
		end

		local chrome = chromeModule(Settings, state)
		local releaseAcrylic = acrylicModule(chrome.base, state)

		local WindowFunctions = {Settings = Settings}
		WindowFunctions.Changed = core.NewSignal()
		local tabContext = {
			navigation = navigation,
			content = chrome.content,
			currentTab = chrome.currentTab,
			base = chrome.base,
			baseUIScale = chrome.baseUIScale,
			tabSwitcherParent = chrome.tabSwitcherParent,
			window = WindowFunctions,
			modal = chrome.modal,
			unloaded = core.NewSignal(),
		}

		function WindowFunctions:UpdateTitle(NewTitle)
			chrome.updateTitle(NewTitle)
		end

		function WindowFunctions:UpdateSubtitle(NewSubtitle)
			chrome.updateSubtitle(NewSubtitle)
		end

		function WindowFunctions:GlobalSetting(Settings)
			return globalSetting(Settings, chrome.globalSettings, state)
		end

		function WindowFunctions:TabGroup()
			return tabGroup(tabContext)
		end

		function WindowFunctions:Notify(Settings)
			return notify(Settings, chrome.notifications)
		end

		function WindowFunctions:Dialog(Settings)
			chrome.cancelInteractions()
			return dialog(Settings, chrome.base, chrome.modal)
		end

		function WindowFunctions:SetNotificationsState(State)
			chrome.notifications.Visible = State
			WindowFunctions.Changed:Fire("Notifications")
		end

		function WindowFunctions:GetNotificationsState()
			return chrome.notifications.Visible
		end

		function WindowFunctions:SetState(State)
			state.windowState = State
			chrome.base.Visible = State
			WindowFunctions.Changed:Fire("State")
		end

		function WindowFunctions:GetState()
			return state.windowState
		end

		local unloadCallbacks = {}
		-- The connection of the keybind of the window. It belongs to this
		-- window alone, so the unload of one window never touches another.
		local menuConnection = nil

		function WindowFunctions:Unload()
			-- The keybind of the window does not listen anymore after the
			-- unload. The unload can run twice, so the connection is let go
			-- of only once.
			if menuConnection then
				menuConnection:Disconnect()
				menuConnection = nil
			end
			-- The list is a copy, so a callback that disconnects itself does
			-- not skip the callback that comes after it.
			for _, callback in ipairs(table.clone(unloadCallbacks)) do
				-- A callback that fails does not stop the unload.
				local ok, err = pcall(callback)
				if not ok then
					warn("FractUI: a callback of the unload failed: " .. tostring(err))
				end
			end
			state.unloaded = true
			-- The widgets release what they own before the tree is destroyed.
			tabContext.unloaded:Fire()
			releaseAcrylic()
			chrome.disconnect()
			chrome.modal:Unload()
			chrome.gui:Destroy()
		end

		function WindowFunctions.onUnloaded(callback)
			table.insert(unloadCallbacks, callback)
			return {
				Disconnect = function()
					for index, existing in ipairs(unloadCallbacks) do
						if existing == callback then
							table.remove(unloadCallbacks, index)
							return
						end
					end
				end,
			}
		end

		local MenuKeybind = Settings.Keybind or Enum.KeyCode.RightControl

		local function ToggleMenu()
			if chrome.modal:IsBlocked() then return end
			local state = not WindowFunctions:GetState()
			WindowFunctions:SetState(state)
			WindowFunctions:Notify({
				Title = Settings.Title,
				Description = (state and "Maximized " or "Minimized ") .. "the menu. Use " .. tostring(MenuKeybind.Name) .. " to toggle it.",
				Lifetime = 5
			})
		end

		menuConnection = UserInputService.InputEnded:Connect(function(inp, gpe)
			if gpe then return end
			if inp.KeyCode == MenuKeybind then
				ToggleMenu()
			end
		end)

		chrome.minimize.MouseButton1Click:Connect(ToggleMenu)
		chrome.exit.MouseButton1Click:Connect(function()
			WindowFunctions:Dialog({
				Title = Settings.Title,
				Description = "Are you sure you want to exit the menu? You will lose any unsaved configurations.",
				Buttons = {
					{
						Name = "Confirm",
						Callback = function()
							WindowFunctions:Unload()
						end,
					},
					{
						Name = "Cancel",
						--// The safe answer owns Enter and Escape because the
						--// other one destroys the window.
						Default = true,
						Cancel = true,
					}
				}
			})
		end)

		function WindowFunctions:SetKeybind(Keycode)
			MenuKeybind = Keycode
			WindowFunctions.Changed:Fire("Keybind")
		end

		function WindowFunctions:GetKeybind()
			return MenuKeybind
		end

		function WindowFunctions:SetAcrylicBlurState(State)
			state.acrylicBlur = State
			chrome.updateAcrylic(State)
			WindowFunctions.Changed:Fire("AcrylicBlur")
		end

		function WindowFunctions:GetAcrylicBlurState()
			return state.acrylicBlur
		end

		local function _SetUserInfoState(State)
			if State then
				chrome.headshot.Image = (chrome.userInfoReady and chrome.headshotImage) or "rbxassetid://0"
				chrome.username.Text = "@" .. LocalPlayer.Name
				chrome.displayName.Text = LocalPlayer.DisplayName
			else
				chrome.headshot.Image = core.assets.userInfoBlurred
				local nameLength = #LocalPlayer.Name
				local displayNameLength = #LocalPlayer.DisplayName
				chrome.username.Text = "@" .. string.rep(".", nameLength)
				chrome.displayName.Text = string.rep(".", displayNameLength)
			end
		end

		local showUserInfo
		if Settings.ShowUserInfo ~= nil then
			showUserInfo = Settings.ShowUserInfo
		else
			showUserInfo = true
		end

		_SetUserInfoState(showUserInfo)

		function WindowFunctions:SetUserInfoState(State)
			showUserInfo = State and true or false
			_SetUserInfoState(showUserInfo)
			WindowFunctions.Changed:Fire("UserInfo")
		end

		function WindowFunctions:GetUserInfoState()
			return showUserInfo
		end

		function WindowFunctions:SetSize(Size)
			chrome.base.Size = Size
			chrome.updateSize()
		end

		function WindowFunctions:GetSize()
			return chrome.base.Size
		end

		function WindowFunctions:SetScale(Scale)
			chrome.baseUIScale.Scale = Scale
			WindowFunctions.Changed:Fire("Scale")
		end

		function WindowFunctions:GetScale()
			return chrome.baseUIScale.Scale
		end

		configInstall(FractUI, WindowFunctions)

		chrome.gui.Enabled = false

		local assetList = {}
		for _, assetId in pairs(core.assets) do
			table.insert(assetList, assetId)
		end

		core.ContentProvider:PreloadAsync(assetList)
		chrome.gui.Enabled = true
		state.windowState = true

		return WindowFunctions
	end
end
end function __DARKLUA_BUNDLE_MODULES.T():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.T if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.T=v end return v.c end end do local function __modImpl()
return function(FractUI)
	--// Supply an authorized video asset id here to try the player locally.
	local VideoAsset = ""

	local Window = FractUI:Window({
		Title = "FractUI Demo",
		Subtitle = "A small tour of the components.",
		Size = UDim2.fromOffset(868, 650),
		DragStyle = 1,
		DisabledWindowControls = {},
		ShowUserInfo = true,
		Keybind = Enum.KeyCode.RightControl,
		AcrylicBlur = false,
	})

	local status
	local scaleSlider
	local demoKeybind
	local menuKeybind
	local blurSetting
	local notificationsSetting
	local userInfoSetting
	local syncing = false
	local scaleConnection
	local windowConnection

	local function setStatus(message)
		if status then
			status:UpdateName("Last action: " .. message)
		end
	end

	local function resetWindowSettings()
		Window:SetScale(1)
		Window:SetKeybind(Enum.KeyCode.RightControl)
		Window:SetAcrylicBlurState(false)
		Window:SetNotificationsState(true)
		Window:SetUserInfoState(true)
		setStatus("window settings reset")
	end

	blurSetting = Window:GlobalSetting({
		Name = "UI Blur",
		Default = Window:GetAcrylicBlurState(),
		Callback = function(state)
			Window:SetAcrylicBlurState(state)
			setStatus("UI blur " .. (state and "enabled" or "disabled"))
		end,
	})

	notificationsSetting = Window:GlobalSetting({
		Name = "Notifications",
		Default = Window:GetNotificationsState(),
		Callback = function(state)
			Window:SetNotificationsState(state)
			setStatus("notifications " .. (state and "enabled" or "disabled"))
		end,
	})

	userInfoSetting = Window:GlobalSetting({
		Name = "Show User Info",
		Default = Window:GetUserInfoState(),
		Callback = function(state)
			Window:SetUserInfoState(state)
			setStatus("user info " .. (state and "shown" or "hidden"))
		end,
	})

	local tabGroup = Window:TabGroup()
	local controls = tabGroup:Tab({ Name = "Controls" })
	local layout = tabGroup:Tab({ Name = "Layout" })
	local media = tabGroup:Tab({ Name = "Media" })
	local settings = tabGroup:Tab({ Name = "Settings" })

	--// Controls: the normal inputs and the choices that go with them.
	local controlsLeft = controls:Section({ Side = "Left" })
	controlsLeft:Header({ Text = "Inputs" })
	controlsLeft:Button({
		Name = "Open dialog",
		Callback = function()
			Window:Dialog({
				Title = "FractUI dialog",
				Description = "This dialog belongs to the demo. Confirming it updates the status label.",
				Buttons = {
					{
						Name = "Confirm",
						Default = true,
						Callback = function()
							setStatus("confirmed the dialog")
						end,
					},
					{
						Name = "Cancel",
						Cancel = true,
					},
				},
			})
		end,
	})

	controlsLeft:Input({
		Name = "Text input",
		Placeholder = "Type here",
		AcceptedCharacters = "All",
		Callback = function(value)
			setStatus("input \"" .. value .. "\"")
		end,
	}, "DemoInput")

	controlsLeft:Slider({
		Name = "Value",
		Default = 50,
		Minimum = 0,
		Maximum = 100,
		DisplayMethod = "Percent",
		Precision = 0,
		Callback = function(value)
			setStatus("value " .. math.floor(value + 0.5) .. "%")
		end,
	}, "DemoValue")

	controlsLeft:Toggle({
		Name = "Toggle",
		Default = true,
		Callback = function(state)
			setStatus("toggle " .. (state and "on" or "off"))
		end,
	}, "DemoToggle")

	demoKeybind = controlsLeft:Keybind({
		Name = "Keybind",
		Blacklist = false,
		Default = Enum.KeyCode.F,
		Callback = function()
			setStatus("keybind pressed")
		end,
		onBinded = function(bind)
			setStatus("keybind " .. bind.Name)
		end,
	}, "DemoKeybind")

	local controlsRight = controls:Section({ Side = "Right" })
	controlsRight:Header({ Text = "Choices" })
	controlsRight:Colorpicker({
		Name = "Accent color",
		Default = Color3.fromRGB(88, 166, 255),
		Alpha = 0.5,
		Callback = function()
			setStatus("accent color changed")
		end,
	}, "DemoColor")

	local fruit = controlsRight:Dropdown({
		Name = "Fruit",
		Search = true,
		Multi = true,
		Required = false,
		Options = {
			"Apple",
			"Banana",
			"Orange",
			"Grapes",
			"Pineapple",
		},
		Default = { "Apple" },
		Callback = function()
			setStatus("fruit selection changed")
		end,
	}, "DemoDropdown")

	controlsRight:Button({
		Name = "Select fruit",
		Callback = function()
			fruit:UpdateSelection({ "Apple", "Orange" })
			setStatus("fruit selection updated")
		end,
	}, "DemoSelectFruit")

	controlsRight:Divider()

	--// Layout: rows, a dependency and the inline controls.
	local layoutLeft = layout:Section({ Side = "Left" })
	layoutLeft:Header({ Text = "Rows and dependencies" })
	local row = layoutLeft:Row({
		Height = 38,
		Padding = 8,
	})

	row:Toggle({
		Name = "Row toggle",
		Default = true,
	})

	row:Button({
		Name = "Row button",
		Callback = function()
			setStatus("row button clicked")
		end,
	})

	local showAdvanced = layoutLeft:Toggle({
		Name = "Show advanced",
		Default = false,
	}, "DemoShowAdvanced")

	local advanced = layoutLeft:DependencyBox({
		Dependencies = { { showAdvanced, true } },
	})

	advanced:Slider({
		Name = "Advanced value",
		Minimum = 0,
		Maximum = 100,
		Default = 25,
	})

	advanced:Label({
		Text = "This block appears while Show advanced is on.",
	})

	local layoutRight = layout:Section({ Side = "Right" })
	layoutRight:Header({ Text = "Text and inline controls" })
	layoutRight:Paragraph({
		Header = "Paragraph",
		Body = "A paragraph pairs a heading with a short body. The inline controls sit at the right edge of their widget.",
	})

	layoutRight:Label({
		Text = "A label with an inline key picker.",
	}):AddKeyPicker("DemoInlineKey", {
		Mode = "Toggle",
		Default = Enum.KeyCode.G,
	})

	layoutRight:SubLabel({
		Text = "A sublabel adds a quieter line.",
	})

	layoutRight:Label({
		Text = "A label with an inline color swatch.",
	}):AddColorPicker("DemoInlineColor", {
		Default = Color3.fromRGB(88, 166, 255),
		Alpha = 0.5,
	})

	layoutRight:Divider()

	--// Media: an image, the empty video player and the two live previews.
	local mediaLeft = media:Section({ Side = "Left" })
	mediaLeft:Header({ Text = "Image and video" })
	mediaLeft:Image({
		Image = "rbxassetid://12187365364",
		Height = 90,
	})

	mediaLeft:SubLabel({
		Text = "The video player is wired, but no video asset ships with the demo.",
	})

	mediaLeft:Video({
		Video = VideoAsset,
		Looped = true,
		Height = 120,
	}, "DemoVideo")

	local mediaRight = media:Section({ Side = "Right" })
	mediaRight:Header({ Text = "Viewport and passthrough" })

	local previewPart = Instance.new("Part")
	previewPart.Name = "FractUI Preview"
	previewPart.Size = Vector3.new(4, 4, 4)
	previewPart.Anchored = true

	mediaRight:Viewport({
		Object = previewPart,
		Clone = true,
		AutoFocus = true,
		Interactive = true,
		Height = 140,
	}, "DemoViewport")

	local banner = Instance.new("TextLabel")
	banner.Name = "FractUI Banner"
	banner.Size = UDim2.fromScale(1, 1)
	banner.BackgroundTransparency = 1
	banner.FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json")
	banner.Text = "Copied by UIPassthrough"
	banner.TextColor3 = Color3.fromRGB(255, 255, 255)
	banner.TextSize = 16

	mediaRight:UIPassthrough({
		Instance = banner,
		Height = 30,
	}, "DemoPassthrough")

	--// Settings: the window scale, the menu key and one reset.
	local settingsLeft = settings:Section({ Side = "Left" })
	settingsLeft:Header({ Text = "Interface" })
	scaleSlider = settingsLeft:Slider({
		Name = "Interface scale",
		Default = 1,
		Minimum = 0.5,
		Maximum = 2,
		Precision = 2,
		Callback = function(value)
			setStatus(string.format("scale %.2f", value))
		end,
	}, "DemoScale")

	--// A config load updates the slider without firing its callback, so the
	--// slider itself is the source that reaches the window.
	scaleConnection = scaleSlider.Changed:Connect(function(value)
		if syncing then return end
		syncing = true
		Window:SetScale(value)
		syncing = false
	end)

	menuKeybind = settingsLeft:Keybind({
		Name = "Menu key",
		Blacklist = {
			Enum.UserInputType.MouseButton1,
			Enum.UserInputType.MouseButton2,
		},
		Default = Window:GetKeybind(),
		onBinded = function(bind)
			if syncing then return end
			--// The window toggles on a key code, so a mouse bind or an unbind
			--// would leave the menu without a usable key.
			if not bind or bind.EnumType ~= Enum.KeyCode then
				local fallback = Window:GetKeybind()
				if not fallback or fallback.EnumType ~= Enum.KeyCode then
					fallback = Enum.KeyCode.RightControl
				end
				menuKeybind:Bind(fallback)
				setStatus("menu key needs a keyboard key")
				return
			end
			Window:SetKeybind(bind)
			setStatus("menu key " .. bind.Name)
		end,
	}, "DemoMenuKey")

	--// The keybind widget clears its display after onBinded returns. The menu
	--// key always keeps a keyboard fallback, so restore it after that clear.
	local keybindUnbind = menuKeybind.Unbind
	menuKeybind.Unbind = function(self)
		keybindUnbind(self)
		local fallback = Window:GetKeybind()
		if not fallback or fallback.EnumType ~= Enum.KeyCode then
			fallback = Enum.KeyCode.RightControl
		end
		self:Bind(fallback)
		setStatus("menu key needs a keyboard key")
	end

	status = settingsLeft:Label({
		Text = "Last action: idle",
	})

	--// InterfaceManager changes the same window. The guard keeps the two
	--// sides from driving each other.
	windowConnection = Window.Changed:Connect(function(property)
		if syncing then return end
		if property == "Scale" then
			syncing = true
			scaleSlider:UpdateValue(Window:GetScale())
			syncing = false
		elseif property == "Keybind" then
			syncing = true
			menuKeybind:Bind(Window:GetKeybind())
			syncing = false
		elseif property == "Notifications" then
			syncing = true
			notificationsSetting:UpdateState(Window:GetNotificationsState())
			syncing = false
		elseif property == "AcrylicBlur" then
			syncing = true
			blurSetting:UpdateState(Window:GetAcrylicBlurState())
			syncing = false
		elseif property == "UserInfo" then
			syncing = true
			userInfoSetting:UpdateState(Window:GetUserInfoState())
			syncing = false
		end
	end)

	local settingsRight = settings:Section({ Side = "Right" })
	settingsRight:Header({ Text = "Window settings" })
	settingsRight:Paragraph({
		Header = "Global settings",
		Body = "UI blur, notifications and user info live in the globe menu in the title bar. The controls on the left change the interface scale and the menu key.",
	})

	settingsRight:Button({
		Name = "Reset window settings",
		Callback = resetWindowSettings,
	}, "DemoReset")

	Window.onUnloaded(function()
		if windowConnection then
			windowConnection:Disconnect()
			windowConnection = nil
		end
		if scaleConnection then
			scaleConnection:Disconnect()
			scaleConnection = nil
		end
		demoKeybind:Destroy()
		menuKeybind:Destroy()
		previewPart:Destroy()
		banner:Destroy()
	end)

	controls:Select()
	return Window
end
end function __DARKLUA_BUNDLE_MODULES.U():typeof(__modImpl())local v=__DARKLUA_BUNDLE_MODULES.cache.U if not v then v={c=__modImpl()}__DARKLUA_BUNDLE_MODULES.cache.U=v end return v.c end end end--[[
MIT License

Copyright (c) 2024 Proton Utilities

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]]

--[[
The media, row, dependency box and inline key picker components were derived
from FractHub-Obsidian-Library.

MIT License

Copyright (c) 2025 deividcomsono

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]]


local core = __DARKLUA_BUNDLE_MODULES.c()
local icons = __DARKLUA_BUNDLE_MODULES.d()
local installWindow = __DARKLUA_BUNDLE_MODULES.T()
local demo = __DARKLUA_BUNDLE_MODULES.U()

local FractUI = core.FractUI
FractUI.Icons = icons

installWindow(FractUI)

function FractUI:Demo()
	return demo(FractUI)
end

return FractUI
