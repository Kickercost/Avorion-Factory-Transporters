function Factory.updateFetchingFromDockedStations(timeStep)
    local sector = Sector()
    local self = Entity()

    local ids = {}
    for id, trades in pairs(Factory.trader.deliveringStations) do
        if #trades > 0 then
            table.insert(ids, id)
        end
    end

    shuffle(random(), ids)

    for index, id in pairs(ids) do
        local trades = Factory.trader.deliveringStations[id]
        local trade = randomEntry(random(), trades)

        local station = Sector():getEntity(id)
        if not station then goto continue end

        if station.dockingParent ~= self.id and self.dockingParent ~= station.id and not self:isInDockingArea(station) then
            goto continue
        end

        local errorCode, amount, maxAmount = station:invokeFunction(trade.script, "getStock", trade.good)
        if errorCode ~= 0 then
            newDeliveringStationsErrors[index] = "Error with partner station!"%_T
            print ("error requesting goods from other station: " .. errorCode .. " " .. station.title)
            goto continue
        end

        if amount == 0 then
            newDeliveringStationsErrors[index] = "No more goods on partner station!"%_T
            goto continue
        end

        local amount, maxAmount = Factory.getStock(trade.good)
        if amount >= maxAmount then
            newDeliveringStationsErrors[index] = "Station at full capacity!"%_T
            goto continue
        end

        local good = goods[trade.good]:good()
        if not good then return end

        if self.freeCargoSpace < good.size then
            newDeliveringStationsErrors[index] = "Station at full capacity!"%_T
            goto continue
        end

        local amount = math.max(1, math.floor(10 / good.size))

        local error1, error2 = station:invokeFunction(trade.script, "sellGoods", good, amount, self.factionIndex)
        if error1 ~= 0 then
            newDeliveringStationsErrors[index] = "Error with partner station!"%_T
            goto continue
        end

        if error2 ~= 0 then
            newDeliveringStationsErrors[index] = Factory.getSellGoodsErrorMessage(error2)
            goto continue
        end

        self:addCargo(good, amount)

        break
        ::continue::
    end
end

function Factory.updateDeliveryToDockedStations(timeStep)
    local ids = {}
    for id, trades in pairs(Factory.trader.deliveredStations) do
        if #trades > 0 then
            table.insert(ids, id)
        end
    end

    local sector = Sector()
    local self = Entity()

    shuffle(random(), ids)

    for index, id in pairs(ids) do
        local trades = Factory.trader.deliveredStations[id]
        local trade = randomEntry(random(), trades)

        local station = sector:getEntity(id)
        if not station then
            newDeliveredStationsErrors[index] = "Error with partner station!"%_T
            goto continue
        end

        if station.dockingParent ~= self.id and self.dockingParent ~= station.id and not self:isInDockingArea(station) then
            goto continue
        end

        local amount = self:getCargoAmount(trade.good)
        if amount == 0 then
            newDeliveredStationsErrors[index] = "No more goods!"%_T
            goto continue
        end

        local good = Factory.getSoldGoodByName(trade.good)
        if not good then
            newDeliveredStationsErrors[index] = "Partner station doesn't buy this!"%_T
            goto continue
        end

        local amount = math.max(1, math.floor(10 / good.size))

        -- do the transaction
        local errorCode1, errorCode2 = station:invokeFunction(trade.script, "buyGoods", good, amount, self.factionIndex, true)
        if errorCode1 ~= 0 then
            newDeliveredStationsErrors[index] = "Error with partner station!"%_T
            goto continue
        end

        if errorCode2 ~= 0 then
            newDeliveredStationsErrors[index] = Factory.getBuyGoodsErrorMessage(errorCode2)
            goto continue
        end

        station:addCargo(good, amount)

        Factory.decreaseGoods(trade.good, amount)

        break
        ::continue::
    end
end

function Factory.updateFetchingShuttleStarts(timeStep)
    if tablelength(deliveryShuttles) >= 20 then return end

    local sector = Sector()
    local self = Entity()
    local controller = FighterController()

    local ids = {}
    for id, trades in pairs(Factory.trader.deliveringStations) do
        if #trades > 0 then
            table.insert(ids, id)
        end
    end

    shuffle(random(), ids)

    for index, id in pairs(ids) do
        local trades = Factory.trader.deliveringStations[id]
        local trade = randomEntry(random(), trades)

        local station = Sector():getEntity(id)
        if not station then goto continue end

        -- if docked, no need to send shuttles
        if station.dockingParent == self.id or self.dockingParent == station.id or self:isInDockingArea(station) then
            goto continue
        end

        -- make sure that a fighter of the type we want can actually start exists
        local errorCode = controller:getFighterTypeStartError(FighterType.CargoShuttle)
        if errorCode then
            newDeliveringStationsErrors[index] = Factory.getFighterStartErrorMessage(errorCode)
            goto continue
        end

        local errorCode, amount, maxAmount = station:invokeFunction(trade.script, "getStock", trade.good)
        if errorCode ~= 0 then
            newDeliveringStationsErrors[index] = "Error with partner station!"%_T
            print ("error requesting goods from other station: " .. errorCode .. " " .. station.title)
            goto continue
        end

        if amount == 0 then
            newDeliveringStationsErrors[index] = "No more goods on partner station!"%_T
            goto continue
        end

        local amount, maxAmount = Factory.getStock(trade.good)
        if amount >= maxAmount then
            newDeliveringStationsErrors[index] = "Station at full capacity!"%_T
            goto continue
        end

        local good = goods[trade.good]:good()
        if not good then return end

        if self.freeCargoSpace < good.size then
            newDeliveringStationsErrors[index] = "Station at full capacity!"%_T
            goto continue
        end

        if Sector().numPlayers > 0 then
            -- start a shuttle
            local shuttle, errorCode = controller:startFighterOfType(FighterType.CargoShuttle)
            if not shuttle then
                newDeliveringStationsErrors[index] = Factory.getFighterStartErrorMessage(errorCode)
                goto continue
            end

            -- assign cargo
            local ai = FighterAI(shuttle.id)
            ai.ignoreMothershipOrders = true
            ai.clearFeedbackEachTick = false
            ai:setOrders(FighterOrders.FlyToLocation, station.id)

            shuttle:setValue("cargo_requested", trade.good)
            shuttle:setValue("cargo_giver", station.id.string)
            shuttle:setValue("cargo_giver_script", trade.script)

            deliveryShuttles[shuttle.id] = shuttle
        else
            local nextShuttle = controller:getFighterStatsOfType(FighterType.CargoShuttle)
            local amount = math.max(1, math.floor(nextShuttle.volume / good.size))

            local error1, error2 = station:invokeFunction(trade.script, "sellGoods", good, amount, self.factionIndex)
            if error1 ~= 0 then
                newDeliveringStationsErrors[index] = "Error with partner station!"%_T
                goto continue
            end

            if error2 ~= 0 then
                newDeliveringStationsErrors[index] = Factory.getSellGoodsErrorMessage(error2)
                goto continue
            end

            self:addCargo(good, amount)
        end

        if true then return end -- lua grammar doesn't allow statements in a block after a 'return'
        ::continue::

    end

end

function Factory.updateDeliveryShuttleStarts(timeStep)
    if tablelength(deliveryShuttles) >= 20 then return end

    local sector = Sector()
    local self = Entity()
    local controller = FighterController()

    local ids = {}
    for id, trades in pairs(Factory.trader.deliveredStations) do
        if #trades > 0 then
            table.insert(ids, id)
        end
    end

    shuffle(random(), ids)

    for index, id in pairs(ids) do
        local trades = Factory.trader.deliveredStations[id]
        local trade = randomEntry(random(), trades)

        local station = sector:getEntity(id)
        if not station then
            newDeliveredStationsErrors[index] = "Error with partner station!"%_T
            goto continue
        end

        -- if docked, no need to send shuttles
        if station.dockingParent == self.id or self.dockingParent == station.id or self:isInDockingArea(station) then
            goto continue
        end

        -- make sure that a fighter of the type we want can actually start
        local errorCode = controller:getFighterTypeStartError(FighterType.CargoShuttle)
        if errorCode then
            newDeliveredStationsErrors[index] = Factory.getFighterStartErrorMessage(errorCode)
            goto continue
        end

        local amount = self:getCargoAmount(trade.good)
        if amount == 0 then
            newDeliveredStationsErrors[index] = "No more goods!"%_T
            goto continue
        end

        local good = Factory.getSoldGoodByName(trade.good)
        if not good then
            newDeliveredStationsErrors[index] = "Partner station doesn't buy this!"%_T
            goto continue
        end

        local nextShuttle = controller:getFighterStatsOfType(FighterType.CargoShuttle)
        local amount = math.max(1, math.floor(nextShuttle.volume / good.size))

        -- do the transaction, use 1 good
        local errorCode1, errorCode2 = station:invokeFunction(trade.script, "buyGoods", good, amount, self.factionIndex, true)
        if errorCode1 ~= 0 then
            newDeliveredStationsErrors[index] = "Error with partner station!"%_T
            goto continue
        end

        if errorCode2 ~= 0 then
            newDeliveredStationsErrors[index] = Factory.getBuyGoodsErrorMessage(errorCode2)
            goto continue
        end

        if sector.numPlayers > 0 then
            -- start a shuttle
            local shuttle, errorCode = controller:startFighterOfType(FighterType.CargoShuttle)
            if not shuttle then
                newDeliveredStationsErrors[index] = Factory.getFighterStartErrorMessage(errorCode)
                print ("FATAL error starting fighter: " .. errorCode)
                goto continue
            end

            -- assign cargo
            local ai = FighterAI(shuttle.id)
            ai.ignoreMothershipOrders = true
            ai.clearFeedbackEachTick = false
            ai:setOrders(FighterOrders.FlyToLocation, station.id)

            shuttle:setValue("cargo_recipient", station.id.string)
            shuttle:setValue("cargo_recipient_script", trade.script)

            shuttle:addCargo(good, amount)
            deliveryShuttles[shuttle.id] = shuttle
        else
            station:addCargo(good, amount)
        end

        Factory.decreaseGoods(trade.good, amount)

        if true then return end -- lua grammar doesn't allow statements in a block after a 'return'
        ::continue::
    end

end