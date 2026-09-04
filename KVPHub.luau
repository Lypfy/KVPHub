local Rayfield = loadstring(game:HttpGet("https://sirius.menu/gen2"))()

local window = Rayfield:CreateWindow({
    name = "KVPHUB",
    subtitle = "Rayfield Gen2",
    sidebarLayout = true,
})

local tab = window:CreateTab({ name = "Home", icon = 93364949241311 })

-- ===== OPTIMIZED AUTO SWING =====
local autoSwingEnabled = false
local autoSwingConnection = nil
local swingRemote = nil

-- Cache swing remote once
local function getSwingRemote()
    if swingRemote and swingRemote.Parent then
        return swingRemote
    end
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("RemoteEvent") and obj.Name == "swing" then
            swingRemote = obj
            return swingRemote
        end
    end
    return nil
end

tab:CreateToggle({
    name = "Auto Swing",
    callback = function(value)
        autoSwingEnabled = value
        
        if autoSwingEnabled then
            -- Cache remote before starting
            getSwingRemote()
            
            autoSwingConnection = game:GetService("RunService").Heartbeat:Connect(function()
                if autoSwingEnabled then
                    local remote = getSwingRemote()
                    if remote then
                        pcall(function()
                            remote:FireServer()
                        end)
                    end
                end
            end)
        else
            if autoSwingConnection then
                autoSwingConnection:Disconnect()
                autoSwingConnection = nil
            end
        end
    end,
})

-- ===== OPTIMIZED AUTO START =====
local autoStartEnabled = false
local autoStartConnection = nil
local changeStartRemote = nil

-- Cache changeStart remote once
local function getChangeStartRemote()
    if changeStartRemote and changeStartRemote.Parent then
        return changeStartRemote
    end
    local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("remotes")
    if remotes then
        changeStartRemote = remotes:FindFirstChild("changeStartValue")
        return changeStartRemote
    end
    return nil
end
-- ===== AUTO START ====
tab:CreateToggle({
    name = "Auto Start",
    callback = function(value)
        autoStartEnabled = value
        
        if autoStartEnabled then
            -- Cache remote before starting
            getChangeStartRemote()
            
            autoStartConnection = game:GetService("RunService").Heartbeat:Connect(function()
                if autoStartEnabled then
                    local remote = getChangeStartRemote()
                    if remote then
                        pcall(function()
                            remote:FireServer()
                        end)
                    end
                end
            end)
        else
            if autoStartConnection then
                autoStartConnection:Disconnect()
                autoStartConnection = nil
            end
        end
    end,
})

-- ===== OPTIMIZED AUTO SKILL (Kết hợp cả 2 phương pháp) =====
local autoSkillEnabled = false
local autoSkillConnection = nil
local abilityUsedRemote = nil

-- Skill configuration mapping (từ script mới)
local SKILL_CONFIGS = {
    ["Frost Cone"] = {
        abilityKey = "e",
        eventName = "spellEvent"
    },
    ["Inner Rage"] = {
        abilityKey = "q",
        eventName = "abilityEvent"
    },
    ["Inner Focus"] = {
        abilityKey = "q",
        eventName = "abilityEvent"
    }
    -- Thêm các skill khác nếu cần
}

-- Cache cho từng skill
local skillCache = {}

-- Cache cho remote
local remoteCache = {}

-- Cache cho ability slot mapping (tự động detect)
local slotSkillCache = {
    q = nil,
    e = nil
}

-- Get skill configuration (có fallback auto-detect)
local function getSkillConfig(toolName)
    local config = SKILL_CONFIGS[toolName]
    if config then
        return config
    end
    
    -- Auto-detect configuration nếu không có trong SKILL_CONFIGS
    return {
        abilityKey = "e",  -- Mặc định
        eventName = nil,   -- Sẽ tự động detect
        autoDetect = true
    }
end

-- Auto-detect event trong tool
local function detectSkillEvents(tool)
    local events = {}
    
    -- Danh sách các event thường gặp
    local eventNames = {
        "spellEvent",
        "abilityEvent",
        "localEvent",
        "onUse",
        "activate",
        "cast",
        "skillEvent",
        "useAbility"
    }
    
    for _, eventName in ipairs(eventNames) do
        local event = tool:FindFirstChild(eventName)
        if event then
            table.insert(events, {
                name = eventName,
                object = event,
                isRemote = event:IsA("RemoteEvent") or event:IsA("RemoteFunction")
            })
        end
    end
    
    return events
end

-- Get all skills in Backpack (optimized)
local function getAllSkills()
    local player = game.Players.LocalPlayer
    if not player then return {} end
    
    local backpack = player:FindFirstChild("Backpack")
    if not backpack then return {} end
    
    local skills = {}
    for _, child in ipairs(backpack:GetChildren()) do
        if child:IsA("Tool") then
            skills[#skills + 1] = child
        end
    end
    return skills
end

-- Cache skill data (kết hợp auto-detect)
local function cacheSkill(tool)
    if not tool then return nil end
    
    local toolName = tool.Name
    local cached = skillCache[toolName]
    
    -- Check if cache is still valid
    if cached and cached.tool and cached.tool.Parent and cached.tool:IsA("Tool") then
        return cached
    end
    
    local config = getSkillConfig(toolName)
    local abilityEvent = nil
    local detectedEvents = {}
    
    -- Nếu có config sẵn
    if config.eventName then
        abilityEvent = tool:FindFirstChild(config.eventName)
    end
    
    -- Nếu không tìm thấy hoặc đang ở chế độ auto-detect
    if not abilityEvent or config.autoDetect then
        detectedEvents = detectSkillEvents(tool)
        -- Lấy event đầu tiên tìm thấy
        if #detectedEvents > 0 then
            abilityEvent = detectedEvents[1].object
            -- Cập nhật config với event đã detect
            config.eventName = detectedEvents[1].name
        end
    end
    
    -- Auto-detect ability key từ abilitySlot nếu có
    local abilityKey = config.abilityKey
    if not abilityKey or abilityKey == "" then
        local slot = tool:FindFirstChild("abilitySlot")
        if slot and slot:IsA("StringValue") then
            abilityKey = slot.Value
        else
            abilityKey = "e"  -- Mặc định
        end
    end
    
    if abilityEvent then
        skillCache[toolName] = {
            tool = tool,
            abilityKey = abilityKey,
            abilityEvent = abilityEvent,
            detectedEvents = detectedEvents,
            config = config,
            lastUsed = 0,
            cooldown = tool:FindFirstChild("cooldown")
        }
        return skillCache[toolName]
    end
    return nil
end

-- Cache skill theo slot (q/e)
local function cacheSkillBySlot(slotKey)
    local player = game.Players.LocalPlayer
    if not player then return nil end
    
    local backpack = player:FindFirstChild("Backpack")
    if not backpack then return nil end
    
    local foundTools = {}
    
    -- Lấy tất cả tool trong backpack
    for _, tool in ipairs(backpack:GetChildren()) do
        if tool:IsA("Tool") then
            table.insert(foundTools, tool)
        end
    end
    
    -- Nếu có ít nhất 2 skill, sắp xếp theo vị trí
    if #foundTools >= 2 then
        -- Sắp xếp để Q là skill đầu tiên, E là skill thứ 2
        table.sort(foundTools, function(a, b)
            local slotA = a:FindFirstChild("abilitySlot")
            local slotB = b:FindFirstChild("abilitySlot")
            
            local valA = slotA and slotA:IsA("StringValue") and slotA.Value or ""
            local valB = slotB and slotB:IsA("StringValue") and slotB.Value or ""
            
            -- Ưu tiên abilitySlot
            if valA == slotKey then return true end
            if valB == slotKey then return false end
            
            -- Nếu không có abilitySlot, dùng vị trí
            return false
        end)
    end
    
    -- Tìm skill theo abilitySlot
    for _, tool in ipairs(foundTools) do
        local slot = tool:FindFirstChild("abilitySlot")
        if slot and slot:IsA("StringValue") and slot.Value == slotKey then
            local cached = cacheSkill(tool)
            if cached then
                cached.abilityKey = slotKey
                slotSkillCache[slotKey] = cached
                print("[Auto Skill] Found skill for slot", slotKey, ":", tool.Name)
                return cached
            end
        end
    end
    
    -- Nếu không có abilitySlot, dùng vị trí trong backpack
    -- Q = skill đầu tiên, E = skill thứ 2
    local slotIndex = (slotKey == "q") and 1 or 2
    
    if #foundTools >= slotIndex then
        local tool = foundTools[slotIndex]
        local cached = cacheSkill(tool)
        if cached then
            cached.abilityKey = slotKey
            slotSkillCache[slotKey] = cached
            print("[Auto Skill] Found skill for slot", slotKey, "by position:", tool.Name)
            return cached
        end
    end
    
    return nil
end

-- Get cached skill by slot
local function getCachedSkillBySlot(slotKey)
    -- Kiểm tra cache còn hợp lệ không
    local cached = slotSkillCache[slotKey]
    if cached and cached.tool and cached.tool.Parent and cached.tool:IsA("Tool") then
        -- BỎ KIỂM TRA COOLDOWN ở đây, để cho CastSkillSlotOptimized kiểm tra
        return cached
    end
    
    -- Cache không hợp lệ, tìm lại
    return cacheSkillBySlot(slotKey)
end

-- Get abilityUsed remote (cached)
local function getAbilityUsedRemote()
    if abilityUsedRemote and abilityUsedRemote.Parent then
        return abilityUsedRemote
    end
    
    local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("remotes")
    if remotes then
        abilityUsedRemote = remotes:FindFirstChild("abilityUsed")
        return abilityUsedRemote
    end
    return nil
end

-- Get any remote by name (cached)
local function getCachedRemote(remoteName, parent)
    if remoteCache[remoteName] and remoteCache[remoteName].Parent then
        return remoteCache[remoteName]
    end
    
    local parentObj = parent or game:GetService("ReplicatedStorage")
    local remote = parentObj:FindFirstChild(remoteName)
    if remote then
        remoteCache[remoteName] = remote
        return remote
    end
    return nil
end

-- Cast skill (kết hợp cả 2 cách)
local function CastSkillSlotOptimized(slotKey, slotIndex)
    pcall(function()
        -- Lấy skill từ cache
        local cached = getCachedSkillBySlot(slotKey)
        local tool = cached and cached.tool
        
        -- Nếu không có cache, thử tìm trực tiếp (fallback)
        if not tool then
            local player = game.Players.LocalPlayer
            if not player then return end
            
            local backpack = player:FindFirstChild("Backpack")
            if backpack then
                for _, c in ipairs(backpack:GetChildren()) do
                    if c:IsA("Tool") then
                        local slot = c:FindFirstChild("abilitySlot")
                        if slot and slot:IsA("StringValue") and slot.Value == slotKey then
                            tool = c
                            cached = cacheSkill(tool)
                            break
                        end
                    end
                end
            end
            
            if not tool and player.Character then
                for _, c in ipairs(player.Character:GetChildren()) do
                    if c:IsA("Tool") then
                        local slot = c:FindFirstChild("abilitySlot")
                        if slot and slot:IsA("StringValue") and slot.Value == slotKey then
                            tool = c
                            cached = cacheSkill(tool)
                            break
                        end
                    end
                end
            end
        end
        
        if tool and cached then
            -- Kiểm tra cooldown
            local cd = tool:FindFirstChild("cooldown")
            if cd and cd.Value > 0 then
                return  -- Đang hồi chiêu
            end
            
            -- Gửi event (ưu tiên event đã cache)
            local eventFired = false
            
            -- Cách 1: Dùng event đã cache (từ config hoặc auto-detect)
            if cached.abilityEvent then
                if cached.abilityEvent:IsA("RemoteEvent") or cached.abilityEvent:IsA("RemoteFunction") then
                    pcall(function()
                        cached.abilityEvent:FireServer()
                    end)
                    eventFired = true
                else
                    pcall(function()
                        cached.abilityEvent:Fire()
                    end)
                    eventFired = true
                end
            end
            
            -- Cách 2: Fallback - thử tất cả event có thể (giống script cũ)
            if not eventFired then
                local eventNames = {"localEvent", "spellEvent", "abilityEvent", "onUse", "activate"}
                for _, eventName in ipairs(eventNames) do
                    local event = tool:FindFirstChild(eventName)
                    if event then
                        pcall(function()
                            if event:IsA("RemoteEvent") or event:IsA("RemoteFunction") then
                                event:FireServer()
                            else
                                event:Fire()
                            end
                        end)
                        eventFired = true
                        break
                    end
                end
            end
            
            -- Cách 3: Dùng abilityUsed remote (nếu có)
            local abilityRemote = getAbilityUsedRemote()
            if abilityRemote then
                pcall(function()
                    abilityRemote:FireServer(slotKey, tool)
                    abilityRemote:FireServer(slotIndex)
                end)
            end
            
            -- Cách 4: Virtual Key Press (backup cuối cùng)
            if VirtualInputManager then
                local keyCode = (slotKey == "q") and Enum.KeyCode.Q or Enum.KeyCode.E
                pcall(function()
                    VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
                    task.delay(0.02, function()
                        VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
                    end)
                end)
            end
            
            -- Cập nhật thời gian sử dụng
            cached.lastUsed = tick()
            
        else
            -- Không tìm thấy tool, thử gửi remote trực tiếp
            local abilityRemote = getAbilityUsedRemote()
            if abilityRemote then
                pcall(function()
                    abilityRemote:FireServer(slotIndex)
                    abilityRemote:FireServer(slotKey)
                end)
            end
        end
    end)
end

-- Auto Skill Loop (cải tiến)
local function autoSkillLoop()
    if not autoSkillEnabled then return end
    
    pcall(function()
        -- Làm mới cache skill
        local currentSkills = getAllSkills()
        local currentSkillNames = {}
        
        for _, tool in ipairs(currentSkills) do
            currentSkillNames[tool.Name] = true
            if not skillCache[tool.Name] then
                cacheSkill(tool)
            end
        end
        
        -- Xóa skill không còn tồn tại
        local cacheChanged = false
        for skillName in pairs(skillCache) do
            if not currentSkillNames[skillName] then
                skillCache[skillName] = nil
                cacheChanged = true
            end
        end
        
        -- Nếu cache thay đổi, reset slot cache
        if cacheChanged then
            slotSkillCache = {
                q = nil,
                e = nil
            }
            -- Tìm lại skill cho từng slot
            for slotKey in pairs(slotSkillCache) do
                cacheSkillBySlot(slotKey)
            end
        end
        
        -- Làm mới cache theo slot
        for slotKey in pairs(slotSkillCache) do
            local cached = slotSkillCache[slotKey]
            if cached and cached.tool and cached.tool.Parent then
                -- Kiểm tra cooldown
                local cd = cached.tool:FindFirstChild("cooldown")
                if cd and cd.Value > 0 then
                    -- Đang hồi chiêu, bỏ qua
                else
                    -- Sử dụng skill
                    CastSkillSlotOptimized(slotKey, slotKey == "q" and 1 or 2)
                end
            else
                -- Cache không hợp lệ, tìm lại
                slotSkillCache[slotKey] = nil
                cacheSkillBySlot(slotKey)
            end
        end
    end)
end

-- Toggle Auto Skill
tab:CreateToggle({
    name = "Auto Skill (Optimized)",
    callback = function(value)
        autoSkillEnabled = value
        
        if autoSkillEnabled then
            -- Pre-cache tất cả skill
            local skills = getAllSkills()
            for _, tool in ipairs(skills) do
                cacheSkill(tool)
                -- Cache theo slot
                local slot = tool:FindFirstChild("abilitySlot")
                if slot and slot:IsA("StringValue") then
                    cacheSkillBySlot(slot.Value)
                end
            end
            
            -- Start loop
            if not autoSkillConnection then
                autoSkillConnection = game:GetService("RunService").Heartbeat:Connect(autoSkillLoop)
            end
        else
            -- Cleanup
            if autoSkillConnection then
                autoSkillConnection:Disconnect()
                autoSkillConnection = nil
            end
            skillCache = {}
            slotSkillCache = { q = nil, e = nil }
        end
    end,
})

-- Hàm CastSkillSlot cũ (giữ lại để tương thích ngược)
local function CastSkillSlot(slotKey, slotIndex)
    CastSkillSlotOptimized(slotKey, slotIndex)
end

print("[Auto Skill] Optimized version loaded successfully!")

-- ===== PATHFINDING & COMBAT SYSTEM =====
local pathfindingEnabled = false
local pathfindingConnection = nil
local attackLoopConnection = nil
local pathfindingService = game:GetService("PathfindingService")
local runService = game:GetService("RunService")
local players = game:GetService("Players")
local localPlayer = players.LocalPlayer
local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")
local stuckTimer = 0
local lastDistance = 0
local stuckDetected = false

-- Configuration
local CONFIG = {
    ATTACK_RANGE = 65,
    DETECTION_RANGE = 1000,
    FOLLOW_DISTANCE = 5,
    PATH_UPDATE_INTERVAL = 0.5,
    ATTACK_COOLDOWN = 0.2,
    WAYPOINT_REACHED_DISTANCE = 8,
    MAX_SPEED = 16,
    BARRIER_SEARCH_RADIUS = 100,
}

-- State variables
local currentTarget = nil
local currentPath = nil
local pathIndex = 1
local lastPathUpdate = 0
local lastAttackTime = 0
local lastLogTime = 0
local logCooldown = 2 -- Only log important messages every 2 seconds

-- Debug logging function with cooldown
local function debugLog(message, level, force)
    level = level or "INFO"
    force = force or false
    
    if force or level == "ERROR" or level == "SUCCESS" then
        print(string.format("[Pathfinding Debug] [%s] %s", level, message))
        return
    end
    
    local currentTime = tick()
    if currentTime - lastLogTime >= logCooldown then
        print(string.format("[Pathfinding Debug] [%s] %s", level, message))
        lastLogTime = currentTime
    end
end

-- Find nearest enemy (NPCs in dungeon rooms)
local function findNearestEnemy()
    local nearest = nil
    local shortestDistance = math.huge
    local enemiesFound = 0
    
    -- Look for dungeon folder in workspace
    local dungeon = workspace:FindFirstChild("dungeon")
    if not dungeon then
        return nil, math.huge
    end
    
    -- Loop through all room folders
    for _, room in ipairs(dungeon:GetChildren()) do
        if room:IsA("Folder") and string.match(room.Name, "^room%d+$") then
            local enemyFolder = room:FindFirstChild("enemyFolder")
            if enemyFolder then
                for _, npc in ipairs(enemyFolder:GetChildren()) do
                    local npcRoot = npc:FindFirstChild("HumanoidRootPart")
                    local npcHumanoid = npc:FindFirstChild("Humanoid")
                    
                    if npcRoot and npcHumanoid and npcHumanoid.Health > 0 then
                        enemiesFound = enemiesFound + 1
                        local distance = (rootPart.Position - npcRoot.Position).Magnitude
                        
                        if distance < CONFIG.DETECTION_RANGE and distance < shortestDistance then
                            nearest = npc
                            shortestDistance = distance
                        end
                    end
                end
            end
        end
    end
    
    if nearest then
        debugLog(string.format("Targeting: %s (%.0f studs away)", nearest.Name, shortestDistance), "INFO")
    end
    
    return nearest, shortestDistance
end

-- Find nearest checkpoint (trong dungeon rooms)
local function findNearestCheckpoint()
    local nearest = nil
    local shortestDistance = math.huge
    local checkpointsFound = 0
    
    -- Look for dungeon folder in workspace
    local dungeon = workspace:FindFirstChild("dungeon")
    if not dungeon then
        return nil
    end
    
    -- Loop through all room folders
    for _, room in ipairs(dungeon:GetChildren()) do
        if room:IsA("Folder") and string.match(room.Name, "^room%d+$") then
            -- Tìm checkpoint trong room
            local checkpoint = room:FindFirstChild("checkPoint")
            if checkpoint and checkpoint:IsA("Part") then
                checkpointsFound = checkpointsFound + 1
                local distance = (rootPart.Position - checkpoint.Position).Magnitude
                if distance < CONFIG.BARRIER_SEARCH_RADIUS and distance < shortestDistance then
                    nearest = checkpoint
                    shortestDistance = distance
                end
            end
        end
    end
    
    if nearest then
        debugLog(string.format("Following checkpoint (%.0f studs away)", shortestDistance), "INFO")
    end
    
    return nearest
end

-- Create path to position
local function createPathToPosition(targetPosition)
    local path = pathfindingService:CreatePath({
        AgentRadius = 2,
        AgentHeight = 5,
        AgentCanJump = true,
        AgentCanClimb = true,
        WaypointSpacing = 3,
    })
    
    local success, errorMessage = pcall(function()
        path:ComputeAsync(rootPart.Position, targetPosition)
    end)
    
    if success and path.Status == Enum.PathStatus.Success then
        local waypoints = path:GetWaypoints()
        debugLog(string.format("Path created: %d waypoints", #waypoints), "INFO")
        return path
    else
        debugLog("Path creation failed", "WARNING")
        return nil
    end
end

-- Follow path (cải thiện xuống dốc)
local stuckTimer = 0
local lastDistance = 0
local stuckThreshold = 5 -- giây (tăng lên)

local function followPath(path)
    if not path or path.Status ~= Enum.PathStatus.Success then
        return false
    end
    
    if not rootPart or not humanoid then
        return false
    end
    
    local waypoints = path:GetWaypoints()
    if #waypoints == 0 then
        return false
    end
    
    if pathIndex > #waypoints then
        pathIndex = 1
        return false
    end
    
    local waypoint = waypoints[pathIndex]
    if not waypoint then
        pathIndex = 1
        return false
    end
    
    local targetPos = waypoint.Position
    if not targetPos then
        return false
    end
    
    local currentPos = rootPart.Position
    if not currentPos then
        return false
    end
    
    local distance = (currentPos - targetPos).Magnitude
    if not distance then
        return false
    end
    
    -- Chỉ set tốc độ khi bắt đầu di chuyển, không set mỗi frame
    if distance > CONFIG.WAYPOINT_REACHED_DISTANCE then
        -- Nếu khoảng cách > 2 studs, mới gọi MoveTo để tránh giật
        if distance > 2 then
            humanoid:MoveTo(targetPos)
        end
        -- Giữ tốc độ luôn ở MAX_SPEED
        humanoid.WalkSpeed = CONFIG.MAX_SPEED
        return false
    else
        -- Đã đến gần waypoint, chuyển tiếp
        pathIndex = pathIndex + 1
        if pathIndex > #waypoints then
            debugLog("Path complete!", "INFO")
            return true
        end
        return false
    end
end

-- Perform attack
local function performAttack(target)
    if not target or not target:FindFirstChild("HumanoidRootPart") then
        return
    end
    
    local targetRoot = target.HumanoidRootPart
    local distance = (rootPart.Position - targetRoot.Position).Magnitude
    
    if distance <= CONFIG.ATTACK_RANGE then
        local currentTime = tick()
        if currentTime - lastAttackTime >= CONFIG.ATTACK_COOLDOWN then
            local lookDirection = (targetRoot.Position - rootPart.Position).Unit
            rootPart.CFrame = CFrame.new(rootPart.Position, rootPart.Position + lookDirection)
            
            pcall(function()
                local swingRemote = getSwingRemote()
                if swingRemote then
                    swingRemote:FireServer()
                end
                
                local startRemote = getChangeStartRemote()
                if startRemote then
                    startRemote:FireServer()
                end
                
                local skillRemote = getAbilityUsedRemote()
                if skillRemote then
                    local skills = getAllSkills()
                    for _, tool in ipairs(skills) do
                        local cached = cacheSkill(tool)
                        if cached and cached.abilityEvent then
                            skillRemote:FireServer(cached.abilityKey, tool)
                            cached.abilityEvent:FireServer()
                        end
                    end
                end
            end)
            
            lastAttackTime = currentTime
        end
    end
end

-- Main pathfinding update
local function updatePathfinding()
    if not pathfindingEnabled then
        return
    end
    
    local enemy, enemyDistance = findNearestEnemy()
    
    if enemy and enemyDistance <= CONFIG.DETECTION_RANGE then
        currentTarget = enemy
        local targetPosition = enemy.HumanoidRootPart.Position
        
        local lookDirection = (targetPosition - rootPart.Position).Unit
        if lookDirection.Magnitude > 0 then
            rootPart.CFrame = CFrame.new(rootPart.Position, rootPart.Position + lookDirection)
        end
        
        if enemyDistance > CONFIG.ATTACK_RANGE then
            if currentPath == nil then
                debugLog("Creating new path to enemy", "INFO")
                currentPath = createPathToPosition(targetPosition)
                pathIndex = 1
                lastPathUpdate = tick()
                stuckTimer = 0
                lastDistance = 0
                stuckDetected = false
            end
            
            if currentPath then
                local pathComplete = followPath(currentPath)
                if pathComplete or stuckDetected then
                    if stuckDetected then
                        debugLog("Recreating path due to stuck", "WARNING")
                        stuckDetected = false
                    end
                    currentPath = nil
                end
            else
                humanoid:MoveTo(targetPosition)
                humanoid.WalkSpeed = CONFIG.MAX_SPEED
            end
        else
            humanoid:MoveTo(rootPart.Position)
            humanoid.WalkSpeed = 0
            performAttack(enemy)
        end
    else
        -- Checkpoint logic tương tự
        local checkpoint = findNearestCheckpoint()
        if checkpoint then
            currentTarget = nil
            local checkpointPosition = checkpoint.Position
            
            local lookDirection = (checkpointPosition - rootPart.Position).Unit
            if lookDirection.Magnitude > 0 then
                rootPart.CFrame = CFrame.new(rootPart.Position, rootPart.Position + lookDirection)
            end
            
            if currentPath == nil then
                debugLog("Creating new path to checkpoint", "INFO")
                currentPath = createPathToPosition(checkpointPosition)
                pathIndex = 1
                lastPathUpdate = tick()
                stuckTimer = 0
                lastDistance = 0
                stuckDetected = false
            end
            
            if currentPath then
                local pathComplete = followPath(currentPath)
                if pathComplete or stuckDetected then
                    if stuckDetected then
                        debugLog("Recreating path due to stuck", "WARNING")
                        stuckDetected = false
                    end
                    currentPath = nil
                    humanoid:MoveTo(rootPart.Position)
                    humanoid.WalkSpeed = 0
                end
            else
                humanoid:MoveTo(checkpointPosition)
                humanoid.WalkSpeed = CONFIG.MAX_SPEED
            end
        else
            if tick() - lastLogTime >= 5 then
                debugLog("No targets or checkpoints found, waiting...", "INFO")
                lastLogTime = tick()
            end
            humanoid:MoveTo(rootPart.Position)
            humanoid.WalkSpeed = 0
            currentPath = nil
            currentTarget = nil
        end
    end
end

-- Detection Range Slider
tab:CreateSlider({
    name = "Detection Range",
    description = "How far to scan for enemies",
    range = { 50, 1000 },
    increment = 10,
    value = CONFIG.DETECTION_RANGE,
    suffix = " studs",
    callback = function(value)
        CONFIG.DETECTION_RANGE = value
        debugLog(string.format("Detection range updated to: %.0f studs", value), "INFO")
    end,
})

-- Attack Range Slider
tab:CreateSlider({
    name = "Attack Range",
    description = "Distance to start attacking enemies",
    range = { 5, 100 },
    increment = 1,
    value = CONFIG.ATTACK_RANGE,
    suffix = " studs",
    callback = function(value)
        CONFIG.ATTACK_RANGE = value
        debugLog(string.format("Attack range updated to: %.0f studs", value), "INFO")
    end,
})

-- Create the toggle button
tab:CreateToggle({
    name = "Auto Pathfind & Attack",
    callback = function(value)
        pathfindingEnabled = value
        
        if pathfindingEnabled then          
            currentPath = nil
            currentTarget = nil
            pathIndex = 1
            lastPathUpdate = 0
            
            if not pathfindingConnection then
                pathfindingConnection = runService.Heartbeat:Connect(updatePathfinding)
            end
            
            if not attackLoopConnection then
                attackLoopConnection = runService.Heartbeat:Connect(function()
                    if pathfindingEnabled and currentTarget then
                        performAttack(currentTarget)
                    end
                end)
            end
        else
            
            if pathfindingConnection then
                pathfindingConnection:Disconnect()
                pathfindingConnection = nil
            end
            
            if attackLoopConnection then
                attackLoopConnection:Disconnect()
                attackLoopConnection = nil
            end
            
            if humanoid then
                humanoid:MoveTo(rootPart.Position)
                humanoid.WalkSpeed = 16
            end
            
            currentPath = nil
            currentTarget = nil
        end
    end,
})

-- Reset on character death
localPlayer.CharacterAdded:Connect(function(newCharacter)
    debugLog("Character respawned, resetting state", "INFO")
    character = newCharacter
    humanoid = character:WaitForChild("Humanoid")
    rootPart = character:WaitForChild("HumanoidRootPart")
    currentPath = nil
    currentTarget = nil
    pathIndex = 1
    debugLog("State reset complete", "SUCCESS")
end)

debugLog("Pathfinding system loaded successfully!", "SUCCESS")

-- ===== PATHFINDING VISUALIZATION =====
local visualizationEnabled = false
local visualizationParts = {}
local lastVisualizedPath = nil
local lastVisualizationUpdate = 0
local visualizationConnection = nil

-- Create visualization parts for path
local function createPathVisualization(path)
    -- Clear old visualization
    for _, part in ipairs(visualizationParts) do
        if part and part.Parent then
            pcall(function() part:Destroy() end)
        end
    end
    visualizationParts = {}
    
    if not visualizationEnabled or not path then
        return
    end
    
    local waypoints = path:GetWaypoints()
    if #waypoints == 0 then
        return
    end
    
    -- Create waypoint markers
    for i, waypoint in ipairs(waypoints) do
        local part = Instance.new("Part")
        part.Size = Vector3.new(1.5, 1.5, 1.5)
        part.Position = waypoint.Position
        part.Anchored = true
        part.CanCollide = false
        part.Material = Enum.Material.Neon
        part.Shape = Enum.PartType.Ball
        
        if waypoint.Action == Enum.PathWaypointAction.Jump then
            part.BrickColor = BrickColor.new("Bright yellow")
        else
            part.BrickColor = BrickColor.new("Bright green")
        end
        
        part.Transparency = 0.3
        part.Parent = workspace
        table.insert(visualizationParts, part)
    end
    
    -- Create line between waypoints
    for i = 1, #waypoints - 1 do
        local startPos = waypoints[i].Position
        local endPos = waypoints[i + 1].Position
        local distance = (endPos - startPos).Magnitude
        
        if distance > 0 then
            local linePart = Instance.new("Part")
            linePart.Size = Vector3.new(0.5, 0.5, distance)
            linePart.Position = (startPos + endPos) / 2
            linePart.Anchored = true
            linePart.CanCollide = false
            linePart.Material = Enum.Material.Neon
            linePart.BrickColor = BrickColor.new("Bright blue")
            linePart.Transparency = 0.4
            
            local direction = (endPos - startPos).Unit
            linePart.CFrame = CFrame.lookAt(linePart.Position, linePart.Position + direction)
            
            linePart.Parent = workspace
            table.insert(visualizationParts, linePart)
        end
    end
    
    lastVisualizedPath = path
end

-- Update indicator for current waypoint
local function updateVisualizationOnWaypoint()
    if not visualizationEnabled or not currentPath then
        return
    end
    
    local currentTime = tick()
    if currentTime - lastVisualizationUpdate < 2 then
        return
    end
    lastVisualizationUpdate = currentTime
    
    local waypoints = currentPath:GetWaypoints()
    if #waypoints == 0 or pathIndex > #waypoints then
        return
    end
    
    -- Remove old indicator (red)
    for i = #visualizationParts, 1, -1 do
        local part = visualizationParts[i]
        if part and part.Parent and part.BrickColor == BrickColor.new("Bright red") then
            pcall(function() part:Destroy() end)
            table.remove(visualizationParts, i)
        end
    end
    
    local waypoint = waypoints[pathIndex]
    if waypoint then
        local indicator = Instance.new("Part")
        indicator.Size = Vector3.new(2.5, 2.5, 2.5)
        indicator.Position = waypoint.Position
        indicator.Anchored = true
        indicator.CanCollide = false
        indicator.Material = Enum.Material.Neon
        indicator.BrickColor = BrickColor.new("Bright red")
        indicator.Shape = Enum.PartType.Ball
        indicator.Transparency = 0.2
        indicator.Parent = workspace
        table.insert(visualizationParts, indicator)
    end
end

-- Visualization loop (runs separately from movement)
local function visualizationLoop()
    if not visualizationEnabled then
        return
    end
    if currentPath then
        updateVisualizationOnWaypoint()
    end
end

-- Toggle for visualization (only ONE toggle)
tab:CreateToggle({
    name = "Show Path Visualization",
    description = "Show path waypoints and lines",
    value = false,
    callback = function(value)
        visualizationEnabled = value
        
        if not visualizationEnabled then
            -- Clear all visualization parts
            for _, part in ipairs(visualizationParts) do
                if part and part.Parent then
                    pcall(function() part:Destroy() end)
                end
            end
            visualizationParts = {}
            lastVisualizedPath = nil
            
            if visualizationConnection then
                visualizationConnection:Disconnect()
                visualizationConnection = nil
            end
        else
            -- Show current path if exists
            if currentPath then
                createPathVisualization(currentPath)
            end
            -- Start connection
            if visualizationConnection then
                visualizationConnection:Disconnect()
                visualizationConnection = nil
            end
            visualizationConnection = runService.Heartbeat:Connect(visualizationLoop)
        end
    end,
})

-- Override createPathToPosition to create visualization when path is created
local originalCreatePath = createPathToPosition
createPathToPosition = function(targetPosition)
    local path = originalCreatePath(targetPosition)
    if visualizationEnabled and path then
        createPathVisualization(path)
    end
    return path
end

-- ===== QUIT UI =====
tab:CreateButton({
    name = "Quit UI",
    callback = function()
        -- Disconnect all connections
        if autoSwingConnection then
            autoSwingConnection:Disconnect()
            autoSwingConnection = nil
        end
        if autoStartConnection then
            autoStartConnection:Disconnect()
            autoStartConnection = nil
        end
        if autoSkillConnection then
            autoSkillConnection:Disconnect()
            autoSkillConnection = nil
        end
        
        -- Clear caches
        skillCache = {}
        swingRemote = nil
        changeStartRemote = nil
        abilityUsedRemote = nil
        
        -- Unload window
        window:Unload()
    end,
})