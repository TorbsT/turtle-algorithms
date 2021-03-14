l = 20
w = 20

for i = 1, l do
    for j = 1, w do
        turtle.forward()
        turtle.digUp()

        if j == math.ceil(w/2) then
            turtle.turnRight()
            turtle.forward()
            turtle.turnRight()
        elseif j == w then
            turtle.turnLeft()
            turtle.forward()
            turtle.turnLeft()
        end
    end

end