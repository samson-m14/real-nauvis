local map_gen_presets = data.raw["map-gen-presets"]
if not map_gen_presets or not map_gen_presets.default then
  error("Real Nauvis: map-gen-presets.default not found")
end

map_gen_presets.default["climate-zone"] = {
  order = "z[climate-zone]",
  basic_settings = {
    property_expression_names = {
      moisture    = "climate-zone-moisture",
    }
  },
  advanced_settings = {}
}
