local _ = require("gettext")
local logger = require("logger")
local Device = require("device")
local Blitbuffer = require("ffi/blitbuffer")
local Size = require("ui/size")
local Geom = require("ui/geometry")
local UIManager = require("ui/uimanager")
local FrameContainer = require("ui/widget/container/framecontainer")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local VerticalGroup = require("ui/widget/verticalgroup")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local IconButton = require("ui/widget/iconbutton")
local Screen = Device.screen

local pluginSettings = require("plugin/settings")
local ScreenLockWidget = require("plugin/ui/lockscreen/screenlockwidget")

local LockScreenFrame = WidgetContainer:extend {
    name = "SLPLockScreen",

    lock_widget = nil,
    action_row = nil,
    on_unlock = nil,
    on_show_notes = nil,
    visible = true,
    -- a slightly grown refresh region seems to reduce ghosting a little
    clear_outset = Screen:scaleBySize(2),

    _refresh_region = nil,
    _content_region = nil,
}

function LockScreenFrame:init()
    local uiSettings = pluginSettings.getUiSettings()
    self.lock_widget = ScreenLockWidget:new {
        ui_root = self,
        scale = uiSettings.scale / 100,
        on_update = function(input)
            if input ~= pluginSettings.readPin() then
                self.lock_widget.state:incFailedCount()
                return
            end
            logger.dbg("ScreenLockPin: unlock")
            self.on_unlock()
        end
    }

    local note_cfg = pluginSettings.getNoteSettings()
    if note_cfg.mode == "button" then
        self.action_row = HorizontalGroup:new {
            IconButton:new {
                icon = "appbar.typeset",
                width = Size.item.height_big * (1 + uiSettings.scale / 100),
                height = Size.item.height_big * (1 + uiSettings.scale / 100),
                callback = self.on_show_notes,
                allow_flash = false,
                padding = Size.padding.large * uiSettings.scale / 100,
            },
        }
    end

    self[1] = FrameContainer:new {
        background = Blitbuffer.COLOR_WHITE,
        -- half-bright gray border plays nice with most wallpapers and mitigates
        -- ghosting a little
        color = Blitbuffer.COLOR_GRAY_7,
        padding = 0,
        -- Content: PIN widget + bottom action row
        VerticalGroup:new {
            self.lock_widget,
            self.action_row,
        }
    }
end

function LockScreenFrame:setVisible(bool)
    self.visible = bool
end

function LockScreenFrame:paintTo(bb, x, y)
    if not self.visible then return end
    local region = self:getContentRegion()
    self[1]:paintTo(bb, x + region.x, y + region.y)
end

function LockScreenFrame:getRefreshRegion()
    if self._refresh_region then return self._refresh_region end
    local content_size = self[1]:getSize()
    local uiSettings = pluginSettings.getUiSettings()
    local pos_x = uiSettings.pos_x / 100
    local pos_y = uiSettings.pos_y / 100
    if pos_x < 0 then pos_x = 0 elseif pos_x > 1 then pos_x = 1 end
    if pos_y < 0 then pos_y = 0 elseif pos_y > 1 then pos_y = 1 end
    local avail_w = math.max(0, Screen:getWidth() - content_size.w)
    local avail_h = math.max(0, Screen:getHeight() - content_size.h)
    local x = math.floor(avail_w * pos_x)
    local y = math.floor(avail_h * pos_y)

    self._content_region = Geom:new {
        x = x,
        y = y,
        w = content_size.w,
        h = content_size.h,
    }
    self._refresh_region = Geom:new {
        x = math.max(0, self._content_region.x - self.clear_outset),
        y = math.max(0, self._content_region.y - self.clear_outset),
        w = math.min(Screen:getWidth(), content_size.w + self.clear_outset * 2),
        h = math.min(Screen:getHeight(), content_size.h + self.clear_outset * 2),
    }
    return self._refresh_region
end

function LockScreenFrame:getContentRegion()
    self:getRefreshRegion()
    return self._content_region
end

function LockScreenFrame:clearInput()
    logger.dbg("ScreenLockPin: clear overlay input")
    self.lock_widget.state:clear()
end

function LockScreenFrame:relayout(refreshmode)
    local screen_dimen = Geom:new{x = 0, y = 0, w = Screen:getWidth(), h = Screen:getHeight()}
    logger.dbg("ScreenLockPin: resize overlay to " .. screen_dimen.x .. "x" .. screen_dimen.y)
    self[1].dimen = screen_dimen
    self.lock_widget:onScreenResize(screen_dimen)
    self._refresh_region = nil
    self._content_region = nil
    UIManager:setDirty(self, refreshmode, self:getRefreshRegion())
end

return LockScreenFrame
