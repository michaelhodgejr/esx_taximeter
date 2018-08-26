Config = {}

-- The currency prefix to be used
Config.CurrencyPrefix = '$'

-- Enables or disables ESX job restriction
Config.RestrictToCertainESXJobs = true

-- Determines which ESX jobs are able to use the meter (if RestrictToCertainESXJobs is true)
Config.JobsThatCanUseMeter = {'taxi'}

-- Enables or Disables the vehicle restriction
Config.RestrictVehicles = true

-- Distance Measurement -- valid options are "mi" or "km". "mi" is default. If you
-- change this be sure to change RateSuffix as well
Config.DistanceMeasurement = 'mi'

-- Rate Suffix
Config.RateSuffix = '/mi'

-- Which vehicles can not use the meter (if RestrictVehicles= true). By default
-- Bicycles, OffRoad and Emergency vehicles are disallowed
Config.DisallowedVehicleClasses = {8, 9, 18}
