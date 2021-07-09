local main = require(game.Nanoblox)
local Command =	{}



Command.name = script.Name
Command.description = "Adds given players (secondArg) to the lead player (firstArg)'s Conga Line where everyone mimics the lead player. Players will default to the lead player if empty."
Command.aliases	= {"CopyCat"}
Command.opposites = {}
Command.tags = {"Fun"}
Command.prefixes = {}
Command.contributors = {82347291, 24670328}
Command.blockPeers = false
Command.blockJuniors = false
Command.autoPreview = false
Command.requiresRig = main.enum.HumanoidRigType.None
Command.revokeRepeats = false
Command.preventRepeats = main.enum.TriStateSetting.False
Command.cooldown = 0
Command.persistence = main.enum.Persistence.UntilPlayerDies
Command.args = {"Player", "Players", "Delay", "Gap"}

function Command.invoke(task, args)
	local leadPlayer, players = unpack(args)
	local originalPlayers = task:getOriginalArg("Players")
	if originalPlayers == nil and task.caller then
		table.insert(players, task.caller)
	end
	local leadUser = main.modules.PlayerStore:getUser(leadPlayer)
	if not leadUser then
		return task:kill()
	end

	-- If players table is empty, then kill task as there are no lines to form
	print("players = ", players)
	if #players == 0 then
		return task:kill()
	end

	-- If a conga list is already present, update it then end this task (we let the first task handle everything)
	local congaList = leadUser.temp:get("congaCommandList")
	if congaList then
		for _, plr in pairs(players) do
			congaList:insert(plr)
		end
		return task:kill()
	end

	-- This removes a player from a conga line if they die, respawn or leave
	local trackingPlayers = {}
	local playerChattedRemote = task:give(main.modules.Remote.new("PlayerChatted-"..task.UID))
	local function trackPlayer(player)
		if not trackingPlayers[player] then
			trackingPlayers[player] = true
			local trackingMaid = task:give(main.modules.Maid.new())
			trackingMaid:give(function()
				trackingPlayers[player] = nil
				congaList:removeValue(player)
			end)
			local humanoid = main.modules.PlayerUtil.getHumanoid(player)
			if not humanoid or humanoid.Health <= 0 then
				trackingMaid:clean()
				return
			end
			trackingMaid:give(humanoid.Died:Connect(function()
				trackingMaid:clean()
			end))
			trackingMaid:give(player.CharacterAdded:Connect(function()
				trackingMaid:clean()
			end))
			trackingMaid:give(main.Players.PlayerRemoving:Connect(function(leavingPlayer)
				if player == leavingPlayer then
					trackingMaid:clean()
				end
			end))

			-- This listens for the players chat messages
			main.modules.ChatUtil.getSpeaker(player)
				:andThen(function(speaker)
					task:give(speaker.SaidMessage:Connect(function(chatMessage)
						local message = tostring(chatMessage.FilterResult)
						if message == "Instance" then
							message = chatMessage.FilterResult:GetChatForUserAsync(player.UserId)
						end
						if main.Chat.BubbleChatEnabled and chatMessage.MessageType == "Message" then
							playerChattedRemote:fireAllClients(player, message)
						end
					end))
				end)
				:catch(warn)
		end
	end

	-- This adds a tag to the leadPlayer's Humanoid to indicate they are a conga leader
	local leadPlayerHumanoid = main.modules.PlayerUtil.getHumanoid(leadPlayer)
	local tag = task:give(Instance.new("BoolValue"))
	tag.Name = "NanobloxCongaLeader"
	tag.Value = true
	tag.Parent = leadPlayerHumanoid

	-- This creates the conga list and adds the players to it
	congaList = leadUser.temp:set("congaCommandList", {})
	for _, player in pairs(players) do
		trackPlayer(player)
		congaList:insert(player)
	end
	
	-- This listens for changes (i.e. players being added or removed from the conga line) and updates the clients
	local congaListRemote = task:give(main.modules.Remote.new("CongaList-"..task.UID))
	task:give(congaList.changed:Connect(function(index, playerOrNil)
		print("index, playerOrNil = ", index, playerOrNil)
		if playerOrNil ~= nil then
			trackPlayer(playerOrNil)
		end
		if not task.isDead then
			congaListRemote:fireAllClients(index, playerOrNil)
		end
	end))
	task:invokeAllAndFutureClients(leadPlayer, congaList)

	-- This removes the conga list When the task is revoked
	task:give(function()
		leadUser.temp:set("congaCommandList", nil)
	end)
end

function Command.revoke(task)
	print("Conga was revoked!")
end



return Command