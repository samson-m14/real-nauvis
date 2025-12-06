-- control.lua

local ore_mixing = require("scripts.ore_mixing")
local stone_regions = require("scripts.stone_regions")

script.on_event(defines.events.on_chunk_generated, function(event)
  ore_mixing.on_chunk_generated(event)
  stone_regions.on_chunk_generated(event)
end)
