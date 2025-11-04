local Device = require("device")
local Blitbuffer = require("ffi/blitbuffer")
local Font = require("ui/font")
local Size = require("ui/size")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local InputContainer = require("ui/widget/container/inputcontainer")
local FrameContainer = require("ui/widget/container/framecontainer")
local ScrollTextWidget = require("ui/widget/scrolltextwidget")
local Input = Device.input
local Screen = Device.screen

local NotesFrame = InputContainer:extend {
    modal = true,
    scale = nil,
    text = nil,
    region = nil,
    on_close = nil,
}

function NotesFrame:init()
    if Device:hasKeys() then
        self.key_events.AnyKeyPressed = { { Input.group.Any } }
    end
    if Device:isTouchDevice() then
        self.ges_events.TapClose = {
            GestureRange:new{
                ges = "tap",
                range = Geom:new{
                    x = 0, y = 0,
                    w = Screen:getWidth(),
                    h = Screen:getHeight(),
                }
            }
        }
    end

    local padding = Size.padding.default + Size.padding.large * self.scale
    self[1] = FrameContainer:new {
        width = self.region.w,
        height = self.region.h,
        background = Blitbuffer.COLOR_WHITE,
        padding = padding,

        ScrollTextWidget:new {
            dialog = self,
            text = self.text,
            face = Font:getFace("smallinfofont", math.floor(16 + 8 * self.scale)),
            width = self.region.w - 2 * padding,
            height = self.region.h - 2 * padding,
        }
    }
end

function NotesFrame:paintTo(bb, x, y)
    self[1]:paintTo(bb, x + self.region.x, y + self.region.y)
end

function NotesFrame:onTapClose()
    self.on_close()
    return true
end
NotesFrame.onAnyKeyPressed = NotesFrame.onTapClose

return NotesFrame
