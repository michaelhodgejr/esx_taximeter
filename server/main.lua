ESX = nil

TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

RegisterServerEvent('esx_taximeter:updatePassengerMeters')
AddEventHandler('esx_taximeter:updatePassengerMeters', function(player, meterAttrs)
  TriggerClientEvent('esx_taximeter:updatePassenger', player, meterAttrs)
end)
