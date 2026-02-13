-- utils.lua
local Utils = {}

-- Field detection based on position
function Utils.getFieldName(position)
    -- Define field boundaries (adjust these values based on your game map)
    local fields = {
        {name = "Sunflower Field", minX = 0, maxX = 50, minZ = 0, maxZ = 50},
        {name = "Dandelion Field", minX = 50, maxX = 100, minZ = 0, maxZ = 50},
        {name = "Mushroom Field", minX = 0, maxX = 50, minZ = 50, maxZ = 100},
        {name = "Blue Flower Field", minX = 50, maxX = 100, minZ = 50, maxZ = 100},
        {name = "Clover Field", minX = 100, maxX = 150, minZ = 0, maxZ = 50},
        {name = "Strawberry Field", minX = 100, maxX = 150, minZ = 50, maxZ = 100},
        {name = "Spider Field", minX = 150, maxX = 200, minZ = 0, maxZ = 50},
        {name = "Bamboo Field", minX = 150, maxX = 200, minZ = 50, maxZ = 100},
        {name = "Pineapple Patch", minX = -50, maxX = 0, minZ = 0, maxZ = 50},
        {name = "Stump Field", minX = -50, maxX = 0, minZ = 50, maxZ = 100},
        {name = "Cactus Field", minX = -100, maxX = -50, minZ = 0, maxZ = 50},
        {name = "Pumpkin Patch", minX = -100, maxX = -50, minZ = 50, maxZ = 100},
        {name = "Pine Tree Forest", minX = 0, maxX = 50, minZ = 100, maxZ = 150},
        {name = "Rose Field", minX = 50, maxX = 100, minZ = 100, maxZ = 150},
        {name = "Mountain Top Field", minX = 100, maxX = 150, minZ = 100, maxZ = 150},
        {name = "Pepper Patch", minX = 150, maxX = 200, minZ = 100, maxZ = 150},
        {name = "Coconut Field", minX = -50, maxX = 0, minZ = 100, maxZ = 150},
    }
    
    for _, field in ipairs(fields) do
        if position.X >= field.minX and position.X <= field.maxX and
           position.Z >= field.minZ and position.Z <= field.maxZ then
            return field.name
        end
    end
    
    return "Unknown Field"
end

return Utils
