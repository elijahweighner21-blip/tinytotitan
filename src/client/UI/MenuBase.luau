--!strict
--[[
	MenuBase
	Shared scaffolding for every full-screen menu: builds the Window (and
	optional Tabs), registers it with UIManager, wires the close button, and
	re-renders when relevant replicated data changes WHILE the menu is open
	(closed menus do no work). Screens only implement `render(tab)`.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage:WaitForChild("Shared").Util.Signal)

local UI = script.Parent
local UIManager = require(UI.UIManager)
local Window = require(UI.Components.Window)
local Tabs = require(UI.Components.Tabs)
local DataController = require(UI.Parent.Controllers.DataController)

local MenuBase = {}

export type Options = {
	Name: string,
	Title: string,
	Icon: string?,
	Accent: Color3?,
	Size: UDim2?,
	Tabs: { Tabs.TabDef }?,
	-- Data keys (top-level save sections) that trigger a re-render.
	Watch: { string }?,
	Render: (menu: Menu, tab: string) -> (),
	OnOpen: ((menu: Menu) -> ())?,
	OnClose: ((menu: Menu) -> ())?,
}

export type Menu = {
	Name: string,
	Window: Window.Window,
	Tabs: Tabs.Tabs?,
	Tab: string,
	Content: Frame,
	Opened: Signal.Signal<>,
	Refresh: (self: Menu) -> (),
	SelectTab: (self: Menu, tab: string) -> (),
	IsOpen: (self: Menu) -> boolean,
}

function MenuBase.new(opts: Options): Menu
	local window = Window.new({
		Name = opts.Name,
		Title = opts.Title,
		Icon = opts.Icon,
		Accent = opts.Accent,
		Size = opts.Size,
		Parent = UIManager.Menus,
		Tabs = opts.Tabs ~= nil,
	})
	local menu: any = {
		Name = opts.Name,
		Window = window,
		Tabs = nil,
		Tab = if opts.Tabs then opts.Tabs[1].Id else "",
		Content = window.Content,
		Opened = Signal.new(),
	}

	function menu.Refresh(self: any)
		if not window:IsOpen() then
			return
		end
		local ok, err = pcall(function()
			opts.Render(self, self.Tab)
		end)
		if not ok then
			warn("[" .. opts.Name .. "] render failed:", err)
		end
	end

	function menu.SelectTab(self: any, tab: string)
		if self.Tabs then
			self.Tabs:Select(tab)
		else
			self.Tab = tab
			self:Refresh()
		end
	end

	function menu.IsOpen(_self: any): boolean
		return window:IsOpen()
	end

	if opts.Tabs then
		menu.Tabs = Tabs.new(window.TabBar, opts.Tabs, opts.Accent, function(id)
			menu.Tab = id
			menu:Refresh()
		end)
	end

	window.OnClose = function()
		UIManager:Close(opts.Name)
	end

	UIManager:RegisterMenu(opts.Name, {
		Root = window.Root,
		Open = function()
			window:Open()
			if opts.OnOpen then
				opts.OnOpen(menu)
			end
			if menu.Tabs and menu.Tabs.Selected == "" then
				menu.Tabs:Select(menu.Tab)
			else
				menu:Refresh()
			end
			menu.Opened:Fire()
		end,
		Close = function()
			window:Close()
			if opts.OnClose then
				opts.OnClose(menu)
			end
		end,
	})

	if opts.Watch then
		local watched: { [string]: boolean } = {}
		for _, key in opts.Watch do
			watched[key] = true
		end
		DataController.Changed:Connect(function(key)
			if watched[key] or watched["*"] then
				menu:Refresh()
			end
		end)
	end
	return menu :: Menu
end

return MenuBase
