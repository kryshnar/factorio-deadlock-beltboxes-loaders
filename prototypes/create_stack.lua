local DBL = require("prototypes.shared")

local function get_group(item, item_type)
	local g = data.raw["item-group"][data.raw["item-subgroup"][data.raw[item_type][item].subgroup].group].name
	if not g then
		g = "intermediate-products"
	end
	return g
end

function DBL.create_stacked_item(item_name, item_type, graphic_path, icon_size)
	if data.raw.item[string.format("deadlock-stack-%s", item_name)] then
		DBL.log_warning(string.format("Attempt to create stacked item that already exists for %s, skipping", item_name))
		return
	end
	DBL.debug(string.format("Creating stacked item: %s", item_name))
	local temp_icons, stacked_icons, this_fuel_category, this_fuel_acceleration_multiplier, this_fuel_top_speed_multiplier, this_fuel_value, this_fuel_emissions_multiplier
	if graphic_path then
		stacked_icons = { { icon = graphic_path, icon_size = icon_size } }
	else
		if data.raw[item_type][item_name].icon then
			temp_icons = { { icon = data.raw[item_type][item_name].icon, icon_size = icon_size } }
			DBL.log_warning(string.format("creating layered stack icon (%s), this is 4x more rendering effort than a custom icon", item_name))
		elseif data.raw[item_type][item_name].icons then
			temp_icons = data.raw[item_type][item_name].icons
			DBL.log_warning(string.format("creating layers-of-layers stack icon (%s), this is %dx more rendering effort than a custom icon!", item_name, 1+(#temp_icons*3)))
		else
			DBL.log_error(string.format("Can't create stacks for item with no icon properties %s", item_name))
			return
		end
		stacked_icons = { { icon = "__deadlock-beltboxes-loaders__/graphics/icons/blank.png", scale = 1, icon_size = 32 } }
		for i = 1, -1, -1 do
			for _,layer in pairs(temp_icons) do
				layer.shift = {0, i*3}
				layer.scale = 0.85 * 32/icon_size
				layer.icon_size = icon_size
				table.insert(stacked_icons, table.deepcopy(layer))
			end
		end
	end
	if data.raw[item_type][item_name].fuel_value then
		this_fuel_category = data.raw[item_type][item_name].fuel_category
		this_fuel_acceleration_multiplier = data.raw[item_type][item_name].fuel_acceleration_multiplier
		this_fuel_top_speed_multiplier = data.raw[item_type][item_name].fuel_top_speed_multiplier
		this_fuel_emissions_multiplier = data.raw[item_type][item_name].fuel_emissions_multiplier
		-- great, the fuel value is a string, with SI units. how very easy to work with
		this_fuel_value = (tonumber(string.match(data.raw[item_type][item_name].fuel_value, "%d+")) * DBL.STACK_SIZE) .. string.match(data.raw[item_type][item_name].fuel_value, "%a+")
	end
	local menu_order = string.format("%03d", DBL.ITEM_ORDER)
	DBL.ITEM_ORDER = DBL.ITEM_ORDER + 1
	data:extend({
		{
			type = "item",
			name = string.format("deadlock-stack-%s", item_name),
			localised_name = {"item-name.deadlock-stacking-stack", {"item-name."..item_name}, DBL.STACK_SIZE},
			icons = stacked_icons,
			icon_size = icon_size,
			stack_size = math.floor(data.raw[item_type][item_name].stack_size/DBL.STACK_SIZE),
			flags = {},
			subgroup = string.format("stacks-%s", get_group(item_name, item_type)),
			order = menu_order,
			allow_decomposition = false,
			fuel_category = this_fuel_category,
			fuel_acceleration_multiplier = this_fuel_acceleration_multiplier,
			fuel_top_speed_multiplier = this_fuel_top_speed_multiplier,
			fuel_emissions_multiplier = this_fuel_emissions_multiplier,
			fuel_value = this_fuel_value,
		}
	})
	DBL.debug(string.format("Created stacked item: %s", item_name))
end

-- make stacking/unstacking recipes for a base item
function DBL.create_stacking_recipes(item_name, item_type, icon_size)
	DBL.debug(string.format("Creating recipes: %s", item_name))
	local menu_order = string.format("%03d",DBL.RECIPE_ORDER)
	DBL.RECIPE_ORDER = DBL.RECIPE_ORDER + 1
	local base_icon = data.raw.item[string.format("deadlock-stack-%s", item_name)].icon
	local base_icons = data.raw.item[string.format("deadlock-stack-%s", item_name)].icons
	if not base_icons then
		base_icons = { { icon = base_icon } }
	end
	local stack_icons = table.deepcopy(base_icons)
	table.insert(stack_icons, 
		{
			icon = string.format("__deadlock-beltboxes-loaders__/graphics/icons/arrow-d-%d.png", icon_size),
			scale = 0.5 * 32 / icon_size,
			icon_size = icon_size,
		}
	)
	-- TODO use a smaller multiplier if the item won't fit at current multiplier

	-- stacking
	if data.raw.recipe[string.format("deadlock-stacks-stack-%s", item_name)] then
		DBL.log_warning(string.format("Attempt to create stacking recipe that already exists for %s, skipping", item_name))
	else
		data:extend({
			{
				type = "recipe",
				name = string.format("deadlock-stacks-stack-%s", item_name),
				localised_name = {"recipe-name.deadlock-stacking-stack", {"item-name."..item_name}},
				category = "stacking",
				group = "intermediate-products",
				subgroup = data.raw.item[string.format("deadlock-stack-%s", item_name)].subgroup,
				order = menu_order.."[a]",
				enabled = false,
				allow_decomposition = false,
				ingredients = { {item_name, DBL.STACK_SIZE * DBL.RECIPE_MULTIPLIER} },
				result = string.format("deadlock-stack-%s", item_name),
				result_count = DBL.RECIPE_MULTIPLIER,
				energy_required = DBL.CRAFT_TIME * DBL.RECIPE_MULTIPLIER,
				icons = stack_icons,
				icon_size = icon_size, 
				hidden = true,
				allow_as_intermediate = false,
				hide_from_stats = true,
			}
		})
	end
	-- unstacking
	if data.raw.recipe[string.format("deadlock-stacks-unstack-%s", item_name)] then
		DBL.log_warning(string.format("Attempt to create unstacking recipe that already exists for %s, skipping", item_name))
	else
		local unstack_icons = table.deepcopy(base_icons)
		table.insert(unstack_icons, 
			{
				icon = string.format("__deadlock-beltboxes-loaders__/graphics/icons/arrow-u-%d.png", icon_size),
				scale = 0.5 * 32 / icon_size,
			}
		)
		local hidden = settings.startup["deadlock-stacking-hide-unstacking"].value
		data:extend({
			{
				type = "recipe",
				name = string.format("deadlock-stacks-unstack-%s", item_name),
				localised_name = {"recipe-name.deadlock-stacking-unstack", {"item-name."..item_name}},
				category = "unstacking",
				group = "intermediate-products",
				subgroup = data.raw.item[string.format("deadlock-stack-%s", item_name)].subgroup,
				order = menu_order.."[b]",
				enabled = false,
				allow_decomposition = false,
				ingredients = { {string.format("deadlock-stack-%s", item_name), DBL.RECIPE_MULTIPLIER} },
				result = item_name,
				result_count = DBL.STACK_SIZE * DBL.RECIPE_MULTIPLIER,
				energy_required = DBL.CRAFT_TIME * DBL.RECIPE_MULTIPLIER,
				icons = unstack_icons,
				icon_size = icon_size,
				hidden = hidden,
				allow_as_intermediate = false,
				hide_from_stats = true,
			}
		})
	end
	DBL.debug(string.format("Created recipes: %s", item_name))
end

-- make the stacking recipes depend on a technology
function DBL.add_stacks_to_tech(item_name, target_technology)
	-- gather what recipes this tech currently unlocks to avoid adding duplicates
	local recipes = {}
	for _, effect in pairs(data.raw.technology[target_technology].effects) do
		if effect.type == "unlock-recipe" then
			recipes[effect.recipe] = true
		end
	end
	-- insert stacking recipe
	if recipes[string.format("deadlock-stacks-stack-%s", item_name)] then
		DBL.log_warning(string.format("Skipping already added tech effect for stacking %s", item_name))
	else
		table.insert(data.raw.technology[target_technology].effects,
			{
				type = "unlock-recipe",
				recipe = string.format("deadlock-stacks-stack-%s", item_name),
			}
		)
	end
	-- insert unstacking recipe
	if recipes[string.format("deadlock-stacks-stack-%s", item_name)] then
		DBL.log_warning(string.format("Skipping already added tech effect for unstacking %s", item_name))
	else
		table.insert(data.raw.technology[target_technology].effects,
			{
				type = "unlock-recipe",
				recipe = string.format("deadlock-stacks-unstack-%s", item_name),
			}
		)
	end
	DBL.debug(string.format("Added stacks for %s to tech %s", item_name, target_technology))
end
