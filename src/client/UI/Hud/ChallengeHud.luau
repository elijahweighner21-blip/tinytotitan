--!strict
--[[
	ChallengeHud
	Everything shown during a challenge run:
	  * 3-2-1-GO countdown
	  * live timer (time trials count up; scored challenges count down)
	  * progress: checkpoints, tokens, hidden targets or best jump distance
	  * medal thresholds so players know what they are chasing
	  * results card with medal, score, personal best, rewards, Retry/Close
	  * a Leave button (server teleports back to the start pad)
]]

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ChallengeConfig = require(Shared.Config.ChallengeConfig)
local Format = require(Shared.Util.Format)

local Client = script.Parent.Parent.Parent
local Net = require(Client.Net)
local Theme = require(Client.UI.Theme)
local Create = require(Client.UI.Create)
local UIManager = require(Client.UI.UIManager)
local Button = require(Client.UI.Components.Button)
local Bus = require(Client.UI.Bus)
local AudioController = require(Client.Controllers.AudioController)

local ChallengeHud = {}

local MEDAL_COLORS = {
	Color3.fromRGB(205, 127, 50),
	Color3.fromRGB(200, 205, 215),
	Color3.fromRGB(255, 205, 60),
	Color3.fromRGB(120, 220, 255),
}
local MEDAL_ICONS = { "🥉", "🥈", "🥇", "💠" }

type Run = {
	Id: string,
	Name: string,
	ScoreKind: string,
	TimeLimit: number,
	Thresholds: { [string]: number },
	LowerIsBetter: boolean,
	StartedAt: number?,
	Progress: string,
}

local run: Run? = nil
local root: Frame
local countdown: TextLabel
local panel: Frame
local titleLabel: TextLabel
local timerLabel: TextLabel
local progressLabel: TextLabel
local medalsLabel: TextLabel
local results: Frame
local resultsMedal: TextLabel
local resultsTitle: TextLabel
local resultsBody: TextLabel
local retryButton: Button.Button
local lastId: string? = nil

local function scoreText(kind: string, score: number): string
	if kind == "Time" then
		return Format.raceTime(score)
	elseif kind == "Distance" then
		return string.format("%.2f body lengths", score)
	end
	return Format.commas(math.floor(score))
end

local function thresholdsText(r: Run): string
	local parts = {}
	for i, name in ChallengeConfig.Medals do
		local v = r.Thresholds[name]
		if v then
			table.insert(
				parts,
				MEDAL_ICONS[i]
					.. " "
					.. (
						if r.ScoreKind == "Time"
							then Format.raceTime(v)
							elseif r.ScoreKind == "Distance" then string.format("%.1f", v)
							else tostring(v)
					)
			)
		end
	end
	return table.concat(parts, "   ")
end

local function showCountdown(seconds: number)
	countdown.Visible = true
	for i = seconds, 1, -1 do
		countdown.Text = tostring(i)
		countdown.TextTransparency = 0
		countdown.Size = UDim2.fromOffset(300, 160)
		AudioController:Play("Click", { Pitch = 0.8 })
		TweenService
			:Create(countdown, TweenInfo.new(0.9), { TextTransparency = 0.6, Size = UDim2.fromOffset(220, 110) })
			:Play()
		task.wait(1)
		if not run then
			countdown.Visible = false
			return
		end
	end
end

local function go()
	countdown.Text = "GO!"
	countdown.TextTransparency = 0
	countdown.TextColor3 = Theme.Colors.Success
	AudioController:Play("Notify", { Pitch = 1.3 })
	TweenService:Create(countdown, TweenInfo.new(0.8), { TextTransparency = 1 }):Play()
	task.delay(0.85, function()
		countdown.Visible = false
		countdown.TextColor3 = Theme.Colors.Text
	end)
end

local function endRun()
	run = nil
	panel.Visible = false
end

local function showResults(p: { [string]: any }, failed: boolean)
	results.Visible = true
	local def = lastId and ChallengeConfig.get(lastId)
	if failed then
		resultsMedal.Text = "✖"
		resultsMedal.TextColor3 = Theme.Colors.Danger
		resultsTitle.Text = "RUN FAILED"
		resultsBody.Text = tostring(p.Reason or "Better luck next time!")
	else
		local medal = tonumber(p.Medal) or 0
		resultsMedal.Text = if medal > 0 then MEDAL_ICONS[medal] else "🏁"
		resultsMedal.TextColor3 = if medal > 0 then MEDAL_COLORS[medal] else Theme.Colors.Text
		resultsTitle.Text = if medal > 0 then string.upper(ChallengeConfig.Medals[medal]) .. " MEDAL!" else "FINISHED"
		local kind = tostring(p.ScoreKind or "Time")
		local lines = {
			"Score: " .. scoreText(kind, tonumber(p.Score) or 0) .. (if p.NewBest then "   ★ NEW BEST!" else ""),
			"Best: " .. scoreText(kind, tonumber(p.Best) or 0),
		}
		if not p.Ranked then
			table.insert(lines, "Practice run (you're bigger than this course was built for) — no medal.")
		end
		local rewards = {}
		if (tonumber(p.Mass) or 0) > 0 then
			table.insert(rewards, "+" .. Format.abbreviate(p.Mass) .. " Mass")
		end
		if (tonumber(p.GrowthEnergy) or 0) > 0 then
			table.insert(rewards, "+⚡" .. Format.abbreviate(p.GrowthEnergy))
		end
		if (tonumber(p.TitanShards) or 0) > 0 then
			table.insert(rewards, "+🔷" .. Format.abbreviate(p.TitanShards))
		end
		if #rewards > 0 then
			table.insert(lines, table.concat(rewards, "   "))
		end
		resultsBody.Text = table.concat(lines, "\n")
		AudioController:Play(if medal >= 3 then "Achievement" else "Reward")
	end
	retryButton:SetEnabled(def ~= nil)
end

local function onSignal(p: { [string]: any })
	local state = p.State
	if state == "Countdown" then
		local def = ChallengeConfig.get(p.Id)
		lastId = p.Id
		results.Visible = false
		run = {
			Id = p.Id,
			Name = if def then def.Name else tostring(p.Id),
			ScoreKind = tostring(p.ScoreKind or "Time"),
			TimeLimit = tonumber(p.TimeLimit) or 60,
			Thresholds = if type(p.Thresholds) == "table" then p.Thresholds else {},
			LowerIsBetter = p.LowerIsBetter == true,
			StartedAt = nil,
			Progress = "",
		}
		local r = run :: Run
		titleLabel.Text = r.Name .. (if p.Ranked == false then "  (practice)" else "")
		medalsLabel.Text = thresholdsText(r)
		local checkpoints = tonumber(p.Checkpoints) or 0
		local tokens = tonumber(p.Tokens) or 0
		local targets = tonumber(p.Targets) or 0
		r.Progress = if checkpoints > 0
			then string.format("Checkpoints 0/%d", checkpoints)
			elseif targets > 0 then string.format("Found 0/%d", targets)
			elseif tokens > 0 then "Tokens 0"
			elseif r.ScoreKind == "Distance" then "Best jump: —"
			else ""
		progressLabel.Text = r.Progress
		timerLabel.Text = if r.ScoreKind == "Time" then "0:00.00" else Format.clock(r.TimeLimit)
		panel.Visible = true
		task.spawn(showCountdown, tonumber(p.Seconds) or 3)
	elseif state == "Running" then
		local r = run
		if r then
			r.StartedAt = os.clock()
			go()
		end
	elseif state == "Checkpoint" then
		progressLabel.Text = string.format("Checkpoints %d/%d", tonumber(p.Index) or 0, tonumber(p.Total) or 0)
		AudioController:Play("Notify")
	elseif state == "Token" then
		progressLabel.Text = string.format("Tokens %d", tonumber(p.Count) or 0)
		AudioController:Play("Collect")
	elseif state == "Target" then
		progressLabel.Text = string.format("Found %d/%d", tonumber(p.Count) or 0, tonumber(p.Total) or 0)
		AudioController:Play("Discovery")
	elseif state == "Jump" then
		progressLabel.Text = string.format("Last: %.2f   Best: %.2f", tonumber(p.Distance) or 0, tonumber(p.Best) or 0)
	elseif state == "Finished" then
		endRun()
		showResults(p, false)
	elseif state == "Failed" then
		endRun()
		showResults(p, true)
	end
end

function ChallengeHud.isRunning(): boolean
	return run ~= nil
end

function ChallengeHud.mount()
	root = Create("Frame", {
		Name = "Challenge",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = UIManager.Overlay,
	})
	countdown = Create.label("", 110, Theme.Colors.Text, Theme.Fonts.Display, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromOffset(300, 160),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextScaled = true,
		TextStrokeTransparency = 0.2,
		Visible = false,
		Parent = root,
	})
	panel = Create("Frame", {
		Name = "Run",
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = 0.15,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 16),
		Size = UDim2.fromOffset(380, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		Parent = root,
		[Create.Children] = {
			Create.corner(Theme.Radius),
			Create.stroke(Theme.Colors.Accent, 0.5, 2),
			Create.padding(10, 14),
			Create.list(Enum.FillDirection.Vertical, 2, Enum.HorizontalAlignment.Center),
		},
	})
	local function centered(text: string, size: number, color: Color3, font: Font, order: number): TextLabel
		return Create.label(text, size, color, font, {
			Size = UDim2.new(1, 0, 0, size + 6),
			TextXAlignment = Enum.TextXAlignment.Center,
			LayoutOrder = order,
			Parent = panel,
		})
	end
	titleLabel = centered("", Theme.TextSize.Body, Theme.Colors.Accent, Theme.Fonts.Title, 1)
	timerLabel = centered("0:00.00", 36, Theme.Colors.Text, Theme.Fonts.Mono, 2)
	progressLabel = centered("", Theme.TextSize.Body, Theme.Colors.TextDim, Theme.Fonts.Title, 3)
	medalsLabel = centered("", Theme.TextSize.Small, Theme.Colors.TextDim, Theme.Fonts.Body, 4)
	Button.new({
		Text = "Leave",
		Style = "Ghost",
		Size = UDim2.fromOffset(100, 28),
		TextSize = Theme.TextSize.Small,
		LayoutOrder = 5,
		Parent = panel,
		OnClick = function()
			local result = Net.request("LeaveChallenge")
			if not result.ok and result.err then
				Bus.toast(result.err, "Warning")
			end
		end,
	})
	results = Create("Frame", {
		Name = "Results",
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = 0.05,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(420, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
		Parent = root,
		[Create.Children] = {
			Create.corner(Theme.Radius),
			Create.stroke(Theme.Colors.Gold, 0.4, 2),
			Create.padding(18, 20),
			Create.list(Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Center),
		},
	})
	resultsMedal = Create.label("", 64, Theme.Colors.Gold, Theme.Fonts.Display, {
		Size = UDim2.new(1, 0, 0, 72),
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 1,
		Parent = results,
	})
	resultsTitle = Create.label("", Theme.TextSize.Title, Theme.Colors.Text, Theme.Fonts.Display, {
		Size = UDim2.new(1, 0, 0, 32),
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 2,
		Parent = results,
	})
	resultsBody = Create.label("", Theme.TextSize.Body, Theme.Colors.TextDim, Theme.Fonts.Body, {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 3,
		Parent = results,
	})
	local buttons = Create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 40),
		LayoutOrder = 4,
		Parent = results,
		[Create.Children] = { Create.list(Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Center) },
	})
	retryButton = Button.new({
		Text = "Retry",
		Style = "Primary",
		Size = UDim2.fromOffset(140, 40),
		Parent = buttons,
		OnClick = function()
			results.Visible = false
			local id = lastId
			if id then
				local result = Net.request("StartChallenge", { Id = id })
				if not result.ok then
					Bus.toast(result.err or "Walk back to the start pad to retry", "Warning")
				end
			end
		end,
	})
	Button.new({
		Text = "Close",
		Style = "Secondary",
		Size = UDim2.fromOffset(140, 40),
		Parent = buttons,
		OnClick = function()
			results.Visible = false
		end,
	})
	Net.onSignal("Challenge", function(p)
		if type(p) == "table" then
			onSignal(p)
		end
	end)
	RunService.RenderStepped:Connect(function()
		local r = run
		if not r or not r.StartedAt then
			return
		end
		local elapsed = os.clock() - (r.StartedAt :: number)
		if r.ScoreKind == "Time" then
			timerLabel.Text = Format.raceTime(elapsed)
			timerLabel.TextColor3 = if elapsed > r.TimeLimit * 0.85 then Theme.Colors.Danger else Theme.Colors.Text
		else
			local left = math.max(0, r.TimeLimit - elapsed)
			timerLabel.Text = Format.clock(left)
			timerLabel.TextColor3 = if left < 5 then Theme.Colors.Danger else Theme.Colors.Text
		end
	end)
end

return ChallengeHud
