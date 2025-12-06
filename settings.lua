-- settings.lua

data:extend({
  {
    type = "bool-setting",
    name = "rn-ore-mixing-enabled",
    setting_type = "startup",
    default_value = true,
    order = "a[ore-mixing]-a[enabled]"
  },
  {
    type = "int-setting",
    name = "rn-ore-mixing-percent",
    setting_type = "startup",
    default_value = 20,
    minimum_value = 0,
    maximum_value = 100,
    order = "a[ore-mixing]-b[percent]"
  },
  {
    type = "bool-setting",
    name = "rn-stone-regions-enabled",
    setting_type = "startup",
    default_value = true,
    order = "stone-a[regions-enabled]"
  }
})
