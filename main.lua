pico-8 cartridge // http://www.pico-8.com
version 38
__lua__

-- Global oxygen variable (full oxygen = 100)
oxygen = 100

-- Player setup
player = {
    x = 64,  -- Starting position in the world
    y = 64,
    speed = 1.5,
    frame = 1,
    anim_timer = 0,
    direction = "up"
}

-- Animation sequences
swim_up_frames   = {0, 2, 4, 6, 8, 10}   -- Upward swimming
swim_right_frames= {12, 14}             -- Rightward swimming
swim_left_frames = {32, 34}             -- Leftward swimming
swim_down_frames = {36, 38, 40, 42}      -- Downward swimming

map_width = 1024 -- 128 tiles * 8 pixels
map_height = 512 -- 64 tiles * 8 pixels (extended map size)

-- Sand block occupies 1 tile (8 pixels) at the bottom
sand_top = map_height - 8

-- Camera position
cam_x = 0
cam_y = 0

function _update()
    local moving_horizontally = false
    local moving_vertically = false

    -- Handle left/right movement with boundaries
    if btn(0) and player.x > 0 then -- Left
        player.x -= player.speed
        player.direction = "left"
        moving_horizontally = true
    elseif btn(1) and player.x < map_width - 16 then -- Right
        player.x += player.speed
        player.direction = "right"
        moving_horizontally = true
    end

    -- Handle up/down movement with boundaries:
    if btn(2) and player.y > 56 then -- Up (upper boundary at y = 56)
        player.y -= player.speed
        moving_vertically = true
    elseif btn(3) and player.y < (sand_top - 16) then -- Down (prevent entering sand)
        player.y += player.speed
        moving_vertically = true
    end

    -- Prioritize left/right animation for diagonal movement
    if moving_horizontally and moving_vertically then
        -- Keep left/right animation
    elseif moving_vertically then
        player.direction = btn(2) and "up" or "down"
    end

    -- Animation logic
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

    -- Reset animation when not moving
    if not (btn(0) or btn(1) or btn(2) or btn(3)) then
        player.frame = 1
    end

    -- Oxygen system:
    -- When underwater (player.y > 56), oxygen decreases slowly.
    -- When at or above the surface (y <= 56), oxygen resets.
    if player.y > 56 then
        oxygen -= 0.05  -- Decrease oxygen more slowly
        if oxygen < 0 then oxygen = 0 end
    else
        oxygen = 100
    end

    -- Update camera to follow the player while staying inside map boundaries
    cam_x = mid(0, player.x - 64, map_width - 128)
    cam_y = mid(0, player.y - 64, map_height - 128)
end

function _draw()
    cls()
    camera(cam_x, cam_y)
    map(0, 0, 0, 0, 128, 128)

    -- Draw the player
    if player.direction == "up" then
        spr(swim_up_frames[player.frame], player.x, player.y, 2, 2)
    elseif player.direction == "right" then
        spr(swim_right_frames[player.frame], player.x, player.y, 2, 2)
    elseif player.direction == "left" then
        spr(swim_left_frames[player.frame], player.x, player.y, 2, 2)
    elseif player.direction == "down" then
        spr(swim_down_frames[player.frame], player.x, player.y, 2, 2)
    end

    -- Draw oxygen bar as a UI element (fixed on screen)
    camera(0,0)  -- Reset camera to draw UI elements
    -- The oxygen bar will be drawn in red (color 8) and have a max width of 40 pixels.
    local bar_width = (oxygen / 100) * 40
    rectfill(5, 5, 5 + bar_width, 10, 8) 
    print("oxygen", 5, 12, 7)
end
