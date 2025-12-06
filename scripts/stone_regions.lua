-- scripts/stone_regions.lua
-- Генерация "каменных регионов" (КАМИДО):
--   - выбираем редкие крупные регионы по шуму
--   - внутри региона, для каждого чанка, спавним кучки больших камней
--   - вокруг куч — мелкие/средние камни как "фон"

local M = {}

-- ==== НАСТРОЙКИ / КОНСТАНТЫ ==================================================

-- Имя глобальной настройки, которая управляет включением/выключением КАМИДО.
local STONE_REGIONS_ENABLED_SETTING = "rn-stone-regions-enabled"

-- Все параметры региона собраны в одну структуру.
local REGION = {
  -- Радиус одного каменного региона (тайлы). Определяет размер "пятна" на карте.
  radius = 80,

  -- Шаг сетки центров регионов (расстояние между потенциальными центрами).
  cell_size = 300,

  -- Шанс того, что в ячейке сетки вообще будет каменный регион.
  chance = 0.6,

  -- Радиус безопасной зоны вокруг (0, 0), где регионы не генерируются.
  safe_radius = 300
}

local REGION_SAFE_RADIUS_SQ = REGION.safe_radius * REGION.safe_radius

-- Параметры больших камней (скал) внутри региона.
local BIG_ROCKS = {
  -- Сколько "куч" больших камней пробуем сделать в одном чанке.
  clusters_per_chunk = 10,

  -- Диапазон количества камней в одной куче.
  min_per_cluster = 3,
  max_per_cluster = 6,

  -- Радиус кучи (внутри этого радиуса вокруг центра мы пытаемся ставить камни).
  radius = 3.0,

  -- Сколько попыток делаем, чтобы найти валидное место для ОДНОГО камня.
  spawn_attempts = 6,
}

-- Параметры мелких/средних камней, которые заполняют пространство вокруг кучи.
local SMALL_ROCKS = {
  -- Радиус "ореола" мелких камней вокруг центра кучи.
  radius = 3.5,

  -- Диапазон количества мелких камней на одну кучку.
  min_per_cluster = 35,
  max_per_cluster = 65,
}

-- Порог влажности: ниже = сухо/песок, выше = обычная земля
local MOISTURE_SAND_THRESHOLD = 0.3
local MOISTURE_PROPERTY_NAME = "moisture"

-- Крупные скалы
local BIG_ROCK_TYPES_NORMAL = {
  "big-rock",
  "huge-rock",
}

local BIG_ROCK_TYPES_SAND = {
  "big-sand-rock",
}

-- Декоративные камешки (medium/small)
local SMALL_DECOR_TYPES_NORMAL = {
  "medium-rock",
  "small-rock",
}

local SMALL_DECOR_TYPES_SAND = {
  "medium-sand-rock",
  "small-sand-rock",
}

local BACKGROUND_DECOR = {
  attempts_per_chunk = 100,   -- сколько проб за чанк
  spawn_chance       = 0.4, -- шанс, что попытка действительно заспавнит камень
}

-- ==== ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ===============================================

-- Детеминированный "рандом" по координатам ячейки и сиду карты.
local function rand01_from_cell(cx, cy, seed)
  local n = math.sin(cx * 12.9898 + cy * 78.233 + seed * 0.0001)
  return n - math.floor(n)
end

-- Проверяем, суша ли в этой точке (не вода).
local function is_land_tile(surface, pos)
  local tile = surface.get_tile(pos.x, pos.y)
  -- В Factorio 2.0 слой воды называется "water_tile"
  return tile and not tile.collides_with("water_tile")
end

local function get_moisture(surface, position)
  -- calculate_tile_properties ждёт список имён и список позиций
  local props = surface.calculate_tile_properties(
    { MOISTURE_PROPERTY_NAME },
    { position }
  )

  if not props then return nil end
  local arr = props[MOISTURE_PROPERTY_NAME]
  if not arr or #arr == 0 then return nil end

  return arr[1]
end

local function choose_rock_sets(surface, position)
  local m = get_moisture(surface, position)
  if m and m < MOISTURE_SAND_THRESHOLD then
    -- сухо → песчаные камни
    return BIG_ROCK_TYPES_SAND, SMALL_DECOR_TYPES_SAND
  else
    -- нормальная влажность → обычные
    return BIG_ROCK_TYPES_NORMAL, SMALL_DECOR_TYPES_NORMAL
  end
end

-- Проверяем, включены ли каменные регионы настройкой.
local function stone_regions_enabled()
  local s = settings.startup
  if not s then return true end

  local setting = s[STONE_REGIONS_ENABLED_SETTING]
  if not setting then
    return true
  end

  return setting.value
end

-- Проверяем, попадает ли точка (x, y) в каменный регион КАМИДО.
local function is_in_stone_region(surface, x, y)
  local cell_size = REGION.cell_size
  local radius    = REGION.radius
  local radius_sq = radius * radius

  local seed = 0
  local mgs = surface.map_gen_settings
  if mgs and mgs.seed then
    seed = mgs.seed
  end

  -- В какую "крупную ячейку" попадает точка
  local base_cx = math.floor(x / cell_size)
  local base_cy = math.floor(y / cell_size)

  -- Смотрим эту и соседние ячейки, чтобы не пропускать регионы по границе.
  for dx = -1, 1 do
    for dy = -1, 1 do
      local cx = base_cx + dx
      local cy = base_cy + dy

      -- Детеминированно решаем, будет ли в этой ячейке вообще регион.
      local r = rand01_from_cell(cx, cy, seed)
      if r < REGION.chance then
        -- Центр региона в центре ячейки (джиттер можно добавить позже).
        local center_x = (cx + 0.5) * cell_size
        local center_y = (cy + 0.5) * cell_size

        local ddx = x - center_x
        local ddy = y - center_y

        if (ddx * ddx + ddy * ddy) <= radius_sq then
          return true
        end
      end
    end
  end

  return false
end

local function spawn_background_decoratives(surface, area)
  local decoratives = {}
  local width  = area.right_bottom.x - area.left_top.x
  local height = area.right_bottom.y - area.left_top.y

  for i = 1, BACKGROUND_DECOR.attempts_per_chunk do
    if math.random() < BACKGROUND_DECOR.spawn_chance then
      local pos = {
        x = area.left_top.x + math.random() * width,
        y = area.left_top.y + math.random() * height
      }

      if is_land_tile(surface, pos) then
        local _, small_decor_types = choose_rock_sets(surface, pos)

        decoratives[#decoratives + 1] = {
          name     = small_decor_types[math.random(#small_decor_types)],
          position = pos,
          amount   = 1
        }
      end
    end
  end

  if #decoratives > 0 then
    surface.create_decoratives{
      check_collision = false,
      decoratives     = decoratives
    }
  end
end


-- ==== МЕЛКИЕ КАМНИ ВОКРУГ КУЧИ ==============================================

local function spawn_small_decoratives(surface, center_pos, decor_types)
  -- decor_types передаём снаружи (обычные или песчаные)
  decor_types = decor_types or SMALL_DECOR_TYPES_NORMAL

  local min_count  = SMALL_ROCKS.min_per_cluster
  local max_count  = SMALL_ROCKS.max_per_cluster
  local radius_max = SMALL_ROCKS.radius

  local count = math.random(min_count, max_count)
  local decoratives = {}

  for i = 1, count do
    local angle = math.random() * 2 * math.pi

    -- больше точек ближе к внешней части, но без “кольца”
    local u = math.random()
    local radius = math.sqrt(u) * radius_max

    local pos = {
      x = center_pos.x + math.cos(angle) * radius,
      y = center_pos.y + math.sin(angle) * radius
    }

    if is_land_tile(surface, pos) then
      decoratives[#decoratives + 1] = {
        name     = decor_types[math.random(#decor_types)],
        position = pos,
        amount   = 1
      }
    end
  end

  if #decoratives > 0 then
    surface.create_decoratives{
      check_collision = false,
      decoratives     = decoratives
    }
  end
end

-- ==== БОЛЬШИЕ КАМНИ-КУЧИ ====================================================

local function spawn_rock_cluster(surface, center_pos)
  -- выбираем, песчаные или обычные наборы
  local big_types, small_decor_types = choose_rock_sets(surface, center_pos)

  local rocks_in_cluster = math.random(
    BIG_ROCKS.min_per_cluster,
    BIG_ROCKS.max_per_cluster
  )

  for i = 1, rocks_in_cluster do
    local angle = math.random() * 2 * math.pi
    local radius = math.random() * BIG_ROCKS.radius

    local pos = {
      x = center_pos.x + math.cos(angle) * radius,
      y = center_pos.y + math.sin(angle) * radius
    }

    if is_land_tile(surface, pos) then
      local rock_name = big_types[math.random(#big_types)]

      if surface.can_place_entity{ name = rock_name, position = pos } then
        surface.create_entity{
          name = rock_name,
          position = pos,
          force = "neutral"
        }
      end
    end
  end

  -- декоративка вокруг кучи (уже с правильным набором типов)
  spawn_small_decoratives(surface, center_pos, small_decor_types)
end


-- ==== ОБРАБОТЧИК ГЕНЕРАЦИИ ЧАНКА ============================================

function M.on_chunk_generated(event)
  local surface = event.surface
  local area    = event.area

  -- 0) Глобальный рубильник "вкл/выкл" каменных регионов.
  if not stone_regions_enabled() then
    return
  end

  -- Центр чанка.
  local center = {
    x = (area.left_top.x + area.right_bottom.x) / 2,
    y = (area.left_top.y + area.right_bottom.y) / 2
  }

  -- 1) Безопасная зона вокруг спавна.
  local dist_sq = center.x * center.x + center.y * center.y
  if dist_sq < REGION_SAFE_RADIUS_SQ then
    return
  end

  -- 2) Проверяем, входит ли чанк в каменный регион.
  if not is_in_stone_region(surface, center.x, center.y) then
    return
  end

  -- 3) Чанк внутри региона: создаём несколько "островков" камней.
  for i = 1, BIG_ROCKS.clusters_per_chunk do
    local x = area.left_top.x + math.random(0, 31) + 0.5
    local y = area.left_top.y + math.random(0, 31) + 0.5
    local pos = { x = x, y = y }

    if is_land_tile(surface, pos) then
      spawn_rock_cluster(surface, pos)
    end
  end
  spawn_background_decoratives(surface, area)
end

return M
