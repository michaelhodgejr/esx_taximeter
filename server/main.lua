ESX = nil

TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

RegisterServerEvent('esx_taximeter:updatePassengerMeters')
AddEventHandler('esx_taximeter:updatePassengerMeters', function(player, meterAttrs)
  TriggerClientEvent('esx_taximeter:updatePassenger', player, meterAttrs)
end)


RegisterServerEvent('esx_taximeter:resetPassengerMeters')
AddEventHandler('esx_taximeter:resetPassengerMeters', function(player)
  TriggerClientEvent('esx_taximeter:resetMeter', player)
end)

RegisterServerEvent('esx_taximeter:updatePassengerLocation')
AddEventHandler('esx_taximeter:updatePassengerLocation', function(player)
  TriggerClientEvent('esx_taximeter:updateLocation', player)
end)
