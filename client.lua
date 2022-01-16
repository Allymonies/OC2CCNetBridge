local device = require("devices")
local socket = require("socket")
--local json = require("json")
local ld = require("LibDeflate")
local base64 = require("base64")
local time = require("posix.time")

local robot = device:find("robot")
local inv = device:find("inventory_operations")

function getData(client)
    local fileData = ""
    local ready = false
    local dataLength = 0
    while not ready do
        time.nanosleep({tv_sec=0,tv_nsec=150*1000*1000})
        while inv:takeFrom(0, 1, "front") == 0 do end
        local item = robot:getStackInSlot(0)
        if item["tag"] ~= nil and item["tag"]["display"] ~= nil and item["tag"]["display"]["Name"] ~= nil then
            local itemNameJson = item["tag"]["display"]["Name"]
            local itemName = string.sub(itemNameJson, 10, -3)    
            if string.sub(itemName, 1, 7) == "SENDING" then
                ready = true
                dataLength = tonumber(string.sub(itemName, 9))
            elseif string.sub(itemName, 1, 4) == "DONE" then
                ready = true
                dataLength = tonumber(string.sub(itemName, 6))
            end
        end
        inv:dropInto(0, 1, "front")
    end
    print("Got data length " .. tostring(dataLength))
    client:send("Content-Length: " .. dataLength .. "\r\n")
    client:send("\r\n")
    local slot = 1
    local chestSize = 27
    local done = false
    local progress = 0

    while not done do
        if inv:takeFrom(slot, 1, "front") == 0 then
            while inv:takeFrom(0, 1, "front") == 0 do end
            local item = robot:getStackInSlot(0)
            local itemNameJson = item["tag"]["display"]["Name"]
            inv:dropInto(0, 1, "front")
            --local itemName = json.decode(itemNameJson)["text"]
            local itemName = string.sub(itemNameJson, 10, -3)    
            if string.sub(itemName, 1, 4) == "DONE" then
                while inv:takeFrom(0, 1, "front") == 0 do end
                print("Request finished!")
                inv:drop(1, "up")
                done = true
                break
            else
                if string.sub(itemName, 1, 7) ~= "SENDING" then
                    print("Got unusual item name " .. itemName)
                end
                while inv:takeFrom(slot, 1, "front") == 0 do end
            end
        end
        local item = robot:getStackInSlot(0)
        local itemNameJson = item["tag"]["display"]["Name"]
        --local itemName = json.decode(itemNameJson)["text"]
        local itemName = string.sub(itemNameJson, 10, -3)
        inv:drop(1, "up")
        local data = base64.decode(itemName)
        progress = progress + #data
        print("Got " .. tostring(progress) .. " of " .. tostring(dataLength))
        client:send(data)
        --fileData = fileData .. data

        slot = slot + 1
        if slot >= chestSize then
            slot = 1
        end
    end

    --local output = ld:DecompressZlib(fileData)
    --return output
    return dataLength
    --[[local file = io.open("output.txt", "wb")
    file:write(output)
    io.flush()
    file:close()]]
end

local prev=16
function sendNibble(value)
    while inv:takeFrom(prev, 1, "front") == 0 do end
    if prev ~= value then
        while inv:dropInto(prev, 1, "front") == 0 do end
        while inv:takeFrom(value, 1, "front") == 0 do end
    end
    -- Drop into data line slot
    while inv:dropInto(17, 1, "front") == 0 do end
    prev = value
end

function requestURL(url)
    robot:turn("right")
    for i = 1, #url do
        local char = string.byte(url:sub(i,i))
        local upper = char >> 4
        local lower = (char & 0x0F)
        sendNibble(upper)
        sendNibble(lower)
    end
    sendNibble(16)
    print("Turning left")
    time.nanosleep({tv_sec=1,tv_nsec=50*1000*1000})
    robot:turn("left")
    print("Turned left")
    time.nanosleep({tv_sec=1,tv_nsec=50*1000*1000})
    print("Stuffs")
end

local server = socket.tcp()
server:bind("*", 80)
server:listen(5)
local ip, port = server:getsockname()
while port ~= "80" do
    server:close()
    server = socket.tcp()
    server:bind("*", 80)
    server:listen(5)
    time.nanosleep({tv_sec=0,tv_nsec=150*1000*1000})
    ip, port = server:getsockname()
end
print("Listening on IP="..ip..", PORT="..port.."...")

while true do
    local client = server:accept()
    if client then
        print("Client connection!")
        local data = ""
        local line, err = client:receive()
        line = string.sub(line, 5)
        local path = string.sub(line, 1, string.find(line, " ")-1)
        local host
        while line ~= "" do
            if string.sub(line, 1, 5):lower() == "host:" then
                host = string.sub(line, 7)
            end
            line, err = client:receive()
        end
        if host and path then
            print("Received request for " .. host .. path)
        end
        client:send("HTTP/1.1 200 OK\r\n")
        client:send("Server: OC2CCNetBridge\r\n")
        client:send("Content-Type: text/html\r\n")
        client:send("Content-Encoding: deflate\r\n")
        requestURL(host .. path)
        data = getData(client)
        --client:send(data)
    end
    client:close()
end