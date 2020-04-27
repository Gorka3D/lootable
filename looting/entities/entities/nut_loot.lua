ENT.Type = "anim"
ENT.PrintName = "Loot"
ENT.Category = "NutScript"
ENT.Spawnable = false
ENT.timeToDelete = 1

if (SERVER) then
	local hook, math, player = hook, math, player
	local IsValid, CurTime, pairs, hook_Run, ipairs, player_GetAll = IsValid, CurTime, pairs, hook.Run, ipairs, player.GetAll
	local EffectData, math_random = EffectData, math.random
	
	function ENT:Think()
		if (IsValid(self) and self.timeToDelete <= CurTime()) then
			self:Remove()
		end
	end

	function ENT:Initialize()
		self:SetModel("models/props_junk/watermelon01.mdl")
		self:SetSolid(SOLID_VPHYSICS)
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetUseType(SIMPLE_USE)
		self.receivers = {}
		self.timeToDelete = CurTime() + nut.config.get("lootTime")

		local physObj = self:GetPhysicsObject()

		if (IsValid(physObj)) then
			physObj:EnableMotion(true)
			physObj:Wake()
		end
	end

	function ENT:setInventory(inventory)
		if (inventory) then
			self:setNetVar("id", inventory:getID())

			inventory.onAuthorizeTransfer = function(inventory, client, oldInventory, item)
				if (IsValid(client) and IsValid(self) and self.receivers[client]) then
					return true
				end
			end
			inventory.getReceiver = function(inventory)
				local receivers = {}

				for k, v in pairs(self.receivers) do
					if (IsValid(k)) then
						receivers[#receivers + 1] = k
					end
				end

				return #receivers > 0 and receivers or nil
			end
		end
	end

	function ENT:OnRemove()
		local index = self:getNetVar("id")

		if (!nut.shuttingDown and !self.nutIsSafe and index) then
			for _, v in ipairs(player_GetAll()) do
				netstream.Start(v, "closeLootMenuSafe")
				local entity = v.nutBagEntity
				if (IsValid(entity)) then
					entity.receivers[v] = nil
				end
				v.nutBagEntity = nil
			end


			local item = nut.item.inventories[index]
			if (item) then
				nut.item.inventories[index] = nil

				nut.db.query("DELETE FROM nut_items WHERE _invID = "..index)
				nut.db.query("DELETE FROM nut_inventories WHERE _invID = "..index)

				hook_Run("StorageItemRemoved", self, item)
			end
		end

		self:EmitSound("physics/cardboard/cardboard_box_break"..math_random(1, 3)..".wav")
		local position = self:LocalToWorld(self:OBBCenter())
		local effect = EffectData()
		effect:SetStart(position)
		effect:SetOrigin(position)
		effect:SetScale(3)
		util.Effect("GlassImpact", effect)
	end

	local OPEN_TIME = .5
	function ENT:OpenInv(activator)
		local inventory = self:getInv()

		activator:setAction("@opening", OPEN_TIME)
		activator:doStaredAction(self, function()
			if (activator:GetPos():Distance(self:GetPos()) < 101) then
				self.receivers[activator] = true
				activator.nutBagEntity = self

				inventory:sync(activator)
				function inventory:canAccess(ply)
					return true;
				end
				netstream.Start(activator, "lootOpen", self, inventory:getID())
				self:EmitSound("items/ammocrate_open.wav")
			end
		end, OPEN_TIME, function()
			if (IsValid(activator)) then
				activator:setAction()
			end
		end)
		return
	end

	function ENT:Use(activator)
		local inventory = self:getInv()
		--local inv = nut.item.inventories[self:getNetVar("id")]
		--if inv and #inv:getItems() < 1 then self.timeToDelete = CurTime() return end

		if (inventory and (activator.nutNextOpen or 0) < CurTime()) then
			if (activator:getChar()) then
				self:OpenInv(activator)
			end

			activator.nutNextOpen = CurTime() + OPEN_TIME * 1.5
		end
	end
else
	ENT.DrawEntityInfo = true
	local toScreen = FindMetaTable("Vector").ToScreen
	local colorAlpha = ColorAlpha
	local drawText = nut.util.drawText
	local configGet = nut.config.get

	function ENT:onDrawEntityInfo(alpha)
		local position = toScreen(self.LocalToWorld(self, self.OBBCenter(self)))
		local x, y = position.x, position.y
		local tx, ty = drawText(self:getNetVar("plyName").."'s Belongings", x, y, colorAlpha(configGet("color"), alpha), 1, 1, nil, alpha * 0.65)
	end
end

function ENT:getStorageInfo()
	return {
		name = "Prueba",
		desc = "A container for junk.",
		invType = 'grid',
		invData = self:getInv().data
	}
end

function ENT:getInv()
	return nut.item.inventories[self:getNetVar("id", 0)]
end
