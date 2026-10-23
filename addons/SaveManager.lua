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

--// The save manager of FractUI.
--// This file is a standalone bundle. The library is handed over with
--// SetLibrary, so the manager never holds a second copy of it. The configs
--// themselves are written by the library, so a config file of both is the
--// same file.

local SaveManager = {
	Library = nil,

	--// The flags that are left out of every save.
	IgnoreIndexes = {},
}

local function getLibrary()
	return SaveManager.Library
end

local function getUtil()
	local Library = getLibrary()
	return Library and Library.Util
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

function SaveManager:SetLibrary(Library)
	SaveManager.Library = Library
	return SaveManager
end

--// Folders \\--

function SaveManager:GetFolder()
	local Library = getLibrary()
	if not Library then return nil end
	return Library.Folder
end

--// Uses another folder for the configs. The data that is already there stays
--// where it is, nothing is moved and nothing is removed.
function SaveManager:SetFolder(Path)
	local Library = getLibrary()
	if not Library then
		return false, "The library is not set, call SetLibrary first."
	end

	return Library:SetFolder(Path)
end

function SaveManager:BuildFolderTree()
	local util = getUtil()
	if not util then
		return false, "The library is not set, call SetLibrary first."
	end

	local folder = self:GetFolder()
	if not folder then
		return false, "The library is not set, call SetLibrary first."
	end

	return util.BuildFolderTree(folder .. "/settings")
end

local function configPath(Name)
	local folder = SaveManager:GetFolder()
	if not folder then return nil end
	return folder .. "/settings/" .. Name .. ".json"
end

local function autoloadPath()
	local folder = SaveManager:GetFolder()
	if not folder then return nil end
	return folder .. "/settings/autoload.txt"
end

--// Configs \\--

--// The names of the configs that are stored on disk.
function SaveManager:List()
	local Library = getLibrary()
	if not Library then return {} end

	local list = Library:RefreshConfigList()
	if type(list) ~= "table" then return {} end

	return list
end

--// Runs an action without the flags of the ignore list, so they are left out
--// of the save.
local function withIgnoredFlags(Library, Action)
	local restore = {}
	local ignored = {}
	for _, flag in ipairs(SaveManager.IgnoreIndexes) do
		local option = Library.Options[flag]
		-- A flag that is in the list twice keeps the value it had before the
		-- save, so it is not left out of every save that follows.
		if option and not ignored[flag] then
			ignored[flag] = true
			restore[flag] = option.IgnoreConfig
			option.IgnoreConfig = true
		end
	end

	local ok, result, message = pcall(Action)

	for flag in pairs(ignored) do
		Library.Options[flag].IgnoreConfig = restore[flag]
	end

	if not ok then error(result, 0) end
	return result, message
end

--// Writes the config. A config that exists is never overwritten, the
--// overwrite path is the other one.
local function writeConfig(Name, Overwrite)
	local Library = getLibrary()
	local util = getUtil()
	if not Library or not util then
		return false, "The library is not set, call SetLibrary first."
	end

	if not util.IsValidName(Name) then
		return false, "Invalid config name provided."
	end

	if not Overwrite and util.IsFile(configPath(Name)) then
		return false, "A config with this name already exists."
	end

	local saved, message = withIgnoredFlags(Library, function()
		return Library:SaveConfig(Name)
	end)

	if not saved then return false, message end
	return true
end

--// Writes the config. The ignored flags are left out of this save only.
function SaveManager:Save(Name)
	return writeConfig(Name, false)
end

--// Writes the config over a config that exists.
function SaveManager:Overwrite(Name)
	return writeConfig(Name, true)
end

--// Reads a config back.
function SaveManager:Load(Name)
	local Library = getLibrary()
	local util = getUtil()
	if not Library or not util then
		return false, "The library is not set, call SetLibrary first."
	end

	if not util.IsValidName(Name) then
		return false, "Invalid config name provided."
	end

	local loaded, message = Library:LoadConfig(Name)
	if not loaded then return false, message end
	return true
end

--// Removes a config. The autoload entry of that config is removed as well.
function SaveManager:Delete(Name)
	local util = getUtil()
	if not util then
		return false, "The library is not set, call SetLibrary first."
	end

	if not util.IsValidName(Name) then
		return false, "Invalid config name provided."
	end

	local file = configPath(Name)
	if not file or not util.IsFile(file) then
		return false, "The config does not exist."
	end

	local deleted, deleteMessage = util.DeleteFile(file)
	if not deleted then return false, deleteMessage end

	-- The autoload entry of the config is removed as well. The config is
	-- gone when the entry cannot be removed, so the report tells what is
	-- left of it.
	local autoload, autoloadOk = self:GetAutoload()
	if autoloadOk and autoload == Name then
		local cleared, clearMessage = self:DeleteAutoload()
		if not cleared then
			return false, "The config was deleted, but the autoload entry is still there: " .. tostring(clearMessage)
		end
	end

	return true
end

--// JSON \\--

--// The config as JSON text. The ignored flags are left out as well.
function SaveManager:SaveJSON()
	local Library = getLibrary()
	if not Library then
		return "", false, "The library is not set, call SetLibrary first."
	end

	local HttpService = Library.GetService("HttpService")
	local configData = withIgnoredFlags(Library, function()
		return Library:BuildConfigData()
	end)
	local encoded, data = pcall(HttpService.JSONEncode, HttpService, configData)
	if not encoded then
		return "", false, "Unable to encode the config."
	end

	return data, true
end

--// Reads a config from JSON text.
function SaveManager:LoadJSON(Content)
	local Library = getLibrary()
	if not Library then
		return false, "The library is not set, call SetLibrary first."
	end

	if type(Content) ~= "string" or Content == "" then
		return false, "No JSON provided."
	end

	local HttpService = Library.GetService("HttpService")
	local decoded, data = pcall(HttpService.JSONDecode, HttpService, Content)
	if not decoded or type(data) ~= "table" then
		return false, "Unable to decode the config."
	end

	local applied, message = Library:ApplyConfigData(data)
	if not applied then return false, message end
	return true
end

--// Ignored flags \\--

--// The flags that are left out of every save.
function SaveManager:SetIgnoreIndexes(Indexes)
	if Indexes == nil then
		SaveManager.IgnoreIndexes = {}
		return true
	end

	if type(Indexes) ~= "table" then
		return false, "The ignore list has to be a table of flags."
	end

	for _, flag in ipairs(Indexes) do
		if type(flag) ~= "string" then
			return false, "The ignore list holds a flag that is not a name."
		end
	end

	SaveManager.IgnoreIndexes = table.clone(Indexes)
	return true
end

function SaveManager:GetIgnoreIndexes()
	return table.clone(SaveManager.IgnoreIndexes)
end

--// Autoload \\--

--// The config that is loaded when the library starts.
function SaveManager:GetAutoload()
	local util = getUtil()
	if not util then
		return "none", false, "The library is not set, call SetLibrary first."
	end

	local file = autoloadPath()
	if not file or not util.IsFile(file) then
		return "none", false, "No autoload config is set."
	end

	local read, name = util.ReadFile(file)
	if not read or type(name) ~= "string" or name == "" then
		return "none", false, "The autoload config is not readable."
	end

	return name, true
end

function SaveManager:SetAutoload(Name)
	local util = getUtil()
	if not util then
		return false, "The library is not set, call SetLibrary first."
	end

	if not util.IsValidName(Name) then
		return false, "Invalid config name provided."
	end

	local built, buildMessage = self:BuildFolderTree()
	if not built then return false, buildMessage end

	local written, writeMessage = util.WriteFile(autoloadPath(), Name)
	if not written then return false, writeMessage end

	return true
end

function SaveManager:DeleteAutoload()
	local util = getUtil()
	if not util then
		return false, "The library is not set, call SetLibrary first."
	end

	local file = autoloadPath()
	if not file or not util.IsFile(file) then
		return false, "No autoload config is set."
	end

	local deleted, deleteMessage = util.DeleteFile(file)
	if not deleted then return false, deleteMessage end

	return true
end

--// Loads the config that is marked as the autoload one.
function SaveManager:LoadAutoload()
	local name, ok, message = self:GetAutoload()
	if not ok then return false, message end

	return self:Load(name)
end

--// The editor \\--

--// Builds the config section inside a section.
function SaveManager:BuildConfigSection(Section, Window)
	local Library = getLibrary()
	if not Library then return Section end

	Section:Header({ Text = "Config" })

	local configName = Section:Input({
		Name = "Config name",
		Placeholder = "Name",
		AcceptedCharacters = "All",
	})

	local configList = Section:Dropdown({
		Name = "Saved configs",
		Multi = false,
		Required = false,
		Options = SaveManager:List(),
	})

	local autoloadLabel = Section:Label({ Text = "Autoload config: none" })

	--// Puts the list of the configs into the dropdown again.
	local function refreshList()
		configList:ClearOptions()
		configList:InsertOptions(SaveManager:List())
	end

	--// The label shows the autoload config.
	local function refreshAutoload()
		local name = SaveManager:GetAutoload()
		autoloadLabel:UpdateName("Autoload config: " .. (name or "none"))
	end

	--// The config that the actions work on: the one of the dropdown, or the
	--// one that was typed in.
	local function selectedName()
		local name = configList.Value
		if type(name) == "string" and name ~= "" then
			return name
		end
		return configName:GetInput()
	end

	Section:Button({
		Name = "Create config",
		Callback = function()
			local Name = configName:GetInput()
			local saved, message = SaveManager:Save(Name)
			if not saved then
				notify(Window, "Config", message)
				return
			end
			notify(Window, "Config", string.format("Created the config %q", Name))
			refreshList()
		end,
	})

	Section:Button({
		Name = "Load config",
		Callback = function()
			local Name = selectedName()
			local loaded, message = SaveManager:Load(Name)
			if not loaded then
				notify(Window, "Config", message)
				return
			end
			notify(Window, "Config", string.format("Loaded the config %q", Name))
		end,
	})

	Section:Button({
		Name = "Overwrite config",
		Callback = function()
			local Name = selectedName()
			confirm(
				Window,
				"Overwrite config",
				string.format("Overwrite the config %q with the values of the interface?", Name),
				"Overwrite",
				function()
					local saved, message = SaveManager:Overwrite(Name)
					if not saved then
						notify(Window, "Config", message)
						return
					end
					notify(Window, "Config", string.format("Overwrote the config %q", Name))
				end
			)
		end,
	})

	Section:Button({
		Name = "Delete config",
		Callback = function()
			local Name = selectedName()
			confirm(
				Window,
				"Delete config",
				string.format("Delete the config %q? This cannot be undone.", Name),
				"Delete",
				function()
					local deleted, message = SaveManager:Delete(Name)
					if not deleted then
						notify(Window, "Config", message)
						return
					end
					notify(Window, "Config", string.format("Deleted the config %q", Name))
					refreshList()
					refreshAutoload()
				end
			)
		end,
	})

	Section:Button({
		Name = "Set as autoload",
		Callback = function()
			local Name = selectedName()
			local saved, message = SaveManager:SetAutoload(Name)
			if not saved then
				notify(Window, "Config", message)
				return
			end
			notify(Window, "Config", string.format("The autoload config is now %q", Name))
			refreshAutoload()
		end,
	})

	Section:Button({
		Name = "Clear autoload",
		Callback = function()
			local cleared, message = SaveManager:DeleteAutoload()
			if not cleared then
				notify(Window, "Config", message)
				return
			end
			notify(Window, "Config", "The autoload config is cleared.")
			refreshAutoload()
		end,
	})

	Section:Button({
		Name = "Refresh config list",
		Callback = function()
			refreshList()
			refreshAutoload()
		end,
	})

	Section:Divider()

	local configJson = Section:Input({
		Name = "Config JSON",
		Placeholder = "{ }",
		AcceptedCharacters = "All",
	})

	Section:Button({
		Name = "Import config",
		Callback = function()
			local Content = configJson:GetInput()
			confirm(
				Window,
				"Import config",
				"Import this config? The values of the interface are replaced.",
				"Import",
				function()
					local applied, message = SaveManager:LoadJSON(Content)
					if not applied then
						notify(Window, "Config", message)
						return
					end
					notify(Window, "Config", "The config was imported.")
				end
			)
		end,
	})

	Section:Button({
		Name = "Export config",
		Callback = function()
			local json, ok, message = SaveManager:SaveJSON()
			if not ok then
				notify(Window, "Config", message)
				return
			end
			configJson:UpdateText(json)
		end,
	})

	refreshAutoload()

	return Section
end

--// Builds the config section in a tab of its own.
function SaveManager:ApplyToTab(Tab, Side)
	if not Tab or not Tab.Section then
		return nil, "A tab is needed."
	end

	local section = Tab:Section({ Side = Side or "Left" })
	return SaveManager:BuildConfigSection(section, Tab.Window)
end

return SaveManager
