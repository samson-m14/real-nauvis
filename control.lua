-- control.lua

local MIX_RULES = {
  ["coal"]         = { "stone" },                 -- уголь → камень
  ["stone"]        = { "coal" },                  -- камень → уголь
  ["iron-ore"]     = { "stone" },                 -- железо → камень
  ["titanium-ore"] = { "iron-ore", "stone" },     -- титан → железо + камень
  ["copper-ore"]   = { "lead-ore" },              -- медь → свинец
  ["lead-ore"]     = { "copper-ore" },            -- свинец → медь
  ["tin-ore"]      = { "stone" }                  -- олово → камень
}

-- Радиус вокруг (0,0), где руды не трогаем (хардкод, как ты и хотел)
local SAFE_RADIUS_TILES = 200
local SAFE_RADIUS_SQ = SAFE_RADIUS_TILES * SAFE_RADIUS_TILES

local function distance_sq(p)
  return p.x * p.x + p.y * p.y
end

script.on_event(defines.events.on_chunk_generated, function(event)
  local surface = event.surface
  local area = event.area

  -- читаем настройки (startup — всё равно фиксированы при старте, но так код проще для будущих правок)
  local enabled = settings.startup["rn-ore-mixing-enabled"].value
  local mix_percent = settings.startup["rn-ore-mixing-percent"].value or 0

  if not enabled or mix_percent <= 0 then
    return
  end

  -- центр чанка, чтобы оценить его удалённость от спавна (0,0)
  local center = {
    x = (area.left_top.x + area.right_bottom.x) / 2,
    y = (area.left_top.y + area.right_bottom.y) / 2
  }

  if distance_sq(center) < SAFE_RADIUS_SQ then
    -- Внутри безопасного радиуса патчи не трогаем
    return
  end

  local resources = surface.find_entities_filtered{
    area = area,
    type = "resource"
  }

  if not resources or #resources == 0 then return end

  for _, ore in pairs(resources) do
    local candidates = MIX_RULES[ore.name]
    if candidates and #candidates > 0 then
      if math.random(100) <= mix_percent then
        local new_name = candidates[math.random(#candidates)]
        surface.create_entity{
          name = new_name,
          position = ore.position,
          amount = ore.amount,
          force = "neutral",
          raise_built = false
        }
        ore.destroy{ raise_destroy = false }
      end
    end
  end
end)
