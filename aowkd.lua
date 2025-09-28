local HttpService = game:GetService("HttpService")
local player = game:GetService("Players").LocalPlayer
local mainGui = player.PlayerGui:WaitForChild("Main", 10)

-- Gear Setup
local gearShop = mainGui:WaitForChild("Gears", 10)
local gearFrame = gearShop:WaitForChild("Frame", 10):WaitForChild("ScrollingFrame", 10)

-- Seed Setup
local seedShop = mainGui:WaitForChild("Seeds", 10)
local seedFrame = seedShop:WaitForChild("Frame", 10):WaitForChild("ScrollingFrame", 10)

local webhookUrl = "https://discord.com/api/webhooks/1380214167889379378/vzIRr2W4_ug9Zs1Lj89a81XayIj3FwLzJko0OSBZInmfT3ymjp__poAQomL5DaZdCiti"

-- Check if UI elements are found
if not gearFrame then warn("gearFrame tidak ditemukan!") end
if not seedFrame then warn("seedFrame tidak ditemukan!") end
if not gearFrame or not seedFrame then
    warn("Gagal menemukan elemen UI. Periksa struktur!")
    return
end

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
local retryDelay = 1.5  -- Delay 1.5 detik untuk beri waktu UI sinkron

-- Cache Frames and Add Debug Listeners
local gearFrames = {}
local seedFrames = {}

for _, gearName in ipairs(gearNames) do
    local gearPath = gearFrame:FindFirstChild(gearName)
    if gearPath and gearPath:IsA("Frame") then
        local stockLabel = gearPath:FindFirstChild("Stock")
        if stockLabel and stockLabel:IsA("TextLabel") then
            gearFrames[gearName] = stockLabel
            -- Debug: Log perubahan stok
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
            -- Debug: Log perubahan stok
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
    warn("Stock text for " .. stockLabel.Parent.Name .. ": " .. text .. " at " .. os.time()) -- Debug text mentah
    local stockText = text:match("x(%d+) in stock")
    return stockText and tonumber(stockText) or 0 -- Kembalikan 0 untuk text invalid
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
    task.wait(0.5) -- Penundaan untuk menghindari rate limit
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
    for i = 1, 3 do -- Coba hingga 3 kali
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

local function checkAndSendItems(itemFrames, itemNames, itemType, title)
    local items = {}
    local attempts = 0
    local lastItems = nil

    while attempts < maxRetryAttempts do
        items = extractItems(itemFrames, itemType)
        warn(itemType .. " stocks diambil (attempt " .. (attempts + 1) .. "): " .. HttpService:JSONEncode(items) .. " at " .. os.time())

        -- Cek apakah stok stabil (sama dengan attempt sebelumnya)
        if lastItems and HttpService:JSONEncode(items) == HttpService:JSONEncode(lastItems) then
            break -- Stok stabil, lanjut kirim
        end
        lastItems = items
        attempts = attempts + 1
        if attempts < maxRetryAttempts then
            task.wait(retryDelay) -- Tunggu 1.5 detik sebelum retry
        end
    end

    -- Skip jika stok tidak stabil setelah max attempts
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
        -- Hitung waktu hingga detik ke-5 pada menit ke-0 berikutnya (setiap 5 menit, setelah restock)
        local currentTime = os.date("*t")
        local currentMinute = currentTime.min
        local currentSecond = currentTime.sec
        local minutesToNext = (5 - (currentMinute % 5)) % 5
        local targetSecond = 2  -- Kirim pada detik 5 setelah restock
        local secondsToNext = (targetSecond - currentSecond) + (minutesToNext * 60)
        if secondsToNext <= 0 then
            secondsToNext = secondsToNext + 300  -- Tambah 5 menit jika sudah lewat
        end
        warn("Menunggu " .. secondsToNext .. " detik untuk " .. itemType .. " hingga detik ke-5 menit ke-0 berikutnya")
        task.wait(secondsToNext)

        -- Kirim webhook
        task.spawn(function()
            checkAndSendItems(itemFrames, itemNames, itemType, title)
        end)
    end
end

-- Start scheduling for both gears and seeds
task.spawn(function()
    scheduleWebhook(gearFrames, gearNames, "Gear", "🛠️ DIKAGAMTENG • Gear Stocks")
end)
task.spawn(function()
    scheduleWebhook(seedFrames, seedNames, "Seed", "🌱 DIKAGAMTENG • Seed Stocks")
end)
