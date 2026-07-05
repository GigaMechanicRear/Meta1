--[[
    Adopt Me Hub | Rayfield UI
    Auto Farm Money / Pet ESP / Auto Age Baby / Auto Complete Tasks / Teleports / Anti AFK
]]

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer

local Window = Rayfield:CreateWindow({
    Name = "Adopt Me Hub",
    LoadingTitle = "Adopt Me Hub",
    LoadingSubtitle = "Enjoy!",
    Theme = "Default",
    ConfigurationSaving = { Enabled = false }
})

local State = {
    AutoFarm = false,
    AutoTasks = false,
    AutoAge = false,
    PetESP = false,
}

-- ================= Helpers =================
local function getRoot()
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    return char:FindFirstChild("HumanoidRootPart")
end

-- Adopt Me API folder (client -> server remotes routed through Framework)
local API = ReplicatedStorage:FindFirstChild("API")

local function invokeAPI(name, ...)
    if not API then return end
    local remote = API:FindFirstChild(name)
    if remote then
        if remote:IsA("RemoteFunction") then
            return pcall(remote.InvokeServer, remote, ...)
        else
            return pcall(remote.FireServer, remote, ...)
        end
    end
end

-- Read current ailments (tasks) of baby/pet from ClientData
local function getAilments()
    local ailments = {}
    local ok, ClientData = pcall(function()
        return require(ReplicatedStorage.ClientModules.Core.ClientData)
    end)
    if not ok or not ClientData then return ailments end
    local data = ClientData.get_data()[LocalPlayer.Name]
    if not data then return ailments end

    -- baby ailments
    if data.ailments_manager and data.ailments_manager.ailments then
        for name in pairs(data.ailments_manager.ailments) do
            table.insert(ailments, {kind = "baby", name = name})
        end
    end
    -- equipped pet ailments
    local pet = data.pet_char_wrappers and data.pet_char_wrappers[1]
    if pet and pet.ailments_manager and pet.ailments_manager.ailments then
        for name in pairs(pet.ailments_manager.ailments) do
            table.insert(ailments, {kind = "pet", name = name, unique = pet.unique})
        end
    end
    return ailments
end

-- Locations for teleporting / task fulfillment
local Locations = {
    School    = Vector3.new(-720, 20, -30),
    Hospital  = Vector3.new(-540, 20, -290),
    Park      = Vector3.new(-370, 12, -930),
    Camping   = Vector3.new(-1370, 40, -700),
    Salon     = Vector3.new(-190, 17, -600),
    Pool      = Vector3.new(-70, 15, -750),
    Neighborhood = Vector3.new(210, 30, -400),
    Pizza     = Vector3.new(220, 17, -690),
}

local AilmentLocation = {
    school = "School", sick = "Hospital", bored = "Park",
    camping = "Camping", beach_party = "Pool", salon = "Salon",
    pizza_party = "Pizza", hungry = "Pizza",
}

local function teleportTo(name)
    local pos = Locations[name]
    local root = getRoot()
    if pos and root then
        root.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
    end
end

-- ================= Auto Tasks / Auto Farm =================
-- Completing ailments IS how you earn money in Adopt Me, so
-- AutoFarm and AutoTasks share the same loop.
task.spawn(function()
    while task.wait(4) do
        if State.AutoFarm or State.AutoTasks then
            local ailments = getAilments()
            for _, ailment in ipairs(ailments) do
                local locName = AilmentLocation[ailment.name]
                if locName then
                    teleportTo(locName)
                    task.wait(1)
                end
                -- try known completion remotes
                if ailment.kind == "pet" and ailment.unique then
                    invokeAPI("AilmentsAPI/InteractWithFocus", "__Enum_PetObjectCreatorType_2", ailment.unique)
                end
                -- generic: use equipped tool / interact with nearby furniture prompts
                local root = getRoot()
                if root then
                    for _, prompt in ipairs(workspace:GetDescendants()) do
                        if prompt:IsA("ProximityPrompt") and prompt.Enabled then
                            local parent = prompt.Parent
                            local part = parent and (parent:IsA("BasePart") and parent or parent:FindFirstChildWhichIsA("BasePart", true))
                            if part and (part.Position - root.Position).Magnitude < 25 then
                                pcall(fireproximityprompt, prompt)
                            end
                        end
                    end
                end
                task.wait(2)
            end
            -- claim paycheck-style money if remote exists
            invokeAPI("MoneyAPI/ClaimDailyReward")
        end
    end
end)

-- ================= Auto Age Baby =================
task.spawn(function()
    while task.wait(10) do
        if State.AutoAge then
            -- aging happens by completing ailments quickly; ensure tasks loop is on
            State.AutoTasks = true
        end
    end
end)

-- ================= Pet ESP =================
local espFolder = Instance.new("Folder")
espFolder.Name = "PetESP"
espFolder.Parent = game:GetService("CoreGui")

task.spawn(function()
    while task.wait(1.5) do
        espFolder:ClearAllChildren()
        if State.PetESP then
            local pets = workspace:FindFirstChild("Pets")
            local containers = pets and {pets} or {workspace}
            for _, container in ipairs(containers) do
                for _, model in ipairs(container:GetChildren()) do
                    if model:IsA("Model") and model:FindFirstChild("AnimationController", true) and not Players:GetPlayerFromCharacter(model) then
                        local part = model:FindFirstChildWhichIsA("BasePart")
                        if part then
                            local hl = Instance.new("Highlight")
                            hl.Adornee = model
                            hl.FillColor = Color3.fromRGB(255, 170, 0)
                            hl.FillTransparency = 0.5
                            hl.Parent = espFolder

                            local billboard = Instance.new("BillboardGui")
                            billboard.Adornee = part
                            billboard.Size = UDim2.new(0, 120, 0, 22)
                            billboard.StudsOffset = Vector3.new(0, 3, 0)
                            billboard.AlwaysOnTop = true
                            billboard.Parent = espFolder
                            local label = Instance.new("TextLabel")
                            label.Size = UDim2.new(1, 0, 1, 0)
                            label.BackgroundTransparency = 1
                            label.Text = model.Name
                            label.TextColor3 = Color3.fromRGB(255, 170, 0)
                            label.TextStrokeTransparency = 0
                            label.TextScaled = true
                            label.Parent = billboard
                        end
                    end
                end
            end
        end
    end
end)

-- ================= UI =================
local FarmTab = Window:CreateTab("Farm", 4483362458)

FarmTab:CreateToggle({
    Name = "Auto Farm Money (via tasks)",
    CurrentValue = false,
    Callback = function(Value) State.AutoFarm = Value end
})

FarmTab:CreateToggle({
    Name = "Auto Complete Tasks (Ailments)",
    CurrentValue = false,
    Callback = function(Value) State.AutoTasks = Value end
})

FarmTab:CreateToggle({
    Name = "Auto Age Baby",
    CurrentValue = false,
    Callback = function(Value) State.AutoAge = Value end
})

FarmTab:CreateButton({
    Name = "Show Current Ailments",
    Callback = function()
        local ailments = getAilments()
        local names = {}
        for _, a in ipairs(ailments) do table.insert(names, a.kind .. ":" .. a.name) end
        Rayfield:Notify({
            Title = "Ailments",
            Content = #names > 0 and table.concat(names, ", ") or "None found",
            Duration = 5
        })
    end
})

local VisualTab = Window:CreateTab("Visuals", 4483362458)

VisualTab:CreateToggle({
    Name = "Pet ESP",
    CurrentValue = false,
    Callback = function(Value) State.PetESP = Value end
})

local TPTab = Window:CreateTab("Teleports", 4483362458)

for name in pairs(Locations) do
    TPTab:CreateButton({
        Name = "Teleport: " .. name,
        Callback = function() teleportTo(name) end
    })
end

-- Anti AFK
LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new())
end)

Rayfield:Notify({Title = "Adopt Me Hub", Content = "Loaded successfully!", Duration = 4})
