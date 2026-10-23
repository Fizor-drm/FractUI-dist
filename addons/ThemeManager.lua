--[[
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

--// The theme manager of FractUI.
--// This file is a standalone bundle. The library is handed over with
--// SetLibrary, so the manager never holds a second copy of it.

local ThemeManager = {
	Library = nil,

	--// An explicit theme folder. Without one the manager follows the folder
	--// of the library.
	Folder = nil,

	DefaultThemeName = nil,

	AppliedToTab = false,
}

local function getLibrary()
	return ThemeManager.Library
end

local function getUtil()
	local Library = getLibrary()
	return Library and Library.Util
end

local function toHex(color)
	return string.format(
		"#%02X%02X%02X",
		math.floor(color.R * 255 + 0.5),
		math.floor(color.G * 255 + 0.5),
		math.floor(color.B * 255 + 0.5)
	)
end

local function notify(Window, Title, Description)
	if Window and Window.Notify then
		Window:Notify({ Title = Title, Description = Description })
	end
end

--// Asks before something is destroyed.
local function confirm(Window, Title, Description, ConfirmText, Action)
	if not Window or not Window.Dialog then
		Action()
		return
	end

	Window:Dialog({
		Title = Title,
		Description = Description,
		Buttons = {
			{
				Name = "Cancel",
				--// The safe answer owns Enter and Escape because the other
				--// one destroys data.
				Default = true,
				Cancel = true,
			},
			{
				Name = ConfirmText,
				Callback = Action,
			},
		},
	})
end

--// Library \\--

function ThemeManager:SetLibrary(Library)
	ThemeManager.Library = Library
	return ThemeManager
end

--// Folders \\--

function ThemeManager:GetFolder()
	if ThemeManager.Folder then
		return ThemeManager.Folder
	end

	local Library = getLibrary()
	if not Library then return nil end

	return Library.Folder .. "/themes"
end

function ThemeManager:SetFolder(Path)
	local util = getUtil()
	if not util then
		return false, "The library is not set, call SetLibrary first."
	end

	if not util.IsValidFolderPath(Path) then
		return false, "Invalid folder path provided."
	end

	-- The folder is only taken when the tree of it is there, so the themes
	-- of the user are still reachable.
	local previous = ThemeManager.Folder
	ThemeManager.Folder = Path

	local built, message = ThemeManager:BuildFolderTree()
	if not built then
		ThemeManager.Folder = previous
		return false, message
	end

	return true
end

function ThemeManager:BuildFolderTree()
	local util = getUtil()
	if not util then
		return false, "The library is not set, call SetLibrary first."
	end

	local path = ThemeManager:GetFolder()
	if not path then
		return false, "The library is not set, call SetLibrary first."
	end

	return util.BuildFolderTree(path)
end

local function themeFilePath(Name)
	return ThemeManager:GetFolder() .. "/" .. Name .. ".json"
end

local function defaultFilePath()
	return ThemeManager:GetFolder() .. "/default.txt"
end

--// Themes \\--

--// The names of the custom themes that are stored on disk.
function ThemeManager:GetThemes()
	local util = getUtil()
	if not util then return {} end

	local path = ThemeManager:GetFolder()
	if not path or not util.IsFolder(path) then return {} end

	local listed, list = util.ListFiles(path)
	if not listed then return {} end

	local names = {}
	for _, file in ipairs(list) do
		local name = file:match("([^/\\]+)%.json$")
		if name and name ~= "default" then
			table.insert(names, name)
		end
	end

	table.sort(names)
	return names
end

--// The built-in theme of the library. It always matches the shipped colors.
function ThemeManager:GetBuiltInThemes()
	local Library = getLibrary()
	if not Library or not Library.Theme then return {} end

	local themes = { Default = {} }
	for _, name in ipairs(Library.Theme.Order) do
		themes.Default[name] = toHex(Library.Theme.Defaults[name])
	end

	return themes
end

--// The colors that are active right now.
function ThemeManager:GetCurrentTheme()
	local Library = getLibrary()
	if not Library or not Library.Theme then return {} end

	local theme = {}
	for _, name in ipairs(Library.Theme.Order) do
		theme[name] = toHex(Library.Theme.Get(name))
	end

	return theme
end

--// Applies a theme. Every token is checked first, so a broken theme keeps
--// the theme that is active.
function ThemeManager:ApplyThemeData(Data)
	local Library = getLibrary()
	if not Library or not Library.Theme then
		return false, "The library is not set, call SetLibrary first."
	end

	if type(Data) ~= "table" then
		return false, "Invalid theme data."
	end

	local tokens = {}
	for name, hex in pairs(Data) do
		if not Library.Theme.Defaults[name] then
			return false, string.format("Unknown theme token %q", tostring(name))
		end
		if type(hex) ~= "string" or not hex:match("^#?%x%x%x%x%x%x$") then
			return false, string.format("The theme token %q is not a hex color", tostring(name))
		end
		tokens[name] = Color3.fromHex(hex)
	end

	local applied, message = Library.Theme.Update(tokens)
	if not applied then
		return false, message
	end

	return true
end

--// The theme data of a stored theme.
function ThemeManager:GetCustomTheme(Name)
	local util = getUtil()
	if not util then return nil end
	if not util.IsValidName(Name) then return nil end

	local file = themeFilePath(Name)
	if not util.IsFile(file) then return nil end

	local read, content = util.ReadFile(file)
	if not read then return nil end

	local Library = getLibrary()
	local HttpService = Library.GetService("HttpService")
	local decoded, data = pcall(HttpService.JSONDecode, HttpService, content)
	if not decoded or type(data) ~= "table" then return nil end

	return data
end

--// Applies a built-in or a stored theme.
function ThemeManager:ApplyTheme(Name)
	if type(Name) ~= "string" or Name == "" then
		return false, "No theme is selected."
	end

	local builtIn = self:GetBuiltInThemes()
	if builtIn[Name] then
		return self:ApplyThemeData(builtIn[Name])
	end

	local data = self:GetCustomTheme(Name)
	if not data then
		return false, "The theme does not exist."
	end

	return self:ApplyThemeData(data)
end

--// Stores the active theme under a name. A theme that exists is never
--// overwritten, the overwrite path is the other one.
local function writeCustomTheme(Name, Overwrite)
	local util = getUtil()
	if not util then
		return false, "The library is not set, call SetLibrary first."
	end

	if not util.IsValidName(Name) then
		return false, "Invalid theme name provided."
	end
	if string.lower(Name) == "default" then
		return false, "Invalid theme name provided."
	end
	if not Overwrite and util.IsFile(themeFilePath(Name)) then
		return false, "A theme with this name already exists."
	end

	local built, buildMessage = ThemeManager:BuildFolderTree()
	if not built then return false, buildMessage end

	local json, ok, encodeMessage = ThemeManager:SaveJSON()
	if not ok then return false, encodeMessage end

	local written, writeMessage = util.WriteFile(themeFilePath(Name), json)
	if not written then return false, writeMessage end

	return true
end

--// Stores the active theme under a name.
function ThemeManager:SaveCustomTheme(Name)
	return writeCustomTheme(Name, false)
end

--// Stores the active theme over a theme that exists.
function ThemeManager:OverwriteCustomTheme(Name)
	return writeCustomTheme(Name, true)
end

--// Removes a stored theme.
function ThemeManager:Delete(Name)
	local util = getUtil()
	if not util then
		return false, "The library is not set, call SetLibrary first."
	end

	if not util.IsValidName(Name) then
		return false, "Invalid theme name provided."
	end
	if self:GetBuiltInThemes()[Name] then
		return false, "The built-in theme cannot be deleted."
	end

	local file = themeFilePath(Name)
	if not util.IsFile(file) then
		return false, "The theme does not exist."
	end

	-- The default theme is looked up on the disk, so a session that never
	-- read it still cleans the reference up.
	local defaultName, defaultOk = self:GetDefaultTheme()
	if not defaultOk then
		defaultName = nil
	end

	local deleted, deleteMessage = util.DeleteFile(file)
	if not deleted then return false, deleteMessage end

	if defaultName == Name then
		local cleared, clearMessage = self:DeleteDefaultTheme()
		if not cleared then return false, clearMessage end
	end

	return true
end

--// The theme that is used when the library starts.
function ThemeManager:GetDefaultTheme()
	local util = getUtil()
	if not util then
		return "none", false, "The library is not set, call SetLibrary first."
	end

	local file = defaultFilePath()
	if not util.IsFile(file) then
		return "none", false, "No default theme is set."
	end

	local read, name = util.ReadFile(file)
	if not read or type(name) ~= "string" or name == "" then
		return "none", false, "The default theme is not readable."
	end

	ThemeManager.DefaultThemeName = name
	return name, true
end

function ThemeManager:SetDefaultTheme(Name)
	local util = getUtil()
	if not util then
		return false, "The library is not set, call SetLibrary first."
	end

	if type(Name) ~= "string" or Name == "" then
		return false, "No theme is selected."
	end

	local built, buildMessage = self:BuildFolderTree()
	if not built then return false, buildMessage end

	if not self:GetBuiltInThemes()[Name] and not self:GetCustomTheme(Name) then
		return false, "The theme does not exist."
	end

	local written, writeMessage = util.WriteFile(defaultFilePath(), Name)
	if not written then return false, writeMessage end

	ThemeManager.DefaultThemeName = Name
	return true
end

function ThemeManager:DeleteDefaultTheme()
	local util = getUtil()
	if not util then
		return false, "The library is not set, call SetLibrary first."
	end

	local file = defaultFilePath()
	if not util.IsFile(file) then
		return false, "No default theme is set."
	end

	local deleted, deleteMessage = util.DeleteFile(file)
	if not deleted then return false, deleteMessage end

	ThemeManager.DefaultThemeName = nil
	return true
end

--// Applies the theme that is marked as the default one.
function ThemeManager:LoadDefaultTheme()
	local name, ok, message = self:GetDefaultTheme()
	if not ok then
		return false, message
	end

	return self:ApplyTheme(name)
end

--// Puts the shipped colors back.
function ThemeManager:ResetTheme()
	local Library = getLibrary()
	if not Library or not Library.Theme then
		return false, "The library is not set, call SetLibrary first."
	end

	Library.Theme.Reset()
	return true
end

--// JSON \\--

function ThemeManager:SaveJSON()
	local Library = getLibrary()
	if not Library then
		return "", false, "The library is not set, call SetLibrary first."
	end

	local HttpService = Library.GetService("HttpService")
	local encoded, data = pcall(HttpService.JSONEncode, HttpService, ThemeManager:GetCurrentTheme())
	if not encoded then
		return "", false, "Unable to encode the theme."
	end

	return data, true
end

function ThemeManager:LoadJSON(Content)
	if type(Content) ~= "string" or Content == "" then
		return false, "No JSON provided."
	end

	local Library = getLibrary()
	if not Library then
		return false, "The library is not set, call SetLibrary first."
	end

	local HttpService = Library.GetService("HttpService")
	local decoded, data = pcall(HttpService.JSONDecode, HttpService, Content)
	if not decoded or type(data) ~= "table" then
		return false, "Unable to decode the theme data."
	end

	return ThemeManager:ApplyThemeData(data)
end

--// The editor \\--

--// Builds the theme editor inside a section.
function ThemeManager:BuildConfigSection(Section, Window)
	local Library = getLibrary()
	if not Library or not Library.Theme then
		return Section
	end

	Section:Header({ Text = "Theme" })

	local pickers = {}

	--// Every token has its own color picker. Picking a color applies it live.
	for _, name in ipairs(Library.Theme.Order) do
		local picker = Section:Colorpicker({
			Name = name,
			Default = Library.Theme.Get(name),
			Callback = function(color)
				ThemeManager:ApplyThemeData({ [name] = toHex(color) })
			end,
		})
		pickers[name] = picker
	end

	--// The pickers show the colors that are active.
	local function refreshPickers()
		for name, picker in pairs(pickers) do
			picker:SetColor(Library.Theme.Get(name))
		end
	end

	Section:Divider()

	local themeList = Section:Dropdown({
		Name = "Theme",
		Multi = false,
		Required = false,
		Options = { "Default" },
		Callback = function(Value)
			if not Value then return end
			local applied, message = ThemeManager:ApplyTheme(Value)
			if not applied then
				notify(Window, "Theme", message)
				return
			end
			refreshPickers()
		end,
	})
	--// Puts the list of the themes into the dropdown again.
	local function refreshList()
		local names = { "Default" }
		for _, name in ipairs(ThemeManager:GetThemes()) do
			table.insert(names, name)
		end
		themeList:ClearOptions()
		themeList:InsertOptions(names)
	end

	local themeName = Section:Input({
		Name = "Theme name",
		Placeholder = "Name",
		AcceptedCharacters = "All",
	})

	Section:Button({
		Name = "Save theme",
		Callback = function()
			local Name = themeName:GetInput()
			local applied, message = ThemeManager:SaveCustomTheme(Name)
			if not applied then
				notify(Window, "Theme", message)
				return
			end
			notify(Window, "Theme", string.format("Saved the theme %q", Name))
			refreshList()
		end,
	})

	Section:Button({
		Name = "Overwrite theme",
		Callback = function()
			local Name = themeName:GetInput()
			confirm(
				Window,
				"Overwrite theme",
				string.format("Overwrite the theme %q with the colors that are active?", Name),
				"Overwrite",
				function()
					local applied, message = ThemeManager:OverwriteCustomTheme(Name)
					if not applied then
						notify(Window, "Theme", message)
						return
					end
					notify(Window, "Theme", string.format("Overwrote the theme %q", Name))
				end
			)
		end,
	})

	Section:Button({
		Name = "Delete theme",
		Callback = function()
			local Name = themeName:GetInput()
			confirm(
				Window,
				"Delete theme",
				string.format("Delete the theme %q? This cannot be undone.", Name),
				"Delete",
				function()
					local deleted, message = ThemeManager:Delete(Name)
					if not deleted then
						notify(Window, "Theme", message)
						return
					end
					notify(Window, "Theme", string.format("Deleted the theme %q", Name))
					refreshList()
				end
			)
		end,
	})

	Section:Button({
		Name = "Set as default",
		Callback = function()
			local Name = themeName:GetInput()
			local applied, message = ThemeManager:SetDefaultTheme(Name)
			if not applied then
				notify(Window, "Theme", message)
				return
			end
			notify(Window, "Theme", string.format("The default theme is now %q", Name))
		end,
	})

	Section:Button({
		Name = "Reset default",
		Callback = function()
			confirm(
				Window,
				"Reset default theme",
				"Clear the default theme? The library keeps the built-in one.",
				"Reset",
				function()
					local reset, message = ThemeManager:DeleteDefaultTheme()
					if not reset then
						notify(Window, "Theme", message)
						return
					end
					notify(Window, "Theme", "The default theme is cleared.")
				end
			)
		end,
	})

	Section:Button({
		Name = "Reset colors",
		Callback = function()
			ThemeManager:ResetTheme()
			refreshPickers()
		end,
	})

	Section:Divider()

	local themeJson = Section:Input({
		Name = "Theme JSON",
		Placeholder = "{ }",
		AcceptedCharacters = "All",
	})

	Section:Button({
		Name = "Import theme",
		Callback = function()
			local Content = themeJson:GetInput()
			confirm(
				Window,
				"Import theme",
				"Import this theme? The colors that are active are replaced.",
				"Import",
				function()
					local applied, message = ThemeManager:LoadJSON(Content)
					if not applied then
						notify(Window, "Theme", message)
						return
					end
					refreshPickers()
					notify(Window, "Theme", "The theme was imported.")
				end
			)
		end,
	})

	Section:Button({
		Name = "Export theme",
		Callback = function()
			local json, ok, message = ThemeManager:SaveJSON()
			if not ok then
				notify(Window, "Theme", message)
				return
			end
			themeJson:UpdateText(json)
		end,
	})

	refreshList()

	ThemeManager.AppliedToTab = true

	return Section
end

--// Builds the theme editor in a tab of its own.
function ThemeManager:ApplyToTab(Tab, Side)
	if not Tab or not Tab.Section then
		return nil, "A tab is needed."
	end

	local section = Tab:Section({ Side = Side or "Left" })
	return ThemeManager:BuildConfigSection(section, Tab.Window)
end

return ThemeManager
