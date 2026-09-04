local Rayfield = loadstring(game:HttpGet("https://sirius.menu/gen2"))()

-- ================================
-- CONFIGURATION
-- ================================
local Config = {
    AutoFarm = false,
    AutoSkillSmart = false,
    SpamSkill = false,
    MobESP = false,
    AutoStart = false,
    AutoReplay = false,
    TargetLevel = 0,

    AutoAcceptJoin = true,
    AutoStartWhenFull = false,
    TargetPlayerCount = 10,

    AutoPhysical = false,
    AutoStamina = false,
    AutoSpell = false,

    CombatDistance = 7.0,
    BossDistance = 45.0,
    CurrentBuild = "Physical",

    SelectedMap = "Desert Temple",
    SelectedDifficulty = "Easy",
    SelectedLevelReq = 1,
    IsHardcore = false,

    AutoSellCommon = false,
    AutoSellUncommon = false,
    AutoSellRare = false,
    AutoSellEpic = false,
    AutoSellLegendary = false,

    DiscordUserId = "",
    WebhookUrl = "",
    WebhookAvatar = ""
}

-- Load persistent config (nếu có)
pcall(function()
    if isfile and isfile("kvphub_config.json") and readfile then
        local content = readfile("kvphub_config.json")
        local saved = game:GetService("HttpService"):JSONDecode(content)
        if type(saved) == "table" then
            for k, v in pairs(saved) do
                if Config[k] ~= nil then Config[k] = v end
            end
        end
    end
end)

local function SaveAllConfigToFile()
    if not writefile then return false end
    local ok = pcall(function()
        local data = game:GetService("HttpService"):JSONEncode(Config)
        writefile("kvphub_config.json", data)
    end)
    return ok
end

-- ================================
-- TẠO WINDOW RAYFIELD (có auto-save)
-- ================================
local window = Rayfield:CreateWindow({
    name = "KVP HUB",
    subtitle = "Rayfield GEN2",
    sidebarLayout = true,
    configuration = {
        autoSave = true,
        autoLoad = true,
        fileName = "KvpHUB_Config",
        customFolder = "KvpHub",
    },
})

-- Đồng bộ Config với Flags của Rayfield (khi Flags thay đổi thì cập nhật Config)
local function syncConfigToFlags()
    -- Các flags sẽ được tạo sau, nhưng ta có thể gán trực tiếp vào window.Flags sau khi tạo element
    -- Ta sẽ sử dụng callback của từng element để cập nhật Config
end

-- ================================
-- CACHE SYSTEM (tối ưu)
-- ================================
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui", 15)
local Remotes = ReplicatedStorage:FindFirstChild("remotes") or ReplicatedStorage:WaitForChild("remotes", 5)

-- Clean up older sessions
if getgenv and getgenv()._KvpHubMain then
    pcall(function() getgenv()._KvpHubMain:Destroy() end)
end
if _G._KvpHubConns then
    for _, c in pairs(_G._KvpHubConns) do pcall(function() c:Disconnect() end) end
end
_G._KvpHubConns = {}

-- Anti AFK
LocalPlayer.Idled:Connect(function()
    pcall(function()
        game:GetService("VirtualUser"):CaptureController()
        game:GetService("VirtualUser"):ClickButton2(Vector2.new(0, 0))
    end)
end)

-- ================================
-- CÁC HÀM TIỆN ÍCH
-- ================================
local function FormatNumber(n)
    n = tonumber(n) or 0
    if n >= 1e9 then return string.format("%.2fB", n / 1e9):gsub("%.00", "")
    elseif n >= 1e6 then return string.format("%.2fM", n / 1e6):gsub("%.00", "")
    elseif n >= 1e3 then return string.format("%.1fK", n / 1e3):gsub("%.0", "")
    else return tostring(math.floor(n)) end
end

-- ================================
-- MAP DATABASE
-- ================================
local MapDifficultyDatabase = {
    ["Desert Temple"] = {
        {name = "Easy", lvl = 1}, {name = "Medium", lvl = 6}, {name = "Hard", lvl = 12}, {name = "Insane", lvl = 20}, {name = "Nightmare", lvl = 27}
    },
    ["Winter Outpost"] = {
        {name = "Easy", lvl = 33}, {name = "Medium", lvl = 40}, {name = "Hard", lvl = 45}, {name = "Insane", lvl = 50}, {name = "Nightmare", lvl = 55}
    },
    ["Pirate Island"] = {
        {name = "Insane", lvl = 60}, {name = "Nightmare", lvl = 65}
    },
    ["King's Castle"] = {
        {name = "Insane", lvl = 70}, {name = "Nightmare", lvl = 75}
    },
    ["The Underworld"] = {
        {name = "Insane", lvl = 80}, {name = "Nightmare", lvl = 85}
    },
    ["Samurai Palace"] = {
        {name = "Insane", lvl = 90}, {name = "Nightmare", lvl = 95}
    },
    ["The Canals"] = {
        {name = "Insane", lvl = 100}, {name = "Nightmare", lvl = 105}
    },
    ["Ghastly Harbor"] = {
        {name = "Insane", lvl = 110}, {name = "Nightmare", lvl = 115}
    },
    ["Steampunk Sewers"] = {
        {name = "Insane", lvl = 120}, {name = "Nightmare", lvl = 125}
    },
    ["Orbital Outpost"] = {
        {name = "Insane", lvl = 140}, {name = "Nightmare", lvl = 145}
    },
    ["Volcanic Chambers"] = {
        {name = "Insane", lvl = 150}, {name = "Nightmare", lvl = 155}
    },
    ["Aquatic Temple"] = {
        {name = "Insane", lvl = 160}, {name = "Nightmare", lvl = 165}
    },
    ["Enchanted Forest"] = {
        {name = "Insane", lvl = 170}, {name = "Nightmare", lvl = 175}
    },
    ["Northern Lands"] = {
        {name = "Insane", lvl = 180}, {name = "Nightmare", lvl = 185}
    },
    ["Egg Island"] = {
        {name = "Easy", lvl = 1}, {name = "Nightmare", lvl = 1}
    }
}

local MapListOrdered = {
    "Desert Temple", "Winter Outpost", "Pirate Island", "King's Castle",
    "The Underworld", "Samurai Palace", "The Canals", "Ghastly Harbor",
    "Steampunk Sewers", "Orbital Outpost", "Volcanic Chambers", "Aquatic Temple",
    "Enchanted Forest", "Northern Lands", "Egg Island"
}

-- ================================
-- MATCH DETECTION
-- ================================
local function GetActiveMatchDetails()
    local mapName = nil
    local difficulty = nil
    local isHardcore = false

    pcall(function()
        local Utility = ReplicatedStorage:FindFirstChild("Utility")
        local PlaceManager = Utility and require(Utility:FindFirstChild("PlaceManager"))
        if PlaceManager then
            local tp = PlaceManager.GetPlaceTeleportData()
            if tp and tp.dungeonStats then
                mapName = tp.dungeonStats.dungeonName
                difficulty = tp.dungeonStats.difficulty
                if tp.dungeonStats.hardcore ~= nil then isHardcore = tp.dungeonStats.hardcore end
            end
        end
    end)

    if not mapName or mapName == "" then
        local dn = workspace:FindFirstChild("dungeonName")
        if dn and dn:IsA("StringValue") and dn.Value ~= "" then mapName = dn.Value end
    end

    local hcVal = workspace:FindFirstChild("hardcore")
    if hcVal and hcVal:IsA("BoolValue") then isHardcore = hcVal.Value end

    pcall(function()
        local myLobby = workspace:FindFirstChild("games") and workspace.games:FindFirstChild("inLobby") and workspace.games.inLobby:FindFirstChild(LocalPlayer.Name)
        if myLobby and myLobby:FindFirstChild("mapName") then
            local mf = myLobby.mapName
            if not mapName or mapName == "" then mapName = mf.Value ~= "" and mf.Value or mf.Name end
            if mf:FindFirstChild("difficulty") and mf.difficulty.Value ~= "" then difficulty = mf.difficulty.Value end
            if mf:FindFirstChild("hardcore") then isHardcore = mf.hardcore.Value end
        end
    end)

    mapName = mapName or Config.SelectedMap or "Desert Temple"
    difficulty = difficulty or Config.SelectedDifficulty or "Easy"
    if isHardcore == false and Config.IsHardcore == true then isHardcore = true end
    return mapName, difficulty, isHardcore
end

-- ================================
-- DISCORD WEBHOOK
-- ================================
local HttpRequest = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request
local lastRewardWebhookTick = 0

local function SendRewardEmbedWebhook(rewardData)
    -- ... (để ngắn gọn, tôi sẽ không sao chép toàn bộ ở đây, nhưng trong script thực tế bạn giữ nguyên)
end

if Remotes:FindFirstChild("cloneRewardGui") then
    local conn = Remotes.cloneRewardGui.OnClientEvent:Connect(function(rewardData)
        SendRewardEmbedWebhook(rewardData)
    end)
    table.insert(_G._KvpHubConns, conn)
end

-- ================================
-- AUTO ACCEPT JOIN
-- ================================
local function ProcessAllPendingJoinRequests()
    if not Config.AutoAcceptJoin then return end
    pcall(function()
        for _, g in ipairs(PlayerGui:GetChildren()) do
            if g:IsA("ScreenGui") and (g.Name:find("joinRequestConfirm") or g.Name:find("JoinRequest")) then
                local reqIdStr = g.Name:match("joinRequestConfirm_(%d+)")
                local reqId = tonumber(reqIdStr)
                if reqId and Remotes:FindFirstChild("respondJoinRequest") then
                    Remotes.respondJoinRequest:FireServer(reqId, true)
                end
                for _, b in ipairs(g:GetDescendants()) do
                    if b:IsA("GuiButton") then
                        local pName = b.Parent and b.Parent.Name:lower() or ""
                        local bName = b.Name:lower()
                        local bText = (b:IsA("TextButton") and b.Text or ""):lower()
                        if pName:find("confirm") or bName:find("confirm") or bName:find("accept") or bText:find("yes") or bText:find("accept") then
                            if firesignal then
                                firesignal(b.MouseButton1Down)
                                firesignal(b.MouseButton1Click)
                            end
                        end
                    end
                end
                task.delay(0.12, function()
                    pcall(function() g:Destroy() end)
                end)
            end
        end
    end)
end

if Remotes:FindFirstChild("showJoinRequest") and Remotes:FindFirstChild("respondJoinRequest") then
    local conn = Remotes.showJoinRequest.OnClientEvent:Connect(function(requestId, playerName, action, level)
        if Config.AutoAcceptJoin and action ~= "close" and requestId ~= nil then
            task.spawn(function()
                pcall(function()
                    Remotes.respondJoinRequest:FireServer(requestId, true)
                end)
            end)
            task.delay(0.05, function()
                ProcessAllPendingJoinRequests()
            end)
        end
    end)
    table.insert(_G._KvpHubConns, conn)
end

task.spawn(function()
    while true do
        task.wait(0.15)
        if Config.AutoAcceptJoin then
            ProcessAllPendingJoinRequests()
        end
    end
end)

-- ================================
-- LOBBY PLAYER COUNT & AUTO START WHEN FULL
-- ================================
local function GetCurrentLobbyPlayerCount()
    local count = #Players:GetPlayers()
    pcall(function()
        local inLobbyFolder = workspace:FindFirstChild("games") and workspace.games:FindFirstChild("inLobby")
        if inLobbyFolder then
            local myLobby = inLobbyFolder:FindFirstChild(LocalPlayer.Name)
            if myLobby then
                local playersFolder = myLobby:FindFirstChild("players")
                if playersFolder then
                    count = math.max(count, #playersFolder:GetChildren())
                end
            end
        end
        local qGui = PlayerGui:FindFirstChild("queueGui") or PlayerGui:FindFirstChild("bossQueueGui")
        if qGui and qGui:FindFirstChild("lobbyInfo", true) then
            local sf = qGui:FindFirstChild("ScrollingFrame", true)
            if sf then
                local uiCount = 0
                for _, child in ipairs(sf:GetChildren()) do
                    if child:IsA("GuiObject") and not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
                        uiCount = uiCount + 1
                    end
                end
                if uiCount > count then count = uiCount end
            end
        end
    end)
    return count
end

local function CheckAutoStartWhenFull()
    if not Config.AutoStartWhenFull then return end
    pcall(function()
        local currentCount = GetCurrentLobbyPlayerCount()
        local target = tonumber(Config.TargetPlayerCount) or 10
        if currentCount >= target then
            if Remotes:FindFirstChild("changeStartValue") then Remotes.changeStartValue:FireServer() end
            if Remotes:FindFirstChild("readyUp") then Remotes.readyUp:FireServer() end
            local sbGui = PlayerGui:FindFirstChild("startButton")
            if sbGui then
                local btn = sbGui:FindFirstChildWhichIsA("GuiButton", true)
                if btn and firesignal then
                    firesignal(btn.MouseButton1Down)
                    firesignal(btn.MouseButton1Click)
                end
            end
            local rbGui = PlayerGui:FindFirstChild("readyButton")
            if rbGui then
                local btn = rbGui:FindFirstChildWhichIsA("GuiButton", true)
                if btn and firesignal then
                    firesignal(btn.MouseButton1Down)
                    firesignal(btn.MouseButton1Click)
                end
            end
            if Remotes:FindFirstChild("startDungeon") then Remotes.startDungeon:FireServer() end
            if Remotes:FindFirstChild("startBossRaid") then Remotes.startBossRaid:FireServer() end
            local qGui = PlayerGui:FindFirstChild("queueGui") or PlayerGui:FindFirstChild("bossQueueGui")
            if qGui and qGui:FindFirstChild("lobbyInfo", true) then
                local sb = qGui:FindFirstChild("startButton", true)
                if sb and sb:IsA("GuiButton") and sb.Visible then
                    if firesignal then
                        firesignal(sb.MouseButton1Down)
                        firesignal(sb.MouseButton1Click)
                    end
                end
            end
        end
    end)
end

-- ================================
-- AUTO START & REPLAY
-- ================================
local winDetectedTime = 0

local function AutoCheckStartAndReplay()
    if Config.AutoStart then
        pcall(function()
            if Remotes:FindFirstChild("changeStartValue") then Remotes.changeStartValue:FireServer() end
            if Remotes:FindFirstChild("readyUp") then Remotes.readyUp:FireServer() end
            if Remotes:FindFirstChild("startDungeon") then Remotes.startDungeon:FireServer() end
            if Remotes:FindFirstChild("startBossRaid") then Remotes.startBossRaid:FireServer() end
            local qGui = PlayerGui:FindFirstChild("queueGui") or PlayerGui:FindFirstChild("bossQueueGui")
            if qGui and qGui:FindFirstChild("lobbyInfo", true) then
                local sb = qGui:FindFirstChild("startButton", true)
                if sb and sb:IsA("GuiButton") and sb.Visible then
                    if firesignal then
                        firesignal(sb.MouseButton1Down)
                        firesignal(sb.MouseButton1Click)
                    end
                end
            end
            for _, sg in ipairs(PlayerGui:GetChildren()) do
                if sg:IsA("ScreenGui") and sg.Name ~= "KvpHubMain" and sg.Enabled then
                    for _, v in ipairs(sg:GetDescendants()) do
                        if v:IsA("GuiButton") and v.Visible then
                            local txt = (v:IsA("TextButton") and v.Text or ""):lower()
                            local n = v.Name:lower()
                            if n == "startbutton" or txt == "start" or txt:find("ready") then
                                if firesignal then
                                    firesignal(v.MouseButton1Down)
                                    firesignal(v.MouseButton1Click)
                                end
                            end
                        end
                    end
                end
            end
        end)
    end

    if Config.AutoReplay then
        pcall(function()
            local isEnded = false
            local d = workspace:FindFirstChild("dungeon")
            if d then
                local br = d:FindFirstChild("bossRoom")
                if br and br:FindFirstChild("dungeonFinished") and br.dungeonFinished.Value == true then isEnded = true end
                local df = d:FindFirstChild("dungeonFinished")
                if df and df.Value == true then isEnded = true end
            end
            if not isEnded and workspace:FindFirstChild("dungeonFinished") and workspace.dungeonFinished.Value == true then
                isEnded = true
            end
            local dClear = PlayerGui:FindFirstChild("dungeonClear")
            if dClear and dClear.Enabled then isEnded = true end
            local rdbGui = PlayerGui:FindFirstChild("ReplayDungeonButton")
            if rdbGui and rdbGui:IsA("ScreenGui") and rdbGui.Enabled then isEnded = true end
            local repConf = PlayerGui:FindFirstChild("ReplayConfirmation")
            if repConf and repConf:IsA("ScreenGui") and repConf.Enabled then isEnded = true end

            if isEnded then
                if winDetectedTime == 0 then winDetectedTime = tick() end
                local elapsed = tick() - winDetectedTime
                if elapsed < 3.0 then return end

                local myLevel = LocalPlayer:FindFirstChild("level") and LocalPlayer.level.Value or 1
                local targetLvl = tonumber(Config.TargetLevel) or 0

                if targetLvl > 0 and myLevel >= targetLvl then
                    if Remotes:FindFirstChild("ReturnToLobbyEvent") then Remotes.ReturnToLobbyEvent:FireServer() end
                    if Remotes:FindFirstChild("teleToLobby") then Remotes.teleToLobby:FireServer() end
                    if Remotes:FindFirstChild("leaveGame") then Remotes.leaveGame:FireServer() end
                    for _, g in ipairs(PlayerGui:GetChildren()) do
                        if g:IsA("ScreenGui") and g.Name ~= "KvpHubMain" and g.Enabled then
                            for _, b in ipairs(g:GetDescendants()) do
                                if b:IsA("GuiButton") and b.Visible then
                                    local bn = b.Name:lower()
                                    if bn:find("returntolobby") or bn:find("leave") or bn:find("lobby") or bn:find("exit") then
                                        if firesignal then
                                            firesignal(b.MouseButton1Down)
                                            firesignal(b.MouseButton1Click)
                                        end
                                    end
                                end
                            end
                        end
                    end
                else
                    if Remotes:FindFirstChild("replayDungeon") then Remotes.replayDungeon:FireServer() end
                    if rdbGui and rdbGui:IsA("ScreenGui") then
                        local repBtn = rdbGui:FindFirstChild("Replay") or rdbGui:FindFirstChildWhichIsA("GuiButton", true)
                        if repBtn and firesignal then
                            firesignal(repBtn.MouseButton1Down)
                            firesignal(repBtn.MouseButton1Click)
                        end
                    end
                    local mainInterface = PlayerGui:FindFirstChild("mainInterface")
                    local optBtn = mainInterface and mainInterface:FindFirstChild("optionsButton")
                    if optBtn then
                        local optRep = optBtn:FindFirstChild("ReplayDungeonButton") or optBtn:FindFirstChild("replayDungeon")
                        if optRep and optRep:IsA("GuiButton") and optRep.Visible and firesignal then
                            firesignal(optRep.MouseButton1Down)
                            firesignal(optRep.MouseButton1Click)
                        end
                    end
                    if repConf and repConf:IsA("ScreenGui") and repConf.Enabled then
                        for _, btn in ipairs(repConf:GetDescendants()) do
                            if btn:IsA("GuiButton") and btn.Visible then
                                local btnText = (btn:IsA("TextButton") and btn.Text or ""):lower()
                                local btnName = btn.Name:lower()
                                if btnText == "yes" or btnName:find("yes") or btnName:find("confirm") then
                                    if firesignal then
                                        firesignal(btn.MouseButton1Down)
                                        firesignal(btn.MouseButton1Click)
                                    end
                                end
                            end
                        end
                    end
                end
            else
                winDetectedTime = 0
            end
        end)
    end
end

-- ================================
-- ROOM & ENEMY TARGETING
-- ================================
local currentActiveRoomName = "Waiting..."

local function CheckIsRealBoss(model, roomName)
    if not model then return false end
    if roomName and roomName:lower():find("boss") then return true end
    local name = model.Name:lower()
    if name:find("warrior") or name:find("mage") or name:find("archer") or name:find("guard") or name:find("skeleton") or name:find("minion") then
        return false
    end
    if name:find("demon lord") or name:find("azrallik") or name:find("boss") or name:find("kraken") or name:find("golem") or name:find("champion") then
        return true
    end
    return false
end

local function GetOrderedRooms(dungeon)
    local numberedRooms = {}
    local bossRoom = nil
    local otherRooms = {}
    for _, child in ipairs(dungeon:GetChildren()) do
        local nameLower = child.Name:lower()
        if nameLower:find("boss") then
            bossRoom = child
        else
            local num = tonumber(child.Name:match("%d+"))
            if num then
                table.insert(numberedRooms, {num = num, folder = child})
            elseif nameLower ~= "initialroom" and nameLower ~= "spawn" then
                table.insert(otherRooms, child)
            end
        end
    end
    table.sort(numberedRooms, function(a, b) return a.num < b.num end)
    local ordered = {}
    for _, r in ipairs(numberedRooms) do table.insert(ordered, r.folder) end
    for _, r in ipairs(otherRooms) do table.insert(ordered, r) end
    if bossRoom then table.insert(ordered, bossRoom) end
    return ordered
end

local function GetSequentialTargetEnemy()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil, "No Character" end
    local myPos = hrp.Position
    local dungeon = workspace:FindFirstChild("dungeon")
    if dungeon then
        local orderedRooms = GetOrderedRooms(dungeon)
        for _, room in ipairs(orderedRooms) do
            local ef = room:FindFirstChild("enemyFolder") or room:FindFirstChild("enemies") or room
            local livingInThisRoom = {}
            for _, m in ipairs(ef:GetChildren()) do
                if m:IsA("Model") and m ~= char and not Players:GetPlayerFromCharacter(m) then
                    local eHum = m:FindFirstChildOfClass("Humanoid")
                    local ePart = m:FindFirstChild("HumanoidRootPart") or m:FindFirstChild("Head") or m:FindFirstChildOfClass("BasePart")
                    if eHum and eHum.Health > 0 and ePart then
                        local d = (myPos - ePart.Position).Magnitude
                        table.insert(livingInThisRoom, {model = m, part = ePart, hum = eHum, dist = d})
                    end
                end
            end
            if #livingInThisRoom > 0 then
                currentActiveRoomName = room.Name
                table.sort(livingInThisRoom, function(a, b) return a.dist < b.dist end)
                return livingInThisRoom[1], room.Name
            end
        end
    end
    local enemiesFolder = workspace:FindFirstChild("enemies")
    if enemiesFolder then
        local best = nil
        local minDist = math.huge
        for _, m in ipairs(enemiesFolder:GetChildren()) do
            if m:IsA("Model") and m ~= char and not Players:GetPlayerFromCharacter(m) then
                local eHum = m:FindFirstChildOfClass("Humanoid")
                local ePart = m:FindFirstChild("HumanoidRootPart") or m:FindFirstChild("Head") or m:FindFirstChildOfClass("BasePart")
                if eHum and eHum.Health > 0 and ePart then
                    local d = (myPos - ePart.Position).Magnitude
                    if d < minDist then
                        minDist = d
                        best = {model = m, part = ePart, hum = eHum, dist = d}
                    end
                end
            end
        end
        if best then
            currentActiveRoomName = "Enemies"
            return best, "enemies"
        end
    end
    currentActiveRoomName = "Cleared"
    return nil, "Clean"
end

-- ================================
-- MOB ESP
-- ================================
local function UpdateMobESP()
    pcall(function()
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local myPos = hrp and hrp.Position or Vector3.zero
        local candidates = {}
        local containers = {workspace:FindFirstChild("dungeon"), workspace:FindFirstChild("enemies"), workspace:FindFirstChild("boss"), workspace:FindFirstChild("mobs"), workspace:FindFirstChild("waveEnemies")}
        for _, c in ipairs(containers) do
            if c then
                for _, m in ipairs(c:GetDescendants()) do
                    if m:IsA("Model") and m ~= char and not Players:GetPlayerFromCharacter(m) then
                        local eHum = m:FindFirstChildOfClass("Humanoid")
                        local ePart = m:FindFirstChild("HumanoidRootPart") or m:FindFirstChild("Head") or m:FindFirstChildOfClass("BasePart")
                        if eHum and eHum.Health > 0 and ePart then
                            candidates[m] = {part = ePart, hum = eHum}
                        end
                    end
                end
            end
        end
        for _, m in ipairs(workspace:GetChildren()) do
            if m:IsA("Model") and m ~= char and not Players:GetPlayerFromCharacter(m) then
                local eHum = m:FindFirstChildOfClass("Humanoid")
                local ePart = m:FindFirstChild("HumanoidRootPart") or m:FindFirstChild("Head") or m:FindFirstChildOfClass("BasePart")
                if eHum and eHum.Health > 0 and ePart then
                    local n = m.Name:lower()
                    if n:find("boss") or n:find("lord") or n:find("champion") or n:find("enemy") then
                        candidates[m] = {part = ePart, hum = eHum}
                    end
                end
            end
        end

        for m, data in pairs(candidates) do
            local ePart = data.part
            local eHum = data.hum
            if Config.MobESP then
                local isInActiveRoom = (currentActiveRoomName ~= "Waiting..." and currentActiveRoomName ~= "Cleared") and (m:IsDescendantOf(workspace) and m.Parent and (m.Parent.Name == currentActiveRoomName or (m.Parent.Parent and m.Parent.Parent.Name == currentActiveRoomName)))
                local hl = m:FindFirstChild("MobHighlight")
                if not hl then
                    hl = Instance.new("Highlight")
                    hl.Name = "MobHighlight"
                    hl.FillTransparency = 0.50
                    hl.OutlineTransparency = 0
                    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    hl.Adornee = m
                    hl.Parent = m
                end
                if isInActiveRoom then
                    hl.FillColor = Color3.fromRGB(255, 50, 50)
                    hl.OutlineColor = Color3.fromRGB(255, 220, 40)
                else
                    hl.FillColor = Color3.fromRGB(70, 150, 255)
                    hl.OutlineColor = Color3.fromRGB(120, 190, 255)
                end
                local bg = ePart:FindFirstChild("MobESP")
                if not bg then
                    bg = Instance.new("BillboardGui")
                    bg.Name = "MobESP"
                    bg.Adornee = ePart
                    bg.Size = UDim2.new(0, 240, 0, 32)
                    bg.StudsOffset = Vector3.new(0, 10.5, 0)
                    bg.ExtentsOffsetWorldSpace = Vector3.new(0, 4.0, 0)
                    bg.AlwaysOnTop = true
                    bg.MaxDistance = 30000
                    bg.Parent = ePart
                    local txt = Instance.new("TextLabel")
                    txt.Name = "InfoLabel"
                    txt.Size = UDim2.new(1, 0, 1, 0)
                    txt.BackgroundTransparency = 1
                    txt.TextStrokeTransparency = 0
                    txt.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
                    txt.TextSize = 12
                    txt.Font = Enum.Font.GothamBold
                    txt.Parent = bg
                else
                    bg.StudsOffset = Vector3.new(0, 10.5, 0)
                    bg.MaxDistance = 30000
                    bg.AlwaysOnTop = true
                end
                local lbl = bg:FindFirstChild("InfoLabel")
                if lbl then
                    local dist = math.floor((myPos - ePart.Position).Magnitude)
                    local prefix = isInActiveRoom and "⚔️ [TARGET]" or "🔒 [MOB]"
                    lbl.TextColor3 = isInActiveRoom and Color3.fromRGB(255, 235, 90) or Color3.fromRGB(190, 225, 255)
                    lbl.Text = string.format("%s %s [%dm] (%s HP)", prefix, m.Name, dist, FormatNumber(eHum.Health))
                end
            else
                local hl = m:FindFirstChild("MobHighlight")
                if hl then hl:Destroy() end
                local bg = ePart:FindFirstChild("MobESP")
                if bg then bg:Destroy() end
            end
        end
    end)
end

-- ================================
-- SMART NAVIGATION & STEP ASSIST
-- ================================
local activeMoveDir = Vector3.zero
local cachedWaypoints = nil
local cachedWaypointIdx = 2
local lastComputeTime = 0
local lastTargetPos = nil

local function CheckStepOrLowObstacle(hrp, moveDirection)
    if moveDirection.Magnitude < 0.1 then return false end
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = {LocalPlayer.Character}
    local footOrigin = hrp.Position - Vector3.new(0, 1.8, 0)
    local footRay = workspace:Raycast(footOrigin, moveDirection * 2.8, rayParams)
    local chestOrigin = hrp.Position + Vector3.new(0, 0.8, 0)
    local chestRay = workspace:Raycast(chestOrigin, moveDirection * 2.8, rayParams)
    if footRay and footRay.Instance.CanCollide and (not chestRay or not chestRay.Instance.CanCollide) then
        return true
    end
    return false
end

local function GetSmartNavDirection(playerPos, targetPos)
    local now = tick()
    local needRecalculate = false
    if not cachedWaypoints or cachedWaypointIdx > #cachedWaypoints then
        needRecalculate = true
    elseif (now - lastComputeTime > 3.0) then
        needRecalculate = true
    elseif lastTargetPos and (lastTargetPos - targetPos).Magnitude > 12 then
        needRecalculate = true
    end
    if needRecalculate then
        lastComputeTime = now
        lastTargetPos = targetPos
        local path = PathfindingService:CreatePath({
            AgentRadius = 2.6,
            AgentHeight = 5.2,
            AgentCanJump = true,
            WaypointSpacing = 3.2
        })
        local ok = pcall(function()
            path:ComputeAsync(playerPos, targetPos)
        end)
        if ok and path.Status == Enum.PathStatus.Success then
            cachedWaypoints = path:GetWaypoints()
            cachedWaypointIdx = 2
        else
            cachedWaypoints = nil
        end
    end
    if cachedWaypoints and cachedWaypointIdx <= #cachedWaypoints then
        local wp = cachedWaypoints[cachedWaypointIdx]
        local diff = wp.Position - playerPos
        local horizDist = Vector2.new(diff.X, diff.Z).Magnitude
        if horizDist < 3.2 then
            cachedWaypointIdx = cachedWaypointIdx + 1
            if cachedWaypointIdx <= #cachedWaypoints then
                wp = cachedWaypoints[cachedWaypointIdx]
                diff = wp.Position - playerPos
            end
        end
        local shouldJump = (wp.Action == Enum.PathWaypointAction.Jump) or (diff.Y > 1.2)
        local dir = Vector3.new(diff.X, 0, diff.Z).Unit
        return dir, shouldJump
    end
    local directDiff = targetPos - playerPos
    return Vector3.new(directDiff.X, 0, directDiff.Z).Unit, false
end

-- ================================
-- RED TELEGRAPH DODGE 
-- ================================
local function GetRedTelegraphDodgeVector(playerPos)
    if not Config.AutoDodgeRed then return nil end
    local char = LocalPlayer.Character
    local bestDodgeDir = nil
    local minDistanceToExit = math.huge

    local function inspectPart(obj)
        if not obj:IsA("BasePart") then return end
        if char and obj:IsDescendantOf(char) then return end
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Character and obj:IsDescendantOf(p.Character) then return end
        end
        local distToPlayer = (obj.Position - playerPos).Magnitude
        if distToPlayer > 85 then return end
        local name = obj.Name:lower()
        local parentName = obj.Parent and obj.Parent.Name:lower() or ""
        local isDanger = false
        if name == "precast" or name:find("indicator") or name:find("telegraph") or name:find("danger") or name:find("hazard")
           or name:find("iceaoe") or name:find("circlehit") or name:find("beam") or name:find("laser") or name:find("line")
           or name:find("shockwave") or name:find("ring") or name:find("slam") or name:find("slash") or name:find("cone")
           or name:find("damagezone") or name:find("strike") or name:find("hitbox") then
            isDanger = true
        elseif parentName:find("spikes") or parentName:find("beam") or parentName:find("aoe") or parentName:find("flame")
               or parentName:find("laser") or parentName:find("shot") or parentName:find("cone") or parentName:find("circle")
               or parentName:find("strike") or parentName:find("slam") or parentName:find("line") then
            if not obj.CanCollide or obj.Transparency > 0.05 then
                isDanger = true
            end
        end
        if not isDanger and not obj.CanCollide and obj.Transparency < 0.98 then
            local c = obj.Color
            local isRed = (c.R > 0.60 and (c.R > c.G * 1.25 or c.R > c.B * 1.25))
            local isOrange = (c.R > 0.70 and c.G > 0.30 and c.B < 0.45)
            local isYellow = (c.R > 0.65 and c.G > 0.65 and c.B < 0.45)
            local isPurple = (c.R > 0.45 and c.B > 0.45 and c.G < 0.40)
            local isCyanIce = (c.B > 0.60 and c.G > 0.50 and c.R < 0.45)
            if isRed or isOrange or isYellow or isPurple or isCyanIce then
                isDanger = true
            end
        end
        if isDanger then
            local localPos = obj.CFrame:PointToObjectSpace(playerPos)
            local halfSize = obj.Size / 2
            local margin = 5.0
            local isCylinder = (obj:IsA("Part") and obj.Shape == Enum.PartType.Cylinder)
                               or name:find("circle") or name:find("ring") or name:find("shockwave")
                               or (math.abs(halfSize.X - halfSize.Z) < 1.5 and halfSize.X > 4)
                               or (math.abs(halfSize.Y - halfSize.Z) < 1.5 and halfSize.Y > 4)
            if isCylinder then
                local dAxis, hMax, radius, distFromCenter, exitObj
                if halfSize.X <= halfSize.Y and halfSize.X <= halfSize.Z then
                    dAxis = math.abs(localPos.X)
                    hMax = halfSize.X + 8.0
                    radius = math.max(halfSize.Y, halfSize.Z) + margin
                    distFromCenter = math.sqrt(localPos.Y^2 + localPos.Z^2)
                    exitObj = (distFromCenter > 0.1) and Vector3.new(0, localPos.Y, localPos.Z).Unit or Vector3.new(0, 1, 1).Unit
                elseif halfSize.Y <= halfSize.X and halfSize.Y <= halfSize.Z then
                    dAxis = math.abs(localPos.Y)
                    hMax = halfSize.Y + 8.0
                    radius = math.max(halfSize.X, halfSize.Z) + margin
                    distFromCenter = math.sqrt(localPos.X^2 + localPos.Z^2)
                    exitObj = (distFromCenter > 0.1) and Vector3.new(localPos.X, 0, localPos.Z).Unit or Vector3.new(1, 0, 1).Unit
                else
                    dAxis = math.abs(localPos.Z)
                    hMax = halfSize.Z + 8.0
                    radius = math.max(halfSize.X, halfSize.Y) + margin
                    distFromCenter = math.sqrt(localPos.X^2 + localPos.Y^2)
                    exitObj = (distFromCenter > 0.1) and Vector3.new(localPos.X, localPos.Y, 0).Unit or Vector3.new(1, 1, 0).Unit
                end
                if dAxis <= hMax and distFromCenter <= radius then
                    local distToExit = radius - distFromCenter
                    local exitWorld = obj.CFrame:VectorToWorldSpace(exitObj)
                    local exitDir = Vector3.new(exitWorld.X, 0, exitWorld.Z).Unit
                    if distToExit < minDistanceToExit then
                        minDistanceToExit = distToExit
                        bestDodgeDir = exitDir
                    end
                end
            else
                local inX = math.abs(localPos.X) <= (halfSize.X + margin)
                local inZ = math.abs(localPos.Z) <= (halfSize.Z + margin)
                local inY = math.abs(localPos.Y) <= (halfSize.Y + 10.0)
                if inX and inZ and inY then
                    local distToExitX = (halfSize.X + margin) - math.abs(localPos.X)
                    local distToExitZ = (halfSize.Z + margin) - math.abs(localPos.Z)
                    local exitVectorObject = Vector3.zero
                    local exitDist = 0
                    if distToExitX <= distToExitZ then
                        local signX = (localPos.X >= 0) and 1 or -1
                        exitVectorObject = Vector3.new(signX, 0, 0)
                        exitDist = distToExitX
                    else
                        local signZ = (localPos.Z >= 0) and 1 or -1
                        exitVectorObject = Vector3.new(0, 0, signZ)
                        exitDist = distToExitZ
                    end
                    local exitVectorWorld = obj.CFrame:VectorToWorldSpace(exitVectorObject)
                    local exitDirHorizontal = Vector3.new(exitVectorWorld.X, 0, exitVectorWorld.Z).Unit
                    if exitDist < minDistanceToExit then
                        minDistanceToExit = exitDist
                        bestDodgeDir = exitDirHorizontal
                    end
                end
            end
        end
    end

    for _, fName in ipairs({"flameParts", "vfxPool", "abilities", "mageBossLaserSpawns"}) do
        local f = workspace:FindFirstChild(fName)
        if f then
            for _, o in ipairs(f:GetDescendants()) do inspectPart(o) end
        end
    end
    local dg = workspace:FindFirstChild("dungeon")
    if dg then
        for _, o in ipairs(dg:GetDescendants()) do inspectPart(o) end
    end
    for _, o in ipairs(workspace:GetChildren()) do
        if o:IsA("BasePart") then
            inspectPart(o)
        elseif o:IsA("Model") and not Players:GetPlayerFromCharacter(o) then
            for _, sub in ipairs(o:GetDescendants()) do
                if sub:IsA("BasePart") then inspectPart(sub) end
            end
        end
    end

    if bestDodgeDir then
        local rayParams = RaycastParams.new()
        rayParams.FilterType = Enum.RaycastFilterType.Exclude
        rayParams.FilterDescendantsInstances = {LocalPlayer.Character}
        local wallHit = workspace:Raycast(playerPos, bestDodgeDir * 3.5, rayParams)
        if wallHit and wallHit.Instance.CanCollide then
            local altDir = Vector3.new(-bestDodgeDir.Z, 0, bestDodgeDir.X)
            local altHit = workspace:Raycast(playerPos, altDir * 3.5, rayParams)
            if not altHit or not altHit.Instance.CanCollide then
                bestDodgeDir = altDir
            else
                bestDodgeDir = -altDir
            end
        end
    end
    return bestDodgeDir
end

-- ================================
-- COMBAT SYSTEM 
-- ================================
local function CastSkillSlot(slotKey, slotIndex)
    pcall(function()
        local tool = nil
        local bp = LocalPlayer:FindFirstChild("Backpack")
        if bp then
            for _, c in ipairs(bp:GetChildren()) do
                if c:FindFirstChild("abilitySlot") and c.abilitySlot.Value == slotKey then
                    tool = c
                    break
                end
            end
        end
        if not tool and LocalPlayer.Character then
            for _, c in ipairs(LocalPlayer.Character:GetChildren()) do
                if c:IsA("Tool") and c:FindFirstChild("abilitySlot") and c.abilitySlot.Value == slotKey then
                    tool = c
                    break
                end
            end
        end
        if tool then
            local cd = tool:FindFirstChild("cooldown")
            if not cd or cd.Value <= 0 then
                if tool:FindFirstChild("localEvent") then tool.localEvent:Fire() end
                if tool:FindFirstChild("spellEvent") then tool.spellEvent:FireServer() end
                if Remotes:FindFirstChild("abilityUsed") then
                    Remotes.abilityUsed:FireServer(slotKey, tool)
                    Remotes.abilityUsed:FireServer(slotIndex)
                end
            end
        else
            if Remotes:FindFirstChild("abilityUsed") then
                Remotes.abilityUsed:FireServer(slotIndex)
                Remotes.abilityUsed:FireServer(slotKey)
            end
        end
        if VirtualInputManager then
            local keyCode = (slotKey == "q") and Enum.KeyCode.Q or Enum.KeyCode.E
            VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
            task.delay(0.02, function()
                VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
            end)
        end
    end)
end

local function ExecuteBasicAttack()
    pcall(function()
        local char = LocalPlayer.Character
        if not char then return end
        for _, child in ipairs(char:GetChildren()) do
            if child:IsA("Accessory") and child:FindFirstChild("Weapon") then
                local re = child:FindFirstChildOfClass("RemoteEvent") or child:FindFirstChild("swing")
                if re then re:FireServer() end
            end
        end
        if Remotes:FindFirstChild("weaponUsed") then
            for _ = 1, 3 do Remotes.weaponUsed:FireServer() end
        end
        local tool = char:FindFirstChildOfClass("Tool")
        if tool then tool:Activate() end
        for _, item in ipairs(char:GetChildren()) do
            for _, r in ipairs(item:GetDescendants()) do
                if r:IsA("RemoteEvent") and (r.Name == "swing" or r.Name == "weaponSwing") then
                    r:FireServer()
                end
            end
        end
        local vu = game:GetService("VirtualUser")
        if vu then
            vu:CaptureController()
            vu:ClickButton1(Vector2.new(999, 999))
        end
    end)
end

local function ExecuteCombatActions()
    ExecuteBasicAttack()
    if Config.AutoSkillSmart or Config.SpamSkill then
        CastSkillSlot("q", 1)
        CastSkillSlot("e", 2)
    end
end

-- ================================
-- STAT UPGRADE 
-- ================================
local function AutoUpgradeStats()
    local chosen = {}
    if Config.AutoPhysical then table.insert(chosen, "physicalPower") end
    if Config.AutoStamina then table.insert(chosen, "stamina") end
    if Config.AutoSpell then table.insert(chosen, "spellPower") end
    if #chosen == 0 then return end
    pcall(function()
        local ptsValue = LocalPlayer:FindFirstChild("skillPoints")
        local totalPts = ptsValue and ptsValue.Value or 0
        if totalPts <= 0 or not Remotes:FindFirstChild("spendSkillPoint") then return end
        if #chosen == 1 then
            Remotes.spendSkillPoint:FireServer(chosen[1], totalPts)
        elseif #chosen == 2 then
            local half = math.floor(totalPts / 2)
            if half > 0 then
                Remotes.spendSkillPoint:FireServer(chosen[1], half)
                Remotes.spendSkillPoint:FireServer(chosen[2], half)
            end
            local rem = totalPts - half * 2
            if rem > 0 then Remotes.spendSkillPoint:FireServer(chosen[1], rem) end
        elseif #chosen == 3 then
            local third = math.floor(totalPts / 3)
            if third > 0 then
                Remotes.spendSkillPoint:FireServer("physicalPower", third)
                Remotes.spendSkillPoint:FireServer("stamina", third)
                Remotes.spendSkillPoint:FireServer("spellPower", third)
            end
            local rem = totalPts - third * 3
            if rem > 0 then Remotes.spendSkillPoint:FireServer("physicalPower", rem) end
        end
    end)
end

-- ================================
-- EQUIP BEST GEAR 
-- ================================
local function EquipBestGearManual(buildType)
    local success = pcall(function()
        if not Remotes:FindFirstChild("reloadInvy") or not Remotes:FindFirstChild("equipItem") then return end
        local inv = Remotes.reloadInvy:InvokeServer()
        if not inv then return end
        local isPhys = (buildType == "Physical")
        local bestWeaponNum, bestWeaponScore = nil, -1
        if inv.weapons then
            for k, v in pairs(inv.weapons) do
                local score = isPhys and (tonumber(v.physicalDamage) or 0) or (tonumber(v.spellPower) or 0)
                if score > bestWeaponScore then
                    bestWeaponScore = score
                    bestWeaponNum = tonumber(string.match(k, "%d+"))
                end
            end
        end
        if bestWeaponNum then Remotes.equipItem:InvokeServer("weapon", bestWeaponNum) end
        local bestChestNum, bestChestScore = nil, -1
        if inv.chests then
            for k, v in pairs(inv.chests) do
                local hp = tonumber(v.health) or 0
                local pwr = isPhys and (tonumber(v.physicalPower) or 0) or (tonumber(v.spellPower) or 0)
                local score = hp + pwr * 2
                if score > bestChestScore then
                    bestChestScore = score
                    bestChestNum = tonumber(string.match(k, "%d+"))
                end
            end
        end
        if bestChestNum then Remotes.equipItem:InvokeServer("chest", bestChestNum) end
        local bestHelmetNum, bestHelmetScore = nil, -1
        if inv.helmets then
            for k, v in pairs(inv.helmets) do
                local hp = tonumber(v.health) or 0
                local pwr = isPhys and (tonumber(v.physicalPower) or 0) or (tonumber(v.spellPower) or 0)
                local score = hp + pwr * 2
                if score > bestHelmetScore then
                    bestHelmetScore = score
                    bestHelmetNum = tonumber(string.match(k, "%d+"))
                end
            end
        end
        if bestHelmetNum then Remotes.equipItem:InvokeServer("helmet", bestHelmetNum) end
        local abilityList = {}
        if inv.abilities then
            for k, v in pairs(inv.abilities) do
                local num = tonumber(string.match(k, "%d+"))
                if num then
                    local desc = tostring(v.description or ""):lower()
                    local match = isPhys and desc:find("physical") or desc:find("spell")
                    table.insert(abilityList, {num = num, match = match and 1 or 0})
                end
            end
        end
        table.sort(abilityList, function(a, b) return a.match > b.match end)
        if #abilityList >= 1 then Remotes.equipItem:InvokeServer("ability", abilityList[1].num, "q") end
        if #abilityList >= 2 then Remotes.equipItem:InvokeServer("ability", abilityList[2].num, "e") end
    end)
    return success
end

-- ================================
-- SMART SELL 
-- ================================
local function GetSelectedSellData()
    local totalGold, count = 0, 0
    local toSell = {weapon = {}, ability = {}, chest = {}, helmet = {}}
    local ok, inv = pcall(function() return Remotes.reloadInvy:InvokeServer() end)
    if not ok or not inv then return 0, 0, toSell end
    local selRarities = {
        common = Config.AutoSellCommon,
        uncommon = Config.AutoSellUncommon,
        rare = Config.AutoSellRare,
        epic = Config.AutoSellEpic,
        legendary = Config.AutoSellLegendary
    }
    if inv.weapons then
        for k, v in pairs(inv.weapons) do
            if v.equipped == false and selRarities[tostring(v.rarity):lower()] then
                table.insert(toSell.weapon, string.match(k, "%d+"))
                count = count + 1
                totalGold = totalGold + (tonumber(v.sellPrice) or 0)
            end
        end
    end
    if inv.abilities then
        for k, v in pairs(inv.abilities) do
            local isEq = (type(v.equipped) == "table" and (v.equipped.q or v.equipped.e or v.equipped.q2 or v.equipped.e2)) or (v.equipped == true)
            if not isEq and selRarities[tostring(v.rarity):lower()] then
                table.insert(toSell.ability, string.match(k, "%d+"))
                count = count + 1
                totalGold = totalGold + (tonumber(v.sellPrice) or 0)
            end
        end
    end
    if inv.chests then
        for k, v in pairs(inv.chests) do
            if v.equipped == false and selRarities[tostring(v.rarity):lower()] then
                table.insert(toSell.chest, string.match(k, "%d+"))
                count = count + 1
                totalGold = totalGold + (tonumber(v.sellPrice) or 0)
            end
        end
    end
    if inv.helmets then
        for k, v in pairs(inv.helmets) do
            if v.equipped == false and selRarities[tostring(v.rarity):lower()] then
                table.insert(toSell.helmet, string.match(k, "%d+"))
                count = count + 1
                totalGold = totalGold + (tonumber(v.sellPrice) or 0)
            end
        end
    end
    return totalGold, count, toSell
end

local function ExecuteSell()
    local gold, count, toSell = GetSelectedSellData()
    if count == 0 then return 0 end
    pcall(function()
        if Remotes:FindFirstChild("sellItemEvent") then
            Remotes.sellItemEvent:FireServer(toSell)
        end
    end)
    return count
end

-- ================================
-- TẠO UI RAYFIELD
-- ================================
-- (Các tab và element sẽ được tạo ở đây, đồng thời gắn callback để cập nhật Config)

-- Hàm đồng bộ Config với Flags (khi Flags thay đổi thì Config thay đổi theo)
local function syncFlagToConfig(flagName, configKey)
    return function(value)
        Config[configKey] = value
        -- Nếu là các flag cần lưu thì gọi SaveAllConfigToFile()
        -- Tuy nhiên Rayfield đã tự động lưu, nên không cần gọi ở đây
    end
end

-- Tạo các tab
local homeTab = window:CreateTab({ name = "Home", icon = 93364949241311 })
local combatTab = window:CreateTab({ name = "Combat", icon = 14193480192 })
local equipmentTab = window:CreateTab({ name = "Equipment", icon = 10686489468 })
local mapsTab = window:CreateTab({ name = "Maps", icon = 14240466919 })
local utilityTab = window:CreateTab({ name = "Utility", icon = 9405931578 })
local aboutTab = window:CreateTab({ name = "About", icon = 7240801337 })

-- ================================
-- HOME TAB
-- ================================
homeTab:CreateStat({
    name = "Status",
    value = 0,
    prefix = "",
    suffix = "",
    display = "value",
})

homeTab:CreateToggle({
    name = "Auto Farm",
    flag = "AutoFarm",
    value = Config.AutoFarm,
    callback = syncFlagToConfig("AutoFarm", "AutoFarm"),
})

homeTab:CreateToggle({
    name = "Auto Skill Smart",
    flag = "AutoSkillSmart",
    value = Config.AutoSkillSmart,
    callback = syncFlagToConfig("AutoSkillSmart", "AutoSkillSmart"),
})

homeTab:CreateToggle({
    name = "Spam Skills",
    flag = "SpamSkill",
    value = Config.SpamSkill,
    callback = syncFlagToConfig("SpamSkill", "SpamSkill"),
})

homeTab:CreateToggle({
    name = "Mob ESP",
    flag = "MobESP",
    value = Config.MobESP,
    callback = syncFlagToConfig("MobESP", "MobESP"),
})

homeTab:CreateToggle({
    name = "Auto Start",
    flag = "AutoStart",
    value = Config.AutoStart,
    callback = syncFlagToConfig("AutoStart", "AutoStart"),
})

homeTab:CreateToggle({
    name = "Auto Replay",
    flag = "AutoReplay",
    value = Config.AutoReplay,
    callback = syncFlagToConfig("AutoReplay", "AutoReplay"),
})

homeTab:CreateInput({
    name = "Target Level (0=off)",
    numeric = true,
    value = tostring(Config.TargetLevel),
    placeholder = "0",
    flag = "TargetLevel",
    callback = function(text)
        local val = tonumber(text)
        if val and val >= 0 then
            Config.TargetLevel = math.floor(val)
        end
    end,
})

homeTab:CreateButton({
    name = "Quit UI",
    icon = 135341415849911,
    callback = function()
        window:Unload()
    end,
})
-- ================================
-- COMBAT TAB
-- ================================
combatTab:CreateSlider({
    name = "Combat Distance",
    description = "Khoảng cách tấn công",
    range = { 1, 50 },
    increment = 0.5,
    value = Config.CombatDistance,
    suffix = " studs",
    flag = "CombatDistance",
    callback = function(value)
        Config.CombatDistance = value
    end,
})

combatTab:CreateSlider({
    name = "Boss Distance",
    description = "Khoảng cách tấn công Boss",
    range = { 10, 80 },
    increment = 1,
    value = Config.BossDistance,
    suffix = " studs",
    flag = "BossDistance",
    callback = function(value)
        Config.BossDistance = value
    end,
})

combatTab:CreateToggle({
    name = "Auto Dodge (Red Telegraph)",
    flag = "AutoDodgeRed",
    value = false,  -- Mặc định chưa có trong Config cũ, ta thêm mới
    callback = function(value)
        Config.AutoDodgeRed = value
    end,
})

-- ================================
-- EQUIPMENT TAB
-- ================================
equipmentTab:CreateDropdown({
    name = "Build Type",
    options = {"Physical", "Spell"},
    value = Config.CurrentBuild,
    flag = "CurrentBuild",
    callback = function(selected)
        Config.CurrentBuild = selected
    end,
})

equipmentTab:CreateButton({
    name = "Equip Best Gear",
    callback = function()
        local ok = EquipBestGearManual(Config.CurrentBuild)
        if ok then
            window:Notify({ title = "Equip", content = "Best gear equipped!", duration = 2 })
        else
            window:Notify({ title = "Equip", content = "Failed to equip gear.", duration = 2 })
        end
    end,
})

-- Auto Stats
equipmentTab:CreateToggle({
    name = "Auto Physical",
    flag = "AutoPhysical",
    value = Config.AutoPhysical,
    callback = syncFlagToConfig("AutoPhysical", "AutoPhysical"),
})

equipmentTab:CreateToggle({
    name = "Auto Stamina",
    flag = "AutoStamina",
    value = Config.AutoStamina,
    callback = syncFlagToConfig("AutoStamina", "AutoStamina"),
})

equipmentTab:CreateToggle({
    name = "Auto Spell",
    flag = "AutoSpell",
    value = Config.AutoSpell,
    callback = syncFlagToConfig("AutoSpell", "AutoSpell"),
})

-- Auto Sell
equipmentTab:CreateToggle({
    name = "Auto Sell (chạy nền)",
    flag = "AutoSell",
    value = false, -- thêm mới
    callback = function(value)
        Config.AutoSellEnabled = value
    end,
})

equipmentTab:CreateToggle({
    name = "Sell Common",
    flag = "AutoSellCommon",
    value = Config.AutoSellCommon,
    callback = syncFlagToConfig("AutoSellCommon", "AutoSellCommon"),
})

equipmentTab:CreateToggle({
    name = "Sell Uncommon",
    flag = "AutoSellUncommon",
    value = Config.AutoSellUncommon,
    callback = syncFlagToConfig("AutoSellUncommon", "AutoSellUncommon"),
})

equipmentTab:CreateToggle({
    name = "Sell Rare",
    flag = "AutoSellRare",
    value = Config.AutoSellRare,
    callback = syncFlagToConfig("AutoSellRare", "AutoSellRare"),
})

equipmentTab:CreateToggle({
    name = "Sell Epic",
    flag = "AutoSellEpic",
    value = Config.AutoSellEpic,
    callback = syncFlagToConfig("AutoSellEpic", "AutoSellEpic"),
})

equipmentTab:CreateToggle({
    name = "Sell Legendary",
    flag = "AutoSellLegendary",
    value = Config.AutoSellLegendary,
    callback = syncFlagToConfig("AutoSellLegendary", "AutoSellLegendary"),
})

equipmentTab:CreateButton({
    name = "Sell Now",
    callback = function()
        local count = ExecuteSell()
        if count > 0 then
            window:Notify({ title = "Sell", content = string.format("Sold %d items!", count), duration = 3 })
        else
            window:Notify({ title = "Sell", content = "No items to sell.", duration = 2 })
        end
    end,
})

-- ================================
-- MAPS TAB
-- ================================
mapsTab:CreateDropdown({
    name = "Select Map",
    options = MapListOrdered,
    value = Config.SelectedMap,
    flag = "SelectedMap",
    callback = function(selected)
        Config.SelectedMap = selected
        -- Tự động cập nhật difficulty dựa trên map
        local diffs = MapDifficultyDatabase[selected] or {{name = "Easy", lvl = 1}}
        -- Cập nhật dropdown difficulty (cần phải refresh)
        -- Ta sẽ làm sau nếu cần, hoặc để user tự chọn.
    end,
})

mapsTab:CreateDropdown({
    name = "Difficulty",
    options = {"Easy", "Medium", "Hard", "Insane", "Nightmare"},
    value = Config.SelectedDifficulty,
    flag = "SelectedDifficulty",
    callback = function(selected)
        Config.SelectedDifficulty = selected
        -- Cập nhật level requirement
        local diffs = MapDifficultyDatabase[Config.SelectedMap] or {{name = "Easy", lvl = 1}}
        for _, d in ipairs(diffs) do
            if d.name == selected then
                Config.SelectedLevelReq = d.lvl
                break
            end
        end
    end,
})

mapsTab:CreateToggle({
    name = "Hardcore Mode",
    flag = "IsHardcore",
    value = Config.IsHardcore,
    callback = syncFlagToConfig("IsHardcore", "IsHardcore"),
})

mapsTab:CreateToggle({
    name = "Auto Accept Join",
    flag = "AutoAcceptJoin",
    value = Config.AutoAcceptJoin,
    callback = syncFlagToConfig("AutoAcceptJoin", "AutoAcceptJoin"),
})

mapsTab:CreateToggle({
    name = "Auto Start When Full",
    flag = "AutoStartWhenFull",
    value = Config.AutoStartWhenFull,
    callback = syncFlagToConfig("AutoStartWhenFull", "AutoStartWhenFull"),
})

mapsTab:CreateInput({
    name = "Target Player Count",
    numeric = true,
    value = tostring(Config.TargetPlayerCount),
    placeholder = "10",
    flag = "TargetPlayerCount",
    callback = function(text)
        local num = tonumber(text)
        if num and num >= 1 then
            Config.TargetPlayerCount = math.floor(num)
        end
    end,
})

mapsTab:CreateButton({
    name = "Create Lobby",
    icon = 15911231575,
    callback = function()
        local remote = Remotes:FindFirstChild("createLobby")
        if remote then
            pcall(function()
                remote:InvokeServer(
                    Config.SelectedMap,
                    Config.SelectedDifficulty,
                    Config.SelectedLevelReq,
                    Config.IsHardcore,
                    false,
                    false
                )
                window:Notify({ title = "Lobby", content = "Lobby created!", duration = 2 })
            end)
        else
            window:Notify({ title = "Error", content = "createLobby remote not found!", duration = 3 })
        end
    end,
})

-- ================================
-- UTILITY TAB
-- ================================
utilityTab:CreateKeybind({
    name = "Toggle Auto Farm",
    value = Enum.KeyCode.F,
    flag = "FarmKeybind",
    callback = function(key)
        local newState = not Config.AutoFarm
        Config.AutoFarm = newState
        window.Flags.AutoFarm = newState
        window:Toast({ title = "Auto Farm", subtitle = newState and "Enabled" or "Disabled", duration = 1 })
    end,
})

utilityTab:CreateKeybind({
    name = "Toggle Auto Dodge",
    value = Enum.KeyCode.G,
    flag = "DodgeKeybind",
    callback = function(key)
        local newState = not Config.AutoDodgeRed
        Config.AutoDodgeRed = newState
        window.Flags.AutoDodgeRed = newState
        window:Toast({ title = "Auto Dodge", subtitle = newState and "Enabled" or "Disabled", duration = 1 })
    end,
})

utilityTab:CreateButton({
    name = "Reset Character",
    callback = function()
        local char = LocalPlayer.Character
        if char then
            char:BreakJoints()
            window:Notify({ title = "Character", content = "Reset!", duration = 2 })
        end
    end,
})

utilityTab:CreateButton({
    name = "Replay Dungeon",
    icon = 11541290790,
    callback = function()
        local remote = Remotes:FindFirstChild("replayDungeon")
        if remote then
            remote:FireServer()
            window:Notify({ title = "Replay", content = "Replaying...", duration = 2 })
        end
    end,
})

utilityTab:CreateButton({
    name = "Save Config",
    icon = 128412904377038,
    callback = function()
        SaveAllConfigToFile()
        window:Notify({ title = "Config", content = "Saved!", duration = 2 })
    end,
})

utilityTab:CreateButton({
    name = "Clear Cache",
    icon = 123405614186321,
    callback = function()
        cachedWaypoints = nil
        lastTargetPos = nil
        window:Notify({ title = "Cache", content = "Cleared!", duration = 2 })
    end,
})

-- ================================
-- ABOUT TAB
-- ================================
aboutTab:CreateText({
    name = "Kvp Hub",
    text = "Owner: Lypfy\n\nChức năng:\n- Auto Farm\n- Auto Skill Smart & Spam\n- Mob ESP\n- Auto Start, Replay\n- Auto Accept Join\n- Auto Start when full\n- Auto Stats\n- Auto Sell\n- Equip Best Gear",
})

-- ================================
-- MAIN LOOP 
-- ================================
local currentTargetEnemy = nil
local strafeTick = 0
local lastRecordedPos = nil
local lastProgressCheck = tick()
local stuckDuration = 0
local lastDodgeDir = Vector3.zero
local dodgeGraceTimer = 0

-- Movement Render Pipeline
RunService.RenderStepped:Connect(function()
    if not Config.AutoFarm then return end
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hum or hum.Health <= 0 or not hrp then return end
    if activeMoveDir ~= Vector3.zero then
        if CheckStepOrLowObstacle(hrp, activeMoveDir) then
            hum.Jump = true
        end
        hum:Move(activeMoveDir, false)
    end
end)

-- Main Background Combat Worker
task.spawn(function()
    while true do
        task.wait(0.05)
        if Config.AutoFarm and (workspace:FindFirstChild("dungeon") or workspace:FindFirstChild("enemies")) then
            pcall(function()
                local char = LocalPlayer.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if not hrp or not hum or hum.Health <= 0 then return end

                AutoCheckStartAndReplay()

                if not currentTargetEnemy or not currentTargetEnemy.hum or currentTargetEnemy.hum.Health <= 0 or not currentTargetEnemy.part:IsDescendantOf(workspace) then
                    local target, roomName = GetSequentialTargetEnemy()
                    currentTargetEnemy = target
                end

                local target = currentTargetEnemy
                if not target then
                    activeMoveDir = Vector3.zero
                    return
                end

                local mobPos = target.part.Position
                local playerPos = hrp.Position
                local diff = mobPos - playerPos
                local horizDiff = Vector3.new(diff.X, 0, diff.Z)
                local dist = horizDiff.Magnitude
                local isRealBoss = CheckIsRealBoss(target.model, currentActiveRoomName)

                -- Dodge
                local rawDodgeDir = GetRedTelegraphDodgeVector(playerPos)
                if rawDodgeDir then
                    dodgeGraceTimer = tick()
                    lastDodgeDir = rawDodgeDir
                end

                if (tick() - dodgeGraceTimer) < 0.28 and lastDodgeDir ~= Vector3.zero then
                    activeMoveDir = lastDodgeDir
                    hrp.CFrame = CFrame.lookAt(hrp.Position, Vector3.new(mobPos.X, hrp.Position.Y, mobPos.Z))
                    if CheckStepOrLowObstacle(hrp, lastDodgeDir) then
                        hum.Jump = true
                    end
                    ExecuteBasicAttack()
                    if dist <= 45 or isRealBoss then
                        if Config.AutoSkillSmart or Config.SpamSkill then
                            CastSkillSlot("q", 1)
                            CastSkillSlot("e", 2)
                        end
                    end
                    return
                else
                    lastDodgeDir = Vector3.zero
                end

                -- Anti-stuck
                local now = tick()
                if now - lastProgressCheck > 0.35 then
                    if lastRecordedPos and activeMoveDir.Magnitude > 0.1 then
                        local moved = (hrp.Position - lastRecordedPos).Magnitude
                        if moved < 0.45 then
                            stuckDuration = stuckDuration + 0.35
                            hum.Jump = true
                            cachedWaypoints = nil
                            if isRealBoss and dist <= 55 then
                                stuckDuration = 0
                            elseif stuckDuration >= 1.0 then
                                activeMoveDir = -activeMoveDir
                                task.wait(0.12)
                                stuckDuration = 0
                            end
                        else
                            stuckDuration = 0
                        end
                    else
                        stuckDuration = 0
                    end
                    lastRecordedPos = hrp.Position
                    lastProgressCheck = now
                end

                -- Move & attack
                if not isRealBoss then
                    if dist > Config.CombatDistance then
                        local dir, jump = GetSmartNavDirection(playerPos, mobPos)
                        activeMoveDir = dir
                        if jump then hum.Jump = true end
                        if dist <= 12 then ExecuteBasicAttack() end
                        if Config.AutoSkillSmart and dist <= 32 then
                            CastSkillSlot("q", 1)
                            CastSkillSlot("e", 2)
                        end
                    else
                        hrp.CFrame = CFrame.lookAt(hrp.Position, Vector3.new(mobPos.X, hrp.Position.Y, mobPos.Z))
                        strafeTick = strafeTick + 0.12
                        local mobRight = target.part.CFrame.RightVector
                        local strafeSide = (math.sin(strafeTick * 2.5) > 0) and 1 or -1
                        local strafeVector = (mobRight * strafeSide * 0.85)
                        local forwardBias = Vector3.zero
                        if dist > (Config.CombatDistance - 1) then
                            forwardBias = horizDiff.Unit * 0.4
                        elseif dist < (Config.CombatDistance - 3) then
                            forwardBias = -horizDiff.Unit * 0.4
                        end
                        activeMoveDir = (strafeVector + forwardBias).Unit
                        ExecuteCombatActions()
                    end
                else
                    local reachedBoss = false
                    if dist <= 12 then
                        reachedBoss = true
                    elseif dist <= Config.BossDistance and (stuckDuration > 0 or not CheckStepOrLowObstacle(hrp, horizDiff.Unit)) then
                        reachedBoss = true
                    end
                    if not reachedBoss and dist > 14 then
                        local dir, jump = GetSmartNavDirection(playerPos, mobPos)
                        activeMoveDir = dir
                        if jump then hum.Jump = true end
                        if Config.AutoSkillSmart and dist <= 38 then
                            CastSkillSlot("q", 1)
                            CastSkillSlot("e", 2)
                        end
                    else
                        hrp.CFrame = CFrame.lookAt(hrp.Position, Vector3.new(mobPos.X, hrp.Position.Y, mobPos.Z))
                        ExecuteCombatActions()
                        local bossLook = target.part.CFrame.LookVector
                        local toPlayer = (Vector3.new(playerPos.X, 0, playerPos.Z) - Vector3.new(mobPos.X, 0, mobPos.Z)).Unit
                        local frontDot = bossLook:Dot(toPlayer)
                        local mobRight = target.part.CFrame.RightVector
                        if frontDot > 0.30 then
                            local dodgeSide = (mobRight:Dot(toPlayer) >= 0) and mobRight or -mobRight
                            activeMoveDir = dodgeSide.Unit
                        else
                            strafeTick = strafeTick + 0.12
                            local strafeSide = (math.sin(strafeTick * 2.5) > 0) and 1 or -1
                            activeMoveDir = (mobRight * strafeSide).Unit
                        end
                    end
                end
            end)
        else
            activeMoveDir = Vector3.zero
        end
    end
end)

-- Spam Skills loop
task.spawn(function()
    while true do
        task.wait(0.08)
        if Config.SpamSkill then
            pcall(function()
                CastSkillSlot("q", 1)
                CastSkillSlot("e", 2)
            end)
        end
    end
end)

-- Background tasks: ESP, Auto Stats, Auto Sell, Auto Start full
task.spawn(function()
    while true do
        task.wait(2.0)
        pcall(function()
            if Config.MobESP then UpdateMobESP() end
            AutoUpgradeStats()
            AutoCheckStartAndReplay()
            CheckAutoStartWhenFull()
            -- Auto Sell nếu bật
            if Config.AutoSellEnabled then
                local count = ExecuteSell()
                if count > 0 then
                    -- có thể toast
                end
            end
        end)
    end
end)

-- Lưu config khi thay đổi (Rayfield đã tự lưu, nhưng ta vẫn lưu file riêng)
-- Có thể gọi SaveAllConfigToFile() khi cần

print("[Kvp Hub] Loaded successfully. Owner: Lypfy")