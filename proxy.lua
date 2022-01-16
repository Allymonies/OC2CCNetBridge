--[[
Assume that input is in front
output is on the bottom
disk drive is on top
--]]
if not fs.exists("LibDeflate.lua") then
    print("LibDeflate not found, downloading...")
    shell.run("wget https://raw.githubusercontent.com/Allymonies/OC2CCNetBridge/main/LibDeflate.lua")
end

if not fs.exists("base64.lua") then
    print("base64 not found, downloading...")
    shell.run("wget https://raw.githubusercontent.com/Allymonies/OC2CCNetBridge/main/base64.lua")
end

local ld = require("LibDeflate")
local base64 = require("base64")

local selfName = "turtle_3"
local diskDriveName = "drive_0"
local ioChest = peripheral.wrap("minecraft:chest_6")
local returnChest = peripheral.wrap("minecraft:chest_7")
local dataChest = peripheral.wrap("minecraft:chest_8")
local inputChest = peripheral.wrap("minecraft:chest_11")

local chestSize = 27
local statusActive = false

function getSizeBytes(size)
    local bytes = ""
    for pos=1, 8 do
        local mask = bit.blshift(1, pos * 8) - 1
        local byte = bit.blogic_rshift(bit.band(size, mask), (pos-1) * 8)
        bytes = bytes .. string.char(byte)
    end
    return bytes
end

local function getDisk()
    local availableSlot = nil
    while availableSlot == nil do
        for k, _ in pairs(returnChest.list()) do
            availableSlot = k
            break
        end
        if availableSlot == nil then
            sleep(0.05)
        end
    end
    returnChest.pushItems(diskDriveName, availableSlot)
end

local function writeDataToChest(data, slot)
    getDisk()
    --turtle.dropUp()
    disk.setLabel("top", data)
    --turtle.suckUp()
    while dataChest.list()[slot] ~= nil do
        sleep(0.05)
    end
    sleep(0.05)
    dataChest.pullItems(diskDriveName, 1, 1, slot)
end

local function setStatus(status)
    if statusActive then
        while dataChest.list()[1] == nil do
            sleep(0.05)
        end
        dataChest.pushItems(diskDriveName, 1)
    else
        getDisk()
        statusActive = true
    end
    --turtle.dropUp()
    disk.setLabel("top", status)
    --turtle.suckUp()
    while dataChest.list()[1] ~= nil do
        sleep(0.05)
    end
    sleep(0.05)
    dataChest.pullItems(diskDriveName, 1, 1, 1)
end

local function getURL(url)
    local req = http.get(url, { ["User-Agent"] = "OC2CCNetBridge Testing"})
    if req then
        local body = req.readAll()
        req.close()
        return body
    else
        return "ERROR, COULD NOT FIND PAGE " .. url
    end
end

local function getEncoded(data)
    local deflated = ld:CompressZlib(data)
    local encoded = base64.encode(deflated)
    return table.unpack({encoded, #deflated})
end

local function sendEncodedData(data, size)
    local sent = 0
    --local sizeBytes = getSizeBytes(#data)
    --local encodedSizeBytes = base64.encode(sizeBytes)
    setStatus("SENDING " .. tostring(size))
    print("status: SENDING")
    --local sizeBytes = getSizeBytes(#data)
    while sent < #data do
        local chunk = data:sub(sent + 1, sent + 32)
        slot = slot + 1
        if slot > chestSize then
            slot = 2
        end
        writeDataToChest(chunk, slot)
        sent = sent + #chunk
        print(tostring(sent) .. " of " .. tostring(#data))
    end
    setStatus("DONE" .. tostring(size))
    print("Done")
end

function sendPage(url)
    local page = getURL(url)

    local encoded, size = getEncoded(page)

    print("Got page, sending encoded data")

    sendEncodedData(encoded, size)
end

local url = ""
local upper = true
local character = 0

while true do
    local inputContents = inputChest.list()
    local data = 0
    if inputContents[18] ~= nil then
        for i = 1, 17 do
            if inputContents[i] == nil then
                data = i
                break
            end
        end
        if data == 17 then
            inputChest.pushItems(peripheral.getName(inputChest), 18, 1, data)
            url = "http://" .. url
            print("Requesting " .. url)
            sendPage(url)
            statusActive = false
            url = ""
        else
            if upper then
                character = (data - 1) * 16
                upper = false
            else
                character = character + (data - 1)
                print("Got character " .. string.char(character))
                url = url .. string.char(character)
                upper = true
            end
            -- Move back, signalling we are ready for more
            inputChest.pushItems(peripheral.getName(inputChest), 18, 1, data)
        end
    else
        sleep(0.05)
    end
end
