local arg = {...}

--this sets the number of sections the mine should have.
--the total number of mined blocks would be 2*sessionlength*(2*sideTunnelLength + sideTunnelDistance+1)
--set to -1 to mine indefinitely
local sessionLength = arg[1] or 10
local increment = 1
if (sessionLength == -1) then
    sessionLength = 2
    increment = 0
end
--this sets the distance between the side tunnels
local sideTunnelDistance = tonumber(arg[2]) or 2
--this sets the length of the side tunnels
local sideTunnelLength = tonumber(arg[3]) or 5
--if this is true, the turtle will try to throw away trash items when its inventory is full
local trashing = tonumber(arg[4]) or false
--if this is true, the turtle will try to break blocks in its way when moving
local breakStuff = arg[5] or true

local itemMemory = {}
local direction = "x+"
local distanceFromHome = {}
distanceFromHome.x = 0
distanceFromHome.y = 0
distanceFromHome.z = 0

--this should contain all blocks the turtle may encounter, that do not just drop themselfes.
local blocks = {
    ["minecraft:diamond_ore"] = {["drops"] = {["minecraft:diamond"] = 1}},
    ["minecraft:redstone_ore"] = {["drops"] = {["minecraft:restone"] = 5}},
    ["minecraft:coal_ore"] = {["drops"] = {["minecraft:coal"] = 1}},
    ["minecraft:emerald_ore"] = {["drops"] = {["minecraft:emerald"] = 1}},
    ["minecraft:lapis_ore"] = {["drops"] = {["minecraft:lapis_lazuli"] = 5}},
    ["appliedenergistics2:quartz_ore"] = {["drops"] = {["appliedenergistics2:material"] = 1}},
    ["thaumcraft:ore_amber"] = {["drops"] = {["thaumcraft:amber"] = 3}},
    ["forestry:resources"] = {["drops"] = {["forestry:apatite"] = 6}},
    ["thermalfoundation:ore_fluid"] = {["drops"] = {["thermalfoundation:material"] = 2}},
    ["projectx:xycronium_ore"] = {["drops"] = {["projectx:xycronium_crystal"] = 4}},
    --TODO:Damage-values
    ["projectred-exploration:ore"] = {
        ["drops"] = {["projectred-core:resource_item"] = 2, ["projectred-exploration:ore"] = 1}
    },
    --TODO:Damage-values
    ["aroma1997sdimension:miningore"] = {["drops"] = {["minecraft:clay_ball"] = 1, ["minecraft:slime_ball"] = 1}}
    --TODO:Damage-values
}

local valuableOres = {
    "minecraft:diamond_ore",
    "minecraft:iron_ore",
    "minecraft:gold_ore",
    "minecraft:lapis_ore",
    "minecraft:coal_ore",
    "minecraft:emerald_ore",
    "minecraft:redstone_ore",
    "thaumcraft:ore_cinnabar",
    "ic2:resource",
    "modularforcefieldsystem:monazit_ore",
    "thermalfoundation:ore",
    --TODO:Damage-values
    "thermalfoundation:ore_fluid",
    "projectred-exploration:ore",
    --TODO:Damage-values
    "techreborn:ore"
    --TODO:Damage-values
}

local buildBlocks = {
    "minecraft:cobblestone",
    "minecraft:dirt"
}

--Trash Items only matter if trashing is set to true.
--when the inventory is full and there is a block about to be mined thats not in trashBLocks,
--the turtle will search its inventory to find an item from trashItems and throw it away to be abled to mine the block
local trashItems = {
    "minecraft:gravel",
    "minecraft:flint",
    "minecraft:dirt",
    "minecraft:cobblestone"
}

local trashBlocks = {
    "minecraft:gravel",
    "minecraft:dirt",
    "minecraft:cobblestone",
    "minecraft:stone"
}

--when storing its inventory into a chest, the turtle will keep one stack from each of the items in this list
local keepOneInInventory = {
    "minecraft:cobblestone",
    "minecraft:coal",
    "minecraft:torch"
}

function turnLeft()
    if (direction == "x+") then
        direction = "y+"
    elseif (direction == "y+") then
        direction = "x-"
    elseif (direction == "x-") then
        direction = "y-"
    elseif (direction == "y-") then
        direction = "x+"
    end
    turtle.turnLeft()
end

function turnRight()
    if (direction == "x+") then
        direction = "y-"
    elseif (direction == "y-") then
        direction = "x-"
    elseif (direction == "x-") then
        direction = "y+"
    elseif (direction == "y+") then
        direction = "x+"
    end
    turtle.turnRight()
end

function digForward(number)
    for i = 0, number, 1 do
        mine()
        stepForward()
        placeBlocksLeftRight()
        placeBlockDown()
        mineUp()
        stepUp()
        placeBlocksLeftRight()
        placeBlockUp()
        stepDown()
    end
end

function mine()
    local success, block = turtle.inspect()
    if (success == false) then
        return true
    else
        if (hasSpaceForBlock(block.name)) then
            return turtle.dig()
        else
            returnHarvest()
            return (mine())
        end
    end
end

function mineUp()
    local success, block = turtle.inspectUp()
    if (success == false) then
        return true
    else
        if (hasSpaceForBlock(block.name)) then
            return turtle.digUp()
        else
            returnHarvest()
            mineUp()
        end
    end
end

function mineDown()
    local success, block = turtle.inspectDown()
    if (success == false) then
        return true
    else
        if (hasSpaceForBlock(block.name)) then
            return turtle.digDown()
        else
            returnHarvest()
            mineDown()
        end
    end
end

function turnTo(dir)
    if (dir == direction) then
        return true
    else
        --check for all 180 turns
        if
            ((dir == "x+" and direction == "x-") or (dir == "x-" and direction == "x+") or
                (dir == "y+" and direction == "y-") or
                (dir == "y-" and direction == "y+"))
         then
            --check for left turns
            turnRight()
            turnRight()
        elseif
            ((dir == "x+" and direction == "y-") or (dir == "x-" and direction == "y+") or
                (dir == "y+" and direction == "x+") or
                (dir == "y-" and direction == "x-"))
         then
            --check for right turns
            turnLeft()
        elseif
            ((dir == "x+" and direction == "y+") or (dir == "x-" and direction == "y-") or
                (dir == "y+" and direction == "x-") or
                (dir == "y-" and direction == "x+"))
         then
            turnRight()
        end
    end
end

function returnHarvest()
    print("Bringing stuff back home.")
    --remember where to return to afterwards
    local returnPosition = {["x"] = distanceFromHome.x, ["y"] = distanceFromHome.y, ["z"] = distanceFromHome.z}
    local returnRotation = direction;

    moveTo({x = 0, y = 0, z = 0}, "x+", {"y", "z", "x"})
    --now the turtle should be standing on the hopper it started at.
    tryDumpInventory()
    --now move back to where we stopped to continue mining
    print("Now returning to mine.")
    moveTo(returnPosition, returnRotation, {"x", "z", "y"})
end

function tryDumpInventory()
    print("Dumpint Inventory.")
    local keepers = {}
    --first of, check which slots contain items the turtle should keep and remember to keep one of each
    for _, v in pairs(keepOneInInventory) do
        for i = 1, 16, 1 do
            if (turtle.getItemDetail(i) ~= nil and turtle.getItemDetail(i).name == v) then
                table.insert(keepers, i)
                break
            end
        end
    end

    --then dump everything else
    for i = 1, 16, 1 do
        if (isItemInList(i, keepers) == false) then
            turtle.select(i)
            while (turtle.dropDown() == false) do
                os.sleep(5)
            end
        end
    end
end

function moveTo(targetPosition, targetRotation, directionOrder)
    print(
        "moving from " ..
            distanceFromHome.x ..
                "," ..
                    distanceFromHome.y ..
                        "," ..
                            distanceFromHome.z ..
                                " to " .. targetPosition.x .. "," .. targetPosition.y .. "," .. targetPosition.z
    )
    for i, v in pairs(directionOrder) do
        if (v == "y" or v == "x") then
            if ((distanceFromHome[v] - targetPosition[v]) > 0) then
                turnTo(v .. "-")
            else
                turnTo(v .. "+")
            end
            while ((distanceFromHome[v] - targetPosition[v]) ~= 0) do
                if (stepForward() == false) then
                    return false
                end
            end
        else
            while ((distanceFromHome[v] - targetPosition[v]) ~= 0) do
                if ((distanceFromHome[v] - targetPosition[v]) > 0) then
                    if (stepDown() == false) then
                        return false
                    end
                else
                    if (stepUp() == false) then
                        return false
                    end
                end
            end
        end
    end
    turnTo(targetRotation)
end

function hasSpaceForBlock(blockName)
    if (trashing and isItemInList(blockName, trashBlocks)) then
        return true
    else
        --no space for the block to mine
        local drops = {blockName = 1}
        local freeSlots = 0
        local neededSlots = 1
        if (blocks[blockName]) then
            drops = {}
            neededSlots = 0
            for n, v in pairs(blocks[blockName].drops) do
                drops[n] = v
                neededSlots = neededSlots + 1
            end
        end
        --check for matching slots in the inventory
        for i = 1, 16, 1 do
            local item = turtle.getItemDetail(i)
            for n, v in pairs(drops) do
                if (v ~= nil) then
                    if (item == nil) then
                        freeSlots = freeSlots + 1
                        if (neededSlots <= freeSlots) then
                            return true
                        end
                    elseif ((item.name == n) and (turtle.getItemSpace(i) > v)) then
                        neededSlots = neededSlots - 1
                        drops[n] = nil
                        if (neededSlots <= freeSlots) then
                            return true
                        end
                    end
                end
            end
        end
        if (trashing) then
            local item = turtle.getItemDetail(i)
            for i = 1, 16, 1 do
                if (isItemInList(item.name, trashItems)) then --item should never be nil here - otherwise the function has a bug above!
                    turtle.select(i)
                    turtle.drop()
                    freeSlots = freeSlots + 1
                    if (neededSlots <= freeSlots) then
                        return true
                    end
                end
            end
        end
    end
    return false
end

function isItemInList(item, list)
    for _, v in pairs(list) do
        if (item == v) then
            return true
        end
    end
    return false
end

function moveForward(stepNumber)
    if (stepNumber == nil) then
        stepForward()
    else
        for sn = 0, stepNumber, 1 do
            stepForward()
        end
    end
end

function stepForward()
    if (isFuelled()) then
        if (breakStuff) then
            while (turtle.forward() == false) do
                mine()
            end
            if (direction == "x+") then
                distanceFromHome.x = distanceFromHome.x + 1
            elseif (direction == "x-") then
                distanceFromHome.x = distanceFromHome.x - 1
            elseif (direction == "y+") then
                distanceFromHome.y = distanceFromHome.y + 1
            elseif (direction == "y-") then
                distanceFromHome.y = distanceFromHome.y - 1
            end
            return true
        else
            if (turtle.forward()) then
                if (direction == "x+") then
                    distanceFromHome.x = distanceFromHome.x + 1
                elseif (direction == "x-") then
                    distanceFromHome.x = distanceFromHome.x - 1
                elseif (direction == "y+") then
                    distanceFromHome.y = distanceFromHome.y + 1
                elseif (direction == "y-") then
                    distanceFromHome.y = distanceFromHome.y - 1
                end
                return true;
            else
                return false;
            end
        end
    else
        return false;
    end
end

function stepUp()
    if (isFuelled()) then
        if (breakStuff) then
            while (turtle.up() == false) do
                mineUp()
            end
            distanceFromHome.z = distanceFromHome.z + 1
            return true
        else
            if (turtle.up()) then
                distanceFromHome.z = distanceFromHome.z + 1
                return true
            else
                return false
            end
        end
    else
        return false
    end
end

function stepDown()
    if (isFuelled()) then
        if (breakStuff) then
            while (turtle.down() == false) do
                mineDown()
            end
            distanceFromHome.z = distanceFromHome.z - 1
            return true
        else
            if (turtle.down()) then
                distanceFromHome.z = distanceFromHome.z - 1
                return true
            else
                return false
            end
        end
    else
        return false
    end
end

function placeBlocksLeftRight()
    turnLeft()
    placeBlockFront()
    turnLeft()
    turnLeft()
    placeBlockFront()
    turnRight()
end

function placeBlockFront(blockName)
    if (selectItem(blockName)) then
        turtle.place()
    end
end

function placeBlockUp(blockName)
    if (selectItem(blockName)) then
        turtle.placeUp()
    end
end

function placeBlockUp(blockName)
    if (selectItem(blockName)) then
        turtle.placeUp()
    end
end

function placeBlockDown(blockName)
    if (selectItem(blockName)) then
        turtle.placeDown()
    end
end

function selectItem(blockName)
    --if no arg is supplied, try with dirt and cobblestone, otherwise use the name provided.
    if (blockName == nil) then
        local blockSlot = getItemSlot("minecraft:cobblestone")
        if (blockSlot == -1) then
            blockSlot = getItemSlot("minecraft:dirt")
            if (blockSlot == -1) then
                return false
            else
                return turtle.select(blockSlot)
            end
        else
            return turtle.select(blockSlot)
        end
    else
        local blockSlot = getItemSlot(blockName)
        if (blockSlot == -1) then
            return false
        else
            return turtle.select(blockSlot)
        end
    end
    return false
end

function endTunnel()
    placeBlockFront()
    stepUp()
    placeBlockFront()
    stepDown()
end

function getItemSlot(itemName)
    if
        ((itemMemory[itemName] ~= nil) and (turtle.getItemDetail(itemMemory[itemName]) ~= nil) and
            (turtle.getItemDetail(itemMemory[itemName])[name] == itemName))
     then
        return itemMemory[itemName]
    else
        for y = 1, 16, 1 do
            if ((turtle.getItemDetail(y) ~= nil) and (turtle.getItemDetail(y).name == itemName)) then
                itemMemory[itemName] = y
                return y
            end
        end
    end
    return -1
end

function isFuelled()
    if (turtle.getFuelLevel() < 50) then
        return (selectItem("minecraft:coal") and turtle.refuel()) --TODO: use table with fuels and combine to more powerful ones
    else
        return true
    end
end

--Here begins the actual Script
print(
    "Start mining for " ..
        sessionLength ..
            " sections which are " .. sideTunnelDistance .. " from each other and " .. sideTunnelLength .. " deep."
)
for k = 1, sessionLength, increment do
    digForward(sideTunnelDistance)
    endTunnel()
    turnLeft()
    digForward(sideTunnelLength)
    endTunnel()
    turnLeft()
    turnLeft()
    moveForward(sideTunnelLength)
    digForward(sideTunnelLength)
    endTunnel()
    turnLeft()
    turnLeft()
    moveForward(sideTunnelLength)
    --every second passing, set a torch
    if (k % 2 == 0)then
        placeBlockUp("minecraft:torch")
    end
    turnRight()
end
--return home after digging
moveTo({["x"] = 0, ["y"] = 0, ["z"] = 0}, "x+", {"y", "z", "x"})
tryDumpInventory()
--ideas :
-- compressInventory(combine non-full stacks) and compressItems(coalblocks, redstoneblocks...) methods - use tables for recipes and stuff
-- mine veins of interesting ores, specified in a table
