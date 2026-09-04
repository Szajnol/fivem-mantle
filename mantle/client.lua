

local wasInAir     = false
local leftGroundAt = 0
local canGrab      = false
local lastTry      = 0

local function probe(sx, sy, sz, ex, ey, ez, ignore)
    local handle = StartExpensiveSynchronousShapeTestLosProbe(
        sx, sy, sz, ex, ey, ez, Config.ShapeTestFlags, ignore, 4
    )
    local _, hit, endCoords, normal = GetShapeTestResult(handle)
    if hit and hit ~= 0 then
        return endCoords, normal
    end
    return nil
end

local function findLedge(ped)
    local pos = GetEntityCoords(ped, true)
    local fwd = GetEntityForwardVector(ped)

    local wallPos, wallNormal
    for i = 1, #Config.ProbeHeights do
        local sz = pos.z + Config.ProbeHeights[i]
        local hitPos, n = probe(
            pos.x, pos.y, sz,
            pos.x + fwd.x * Config.Reach, pos.y + fwd.y * Config.Reach, sz,
            ped
        )
        if hitPos and math.abs(n.z) < 0.45 then
            wallPos, wallNormal = hitPos, n
            break
        end
    end
    if not wallPos then return nil end

    local px = wallPos.x - wallNormal.x * 0.25
    local py = wallPos.y - wallNormal.y * 0.25

    local topHit = probe(
        px, py, pos.z + Config.MaxHeight + 0.35,
        px, py, pos.z + Config.MinHeight,
        ped
    )
    if not topHit then return nil end

    local rel = topHit.z - pos.z
    if rel < Config.MinHeight or rel > Config.MaxHeight then return nil end

    return topHit
end

CreateThread(function()
    while true do
        local sleep = 200
        local ped   = PlayerPedId()

        local busy = IsPedClimbing(ped) or IsPedVaulting(ped)
            or IsPedRagdoll(ped) or IsPedSwimming(ped)

        local airborne = IsPedOnFoot(ped)
            and not IsEntityDead(ped)
            and not IsPedInAnyVehicle(ped, false)
            and not busy
            and (IsPedJumping(ped) or IsPedFalling(ped) or IsEntityInAir(ped))

        if airborne then
            sleep = 0

            if not wasInAir then
                wasInAir     = true
                leftGroundAt = GetGameTimer()
                canGrab      = true
            end

            local now   = GetGameTimer()
            local ready = canGrab
                and (now - leftGroundAt) >= Config.MinAirTime
                and (now - lastTry) >= Config.Cooldown

            if Config.Debug and ready then
                local ledge = findLedge(ped)
                if ledge then
                    DrawLine(ledge.x, ledge.y, ledge.z,
                             ledge.x, ledge.y, ledge.z + 0.5, 0, 255, 0, 200)
                end
            end

            if ready and IsControlJustPressed(0, Config.Key) and findLedge(ped) then
                lastTry = now
                if Config.OneGrabPerJump then canGrab = false end
                TaskClimb(ped, true)
            end
        else
            wasInAir = false
        end

        Wait(sleep)
    end
end)
