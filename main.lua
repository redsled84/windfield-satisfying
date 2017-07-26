local _ = require 'moses'
local wf = require 'windfield'
local ROT = require 'rotLove/rot'
local inspect = require 'inspect'
local Cam = require 'camera'
local cam = Cam(0, 0)

function love.load()
  world = wf.newWorld(0, 0, true)
  world:addCollisionClass('Wall')
  world:addCollisionClass('Door')
  world:addCollisionClass('Player')

  tileSize = 32
  cells = {}
  -- local f = ROT.Display(40, 40)
  rog = ROT.Map.Brogue(40, 40)
  rog:create(function(x, y, val)
    if val == 1 then
      local cell = world:newRectangleCollider(x*tileSize, y*tileSize, tileSize, tileSize)
      cell:setType('static')
      cell:setCollisionClass('Wall')
      table.insert(cells, {x=x,y=y,val=val})
    end
  end, true)
  
  local doors = rog._doors

  for i, v in ipairs(doors) do
    local x = v[1]
    local y = v[2]
    local cell = world:newRectangleCollider(x*tileSize, y*tileSize, tileSize, tileSize)
    cell:setType('static')
    cell:setCollisionClass('Door')
    table.insert(cells, {x=x,y=y,val=2})
  end

  local spawn = {
    rog._rooms[1]._walls[4][1],
    rog._rooms[1]._walls[4][2]
  }
  dRadius = 2.3
  player = world:newCircleCollider(spawn[1]*tileSize+tileSize, spawn[2]*tileSize, tileSize / dRadius)
  player.touchingDoor = false
  player:setCollisionClass('Player')
  player:setPreSolve(function(c1, c2, contact)
    if c1.collision_class == 'Player' and c2.collision_class == 'Door' then
      if love.keyboard.isDown('space') then
        contact:setEnabled(false)
        player.touchingDoor = false
      else
        player.touchingDoor = true
      end
    end
  end)

  print(#cells)
end

local garbageTimer = 0
local collectionInterval = .5
function love.update(dt)
  if garbageTimer > collectionInterval then
    collectgarbage('collect')
    garbageTimer = 0
  else
    garbageTimer = garbageTimer + dt
  end

  world:update(dt)

  local dx, dy = 0, 0
  local speed = 150
  if love.keyboard.isDown('d') then
    dx = speed
  elseif love.keyboard.isDown('a') then
    dx = -speed
  end
  if love.keyboard.isDown('w') then
    dy = -speed
  elseif love.keyboard.isDown('s') then
    dy = speed
  end
  if not (love.keyboard.isDown('d') or love.keyboard.isDown('a')) then
    dx = 0
  end
  if not (love.keyboard.isDown('w') or love.keyboard.isDown('s')) then
    dy = 0
  end

  player:setLinearVelocity(dx, dy)

  local camX, camY = player:getPosition()
  cam:lookAt(camX, camY)

  if player:exit('Door') then
    player.touchingDoor = false
  end
end

function love.draw()
  cam:attach()
  -- draw cells
  local x, y = player:getPosition()
  for i = #cells, 1, -1 do
    local cell = cells[i]
    local dist
    if cell then
      dist = math.sqrt((cell.x*tileSize+tileSize/2 - x+tileSize/dRadius)^2 + (cell.y*tileSize+tileSize/2 - y+tileSize/dRadius)^2)
    end
    local alpha = 255
    if dist then
      if dist > 360 then
        alpha = 0
      elseif dist > 300 then
        alpha = 80
      elseif dist > 200 then
        alpha = 180
      elseif dist > 100 then
        alpha = 235
      elseif dist <= 100 then
        alpha = 255
      end
    end
    if cell.val == 1 then
      love.graphics.setColor(70, 70, 70, alpha)
      love.graphics.rectangle('line', cell.x*tileSize, cell.y*tileSize, tileSize, tileSize)
      love.graphics.setColor(120, 120, 120, alpha)
      love.graphics.rectangle('fill', cell.x*tileSize, cell.y*tileSize, tileSize, tileSize)
    elseif cell.val == 2 then
      love.graphics.setColor(180, 60, 120, alpha)
      love.graphics.rectangle('line', cell.x*tileSize, cell.y*tileSize, tileSize, tileSize)
      love.graphics.setColor(230, 90, 150, alpha)
      love.graphics.rectangle('fill', cell.x*tileSize, cell.y*tileSize, tileSize, tileSize)  
    end
  end
  
  --player
  love.graphics.setColor(255,140,235)
  love.graphics.circle('fill', x, y, tileSize/dRadius)
  love.graphics.setColor(255, 255, 255)
  love.graphics.circle('fill', x, y, tileSize/dRadius-3)
  cam:detach()

  --minimap
  local scaler = 4
  local lenX = #rog._map[1] * scaler
  local lenY = #rog._map * scaler
  local buffer = 5
  local mx = love.graphics.getWidth() - lenX - buffer * 3
  local my = buffer
  love.graphics.setColor(60,60,255)
  love.graphics.rectangle('fill', mx, my, buffer*3+lenX, buffer*3+lenY)
  for i, v in ipairs(cells) do
    if v.val == 1 then
      love.graphics.setColor(0,255,0)
    elseif v.val == 2 then
      love.graphics.setColor(255,0,0)
    end
    love.graphics.rectangle('fill', mx+v.x*scaler+buffer, my+v.y*scaler+buffer, scaler, scaler)
  end
  love.graphics.setColor(255,255,60)
  local px, py = player:getPosition()
  love.graphics.circle('fill', mx+buffer+(px/tileSize)*scaler, my+buffer+(py/tileSize)*scaler, (tileSize/scaler)/dRadius)

  -- tip box
  if player.touchingDoor then
    love.graphics.setColor(235,235,235)
    local str = "Hold 'space' to enter the door"
    local fontSize = 10
    local paddingX = 30
    local paddingY = 40
    local tx = love.graphics.getWidth() / 1.8 - (string.len(str) / 2) * fontSize
    local ty = love.graphics.getHeight() / 1.5 - fontSize / 2
    local rx = tx - paddingX
    local ry = ty - paddingY
    love.graphics.rectangle('fill', rx, ry, string.len(str)*fontSize, paddingY*2)
    love.graphics.setColor(185, 20, 20)
    love.graphics.print(str, tx+fontSize, ty-fontSize/2)
  end

  local count = collectgarbage('count')
  love.graphics.print(tostring(count), 10, 10)
end

function love.keypressed(key)
  if key == 'escape' then
    world:destroy()
    love.event.quit()
  end
end