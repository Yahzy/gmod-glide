-- Files under `lua/glide/autoload/` runs after
-- all Glide files have been included.

-- You can safely access the `Glide` global table in here.
-- Glide.Print( "Hello from the %s extension!", "example" )

--[[----------------------------------------
    Example: Custom input groups and actions
------------------------------------------]]

-- You can create a new input group like this:
-- Glide.SetupInputGroup( "example_controls" )

-- Then, add a input action to be triggered when a key is pressed like this:
-- Glide.AddInputAction( "example_controls", "drop_bomb", KEY_SPACE )

-- Add display names for them too.
--[[
if CLIENT then
    -- Group strings should follow this format: "glide.input.your_group_id_here"
    language.Add( "glide.input.example_controls", "Example Controls" )

    -- Action strings should follow this format: "glide.input.your_action_id_here"
    language.Add( "glide.input.drop_bomb", "Drop bomb" )
end
]]

-- To make this new input group work, on the SERVER side of your vehicle's class,
-- you should add this function:
--[[
    function ENT:GetInputGroups( seatIndex )
        return { "general_controls", "example_controls" }
    end
]]

-- If you're sitting on the vehicle, exit and then enter it again. When the
-- spacebar key is pressed, `ENT:OnSeatInput` should now receive a "drop_bomb" action.
--[[
    function ENT:OnSeatInput( seatIndex, action, pressed )
        if action == "drop_bomb" then
            -- Do your own thing here.
        else
            -- Otherwise let the base class handle this.
            BaseClass.OnSeatInput( self, seatIndex, action, pressed )
        end
    end
]]
