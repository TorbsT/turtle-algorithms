x = 0
y = 0
z = 0
direction = 0

waitPeriod = 60*5
range = 16
minFuel = 100

sides = redstone.getSides()
for i = 1, table.getn(sides) do
    s = sides[i]
    redstone.setOutput(s, true)
end

function enoughFuel()
    f = turtle.getFuelLevel()
    if f == "unlimited" then
        f = turtle.getFuelLimit()
    end
    if f >= minFuel then 
        return true
    end
    for i = 1, 16 do
        turtle.select(i)
        if turtle.refuel(1) then
            return enoughFuel()
        end
    end
    return false
end
function depositItems()
    for i = 1, 16 do
        turtle.select(i)
        if not turtle.refuel(0) then
            turtle.dropDown()
        end
    end
end
function collect()
    chargeForward()
    chargeDown()
    up()
    turnLeft()
    chargeForward()
    turnLeft()
    
    turnDir = false

    while true do
        turtle.suckDown()
        a = forward()
        if not a then
            turn(turnDir)
            b = forward()
            if not b then
                print("done")
                break
            end
            turn(turnDir)
            turnDir = not turnDir
        end
    end
    goHome()
end
function goHome()
    goTo(0, 0, 0)
    turnTo(0)
end
function goTo(X, Y, Z)
    while x ~= X or y ~= Y or z ~= Z do
        if z ~= Z then
            if z > Z then
                turnTo(1)
            else
                turnTo(3)
            end
            a = forward()
        elseif y ~= Y then
            if y > Y then
                -- should rarely happen
                a = down()
            else
                a = up()
            end
        elseif x ~= X then
            if x > X then
                turnTo(0)
            else
                turnTo(2)
            end
            a = forward()
        end
    end
end
function turnTo(targetDir)
    d = targetDir - direction
    if d == -3 then
        turnRight()
    elseif d == 3 then
        turnLeft()
    else
        for i=1, math.abs(d), 1 do
            if d > 0 then
                turnRight()
            elseif d < 0 then
                turnLeft()
            else
                print("ERROR: what "..d)
            end
        end
    end
    if direction ~= targetDir then
        print("Tried to turnTo("..targetDir.."), but direction is now "..direction)
    end
end

function charge(m) --Returns TRUE if managed to forward() once
    local r = false
    while true do
        if math.abs(x) > range or math.abs(z) > range then
            print("ERROR in charge(): Out of range")
            break
        end
        local a
        if m == "forward" then
            a = forward()
        end
        if m == "down" then
            a = down()
        end
        if not a then
            break
        end
        r = true
    end
    return r
end
function chargeForward()
    return charge("forward")
end
function chargeDown()
    return charge("down")
end
function forward()
    a = turtle.forward()
    if a then
        value = direction / 2
        if value < 1 then
            value = -1
        else
            value = 1
        end
        if direction % 2 == 0 then
            x = x + value
        else
            z = z + value
        end
    end
    return a
end
function up()
    a = turtle.up()
    if a then
        y = y + 1
    end
    return a
end
function down()
    a = turtle.down()
    if a then
        y = y - 1
    end
    return a
end

function turn(rightTurn)
    if rightTurn then
        turnRight()
    end
    if not rightTurn then
        turnLeft()
    end
end
function turnLeft()
    a = turtle.turnLeft()
    if a then
        direction = direction - 1
    end
    directionOverflow()
end
function turnRight()
    a = turtle.turnRight()
    if a then
        direction = direction + 1
    end
    directionOverflow()
end
function directionOverflow()
    if direction > 3 or direction < 0 then
        if direction > 3 then
            direction = direction - 4
        else
            direction = direction + 4
        end
        directionOverflow()
    end
end

-- SCRIPT

while true do
    if enoughFuel() then
        collect()
        depositItems()
        os.sleep(waitPeriod)
    else
        print("Need more fuel!")
    end
end