-- Server entry point. The only Script on the server; everything else is a
-- ModuleScript started from here, so startup order is explicit and reviewable.
--
-- Order is load-bearing:
--   CargoService has no dependencies and must exist before DataService, which
--   asks it whether to apply a logout penalty.
--   DataService owns every profile; currency and inventory read through it, so
--   it starts before both.
--   PickaxeService must exist before ShopService can regrant a purchase.

local ServerScriptService = game:GetService("ServerScriptService")

local Services = ServerScriptService.Server.Services

local CargoService = require(Services.CargoService)
local DataService = require(Services.DataService)
local CurrencyService = require(Services.CurrencyService)
local InventoryService = require(Services.InventoryService)
local PlayerService = require(Services.PlayerService)
local PickaxeService = require(Services.PickaxeService)
local ElevatorService = require(Services.ElevatorService)
local TeleportService = require(Services.TeleportService)
local MarketService = require(Services.MarketService)
local ShopService = require(Services.ShopService)
local MiningService = require(Services.MiningService)
local HazardService = require(Services.HazardService)

CargoService.Start()
DataService.Start()
CurrencyService.Start()
InventoryService.Start()
PlayerService.Start()
PickaxeService.Start()
ElevatorService.Start()
TeleportService.Start()
MarketService.Start()
ShopService.Start()
MiningService.Start()
HazardService.Start()

print("Server: startup complete.")
