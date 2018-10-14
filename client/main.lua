-- Local
local Keys = {
  ["ESC"] = 322, ["F1"] = 288, ["F2"] = 289, ["F3"] = 170, ["F5"] = 166, ["F6"] = 167, ["F7"] = 168, ["F8"] = 169, ["F9"] = 56, ["F10"] = 57,
  ["~"] = 243, ["1"] = 157, ["2"] = 158, ["3"] = 160, ["4"] = 164, ["5"] = 165, ["6"] = 159, ["7"] = 161, ["8"] = 162, ["9"] = 163, ["-"] = 84, ["="] = 83, ["BACKSPACE"] = 177,
  ["TAB"] = 37, ["Q"] = 44, ["W"] = 32, ["E"] = 38, ["R"] = 45, ["T"] = 245, ["Y"] = 246, ["U"] = 303, ["P"] = 199, ["["] = 39, ["]"] = 40, ["ENTER"] = 18,
  ["CAPS"] = 137, ["A"] = 34, ["S"] = 8, ["D"] = 9, ["F"] = 23, ["G"] = 47, ["H"] = 74, ["K"] = 311, ["L"] = 182,
  ["LEFTSHIFT"] = 21, ["Z"] = 20, ["X"] = 73, ["C"] = 26, ["V"] = 0, ["B"] = 29, ["N"] = 249, ["M"] = 244, [","] = 82, ["."] = 81,
  ["LEFTCTRL"] = 36, ["LEFTALT"] = 19, ["SPACE"] = 22, ["RIGHTCTRL"] = 70,
  ["HOME"] = 213, ["PAGEUP"] = 10, ["PAGEDOWN"] = 11, ["DELETE"] = 178,
  ["LEFT"] = 174, ["RIGHT"] = 175, ["TOP"] = 27, ["DOWN"] = 173,
  ["NENTER"] = 201, ["N4"] = 108, ["N5"] = 60, ["N6"] = 107, ["N+"] = 96, ["N-"] = 97, ["N7"] = 117, ["N8"] = 61, ["N9"] = 118
}

ESX = nil

local lastLocation = nil
local meterOwner = false
local configOpen = false
local configOpenFirstTime = false
local playersInVehicle = {}
local firstConfigOpenInVehicle = false
local currentJob = 'unemployed'

local meterAttrs = {
  meterVisible = false,
  rateType = 'distance',
  rateAmount = nil,
  currencyPrefix = Config.CurrencyPrefix,
  rateSuffix = Config.RateSuffix,
  currentFare = 0,
  distanceTraveled = 0
}

--[[
  Setup of ESX
]]
Citizen.CreateThread(function()
  while ESX == nil do
    TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
    Citizen.Wait(0)
  end
end)

--[[
  Recalcuation of amount and distribution to vehicles passengers
]]
Citizen.CreateThread(function()
  while true do
    calculateFareAmount()

    if meterOwner then
      updatePassengerMeters()
    end

    Citizen.Wait(2000)
  end
end)


Citizen.CreateThread(function()
  while true do
    if not IsPedInAnyVehicle(GetPlayerPed(-1), true) then
      meterAttrs['meterVisible'] = false
      firstConfigOpenInVehicle = false
    end

    updateMeter()
    Citizen.Wait(0)
  end
end)

Citizen.CreateThread(function()
  while true do
    Citizen.Wait(0)
    local ped = GetPlayerPed(-1)

    if IsPedSittingInAnyVehicle(ped) and IsDriver() and IsAppropriateVehicle() and hasMeterAppropriateJob() then
      meterOwner = true

      if IsControlPressed(0, Keys['LEFTCTRL']) and IsControlPressed(0, Keys['G']) then
        if not configOpen then
          showConfig()
          configOpen = true
        end

        -- Rest rate amount when getting in a new vehicle
        if not firstConfigOpenInVehicle then
          meterAttrs = {
            meterVisible = false,
            rateType = 'distance',
            rateAmount = nil,
            currencyPrefix = Config.CurrencyPrefix,
            rateSuffix = Config.RateSuffix,
            currentFare = 0,
            distanceTraveled = 0
          }
          firstConfigOpenInVehicle = true
        end
      end
    end
  end
end)

RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(xPlayer)
  currentJob = ESX.GetPlayerData().job.name
end)

RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(xPlayer)
  currentJob = ESX.GetPlayerData().job.name
end)

RegisterNetEvent("esx_taximeter:updatePassenger")
AddEventHandler("esx_taximeter:updatePassenger", function(attributes)
  meterAttrs = attributes
  meterOwner = false
  updateMeter()
end)

RegisterNetEvent("esx_taximeter:updateLocation")
AddEventHandler("esx_taximeter:updateLocation", function()
  lastLocation = GetEntityCoords(GetPlayerPed(-1))
end)



RegisterNetEvent("esx_taximeter:resetMeter")
AddEventHandler("esx_taximeter:resetMeter", function()
  resetMeter()
  updateMeter()
end)


RegisterNUICallback('closeConfig', function()
  SetNuiFocus(false, false)
  SendNUIMessage({type = 'hide_config'})
  configOpen = false
end)

RegisterNUICallback('setRate', function()
  SetNuiFocus(false, false)
  SendNUIMessage({type = 'hide_config'})
  MeterSetRate()
end)

RegisterNUICallback('resetFare', function()
  resetMeter()
end)

RegisterNUICallback('updateAttrs', function(attrs)
  for k,v in pairs(attrs) do
    if k == 'meterVisible' then
      setMeterVisiblity()
    else
      if k == 'rateType' then
        meterAttrs[k] = v
        resetMeter()
      else
        meterAttrs[k] = v
      end
    end
  end

  playersInVehicle = {}
end)

--[[
  Determines if the user is in an allowed vehicle

  Returns
    boolean
]]
function IsAppropriateVehicle()
  local vehicle = GetVehiclePedIsIn(GetPlayerPed(-1))
  local vehicleClass = GetVehicleClass(vehicle)

  if Config.RestrictVehicles then
    if not has_value(Config.DisallowedVehicleClasses, vehicleClass) then
      return true
    else
      return false
    end
  else
    return true
  end
end

--[[
  Determines if the player has a job that allows access to the taxi meter

  Returns
  boolean
]]
function hasMeterAppropriateJob()
  if not Config.RestrictToCertainESXJobs then
    return true
  end

  if has_value(Config.JobsThatCanUseMeter, currentJob) then
    return true
  else
    return false
  end
end

--[[
  Sends the drivers attributes to all passengers in the vehicle to sync up
  their meter with that of the drivers
]]
function updatePassengerMeters()
  players = GetPlayersInVehicle()

  for index,player in ipairs(players) do
    local playerId = GetPlayerServerId(player)

    if not has_value(playersInVehicle, playerId) then
      TriggerServerEvent('esx_taximeter:updatePassengerMeters', playerId, meterAttrs)
      table.insert(playersInVehicle, playerId)
    end
  end

end

--[[
  Gets all players that are in the vehicle with the meter owner

  Returns
    Table
]]
function GetPlayersInVehicle()
  local players = GetPlayers()
  local ply = GetPlayerPed(-1)
  local returnablePlayers = {}
  local playerVehicle = GetVehiclePedIsIn(ply)

  for index,value in ipairs(players) do
    local target = GetPlayerPed(value)

    if(target ~= ply) then
      local vehicle = GetVehiclePedIsIn(target)

      if playerVehicle == vehicle then
        table.insert(returnablePlayers, value)
      end
    end
  end

  return returnablePlayers
end

--[[
  Resets the distance and the fare amount for the meter
]]
function resetMeter()
  meterAttrs['currentFare'] = nil
  lastLocation = GetEntityCoords(GetPlayerPed(-1))
  meterAttrs['distanceTraveled'] = 0

  for i, player in ipairs(playersInVehicle) do
    TriggerServerEvent('esx_taximeter:resetPassengerMeters', player)
  end
end

function updatePassengerLocations()
  for i, player in ipairs(playersInVehicle) do
    TriggerServerEvent('esx_taximeter:updatePassengerLocation', player)
  end
end

--[[
  Method for displaying the enter rate dialog
]]
function MeterSetRate()
  Citizen.CreateThread(function()
    DisplayOnscreenKeyboard(false, "", "", "", "", "", "", 8)

    while true do
      if (UpdateOnscreenKeyboard() == 1) then
        local rate = GetOnscreenKeyboardResult()

        if (string.len(rate) > 0) then
            local rate = tonumber(rate)

            if (rate < 99999 and rate > 1) then
              meterAttrs['rateAmount'] = rate
              meterAttrs['currentFare'] = 0
              playersInVehicle = {}
              showConfig()
            end

            break
          else
            DisplayOnscreenKeyboard(false, "", "", "", "", "", "", 8)
          end
      elseif (UpdateOnscreenKeyboard() == 2) then
        break
      end

      Citizen.Wait(0)
    end
  end)
end

--[[
  Sets the meters current visbility state
  Toggling the meter on or off resets the amount
]]
function setMeterVisiblity()
  if meterAttrs['meterVisible'] then
    meterAttrs['meterVisible'] = false
  else
    meterAttrs['meterVisible'] = true
    lastLocation = GetEntityCoords(GetPlayerPed(-1))
    updatePassengerLocations()
  end
end

--[[
  Shows the NUI configuration page to the user
]]
function showConfig()
  SetNuiFocus(true, true)
  SendNUIMessage({type = 'show_config'})
end

--[[
  Sends an update ping to display script
]]
function updateMeter()
  SendNUIMessage({type = 'update_meter', attributes = meterAttrs})
end

--[[
  Determines if the ped is the driver of the vehicle

  Returns
    boolean
]]
function IsDriver ()
  return GetPedInVehicleSeat(GetVehiclePedIsIn(GetPlayerPed(-1), false), -1) == GetPlayerPed(-1)
end

--[[
  Calculates the fare amount and updates the meter
]]
function calculateFareAmount()
  if (meterAttrs['meterVisible']) and (meterAttrs['rateType'] == 'distance') and not (meterAttrs['rateAmount'] == nil)  then
    start = lastLocation

    if start then
      current = GetEntityCoords(GetPlayerPed(-1))
      distance = CalculateTravelDistanceBetweenPoints(start, current)
      lastLocation = current
      meterAttrs['distanceTraveled'] = meterAttrs['distanceTraveled'] + distance

      if Config.DistanceMeasurement == 'mi' then
        fare_amount = (meterAttrs['distanceTraveled'] / 1609.34) * meterAttrs['rateAmount']
      else
        fare_amount = (meterAttrs['distanceTraveled'] / 1000.00) * meterAttrs['rateAmount']
      end

      meterAttrs['currentFare'] = string.format("%.2f", fare_amount)
    end
  end
end

--[[
  Gets a list of current players on the server

  Returns
    Table
]]
function GetPlayers()
  local players = {}

  for i = 0, 31 do
    if NetworkIsPlayerActive(i) then
      table.insert(players, i)
    end
  end

  return players
end

--[[
  Determines if a table has a value in it

  Params
    tab - Table
    val - value to search

  Returns
    boolean
]]
function has_value (tab, val)
  for index, value in ipairs(tab) do
    if value == val then
        return true
    end
  end

  return false
end
