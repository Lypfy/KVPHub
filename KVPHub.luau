local Rayfield = loadstring(game:HttpGet("https://sirius.menu/gen2"))()

local window = Rayfield:CreateWindow({
    name = "KVPHUB",
    subtitle = "Rayfield Gen2",
    sidebarLayout = true,
})

local tab = window:CreateTab({ name = "Home", icon = 93364949241311 })

-- Auto Swing Toggle
local autoSwingEnabled = false
local autoSwingConnection = nil

tab:CreateToggle({
    name = "Auto Swing",
    callback = function(value)
        autoSwingEnabled = value
        print("Auto Swing:", value)
        
        if autoSwingEnabled then
            autoSwingConnection = game:GetService("RunService").Heartbeat:Connect(function()
                if autoSwingEnabled then
                    pcall(function()
                        for _, obj in ipairs(workspace:GetDescendants()) do
                            if obj:IsA("RemoteEvent") and obj.Name == "swing" then
                                obj:FireServer(unpack({}))
                                break
                            end
                        end
                    end)
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

-- Auto Start Toggle
local autoStartEnabled = false
local autoStartConnection = nil

tab:CreateToggle({
    name = "Auto Start",
    callback = function(value)
        autoStartEnabled = value
        print("Auto Start:", value)
        
        if autoStartEnabled then
            -- Start auto start loop
            autoStartConnection = game:GetService("RunService").Heartbeat:Connect(function()
                if autoStartEnabled then
                    pcall(function()
                        local args = {}
                        game:GetService("ReplicatedStorage"):WaitForChild("remotes", 9e9):WaitForChild("changeStartValue", 9e9):FireServer(unpack(args))
                    end)
                end
            end)
        else
            -- Stop auto start loop
            if autoStartConnection then
                autoStartConnection:Disconnect()
                autoStartConnection = nil
            end
        end
    end,
})

tab:CreateButton({
    name = "Quit UI",
    callback = function()
        -- Disconnect all connections to prevent memory leaks
        if autoSwingConnection then
            autoSwingConnection:Disconnect()
            autoSwingConnection = nil
        end
        if autoStartConnection then
            autoStartConnection:Disconnect()
            autoStartConnection = nil
        end
        
        -- Unload the window interface
        window:Unload()
        
        print("UI Closed Successfully")
    end,
})