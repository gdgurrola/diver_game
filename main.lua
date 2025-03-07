pico-8 cartridge // http://www.pico-8.com
version 38
__lua__

-- Global variables
game_state = "start"  -- possible states: "start", "pregame", "jump", "game", "end"
end_message = ""      -- message shown in the end state
oxygen = 100
refills = 4         -- 3 breaths per round
score = 0
high_score = 0      -- high_score updates only on a successful round
pickup_effects = {} -- for showing pickup/deposit effects
jump_speed = 0 
max_fish_count = 50
dash_timer = 0
sharks = {}



-- Player setup (drawn 2x; native 8x8 becomes 16x16)
player = {
    x = 64,
    y = 64,
    speed = 1.5,
    frame = 1,
    anim_timer = 0,
    direction = "up",
    inventory = {}  -- holds picked-up fish (max 10)
}

-- Animation sequences for the player
swim_up_frames    = {0, 2, 4, 6, 8, 10}
swim_right_frames = {12, 14}
swim_left_frames  = {32, 34}
swim_down_frames  = {36, 38, 40, 42}

map_width = 1024  -- 128 tiles * 8 pixels
map_height = 512  -- 64 tiles * 8 pixels (extended map)
sand_top = map_height - 8

boat = { x = 16, y = 45, width = 32, height = 20 }

-- Camera position variables
cam_x = 0
cam_y = 0

---------------------------------------------------
-- FISH SPAWNING SETUP
---------------------------------------------------
fish_list = {}
fish_types = {
    {sprite = 67,  value = 30,  min_spawn_y = 100},
    {sprite = 82,  value = 150, min_spawn_y = 180},
    {sprite = 68,  value = 50,  min_spawn_y = 260},
    {sprite = 69,  value = 30,  min_spawn_y = 340},
    {sprite = 84,  value = 30,  min_spawn_y = 420},
    {sprite = 85,  value = 50,  min_spawn_y = 100},
    {sprite = 99,  value = 120, min_spawn_y = 180},
    {sprite = 98,  value = 100, min_spawn_y = 260},
    {sprite = 84,  value = 120, min_spawn_y = 340},
    {sprite = 83,  value = 300, min_spawn_y = 340},
    {sprite = 100, value = 80,  min_spawn_y = 420},
    {sprite = 101, value = 130, min_spawn_y = 100},
    {sprite = 112, value = 200, min_spawn_y = 420}
}

-- Weighted random selection: weight = (300 / fish.value)
function pick_fish_type()
    local total = 0
    for i=1, #fish_types do
        total += 300 / fish_types[i].value
    end
    local r = rnd(total)
    local sum = 0
    for i=1, #fish_types do
        sum += 300 / fish_types[i].value
        if r < sum then
            return fish_types[i]
        end
    end
    return fish_types[#fish_types]
end

function spawn_fish()
    local ftype = pick_fish_type()
    local x = rnd(map_width - 16)
    local y = ftype.min_spawn_y + rnd((map_height - 8) - ftype.min_spawn_y)
    while (x >= cam_x and x <= cam_x + 128 and y >= cam_y and y <= cam_y + 128) do
        x = rnd(map_width - 16)
        y = ftype.min_spawn_y + rnd((map_height - 8) - ftype.min_spawn_y)
    end
    local dir = (flr(rnd(2)) == 0) and "right" or "left"
    local vx = (dir == "right") and 0.5 or -0.5
    local flip = (dir == "left")
    local fish = { x = x, y = y, vx = vx, type = ftype, flip = flip }
    add(fish_list, fish)
end


function initialize_sharks()
    -- Clear previous sharks, if any:
    sharks = {}
    for i = 1, 4 do
      local s = {
        x = rnd(map_width - 16),      
        y = 100 + rnd(map_height - 116), -- Ensures y is never between 0 and 100
        direction = (flr(rnd(2)) == 0) and "left" or "right",  -- Random starting direction
        speed = 0.5,                   -- Start with normal speed
        anim_timer = 0,                -- Animation timer
        frame = 102,                   -- Start with body sprite 102
        mouth_frame = 118,             -- Start with mouth sprite 118
        flip = false                  -- Default flip value (we'll update this)
      }
      add(sharks, s)
    end
end

function update_sharks()
    for s in all(sharks) do
        -- Toggle between body sprite (102/104) and mouth sprite (118/120)
        s.anim_timer += 1
        if s.anim_timer > 10 then
            if s.frame == 102 then
                s.frame = 104
                s.mouth_frame = 120
            else
                s.frame = 102
                s.mouth_frame = 118
            end
            s.anim_timer = 0
        end

        -- Calculate horizontal distance to player.
        local xdist = abs(s.x - player.x)
        local ydist = abs(s.y - player.y)

        -- Increase speed when the player is close
        if xdist < 50 and xdist > 10 and ydist < 50 then
            s.speed = 2.0  
            -- Turn toward the player:
            if s.x < player.x then
                s.direction = "right"
            else
                s.direction = "left"
            end
        elseif xdist > 100 then
            s.speed = 0.5
        end

        -- Move the shark horizontally only.
        if s.direction == "left" then
            s.x -= s.speed
        else
            s.x += s.speed
        end

        -- Ensure the shark stays within the map bounds:
        if s.x < 0 then
            s.x = 0
            s.direction = "right"
        elseif s.x > map_width - 16 then
            s.x = map_width - 16
            s.direction = "left"
        end

        -- Update the flip property based on direction.
        s.flip = (s.direction == "right")
    end
end


function draw_sharks()
    local scale = 2  -- magnification factor
    for s in all(sharks) do
      local cell = s.frame  -- should be 102 or 104
      local sx = (cell % 16) * 8
      local sy = flr(cell / 16) * 8
  
      local dw = 16 * scale
      local dx = s.x
      if s.flip then
        dx = s.x + dw  -- adjust x so the sprite stays in place when flipped
        dw = -dw       -- negative width flips the sprite horizontally
      end
  
      sspr(sx, sy, 16, 16, dx, s.y, dw, 16 * scale)
    end
  end
  

-- Function to draw shark hitboxes for debugging
function draw_shark_hitboxes()
    for s in all(sharks) do
        -- Define collision box for shark mouth
        local mouth_x = s.x + (s.flip and 28 or 2)  -- Moves to the right when flipped
        local mouth_y = s.y + 16  -- Adjust to align with mouth position

        -- Define mouth hitbox dimensions
        local mouth_hitbox = {x = mouth_x, y = mouth_y, width = 4, height = 4}

        -- Draw hitbox rectangle
        rect(mouth_hitbox.x, mouth_hitbox.y, mouth_hitbox.x + mouth_hitbox.width, mouth_hitbox.y + mouth_hitbox.height, 8) -- Red hitbox
    end
end


-- Collision detection: defaults: player 16x16, fish 8x8, boat uses its width/height.
function collides(a, b, aw, ah, bw, bh)
    aw = aw or 16
    ah = ah or 16
    bw = bw or 8
    bh = bh or 8
    return a.x < b.x + bw and a.x + aw > b.x and a.y < b.y + bh and a.y + ah > b.y
end




---------------------------------------------------
-- _update() function with game state handling
---------------------------------------------------
function _update()
    if game_state == "start" then
        if btnp(4) then  -- Z button
            game_state = "pregame"
            player.x = boat.x + boat.width/2 - 10
            player.y = boat.y - 3
        end

    elseif game_state == "pregame" then
        if btnp(4) then
            game_state = "jump"
            jump_speed = 0  -- initialize jump speed
            initialize_sharks()
        end

    elseif game_state == "jump" then
        -- Accelerate the player downward until they reach y = 56
        jump_speed = jump_speed + 0.2  -- acceleration factor
        player.y = player.y + jump_speed
        if player.y >= 56 then
            player.y = 56
            game_state = "game"
            -- Reset gameplay variables for a new round:
            oxygen = 100
            refills = 3
            player.inventory = {}
            -- Note: score is preserved from previous rounds if desired,
            -- or you can reset it here if you want each round separate.
        end

    elseif game_state == "game" then
        local moving_horizontally = false
        local moving_vertically = false

        -- Determine current movement speed; if dash_timer > 0, speed is boosted.
    local current_speed = player.speed
    if dash_timer > 0 then
        current_speed = player.speed * 2  -- Change 2 to another multiplier if desired.
        dash_timer = dash_timer - 2
    end


        if btn(0) and player.x > 0 then
            player.x -= current_speed --player.speed
            player.direction = "left"
            moving_horizontally = true
        elseif btn(1) and player.x < map_width - 16 then
            player.x += current_speed --player.speed
            player.direction = "right"
            moving_horizontally = true
        end

        if btn(2) and player.y > 56 then
            player.y -= current_speed 
            moving_vertically = true
        elseif btn(3) and player.y < (sand_top - 16) then
            player.y += current_speed 
            moving_vertically = true
        end

        if moving_horizontally and moving_vertically then
            -- keep left/right animation for diagonal movement
        elseif moving_vertically then
            player.direction = btn(2) and "up" or "down"
        end

        if not (btn(0) or btn(1) or btn(2) or btn(3)) then
            player.frame = 1
            if player.y > 56 then  -- float upward slowly if idle
                player.y -= 0.3
            end
        else
            player.anim_timer += 1
            if player.anim_timer > 4 then
                player.frame += 1
                if player.direction == "up" and player.frame > #swim_up_frames then
                    player.frame = 1
                elseif player.direction == "right" and player.frame > #swim_right_frames then
                    player.frame = 1
                elseif player.direction == "left" and player.frame > #swim_left_frames then
                    player.frame = 1
                elseif player.direction == "down" and player.frame > #swim_down_frames then
                    player.frame = 1
                end
                player.anim_timer = 0
            end
        end


   
        if player.y > 56 then
            oxygen -= 0.05
            if oxygen < 0 then oxygen = 0 end
        elseif player.y <= 56 and refills > 0 then
            if oxygen < 100 then
                oxygen = 100
                refills -= 1
            end
        end

        cam_x = mid(0, player.x - 64, map_width - 128)
        cam_y = mid(0, player.y - 64, map_height - 128)

        if #fish_list < max_fish_count and rnd(1) < 0.2 then
            spawn_fish()
        end
        
        for f in all(fish_list) do
            f.x += f.vx
            if f.x < -16 or f.x > map_width then
                del(fish_list, f)
            end
        end




local boat_colliding = collides(player, boat, 16, 16, boat.width, boat.height)


-- In the "game" branch of _update(), after handling movement and animation:

-- Pickup fish: when NOT colliding with boat and X (btnp(5)) is pressed
if btnp(5) and (not boat_colliding) then
    for i = #fish_list, 1, -1 do
        local f = fish_list[i]
        if collides(player, f) and #player.inventory < 10 then
            add(player.inventory, f)
            add(pickup_effects, {x = f.x, y = f.y, value = f.type.value, timer = 60})
            del(fish_list, f)
        end
    end
end

for s in all(sharks) do
    -- Define collision box for shark mouth
    local mouth_x = s.x + (s.flip and 28 or 2)  -- Move right when flipped
    local mouth_y = s.y + 16  -- Adjust to match the actual mouth position

    -- Define mouth hitbox dimensions
    local mouth_hitbox = {x = mouth_x, y = mouth_y, width = 4, height = 4}

    -- Check collision from **all four sides**
    if collides(player, mouth_hitbox, 16, 16, 4, 4) then
        end_message = "You were eaten by a shark!"
        game_state = "end"
    end
end




-- Check if the player is colliding with the boat.
local boat_colliding = collides(player, boat, 16, 16, boat.width, boat.height)

-- Dash activation: if player presses Z (btnp(4)) and is NOT colliding with the boat,
-- and if they have fish in their inventory, activate dash.
if btnp(4) and (not boat_colliding) then
    if #player.inventory > 0 then
        dash_timer = (#player.inventory) * 10  -- e.g., 10 frames boost per fish lost
        player.inventory = {}  -- Clear inventory as the cost for dashing
    end
end


-- Automatic deposit: if the player touches the boat, deposit all fish in the inventory.
if boat_colliding then
    if #player.inventory > 0 then
        local deposit_value = 0
        for i = 1, #player.inventory do
            deposit_value += player.inventory[i].type.value
        end
        score += deposit_value
        add(pickup_effects, {x = boat.x + boat.width/2, y = boat.y, value = deposit_value, timer = 60})
        player.inventory = {}  -- Clear the inventory after deposit.
    end
end


        for e in all(pickup_effects) do
            e.timer -= 1
            e.y -= 0.2
            if e.timer <= 0 then
                del(pickup_effects, e)
            end
        end

        update_sharks()



        -- End conditions:
        if oxygen == 0 then
            end_message = "You ran out of oxygen!"
            game_state = "end"
        end
        if boat_colliding and player.y <= 56 and refills==0 then
            end_message = "You made it back! Good job!"
            game_state = "end"
            -- Only update high score after round completion if successful.
            if score > high_score then
                high_score = score
            end
        end

    elseif game_state == "end" then
        if btnp(4) then
            game_state = "pregame"
            oxygen = 100
            refills = 3
            score = 0
            player.inventory = {}
            player.x = boat.x + boat.width/2 - 10
            player.y = boat.y - 3
        end
    end
end

---------------------------------------------------
-- _draw() function with game state branching
---------------------------------------------------
function _draw()
    cls()
    if game_state == "start" then
        camera(0,0)
        map(0, 0, 0, 0, 64, 64)
        print("welcome to free diving!", 20, 25, 10)
        print("press z to begin", 30, 40, 7)

        print("rules: ",10, 70, 7)
        print("- press x to collect fish", 10, 80, 7)

        print("- press z to sprint swim", 10,90, 7)
        print("- sprinting = lose inventory", 10,  100, 7)
        print("- drop fish off at boat", 10, 110, 7)
        print("- avoid sharks + save oxygen", 10, 120, 7 )
    elseif game_state == "pregame" then
        camera(0,0)
        map(0, 0, 0, 0, 128, 128)
        spr(swim_up_frames[player.frame], player.x, player.y, 2, 2)
        print("press z to jump into the water", 5, 75, 7)
    elseif game_state == "jump" then
        camera(0,0)
        map(0, 0, 0, 0, 128, 128)
        spr(swim_up_frames[player.frame], player.x, player.y, 2, 2)
    elseif game_state == "game" then
        camera(cam_x, cam_y)
        map(0, 0, 0, 0, 128, 128)
        if player.direction == "up" then
            spr(swim_up_frames[player.frame], player.x, player.y, 2, 2)
        elseif player.direction == "right" then
            spr(swim_right_frames[player.frame], player.x, player.y, 2, 2)
        elseif player.direction == "left" then
            spr(swim_left_frames[player.frame], player.x, player.y, 2, 2)
        elseif player.direction == "down" then
            spr(swim_down_frames[player.frame], player.x, player.y, 2, 2)
        end
        for f in all(fish_list) do
            spr(f.type.sprite, f.x, f.y, 1, 1, f.flip)
        end
        for e in all(pickup_effects) do
            print("+"..e.value, e.x, e.y, 10)
        end


        -- In the "game" branch of _draw(), after drawing fish and pickup effects:
        draw_sharks()



        camera(0,0)
        print("score: "..score, 5, 5, 7)
        print("high: "..high_score, 5, 12, 7)
        local ui_y = 100
        print("inventory: "..#player.inventory.."/10", 5, ui_y, 7)
        local oxygen_y = ui_y + 15
        local bar_width = (oxygen / 100) * 40
        rectfill(5, oxygen_y, 5 + bar_width, oxygen_y + 5, 8)
        print("oxygen", 5, oxygen_y - 8, 7)
        local max_refills = 3
        local square_size = 5
        local spacing = 2
        local start_x = 32
        local square_y = oxygen_y - 8
        for i = 1, max_refills do
            local sq_x = start_x + (i - 1) * (square_size + spacing)
            if i <= refills then
                rectfill(sq_x, square_y, sq_x + square_size, square_y + square_size, 140)
            else
                rect(sq_x, square_y, sq_x + square_size, square_y + square_size, 140)
            end
        end
    elseif game_state == "end" then
        camera(0,0)
        map(0, 7, 0, 0, 128, 128)
        print(end_message, 12, 50, 7)
        print("press z to restart", 25, 60, 7)
        print("final score: "..score, 30, 70, 7)
    end
end

