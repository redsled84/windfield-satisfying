local _ = require 'moses'
local wf = require 'windfield'
local ROT = require 'rotLove/rot'
local inspect = require 'inspect'
local Cam = require 'camera'
local cam = Cam(0, 0)

local function existantRect(rects, x, y)
  for i = 1, #rects do
    local rect = rects[i]
    if rect.x == x and rect.y == y then
      return true
    end
  end
  return false
end

local function optimizeMap(grid)
  local rects = {}
  for y = 1, #grid do
    local rx = 1
    for x = 1, #grid[y] do
      local rw = x - rx 
      local n = grid[y][x]
      local rowContainsZero = false
      if n == 0 then
        rowContainsZero = true
      end
      if not rowContainsZero and x == #grid[y] and not existantRect(rects, rx, y) then
        table.insert(rects, {x=rx, y=y, w=rw, h=1})
      end
      if x < #grid[y] then
        if n == 0 and grid[y][x+1] == 1 then
          rx = x + 1
        end
        if n == 2 and grid[y-1][x] == 0 and grid[y+1][x] == 0 then
          table.insert(rects, {x=rx, y=y, w=rw, h=1})
          rx = x+1
        end
        if n == 1 and grid[y][x+1] == 0 and not existantRect(rects, rx, y) then
          table.insert(rects, {x=rx, y=y, w=rw+1, h=1})
        end
      end
    end
  end
  table.insert(rects, {x=#grid[1], y = 1, w = 1, h = #grid})
  return rects
end

function love.load()
  world = wf.newWorld(0, 0, true)
  world:addCollisionClass('Wall')
  world:addCollisionClass('Door')
  world:addCollisionClass('Player')
  world:addCollisionClass('Bullet')

  tileSize = 20
  cells = {}
  -- local f = ROT.Display(40, 40)
  rog = ROT.Map.Brogue(40, 40)
  rog:create(function(x, y, val)end, true)
  rects = optimizeMap(rog._map)
  for i = 1, #rects do
    local rect = rects[i]
    local w = rect.w > 0 and rect.w or 1
    local h = rect.h > 0 and rect.h or 1
    local cell = world:newRectangleCollider(rect.x*tileSize, rect.y*tileSize, w*tileSize, h*tileSize)
    cell:setType('static')
    cell:setCollisionClass('Wall')
  end

  for y = 1, #rog._map do
    for x = 1, #rog._map[y] do
      if rog._map[y][x] == 1 then
        table.insert(cells, {x=x,y=y,val=1,seen=false})
      end
      if rog._map[y][x] == 2 then
        local cell = world:newRectangleCollider(x*tileSize, y*tileSize, tileSize, tileSize)
        cell:setType('static')
        cell:setCollisionClass('Door')
        table.insert(cells, {x=x,y=y,val=2,seen=false})
      end
    end
  end

  local spawn = {
    rog._rooms[1]._walls[2][2],
    rog._rooms[1]._walls[2][1]
  }
  dRadius = 2.3

  bullets = {}
  bulletSpeed = 350

  player = world:newCircleCollider(spawn[1]*tileSize+tileSize,spawn[2]*tileSize+tileSize,
    tileSize / dRadius)
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
end

local garbageTimer = 0
local collectionInterval = .5
function love.update(dt)
  if garbageTimer > collectionInterval then
    collectgarbage('collect')
    -- print(#bullets)
    garbageTimer = 0
  else
    garbageTimer = garbageTimer + dt
  end

  local deadCount = 0
  for i = 1, #bullets do
    if bullets[i]:isDestroyed() then
      deadCount = deadCount + 1
    end
  end
  if deadCount == #bullets then
    for i = #bullets, 1, -1 do
      bullets[i] = nil
    end
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
      dist = math.sqrt((cell.x*tileSize+tileSize/2 - x+tileSize/dRadius)^2
        + (cell.y*tileSize+tileSize/2 - y+tileSize/dRadius)^2)
    end
    local alpha = 255
    if dist then
      if dist > 360 and not cell.seen then
        alpha = 0
      elseif dist > 360 and cell.seen then
        alpha = 35
      elseif dist > 300 then
        alpha = 80
      elseif dist > 200 then
        alpha = 180
      elseif dist > 100 then
        alpha = 235
      elseif dist <= 100 then
        alpha = 255
      end
      if dist < 235 then
        cell.seen = true
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

  -- floor
  for i, v in ipairs(rog._map) do
    for j, kv in ipairs(v) do
      dist = math.sqrt((j*tileSize+tileSize/2 - x+tileSize/dRadius)^2
        + (i*tileSize+tileSize/2 - y+tileSize/dRadius)^2)
      local alpha = 255
      if dist then
        if dist > 360 then
          alpha = 0
        elseif dist > 300 then
          alpha = 80
        elseif dist > 200 then
          alpha = 140
        elseif dist > 100 then
          alpha = 200
        elseif dist <= 100 then
          alpha = 235
        end
      end
      if kv == 0 then
        love.graphics.setColor(205,133,63, alpha)
        love.graphics.rectangle('fill', j * tileSize, i *tileSize, tileSize, tileSize)
      end
    end
  end
  
  -- player
  love.graphics.setColor(140, 140, 140)
  love.graphics.circle('fill', x, y, tileSize/dRadius)
  love.graphics.setColor(255, 255, 255)
  love.graphics.circle('fill', x, y, tileSize/dRadius-3)

  -- bullets
  for i=#bullets, 1, -1 do
    local v = bullets[i]
    if v then
      love.graphics.setColor(255,255,255)
      if not v:isDestroyed() then
        love.graphics.rectangle('fill', v:getX(), v:getY(), v.width, v.height)
      end
    end
  end
  --[[
  Printing the id of a cell
  for y = 1, #rog._map do
    for x = 1, #rog._map[y] do
      local n = rog._map[y][x]
      love.graphics.setColor(255,255,255)
      love.graphics.print(tostring(n), x*tileSize, y*tileSize)
    end
  end
  ]]

  cam:detach()

  -- minimap
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
    if v.seen then
      love.graphics.rectangle('fill', mx+v.x*scaler+buffer, my+v.y*scaler+buffer, scaler, scaler)
    end
  end
  
  love.graphics.setColor(255,255,60)
  local px, py = player:getPosition()
  love.graphics.circle('fill', mx+buffer+(px/tileSize)*scaler,
    my+buffer+(py/tileSize)*scaler, (tileSize/scaler)/dRadius)

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
  local px, py = player:getPosition()
  local bullet
  if key == 'right' then
    bullet = world:newRectangleCollider(px + tileSize/dRadius+3, py, 6, 3)
    bullet:setLinearVelocity(bulletSpeed, 0)
    bullet.width = 6
    bullet.height = 3
  end
  if key == 'left' then
    bullet = world:newRectangleCollider(px - tileSize/dRadius-3, py, 6, 3)
    bullet:setLinearVelocity(-bulletSpeed, 0)
    bullet.width = 6
    bullet.height = 3
  end
  if key == 'up' then
    bullet = world:newRectangleCollider(px, py - tileSize/dRadius-8, 3, 6)
    bullet:setLinearVelocity(0, -bulletSpeed)
    bullet.width = 3
    bullet.height = 6
  end
  if key == 'down' then
    bullet = world:newRectangleCollider(px, py + tileSize/dRadius+3, 3, 6)
    bullet:setLinearVelocity(0, bulletSpeed)
    bullet.width = 3
    bullet.height = 6
  end
  if bullet then
    bullet:setCollisionClass('Bullet')
    bullet:setObject(bullet)
    bullets[#bullets+1] = bullet
    bullet.i = #bullets+1
    bullet:setPreSolve(function(c1, c2, contact)
      if c1.collision_class == 'Bullet' and (c2.collision_class == 'Wall' or c2.collision_class == 'Door') then
        bullet:destroy()
      end
    end)
  end
  if key == 'r' then
    love.event.quit('restart')
  end
end