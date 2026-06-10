-- orbit: a spinning planet with a parented moon; click to launch stars.
function on_init()
  planet = GameObject{name="planet", shape="circle", x=480, y=300, w=60, tint={80,160,255}}
  moon = GameObject{name="moon", shape="circle", x=560, y=300, w=20, tint={220,220,220}}
  moon:set_parent(planet)
  planet:add_component{ update = function(self, go, dt) go:rotate(90 * dt) end }
end

function on_update(dt)
  if mouse_pressed() then
    local mx, my = mouse_pos()
    local star = GameObject{shape="rect", x=mx, y=my, w=6, tag="star", tint={255,240,120}}
    star:add_component{
      update = function(self, go, dt)
        go:move(0, -120 * dt)
        if go.y < -10 then go:destroy() end
      end,
    }
  end
end
