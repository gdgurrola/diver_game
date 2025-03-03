pico-8 cartridge // http://www.pico-8.com
version 38
__lua__

-- Player setup
player = {
    x = 64,  -- Starting position in the world (adjust if needed)
    y = 64,
    speed = 1.5,
    frame = 1,
    anim_timer = 0,
    direction = "up"
}

-- Animation sequences
swim_up_frames = {0, 2, 4, 6, 8, 10} -- Upward swimming
swim_right_frames = {12, 14} -- Rightward swimming
swim_left_frames = {32, 34} -- Leftward swimming
swim_down_frames = {36, 38, 40, 42} -- Downward swimming

map_width = 1024 -- 128 tiles * 8 pixels
map_height = 512 -- 32 tiles * 8 pixels


-- Camera position
cam_x = 0
cam_y = 0

function _update()
    local moving_horizontally = false
    local moving_vertically = false

    -- Handle movement
    if btn(0) then -- Left
        player.x -= player.speed
        player.direction = "left"
        moving_horizontally = true
    elseif btn(1) then -- Right
        player.x += player.speed
        player.direction = "right"
        moving_horizontally = true
    end

    if btn(2) then -- Up
        player.y -= player.speed
        moving_vertically = true
    elseif btn(3) then -- Down
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

    -- 📌 Fix: Update camera to follow the player
    cam_x = mid(0, player.x - 64, map_width - 128) -- Prevent scrolling beyond map width
    cam_y = mid(0, player.y - 64, map_height - 128) -- Prevent scrolling beyond map height
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
end
