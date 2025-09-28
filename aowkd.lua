local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local RunService = game:GetService("RunService")

-- Ganti dengan URL raw GitHub Anda
local SCRIPT_URL = "https://raw.githubusercontent.com/username/repo/main/script.lua"

-- Daftarkan queue_on_teleport untuk teleport dalam game
if queue_on_teleport then
    queue_on_teleport([[
        loadstring(game:HttpGet("]] .. SCRIPT_URL .. [["))()
    ]])
    print("queue_on_teleport diatur untuk memuat ulang script dari " .. SCRIPT_URL)
else
    warn("queue_on_teleport tidak tersedia, pastikan executor mendukungnya!")
end

-- Fungsi untuk menunggu GUI dengan retry
local function waitForGui(parent, childName, timeout, retries, delay)
    local attempts = 0
    while attempts < retries do
        local success, result = pcall(function()
            return parent:WaitForChild(childName, timeout)
        end)
        if success and result then
            return result
        end
        warn("Gagal menemukan " .. childName .. " di " .. tostring(parent) .. ", retry (" .. (attempts + 1) .. "/" .. retries .. ")")
        attempts = attempts + 1
        task.wait(delay)
    end
    return nil
end

-- Inisialisasi GUI dengan retry
local function initializeGui()
    local mainGui = waitForGui(player.PlayerGui, "Main", 10, 5, 2)
    if not mainGui then
        warn("Gagal menemukan MainGui setelah retry!")
        return nil, nil, nil
    end

    local gearShop = waitForGui(mainGui, "Gears", 10, 5, 2)
    local seedShop = waitForGui(mainGui, "Seeds", 10, 5, 2)
    if not gearShop or not seedShop then
        warn("Gagal menemukan GearShop atau SeedShop!")
        return nil, nil, nil
    end

    local gearFrame = waitForGui(gearShop, "Frame", 10, 5, 2)
    gearFrame = gearFrame and waitForGui(gearFrame, "ScrollingFrame", 10, 5, 2)
    local seedFrame = waitForGui(seedShop, "Frame", 10, 5, 2)
    seedFrame = seedFrame and waitForGui(seedFrame, "ScrollingFrame", 10, 5, 2)

    if not gearFrame or not seedFrame then
        warn("Gagal menemukan gearFrame atau seedFrame!")
        return nil, nil, nil
    end

    return mainGui, gearFrame, seedFrame
end

-- Gear dan Seed Names dengan Emojis
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

local webhookUrl = "https://discord.com/api/webhooks/1380214167889379378/vzIRr2W4_ug9Zs1Lj89a81XayIj3FwLzJko0OSBZInmfT3ymjp__poAQomL5DaZdCiti"
local maxRetryAttempts = 5
local retryDelay = 1.5

-- Cache Frames dan Debug Listeners
local function initializeFrames(gearFrame, seedFrame)
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

    return gearFrames, seedFrames
end

local function getStock(stockLabel)
    local text = stockLabel.Text
    warn("Stock text for " .. stockLabel.Parent.Name .. ": " .. text .. " at " .. os.time())
    local stockText = text:match("x(%d+) in stock")
    return stockText and tonumber(stockText) or 0
end

local function extractItems(itemFrames, itemType)
    local result = {}
    local seen = {}

    for itemName, stockLabel in pairs(itemFrames) do
        local stock = getStock(stockLabel)
        local emoji = emojiMap[itemName] or ""
        if stock and stock > 0 and not seen[itemName] then
            seen[itemName] = true
            table.insert(result, {
                key = itemType .. "_" .. itemName,
                name = itemName,
                displayName = emoji ~= "" and (emoji .. " " .. itemName) or itemName,
                stock = stock
            })
        end
    end
    return result
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
            return HttpService:RequestAsync({
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

local function checkAndSendItems(itemFrames, itemNames, itemType, title)
    local items = {}
    local attempts = 0
    local lastItems = nil

    while attempts < maxRetryAttempts do
        items = extractItems(itemFrames, itemType)
        warn(itemType .. " stocks diambil (attempt " .. (attempts + 1) .. "): " .. HttpService:JSONEncode(items) .. " at " .. os.time())
        if lastItems and HttpService:JSONEncode(items) == HttpService:JSONEncode(lastItems) then
            break
        end
        lastItems = items
        attempts = attempts + 1
        if attempts < maxRetryAttempts then
            task.wait(retryDelay)
        end
    end

    if attempts >= maxRetryAttempts and lastItems and HttpService:JSONEncode(items) ~= HttpService:JSONEncode(lastItems) then
        warn("Stok tidak stabil untuk " .. itemType .. ", skip pengiriman")
        return
    end

    local lines = {}
    for _, item in ipairs(items) do
        table.insert(lines, item.displayName .. " **x" .. item.stock .. "**")
    end

    if #lines > 0 and sendEmbed(lines, title) then
        print("Webhook terkirim untuk " .. itemType .. ": " .. os.time())
    else
        warn("Tidak ada stok untuk " .. itemType .. " atau gagal kirim")
    end
end

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
        warn("Menunggu " .. secondsToNext .. " detik untuk " .. itemType .. " hingga detik ke-2 menit ke-0 berikutnya")
        task.wait(secondsToNext)

        task.spawn(function()
            checkAndSendItems(itemFrames, itemNames, itemType, title)
        end)
    end
end

-- Fungsi utama
local function main()
    while true do
        local mainGui, gearFrame, seedFrame = initializeGui()
        if mainGui and gearFrame and seedFrame then
            local gearFrames, seedFrames = initializeFrames(gearFrame, seedFrame)
            if next(gearFrames) or next(seedFrames) then
                task.spawn(function()
                    scheduleWebhook(gearFrames, gearNames, "Gear", "🛠️ DIKAGAMTENG • Gear Stocks")
                end)
                task.spawn(function()
                    scheduleWebhook(seedFrames, seedNames, "Seed", "🌱 DIKAGAMTENG • Seed Stocks")
                end)
                while mainGui and mainGui.Parent and Players.LocalPlayer do
                    task.wait(1)
                end
                warn("GUI hilang atau pemain disconnect, mencoba inisialisasi ulang...")
            else
                warn("Tidak ada frame yang ditemukan, mencoba ulang...")
            end
        end
        task.wait(5)
    end
end

-- Pantau disconnect pemain
Players.PlayerRemoving:Connect(function(p)
    if p == player then
        warn("Pemain disconnect, script akan dimuat ulang saat bergabung kembali melalui auto-execute atau queue_on_teleport...")
    end
end)

-- Jalankan script utama
task.spawn(main)
