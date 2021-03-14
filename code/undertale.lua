local args = { ... }

currentIssue = nil
issueNoFuel = {"Not enough fuel to proceed", "Fuel was restored"}
issueFullChest = {"I need redstone power to start the trip. Chests might be full", "Redstone power restored"}
issueWaterGone = {"No water in inventory", "Water restored to system"}

-- BLOCKS
air = "minecraft:air"
bedrock = "minecraft:bedrock"

-- FLUIDS
water = "minecraft:water"
lava = "minecraft:flowing_lava"
crudeOil = "galacticraftcore:crude_oil_still"

-- ITEMS
lavaBucket = "minecraft:lava_bucket"
waterBucket = "minecraft:water_bucket"
emptyBucket = "minecraft:bucket"

liquids = {
    water,
    lava,
    crudeOil
}

function init()
    -- TODO:
    -- add bool option that may change if turtle prefers speed to getting the cave to look good - pillaring etc? check blocks on the way up?
    refuelFoundLava = true
    rectangleMode = true
    maxFuel = 15000
    pos = {x=0, y=0, z=0, d=1}
    iPos = {x=nil, y=nil, z=nil, d=nil}
    minY = 5  -- 1: get all diamonds. 5: down to bedrock. 
    maxY = 15  -- 15 is max for diamonds, but should those be visible in the roof?
    for i = 1, #args do
        arg = split(args[i], "=")
        if #arg ~= 2 then
            print("error on init() - args must be on format var=value. Arg "..i.." is "..args[i])
            error()
        end
        name = arg[1]
        value = arg[2]

        name = string.lower(name)
        value = string.lower(value)
        if value == "true" then
            value = true
        elseif value == "false" then
            value = false
        else
            value = tonumber(value)
            if value == nil then
                print("error on init() - value must be a number or bool. Value is "..value)
                error()
            end
        end

        setVar(name, value)
    end
    if y() < 6 then
        print("input error - y must be >= 6")
        error()
    end
    iPos["x"] = x()
    iPos["y"] = y()
    iPos["z"] = z()
    iPos["d"] = d()

    cycle()
end
function setVar(n, v)  -- n: string, v: int. n is always lowercase
    if n == "x" or n == "y" or n == "z" or n == "d" then
        pos[n] = v
    elseif n == "miny" then
        minY = v
    elseif n == "maxy" then
        maxY = v
    elseif n == "maxfuel" then
        maxFuel = v
    elseif n == "refuelfoundlava" then
        refuelFoundLava = v
    elseif n == "rectanglemode" then
        rectangleMode = v
    else
        print("error on setVar("..n..", "..v..") - "..n.." is not a recognized variable")
        error()
    end
end
function cycle()
    while true do
        trip()
    end
end
function trip()
    while not affordEdgeTraverse() do
        a = refuel()
        if not a then
            issue(issueNoFuel)
            os.sleep(1)
        end
    end
    solveIssue(issueNoFuel)

    while chestIsFull() do
        issue(issueFullChest)
        os.sleep(1)
    end
    solveIssue(issueFullChest)
    -- dont think it reaches this part
    desTo(0, minY, 0, "xzy")

    homeBound = false
    while true do
        -- has enough fuel for pillar and return
        -- has not full inventory
        if fullInventory() then
            homeBound = true
        end
        while not affordEdgeTraverse() do
            a = refuel()
            if not a then
                homeBound = true
                break
            end
        end
        if homeBound then break end
        edgeTraverse()
    end
    goHome()
    if isHome() then
        dropItems()
    end
end

function chestIsFull()
    os.pullEvent("redstone")
    for k,v in pairs(redstone.getSides()) do
        b = rs.getInput(v)
        if b then
            return false
        end
    end
    
    return true
end
function fullInventory()
    for i = 1, 16 do
        turtle.select(i)
        if turtle.getItemCount(i) == 0 then
            return false
        end
    end
    return true
end
function affordEdgeTraverse()  -- an estimate. should be worst case?
    
    local cost = pillarCost() + homeCost() + 2

    if turtle.getFuelLevel() == "unlimited" then return true end
    local r = cost < turtle.getFuelLevel()
    return r
end
function pillarCost()
    local downCost = y()-minY
    local upCost = maxY-minY
    local cost = upCost + downCost
    return cost
end
function homeCost()
    local hangCost = math.abs(y()-hangY())  -- destination y is hanging
    local centerCost = math.abs(x())+math.abs(z())
    local upCost = math.abs(iY()-hangY())
    local homeCost = math.abs(iX())+math.abs(iZ())

    local cost = hangCost + centerCost + upCost + homeCost
    return cost
end
function refuel()
    for i = 1, 16 do
        turtle.select(i)
        if turtle.refuel(1) then
            return true
        end
    end
    return false
end
function edgeTraverse()
    des("forward")
    foundLeft, foundFront = pillar()
    if foundLeft then
        left()
    else
        if not rectangleMode then  -- turtle should never turn right in rectangle mode
            if not foundFront then
                right()
                if not facedBlockIsOfInterest() then
                    left()
                end
            end 
        end
    end
end
function goHome()
    desTo(x(), hangY(), z())
    if d() == 1 or d() == 3 then
        desTo(0, maxY, 0, "zxy")
    elseif d() == 2 or d() == 4 then
        desTo(0, maxY, 0, "xzy")
    else
        print("error on goHome()")
        error()
    end

    desTo(iX(), iY(), iZ(), "yxz")
end
function isHome()
    return x() == iX() and y() == iY() and z() == iZ()
end
function dropItems()
    for i = 1, 16 do
        tryDrop(i)
    end
end
function tryDrop(i)
    turtle.select(i)
    if turtle.refuel(0) then
        return false
    elseif holdsItem(emptyBucket) then
        return false
    elseif holdsItem(waterBucket) then
        return false
    end
    a = turtle.dropUp()
    return a
end
function pillar()
    local foundFront = floor()
    local foundLeft = roof()
    return foundLeft, foundFront
end
function roof()
    left()
    local foundBlock = searchToY(maxY)
    right()
    return foundBlock
end
function floor()
    local foundBlock = searchToY(minY)
    return foundBlock
end
function searchToY(Y)
    local foundBlock = facedBlockIsOfInterest()
    if not foundBlock then
        while y() ~= Y do
            adjustY(Y)
            foundBlock = facedBlockIsOfInterest()
            if foundBlock then break end
        end
    end
    desTo(x(), Y, z())
    return foundBlock
end
function facedBlockIsOfInterest()
    succ, data = inspect("forward")
    if (not succ) or (isFlowing(data)) or (data.name == bedrock) then
        return false
    end
    return true
end

function desTo(X, Y, Z, priority)
    p = priority or "xzy"  -- default value
    for i = 1, #p do
        local c = p:sub(i,i)
        if c == "x" then
            while x() ~= X do
                a = adjustX(X)
                if not a then
                    break
                end
            end
        elseif c == "y" then
            while y() ~= Y do
                a = adjustY(Y)
                if not a then
                    break
                end
            end
        elseif c == "z" then
            while z() ~= Z do
                a = adjustZ(Z)
                if not a then
                    break
                end
            end
        end
    end
end

function adjustX(X)
    if x() < X then
        a = addX()
    elseif x() > X then
        a = subX()
    end
    return a
end
function adjustY(Y)
    if y() < Y then
        a = addY()
    elseif y() > Y then
        a = subY()
    end
    return a
end
function adjustZ(Z)
    if z() < Z then
        a = addZ()
    elseif z() > Z then
        a = subZ()
    end
    return a
end

function addX() return moveX(1) end
function subX() return moveX(-1) end
function addY() return moveY(1) end
function subY() return moveY(-1) end
function addZ() return moveZ(1) end
function subZ() return moveZ(-1) end

function moveX(pn)
    verPn(pn)
    if pn == 1 then
        turnTo(1)
    elseif pn == -1 then
        turnTo(3)
    end
    return des("forward")
end
function moveY(pn)
    verPn(pn)
    if pn == 1 then
        return des("up")
    elseif pn == -1 then
        return des("down")
    end
end
function moveZ(pn)
    verPn(pn)
    if pn == 1 then
        turnTo(2)
    elseif pn == -1 then
        turnTo(4)
    end
    return des("forward")
end
function des(dir)  -- short for handling the block in front, up or down, and moving
    succ, data = inspect(dir)
    if succ then
        if data.name == lava then
            if data.metadata == 0 then  -- else don't do anything
                a = encounterLava(dir)
                if a then return des(dir) end  -- recursive only if bucketing happened.
                -- if couldn't handle lava, just step into lava
            end
        elseif data.name == bedrock then
            return false
        elseif data.name == water then
            if data.metadata == 0 then
                a = encounterWater(dir)
                if a then return des(dir) end
                -- recursive if could fill a bucket.
                -- if couldn't, step into water
            end
        elseif data.name == air then
            -- don't do anything
        else
            dig(dir)
        end
    end

    a = step(dir)
    if not a then  -- probably mob in the way
        os.sleep(1)
        return des(dir)
    end
    return true
end
function encounterLava(dir)
    --  if has_water and (max_reached or (no_emptybucket and no_lavabucket)):
    --      splash
    --  elseif (has_lava or has_emptybucket):
    --      refuel
    --  else:
    --      go_through

    if pickItem(waterBucket) and (maxFuelReached() or lEBucketCount() == 0) then
        print("Splash water")
        splashWater("up")  -- whether or not the water can be retrieved is irrelevant
        return true
    elseif (lEBucketCount() >= 1) then
        print("Rebucket")
        reBucket(dir)
        return true
    else
        print("Couldn't do anything")
        return false  -- nothing happened
    end
end
function encounterWater(dir)
    if lEBucketCount() >= 2 then
        reBucket(dir)
        return true
    end
    return false
end
function lEBucketCount()  -- lavaBucketCount + emptyBucketCount
    local count = 0
    for i = 1, 15 do
        turtle.select(i)
        if holdsItem(lavaBucket) or holdsItem(emptyBucket) then
            count = count + 1
        end
    end
    return count
end
function maxFuelReached()
    return fuelReached(maxFuel)
end
function fuelReached(n)
    return turtle.getFuelLevel() >= n
end
function isFlowing(data)
    if isLiquid(data) then
        if data.metadata ~= 0 then
            return true
        end
    end
    return false
end
function isLiquid(data)
    for i = 1, #liquids do
        if data.name == liquids[i] then
            return true
        end
    end
    return false
end
function step(dir) -- Move forward/up/down without desing
    if dir == "forward" then
        a = turtle.forward()
        if a then
            if d() == 1 then
                pos["x"] = x() + 1
            elseif d() == 2 then
                pos["z"] = z() + 1
            elseif d() == 3 then
                pos["x"] = x() - 1
            elseif d() == 4 then
                pos["z"] = z() - 1
            else
                print("error on step()")
                error()
            end
        end
    elseif dir == "up" then
        a = turtle.up()
        if a then
            pos["y"] = y() + 1
        end
    elseif dir == "down" then
        a = turtle.down()
        if a then
            pos["y"] = y() - 1
        end
    else
        print("error 2 on step()")
    end
    return a
end
function splashWater(dir)
    -- probably only call with dir up
    a = pickItem(waterBucket)
    if a then
        solveIssue(issueWaterGone)
        a = place(dir)
        if a then
            os.sleep(1)
            place(dir)
            if holdsItem(waterBucket) then
                return true
            else
                issue(issueWaterGone)
                print("Details: water disappeared after splash")
            end
        else
            print("Couldn't place water")
        end
    else
        issue(issueWaterGone)
    end
    return false
end
function reBucket(dir)
    a = pickItem(emptyBucket)
    if a then
        return place(dir)
    else
        a = pickItem(lavaBucket)
        if a then
            a = turtle.refuel()
            if a then
                return place(dir)
            end
        end
    end
    return false
end
function pickItem(name)
    for i = 1, 16 do
        turtle.select(i)
        if holdsItem(name) then
            return true
        end
    end
    return false
end
function holdsItem(name)
    data = turtle.getItemDetail()
    if data then
        return data.name == name
    end
    return false
end
function place(dir)
    if dir == "forward" then
        return turtle.place()
    elseif dir == "up" then
        return turtle.placeUp()
    elseif dir == "down" then
        return turtle.placeDown()
    else
        print("error on place() - invalid dir")
        error()
    end
end
function dig(dir)
    turtle.select(1)
    if dir == "forward" then
        return turtle.dig()
    elseif dir == "up" then
        return turtle.digUp()
    elseif dir == "down" then
        return turtle.digDown()
    else
        print("error on dig() - invalid dir")
        error()
    end
end
function inspect(dir)
    if dir == "forward" then
        return turtle.inspect()
    elseif dir == "up" then
        return turtle.inspectUp()
    elseif dir == "down" then
        return turtle.inspectDown()
    else
        print("error on inspect() - invalid dir")
        error()
    end
end
function verPn(pn)  --Verifies that a pn is 1 or -1
    if pn == 1 or pn == -1 then
        return true
    else
        print("error on verPn")
        error()
        return false
    end
end
function turnTo(D)
    while d() ~= D do
        if D == d() + 1 or D == d() - 3 then
            right()
        else
            left()
        end
    end
end
function left()
    a = turtle.turnLeft()
    pos["d"] = d() - 1
    if a then
        if d() < 1 then
            pos["d"] = d() + 4
        end
    end
    return a
end
function right()
    a = turtle.turnRight()
    pos["d"] = d() + 1
    if a then
        if d() > 4 then
            pos["d"] = d() - 4
        end
    end
    return a
end
function x() return pos["x"] end
function y() return pos["y"] end
function z() return pos["z"] end
function d() return pos["d"] end
function hangY() return math.max(maxY-2, minY) end

function iX() return iPos["x"] end
function iY() return iPos["y"] end
function iZ() return iPos["z"] end
function iD() return iPos["d"] end

-- functions on the program itself
function issue(s)
    if currentIssue ~= s then
        if currentIssue ~= nil then
            print("An issue occured, but the previous issue was never solved: '"..currentIssue[1].."'")
            print(s[1])
        else
            print("An issue occured: '"..s[1].."'")
        end
        currentIssue = s
    end
end
function solveIssue(s)
    if currentIssue == s then
        print("Issue resolved: '"..currentIssue[2].."'")
        currentIssue = nil
    end
end
function split(s, delimiter)
    result = {};
    for match in (s..delimiter):gmatch("(.-)"..delimiter) do
        table.insert(result, match);
    end
    return result;
end

init()