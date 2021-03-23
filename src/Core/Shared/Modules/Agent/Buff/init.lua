local main = require(game.Nanoblox)
local httpService = game:GetService("HttpService")
local Maid = main.modules.Maid
local Signal = main.modules.Signal
local Buff = {}
Buff.__index = Buff



-- CONSTRUCTOR
function Buff.new(effect, weight)
    --[[
        Effect can be a string, or a table containing a string and additional value
        For instance:

        agent:buff("WalkSpeed", 5):set(0)
        vs
        agent:buff({"BodyGroupTransparency", "LeftArm"}, 5):set(0)

        The table is necessary for effects where additional needs to be defined (such as 'BodyGroupTransparency')

    --]]
    local realEffect = effect
    local realAdditional
    if type(effect) == "table" then
        realEffect = effect[1]
        realAdditional = effect[2]
    end
        

	local self = {}
	setmetatable(self, Buff)
	
    local buffId = httpService:GenerateGUID(true)
    self.buffId = buffId
    self.timeUpdated = os.clock()
    local maid = Maid.new()
    self._maid = maid
    self.isDestroyed = false
    self.effect = realEffect
    self.additional = realAdditional
    self.weight = weight or 1
    self.updated = maid:give(Signal.new())
    self.agent = nil
    self.appliedValueTables = {}
    self.incremental = nil
    self.previousIncremental = nil

	return self
end



-- METHODS
function Buff:set(value, optionalTweenInfo)
    self.previousIncremental = self.incremental
    self.incremental = false
    self.tweenInfo = optionalTweenInfo
    self.value = value
    self.timeUpdated = os.clock()
    self.updated:Fire(self.effect)
    return self
end

function Buff:increment(value, optionalTweenInfo)
    assert(type(value) == "number", "incremental value must be a number!")
    self.previousIncremental = self.incremental
    self.incremental = true
    self.tweenInfo = optionalTweenInfo
    self.value = value
    self.timeUpdated = os.clock()
    self.updated:Fire(self.effect)
    return self
end

function Buff:decrement(value, optionalTweenInfo)
    self:increment(-value, optionalTweenInfo)
    return self
end

function Buff:_getAppliedValueTable(effect, instance)
    local parentTab = self.appliedValueTables[effect]
    if not parentTab then
        parentTab = {}
        self.appliedValueTables[effect] = parentTab
    end
    local tab = parentTab[instance]
    if not tab then
        tab = {}
        parentTab[instance] = tab
    end
    return tab
end

function Buff:destroy()
    self.isDestroyed = true
    self.updated:Fire()
    self._maid:clean()
    return self
end
Buff.Destroy = Buff.destroy



return Buff