-- LOCAL
local main = require(game.Nanoblox)
local CommandController = {}
local clientTasks = {}



-- START
function CommandController.start()
	
	local invokeClientCommand = main.modules.Remote.new("invokeClientCommand")
	invokeClientCommand.onClientInvoke = function(taskProperties)
		local task = main.modules.Task.new(taskProperties)
		clientTasks[task.UID] = task
		task:execute():await()
		if task.killAfterExecution then
			task:kill()
		end
		return
	end

	local revokeClientCommand = main.modules.Remote.new("revokeClientCommand")
	revokeClientCommand.onClientEvent:Connect(function(taskUID)
		local task = clientTasks[taskUID]
		if task then
			task:kill()
			clientTasks[taskUID] = nil
		end
	end)

	local callClientTaskMethod = main.modules.Remote.new("callClientTaskMethod")
	callClientTaskMethod.onClientEvent:Connect(function(taskUID, methodName)
		local task = clientTasks[taskUID]
		if task then
			local method = task[methodName]
			if method then
				method(task)
			end
		end
	end)

	local replicateClientCommand = main.modules.Remote.new("replicateClientCommand")
	replicateClientCommand.onClientEvent:Connect(function(taskUID, packedData)
		local task = clientTasks[taskUID]
		if task and task.replication then
			task:replication(table.unpack(packedData))
		end
	end)

	local previewCommand = main.modules.Remote.new("previewCommand")
	previewCommand.onClientEvent:Connect(function(statement)
		--!!! preview command statement
	end)
	
end



return CommandController