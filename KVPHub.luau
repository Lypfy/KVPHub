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

-- ===== OPTIMIZED AUTO SKILL =====
local autoSkillEnabled = false
local autoSkillConnection = nil
local abilityUsedRemote = nil

-- Skill configuration mapping
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
}

-- Cache cho từng skill
local skillCache = {}

-- Get skill configuration
local function getSkillConfig(toolName)
    local config = SKILL_CONFIGS[toolName]
    return config or { abilityKey = "e", eventName = "spellEvent" }
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

-- Cache skill data
local function cacheSkill(tool)
    if not tool then return nil end
    
    local toolName = tool.Name
    local cached = skillCache[toolName]
    
    -- Check if cache is still valid
    if cached and cached.tool and cached.tool.Parent and cached.tool:IsA("Tool") then
        return cached
    end
    
    local config = getSkillConfig(toolName)
    local abilityEvent = tool:FindFirstChild(config.eventName)
    
    if abilityEvent then
        skillCache[toolName] = {
            tool = tool,
            abilityKey = config.abilityKey,
            abilityEvent = abilityEvent
        }
        return skillCache[toolName]
    end
    return nil
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

-- Auto Skill Toggle
tab:CreateToggle({
    name = "Auto Skill",
    callback = function(value)
        autoSkillEnabled = value

        if autoSkillEnabled then
            -- Pre-cache everything
            getAbilityUsedRemote()
            local skills = getAllSkills()
            for _, tool in ipairs(skills) do
                cacheSkill(tool)
            end

            autoSkillConnection = game:GetService("RunService").Heartbeat:Connect(function()
                if not autoSkillEnabled then
                    return
                end

                pcall(function()
                    -- Update skill cache
                    local currentSkills = getAllSkills()
                    local currentSkillNames = {}
                    
                    for _, tool in ipairs(currentSkills) do
                        currentSkillNames[tool.Name] = true
                        if not skillCache[tool.Name] then
                            cacheSkill(tool)
                        end
                    end
                    
                    -- Remove invalid skills
                    for skillName in pairs(skillCache) do
                        if not currentSkillNames[skillName] then
                            skillCache[skillName] = nil
                        end
                    end

                    local remote = getAbilityUsedRemote()
                    if not remote then
                        return
                    end

                    -- Fire all skills
                    for skillName, cached in pairs(skillCache) do
                        local shouldFire = true
                        
                        -- Validate tool
                        if not cached.tool or not cached.tool.Parent or not cached.tool:IsA("Tool") then
                            skillCache[skillName] = nil
                            shouldFire = false
                        end
                        
                        -- Validate and refresh event if needed
                        if shouldFire and (not cached.abilityEvent or not cached.abilityEvent.Parent) then
                            local newCache = cacheSkill(cached.tool)
                            if newCache then
                                skillCache[skillName] = newCache
                                cached = newCache
                            else
                                shouldFire = false
                            end
                        end
                        
                        -- Fire skill if valid
                        if shouldFire and cached.tool and cached.abilityEvent then
                            remote:FireServer(cached.abilityKey, cached.tool)
                            cached.abilityEvent:FireServer()
                        end
                    end
                end)
            end)

        else
            -- Cleanup
            if autoSkillConnection then
                autoSkillConnection:Disconnect()
                autoSkillConnection = nil
            end
            
            skillCache = {}
        end
    end,
})

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
