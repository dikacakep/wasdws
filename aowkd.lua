local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local mainGui = player.PlayerGui:WaitForChild("Main", 30) -- Timeout diperpanjang ke 30 detik

-- Gear Setup
local gearShop = mainGui:WaitForChild("Gears", 15)
local gearFrame = gearShop:WaitForChild("Frame", 15):WaitForChild("ScrollingFrame", 15)

-- Seed Setup
local seedShop = mainGui:WaitForChild("Seeds", 15)
local seedFrame = seedShop:WaitForChild("Frame", 15):WaitForChild("ScrollingFrame", 15)

local webhookUrl = "https://discord.com/api/webhooks/1380214167889379378/vzIRr2W4_ug9Zs1Lj89a81XayIj3FwLzJko0OSBZInmfT3ymjp__poAQomL5DaZdCiti"

-- Check if UI elements are found
if not gearFrame then warn("gearFrame tidak ditemukan!") end
if not seedFrame then warn("seedFrame tidak ditemukan!") end
if not gearFrame or not seedFrame then
    warn("Gagal menemukan elemen UI. Mencoba ulang...")
    local retries = 0
    local maxRetries = 5
    while retries < maxRetries and (not gearFrame or not seedFrame) do
        task.wait(5)
        retries = retries + 1
        gearFrame = gearShop and gearShop:FindFirstChild("Frame") and gearShop.Frame:FindFirstChild("ScrollingFrame")
        seedFrame = seedShop and seedShop:FindFirstChild("Frame") and seedShop.Frame:FindFirstChild("ScrollingFrame")
        if gearFrame and seedFrame then
            warn("Berhasil menemukan GUI setelah retry #" .. retries)
            break
        end
    end
    if not gearFrame or not seedFrame then
        warn("Gagal menemukan elemen UI setelah " .. maxRetries .. " percobaan. Script berhenti.")
        return
    end
end

-- Items to monitor and auto-buy
local monitorItems = {
    "Shroombino Seed",
    "Carnivorous Plant Seed",
    "Mr Carrot Seed",
    "Tomatrio Seed",
    "Cocotank Seed",
    "Water Bucket"
}

-- Gear and Seed Names with Emojis
local gearNames = {
    "Water Bucket", "Frost Grenade", "Banana Gun", "Frost Blower", "Carrot Launcher"
}
local seedNames = {
    "Cactus Seed", "Strawberry Seed", "Pumpkin Seed", "Sunflower Seed", "Dragon Fruit Seed",
    "Eggplant Seed", "Watermelon Seed", "Cocotank Seed", "Carnivorous Plant Seed",
    "Mr Carrot Seed", "Tomatrio Seed", "Shroombino Seed", "Grape Seed"
}

local emojiMap = {
    ["Water Bucket"] = "🪣", ["Grape Seed"] = "💣", ["Shroombino Seed"] = "💣", ["Frost Grenade"] = "💣", ["Banana Gun"] = "🍌",
    ["Frost Blower"] = "🌬️", ["Carrot Launcher"] = "🥕",
    ["Cactus Seed"] = "🌵", ["Strawberry Seed"] = "🍓", ["Pumpkin Seed"] = "🎃",
    ["Sunflower Seed"] = "🌻", ["Dragon Fruit Seed"] = "🌴", ["Eggplant Seed"] = "🍆",
    ["Watermelon Seed"] = "🍉", ["Cocotank Seed"] = "🥥", ["Carnivorous Plant Seed"] = "🌱",
    ["Mr Carrot Seed"] = "🥕", ["Tomatrio Seed"] = "🍅"
}

-- Shared Variables
local maxRetryAttempts = 5
local retryDelay = 1.5
local BUY_DELAY_SECONDS = 60 -- 1 menit delay sebelum membeli
local monitoring = {} -- Untuk melacak item yang dipantau

-- Cache Frames and Add Debug Listeners
local gearFrames = {}
local seedFrames = {}

for _, gearName in ipairs(gearNames) do
    local gearPath = gearFrame:FindFirstChild(gearName)
    if gearPath and gearPath:IsA("Frame") then
        local stockLabel = gearPath:FindFirstChild("Stock")
        if stockLabel and stockLabel:IsA("TextLabel") then
            gearFrames[gearName] = stockLabel
            stockLabel:GetPropertyChangedSignal("Text"):Connect(function()
                warn("Gear stock changed for " .. gearName .. ": " .. stockLabel.Text .. " at " .. os.time())
            end)
        else
            warn("Stock label tidak ditemukan untuk gear: " .. gearName)
        end
    else
        warn("Gear tidak ditemukan: " .. gearName)
    end
end

for _, seedName in ipairs(seedNames) do
    local seedPath = seedFrame:FindFirstChild(seedName)
    if seedPath and seedPath:IsA("Frame") then
        local stockLabel = seedPath:FindFirstChild("Stock")
        if stockLabel and stockLabel:IsA("TextLabel") then
            seedFrames[seedName] = stockLabel
            stockLabel:GetPropertyChangedSignal("Text"):Connect(function()
                warn("Seed stock changed for " .. seedName .. ": " .. stockLabel.Text .. " at " .. os.time())
            end)
        else
            warn("Stock label tidak ditemukan untuk seed: " .. seedName)
        end
    else
        warn("Seed tidak ditemukan: " .. seedName)
    end
end

local function getStock(stockLabel)
    local text = stockLabel.Text
    warn("Stock text for " .. stockLabel.Parent.Name .. ": " .. text .. " at " .. os.time())
    local stockText = text:match("x(%d+) in stock")
    return stockText and tonumber(stockText) or 0
end

local function sendEmbed(lines, title)
    if #lines == 0 then return false end
    task.wait(0.5)
    local payload = HttpService:JSONEncode({
        embeds = {{
            title = title,
            color = 0x57F287,
            fields = {{
                name = "Stock Update",
                value = table.concat(lines, "\n"),
                inline = false
            }},
            timestamp = DateTime.now():ToIsoDate()
        }}
    })
    local success, result
    for i = 1, 3 do
        success, result = pcall(function()
            return request({
                Url = webhookUrl,
                Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = payload
            })
        end)
        if success then break end
        warn("Webhook attempt " .. i .. " failed: " .. tostring(result))
        task.wait(1)
    end
    if not success then
        warn("Webhook gagal setelah 3 percobaan: " .. tostring(result))
    end
    return success
end

local function sendPurchaseWebhook(itemName, initialStock, bought, afterStock)
    local playerName = player and player.Name or "Unknown"
    local timeStr = os.date("%Y-%m-%d %H:%M:%S", os.time())
    local emoji = emojiMap[itemName] or ""
    local displayName = emoji ~= "" and (emoji .. " " .. itemName) or itemName
    local payload = HttpService:JSONEncode({
        embeds = {{
            title = "✅ Pembelian Berhasil",
            color = 0x57F287,
            fields = {
                {name = "Akun", value = playerName, inline = true},
                {name = "Item", value = displayName, inline = true},
                {name = "Jumlah (sebelum)", value = tostring(initialStock), inline = true},
                {name = "Dibeli", value = tostring(bought), inline = true},
                {name = "Sisa (setelah)", value = tostring(afterStock), inline = true},
                {name = "Waktu", value = timeStr, inline = false}
            },
            timestamp = DateTime.now():ToIsoDate()
        }}
    })
    local success, result
    for i = 1, 3 do
        success, result = pcall(function()
            return request({
                Url = webhookUrl,
                Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = payload
            })
        end)
        if success then break end
        warn("Purchase webhook attempt " .. i .. " failed: " .. tostring(result))
        task.wait(1)
    end
    if not success then
        warn("Purchase webhook gagal setelah 3 percobaan: " .. tostring(result))
    end
    return success
end

local function findItemGui(name)
    local node = seedFrame and seedFrame:FindFirstChild(name)
    if node then
        return node, "Seeds"
    end
    node = gearFrame and gearFrame:FindFirstChild(name)
    if node then
        return node, "Gears"
    end
    return nil, nil
end

local function initMonitorFor(name)
    local container, cat = findItemGui(name)
    if not container then
        warn("[aowkd] Container not found for " .. name)
        return false
    end
    local stockLabel = container:FindFirstChild("Stock")
    if not stockLabel then
        warn("[aowkd] Stock label not found for " .. name)
        return false
    end
    monitoring[name] = {
        container = container,
        stockLabel = stockLabel,
        pending = false
    }
    spawn(function()
        local currentText = tostring(stockLabel.Text)
        while monitoring[name] and monitoring[name].stockLabel == stockLabel do
            local changed = false
            local con = nil
            local ok, _ = pcall(function()
                con = stockLabel:GetPropertyChangedSignal("Text")
            end)
            if ok and con then
                local fired = false
                local conn
                conn = con:Connect(function()
                    fired = true
                    if conn then conn:Disconnect() end
                end)
                local waited = 0
                while not fired and waited < 1.5 and monitoring[name] and monitoring[name].stockLabel == stockLabel do
                    task.wait(0.1)
                    waited = waited + 0.1
                end
                if fired then changed = true end
            else
                task.wait(1)
                changed = true
            end
            if not (monitoring[name] and monitoring[name].stockLabel == stockLabel) then break end
            if changed then
                local txt = tostring(stockLabel.Text)
                local stockNum = getStock(stockLabel)
                if stockNum > 0 then
                    warn(string.format("[aowkd] Stock detected for %s : %d", name, stockNum))
                    if not monitoring[name].pending then
                        monitoring[name].pending = true
                        task.spawn(function()
                            task.wait(BUY_DELAY_SECONDS) -- Tunggu 1 menit
                            if not (monitoring[name] and monitoring[name].stockLabel == stockLabel) then
                                monitoring[name].pending = false
                                return
                            end
                            local initialStock = getStock(stockLabel)
                            if initialStock <= 0 then
                                warn(string.format("[aowkd] Stock for %s vanished before buy (now %d).", name, initialStock))
                                monitoring[name].pending = false
                                return
                            end
                            local bought = 0
                            local currentStock = initialStock
                            while currentStock > 0 do
                                local remoteParent = game:GetService("ReplicatedStorage"):FindFirstChild("BridgeNet2")
                                local remote = remoteParent and remoteParent:FindFirstChild("dataRemoteEvent")
                                if not remote then
                                    warn("[aowkd] Remote not found for buy: " .. name)
                                    break
                                end
                                local clickedOk = pcall(function()
                                    remote:FireServer({name, "\a"})
                                end)
                                if not clickedOk then
                                    warn("[aowkd] Failed to fire remote for " .. name)
                                    break
                                end
                                task.wait(0.5)
                                local newStock = getStock(stockLabel)
                                if newStock < currentStock then
                                    bought = bought + (currentStock - newStock)
                                else
                                    warn(string.format("[aowkd] Buy did not decrease stock for %s, stopping.", name))
                                    break
                                end
                                currentStock = newStock
                            end
                            local afterStock = currentStock
                            if bought > 0 then
                                warn(string.format("[aowkd] Purchase success: %s bought %d of %s (before:%d after:%d) at %s", player.Name, bought, name, initialStock, afterStock, os.date("%Y-%m-%d %H:%M:%S", os.time())))
                                sendPurchaseWebhook(name, initialStock, bought, afterStock)
                            else
                                warn(string.format("[aowkd] No items bought for %s (before:%d after:%d).", name, initialStock, afterStock))
                            end
                            monitoring[name].pending = false
                        end)
                    end
                end
            end
        end
    end)
    return true
end

-- Initialize monitors for all configured item names
for _, itemName in ipairs(monitorItems) do
    local ok = initMonitorFor(itemName)
    if not ok then
        task.spawn(function()
            local retries = 0
            while retries < 10 do
                task.wait(2)
                if initMonitorFor(itemName) then
                    break
                end
                retries = retries + 1
            end
            if retries >= 10 then
                warn("[aowkd] Failed to init monitor for " .. itemName .. " after retries.")
            end
        end)
    end
end

-- Re-init monitors if PlayerGui.Main gets recreated
player.PlayerGui.ChildAdded:Connect(function(child)
    if child.Name == "Main" then
        task.wait(1)
        gearFrame = gearShop and gearShop:FindFirstChild("Frame") and gearShop.Frame:FindFirstChild("ScrollingFrame")
        seedFrame = seedShop and seedShop:FindFirstChild("Frame") and seedShop.Frame:FindFirstChild("ScrollingFrame")
        for _, name in ipairs(monitorItems) do
            if not monitoring[name] then
                pcall(function() initMonitorFor(name) end)
            else
                local container = monitoring[name].container
                if not container or not container.Parent then
                    pcall(function() initMonitorFor(name) end)
                end
            end
        end
    end
end)

-- Schedule stock check webhook
local function scheduleWebhook(itemFrames, itemNames, itemType, title)
    while true do
        local currentTime = os.date("*t")
        local currentMinute = currentTime.min
        local currentSecond = currentTime.sec
        local minutesToNext = (5 - (currentMinute % 5)) % 5
        local targetSecond = 2
        local secondsToNext = (targetSecond - currentSecond) + (minutesToNext * 60)
        if secondsToNext <= 0 then
            secondsToNext = secondsToNext + 300
        end
        warn("Menunggu " .. secondsToNext .. " detik untuk " .. itemType .. " hingga detik ke-5 menit detik ke-0 berikutnya")
        task.wait(secondsToNext)
        task.spawn(function()
            local items = extractItems(itemFrames, itemType)
            warn(itemType .. " stocks diambil: " .. HttpService:JSONEncode(items) .. " at " .. os.time())
            local lines = {}
            for _, item in ipairs(items) do
                table.insert(lines, item.displayName .. " **x" .. item.stock .. "**")
            end
            if #lines > 0 and sendEmbed(lines, title) then
                print("Webhook terkirim untuk " .. itemType .. ": " .. os.time())
            else
                warn("Tidak ada stok untuk " .. itemType .. " atau gagal kirim")
            end
        end)
    end
end

task.spawn(function()
    scheduleWebhook(gearFrames, gearNames, "Gear", "🛠️ DIKAGAMTENG • Gear Stocks")
end)
task.spawn(function()
    scheduleWebhook(seedFrames, seedNames, "Seed", "🌱 DIKAGAMTENG • Seed Stocks")
end)
