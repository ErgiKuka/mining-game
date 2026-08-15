-- Server entry point. The only Script on the server; everything else is a
-- ModuleScript started from here, so startup order is explicit and reviewable.
--
-- Order matters: InventoryService owns gear and capacity, and PickaxeService
-- must exist before ShopService can regrant a purchased pickaxe.

local ServerScriptService = game:GetService("ServerScriptService")

local Services = ServerScriptService.Server.Services

local CurrencyService = require(Services.CurrencyService)
local InventoryService = require(Services.InventoryService)
local PlayerService = require(Services.PlayerService)
local PickaxeService = require(Services.PickaxeService)
local ElevatorService = require(Services.ElevatorService)
local TeleportService = require(Services.TeleportService)
local MarketService = require(Services.MarketService)
local ShopService = require(Services.ShopService)
local MiningService = require(Services.MiningService)

CurrencyService.Start()
InventoryService.Start()
PlayerService.Start()
PickaxeService.Start()
ElevatorService.Start()
TeleportService.Start()
MarketService.Start()
ShopService.Start()
MiningService.Start()

print("Server: startup complete.")
