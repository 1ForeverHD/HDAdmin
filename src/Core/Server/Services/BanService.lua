-- LOCAL
local main = require(game.Nanoblox)
local System = main.modules.System
local BanService = System.new("Bans")
local PlayerStore = main.modules.PlayerStore
local unbanLimit = 7884000000   -- 250 Years (anything above is displayed as Expires: Never) Do not exceed 500 years otherwise os.date fails



-- EVENTS
BanService.recordAdded:Connect(function(recordKey, record)
	local targetUserId = tonumber(recordKey)
	--warn(("BAN '%s' ADDED!"):format(recordKey))
	-- Kick player if present
	local player = targetUserId and main.Players:GetPlayerByUserId(targetUserId)
	if player then
		BanService.kick(player)
	end
	-- Update any clients with 
end)

BanService.recordRemoved:Connect(function(recordKey)
	--warn(("BAN '%s' REMOVED!"):format(recordKey))
end)

BanService.recordChanged:Connect(function(recordKey, key, value)
	--warn(("BAN '%s' CHANGED %s to %s"):format(recordKey, tostring(key), tostring(value)))
end)



-- PLAYERSERVICE METHODS
function BanService.playerAddedMethod(player)
	-- Check for ban (1)
	local record = BanService:getRecord(player.UserId)
	if record then
		local currentTime = os.time()
		if record.expiryTime <= currentTime then
			-- Ban expired, permanently remove
			local key = tostring(player.UserId)
			BanService:removeRecord(key)
		elseif record.accurate == true then
			BanService.kick(player)
			-- Returning false blocks the user from loading
			-- (which is no longer necessary as the user has been kicked)
			return false
		end
	end
	return true
end

function BanService.playerLoadedMethod(player, user)
	-- Check for ban (2)
	-- When a player is banned who has never played the game before, the
	-- server is unsure whether the caller has permission to ban the target
	-- As a result, the user is banned with 'accurate' set to false.
	-- This means the banned user and callers permissions can be verified
	-- at a later date, once this user has finally joined and their
	-- role data has loaded. If it turns out this caller did not have
	-- the authority to ban the target, then unban the user
	local record = BanService:getRecord(player.UserId)
	if record and record.accurate == false then
		local RoleService = main.services.RoleService
		local callersHighestRole = RoleService.getRole(record.callerHighestRoleUID)
		local targetsHighestRole = RoleService.getHighestRole(user.perm.roles)
		if not RoleService.isSenior(callersHighestRole, targetsHighestRole) then
			-- the banner did not have permission, unban user (target)
			BanService.unban(player.UserId)
		else
			-- the caller had permission, approve ban
			BanService:updateRecord(player.UserId, {accurate = true})
			BanService.kick(player)
		end
	end
	return true
end



-- METHODS
function BanService.generateRecord(targetUserId)
	local currentTime = os.time()
	return {
		banTime = currentTime,
		expiryTime = currentTime + unbanLimit*2,
		reason = "",
		targetUserId = targetUserId or 0,
		callerUserId = 0,
		callerHighestRoleUID = "",
		accurate = true, -- if not accurate, a check will be performed when the bannedUser enters the game
	}
end

function BanService.verifyBan(targetUserId, callerUser)
	local key = tostring(targetUserId)
	local targetPermData
	local targetUser = PlayerStore:getUser(key)
	if targetUser then
		targetPermData = targetUser.perm
	else
		targetPermData = PlayerStore:grabData(key)
		if not targetPermData then
			return true, "NotAccurate"
		end
	end
	local RoleService = main.services.RoleService
	local callersHighestRole = RoleService.getHighestRole(callerUser.roles)
	local targetsHighestRole = RoleService.getHighestRole(targetPermData.roles)
	if not RoleService.isSenior(callersHighestRole, targetsHighestRole) then
		return false, "Cannot ban peers or seniors"
	end
	return true
end

function BanService.ban(targetUserId, callerUser, isGlobal, properties)
	-- Verify user can ban target
	local canBanTarget, warning = BanService.verifyBan(targetUserId, callerUser)
	if not canBanTarget then
		return false, warning
	end
	-- Create ban record
	local RoleService = main.services.RoleService
	properties.callerUserId = callerUser.userId
	properties.callerHighestRoleUID = RoleService.getHighestRole(callerUser.perm.roles).UID
	if warning == "NotAccurate" then
		properties.accurate = false
	end
	-- Create ban
	BanService.createBan(targetUserId, isGlobal, properties)
	return true
end

function BanService.createBan(targetUserId, isGlobal, properties)
	local key = tostring(targetUserId)
	local record = BanService:createRecord(key, isGlobal, properties)
	return record
end

function BanService.getBan(targetUserId)
	local key = tostring(targetUserId)
	return BanService:getRecord(key)
end

function BanService.getBans()
	return BanService:getRecords()
end

function BanService.updateBan(targetUserId, propertiesToUpdate)
	local key = tostring(targetUserId)
	BanService:updateRecord(key, propertiesToUpdate)
	return true
end

function BanService.removeBan(targetUserId)
	local key = tostring(targetUserId)
	BanService:removeRecord(key)
	return true
end

function BanService.kick(player)
	local record = BanService:getRecord(player.UserId)
	if not record then
		return false
	end
	local kickMessage = ""
	local expiryTime = record.expiryTime
	local expiryTimeLimit = os.time()+(unbanLimit*2)
	if expiryTime > expiryTimeLimit then
		expiryTime = expiryTimeLimit
	end
	main.services.TimeService.grabLocalDate(player, expiryTime)
		:andThen(function(clientDate, clientMonth)
			local function formatTime(minOrHour)
				local newMinOrHour = tostring(minOrHour)
				if #newMinOrHour < 2 then
					newMinOrHour = "0"..newMinOrHour
				end
				return newMinOrHour
			end
			local banRow = ("🚫 You're banned from %s  🚫"):format((record._global == true and "all servers") or "this server")
			local expireRow = (expiryTime > os.time()+(unbanLimit) and "⌛ Expires: Never") or ("⌛ Expires: %s:%s, %s %s %s"):format(formatTime(clientDate.hour), formatTime(clientDate.min), tostring(clientDate.day), tostring(clientMonth), tostring(clientDate.year))
			local reasonRow = ("💬 Reason: '%s'"):format(tostring(record.reason))
			local banMessage = "\n"..banRow.."\n\n"..expireRow.."\n\n"..reasonRow.."\n"
			player:Kick(banMessage)
		end)
end



--[[
local main = require(game.Nanoblox) main.services.BanService.ban(game.Players.ForeverHD, main.UserStore:getUser(game.Players.ForeverHD), true, {banTime = os.time() + 120})

local main = require(game.Nanoblox)
local BanService = main.services.BanService
local targetId = 82347291--math.random(1,10000)
BanService.createBan(targetId, true, {
	reason = "Hello world its me 1",
	expiryTime = os.time() + 60,
})

local main = require(game.Nanoblox)
local BanService = main.services.BanService
local targetId = 82347291
BanService.updateBan(targetId, {_global = true, reason = math.random(1,1000)})

local main = require(game.Nanoblox)
local BanService = main.services.BanService
local targetId = 82347291
BanService.removeBan(targetId)

local main = require(game.Nanoblox)
local BanService = main.services.BanService
local targetId = 82347291
print(BanService.getBan(targetId))
print(BanService.getBan(targetId)._global)

--]]

return BanService