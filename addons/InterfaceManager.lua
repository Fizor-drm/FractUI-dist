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

--// The interface manager of FractUI.
--// This file is a standalone bundle. The library is handed over with
--// SetLibrary, so the manager never holds a second copy of it.
--// It only touches the interface of the window. It never talks to the game
--// and it never talks to the network.

local InterfaceManager = {
	Library = nil,
	Window = nil,

	--// The connections the manager holds. They are released before the
	--// section is built again, so a section that is mounted twice does not
	--// listen twice.
	Connections = {},

	--// The widgets of the last section, so a script can drive them.
	Widgets = {},
}

local function getLibrary()
	return InterfaceManager.Library
end

--// Library \\--

function InterfaceManager:SetLibrary(Library)
	InterfaceManager.Library = Library
	return InterfaceManager
end

function InterfaceManager:SetWindow(Window)
	InterfaceManager.Window = Window
	return InterfaceManager
end

--// Releases the connections of the manager.
function InterfaceManager:Destroy()
	for _, connection in ipairs(InterfaceManager.Connections) do
		if connection and connection.Disconnect then
			connection:Disconnect()
		end
	end
	InterfaceManager.Connections = {}
end

--// The editor \\--

--// Builds the interface section inside a section.
function InterfaceManager:BuildConfigSection(Section, Window)
	local Library = getLibrary()
	if not Library then return Section end

	Window = Window or InterfaceManager.Window
	if not Window then return Section end

	--// A section that is built again does not keep the connections of the
	--// last one.
	InterfaceManager:Destroy()

	InterfaceManager.Window = Window

	Section:Header({ Text = "Interface" })

	--// The section follows the window while it changes somewhere else. The
	--// guard keeps the two sides from driving each other.
	local updating = false

	local scale = Section:Slider({
		Name = "Scale",
		Default = Window:GetScale(),
		Minimum = 0.5,
		Maximum = 2,
		Precision = 2,
		Callback = function(Value)
			Window:SetScale(Value)
		end,
	})

	local blur = Section:Toggle({
		Name = "Acrylic blur",
		Default = Window:GetAcrylicBlurState(),
		Callback = function(State)
			Window:SetAcrylicBlurState(State)
		end,
	})

	local notifications = Section:Toggle({
		Name = "Notifications",
		Default = Window:GetNotificationsState(),
		Callback = function(State)
			Window:SetNotificationsState(State)
		end,
	})

	local userInfo = Section:Toggle({
		Name = "User info",
		Default = Window:GetUserInfoState(),
		Callback = function(State)
			Window:SetUserInfoState(State)
		end,
	})

	local visible = Section:Toggle({
		Name = "Visible",
		Default = Window:GetState(),
		Callback = function(State)
			Window:SetState(State)
		end,
	})

	local keybind = Section:Keybind({
		Name = "Window keybind",
		Default = Window:GetKeybind(),
		onBinded = function(Key)
			if updating or not Key then return end
			Window:SetKeybind(Key)
		end,
	})

	local function refresh()
		if updating then return end
		updating = true

		scale:UpdateValue(Window:GetScale())
		blur:UpdateState(Window:GetAcrylicBlurState())
		notifications:UpdateState(Window:GetNotificationsState())
		userInfo:UpdateState(Window:GetUserInfoState())
		visible:UpdateState(Window:GetState())
		-- The keybind of the window shows in the section as well.
		keybind:Bind(Window:GetKeybind())

		updating = false
	end

	if Window.Changed then
		table.insert(InterfaceManager.Connections, Window.Changed:Connect(refresh))
	end

	if Window.onUnloaded then
		table.insert(InterfaceManager.Connections, Window.onUnloaded(function()
			InterfaceManager:Destroy()
		end))
	end

	InterfaceManager.Widgets = {
		Scale = scale,
		Blur = blur,
		Notifications = notifications,
		UserInfo = userInfo,
		Visible = visible,
		Keybind = keybind,
	}

	return Section
end

--// Builds the interface section in a tab of its own.
function InterfaceManager:ApplyToTab(Tab, Side)
	if not Tab or not Tab.Section then
		return nil, "A tab is needed."
	end

	local section = Tab:Section({ Side = Side or "Left" })
	return InterfaceManager:BuildConfigSection(section, Tab.Window)
end

return InterfaceManager
