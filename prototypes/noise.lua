-- prototypes/noise.lua

-- Базовый уровень влажности в центре (y ~ 0)
local MOISTURE_BASE = 0.5

-- Наклон градиента по оси Y:
-- выражение: MOISTURE_BASE - y * MOISTURE_GRADIENT
-- 0.000225 даёт коридор примерно ~4000 тайлов
local MOISTURE_GRADIENT = 0.000225

-- Параметры шума влажности
local MOISTURE_NOISE_PERSISTENCE  = 0.7
local MOISTURE_NOISE_OCTAVES      = 3
local MOISTURE_NOISE_INPUT_SCALE  = 1 / 512
local MOISTURE_NOISE_OUTPUT_SCALE = 0.08

-- Ограничения итоговой влажности (5% на юге, 95% на севере)
local MOISTURE_MIN = 0.05
local MOISTURE_MAX = 0.95

data:extend({
  {
    type = "noise-expression",
    name = "climate-zone-moisture",
    expression =
      "clamp(" ..
        MOISTURE_BASE .. " - y * " .. MOISTURE_GRADIENT ..
        " + multioctave_noise{" ..
          "x = x, y = y," ..
          " persistence = " .. MOISTURE_NOISE_PERSISTENCE .. "," ..
          " seed0 = map_seed, seed1 = 0," ..
          " octaves = " .. MOISTURE_NOISE_OCTAVES .. "," ..
          " input_scale = " .. MOISTURE_NOISE_INPUT_SCALE .. "," ..
          " output_scale = " .. MOISTURE_NOISE_OUTPUT_SCALE ..
        "}" ..
      ", " .. MOISTURE_MIN .. ", " .. MOISTURE_MAX .. ")"
  }
})