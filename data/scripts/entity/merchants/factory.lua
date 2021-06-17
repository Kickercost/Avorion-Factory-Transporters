local existingUpdate = Factory.updateServer
local lastRunKey = "FactoryTransporters:lastRunTime"
local lastRunTimeoutKey = "FactoryTransporters:lastRunTimeout"
local debugMessagesOnKey = "FactoryTransporters:debugMessagesOn"

local existingFetchShuttles = Factory.updateFetchingShuttleStarts
local existingInitialize = Factory.initialize
local currentMaxStock = Factory.getMaxGoods

local stationsInRange = {}



function Factory.updateFetchingShuttleStarts(timestep)
    --local stationFaction = Faction()
    local self = Entity()
    local sector = Sector()
    --if stationFaction.isPlayer then
        for k, v in pairs(stationsInRange) do
            local trades = Factory.trader.deliveringStations[v.id.string]
            if (trades) then
                for k, tradeGood in pairs(trades) do
                    local station = sector:getEntity(v.id)
                    local result, availableStockAmount, availableMaxAmount = station:invokeFunction(tradeGood.script, "getStock", tradeGood.good)
                    print("Execution result : " .. result)
                    local thisStockAmount, thisStockMaxAmount = Factory.getStock(tradeGood.good)
                    local good = goods[tradeGood.good]:good()

                    print( self.name .. " has freeCargoSpace of '" .. self.freeCargoSpace .. "' the size of the good("..  tradeGood.good ..") is '" .. good.size .. "' current stock:'" .. thisStockAmount .. "' max stock capacity:'" .. thisStockMaxAmount .. "' available station(" .. station.name .. ") stock:'" .. availableStockAmount .. "'")
                    if (self.freeCargoSpace < good.size or thisStockAmount >= thisStockMaxAmount or availableStockAmount < 1) then
                        goto continue
                    end
                    local amountToGet = math.min(availableStockAmount, thisStockMaxAmount)
                    print("attempting to aquire " .. amountToGet .. "from station: " .. station.name)
                    station:invokeFunction(tradeGood.script, "sellGoods", good, amountToGet, self.factionIndex)
                    self:addCargo(good, amountToGet)
                    --local callResult = station:invokeFunction(tradeGood.script, "removeCargo", good, amountToGet)
                    --if (callResult == 0) then
                    --station:removeCargo(good, amountToGet)
                    --Factory:addCargo(good, amountToGet)
                    --    --Factory:increaseGoods(good, amountToGet)
                    --else
                    --    print("error attempting to decrease goods on station")
                    --end
                    :: continue ::
                end

            end
        end
    --end
    existingFetchShuttles(timestep)
end

function Factory.initialize()
    local self = Entity()
    if (self:getValue(lastRunTimeoutKey) == nil) then
        self:setValue(lastRunTimeoutKey, 5)
    end

    if (self:getValue(debugMessagesOnKey) == nil) then
        self:setValue(debugMessagesOnKey, "false")
    end
    existingInitialize()
end

function Factory.updateServer(timestep)
    --local stationFaction = Faction()
    --if stationFaction.isPlayer then
        local sector = Sector()
        local self = Entity()
        local runTimeout = self:getValue(lastRunTimeoutKey)
        local updateTime = os.time()
        if (self:getValue(lastRunKey) == nil or os.difftime(updateTime, self:getValue(lastRunKey)) > runTimeout) then
            local stations = { sector:getEntitiesByType(EntityType.Station) }
            self:setValue(lastRunKey, updateTime)

            local updatedStationsInRange = {}
            for i, station in ipairs(stations) do
                local output = "nothing docked"
                if (self:isInDockingArea(station)) then
                    output = "Self: '" .. self.name .. "' has Station:'" .. station.name .. "' registered as docked"
                    table.insert(updatedStationsInRange, station)
                end
                if (self:getValue(debugMessagesOnKey) == "true") then
                    print(output)
                end
            end
            stationsInRange = updatedStationsInRange;
        end

    --end

    existingUpdate(timestep)
end

