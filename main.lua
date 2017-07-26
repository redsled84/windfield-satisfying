local wf = require 'windfield'
function love.load()
  world = wf.newWorld(0, 512, true)
  world:addCollisionClass('Platform')
  world:addCollisionClass('Player')
  
  ground = world:newRectangleCollider(100, 500, 600, 50)
  ground:setType('static')
  for i = 1, 3 do
    local platform = world:newRectangleCollider(350, 400 - ((i-1)*100), 100, 20)
    platform:setType('static')
    platform:setCollisionClass('Platform')
  end
  player = world:newRectangleCollider(390, 450, 20, 40)
  player:setCollisionClass('Player')
  
  player:setPreSolve(function(collider_1, collider_2, contact)        
    if collider_1.collision_class == 'Player' and collider_2.collision_class == 'Platform' then
      local px, py = collider_1:getPosition()            
      local pw, ph = 20, 40            
      local tx, ty = collider_2:getPosition() 
      local tw, th = 100, 20
      if py + ph/2 > ty - th/2 then contact:setEnabled(false) end
    end   
  end)
end

function love.update(dt)
  world:update(dt)
end

function love.draw()
  world:draw()
end

function love.keypressed(key)
  if key == 'space' then
    player:applyLinearImpulse(0, -506)
  end
end