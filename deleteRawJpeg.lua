local dt = require("darktable")
local df = require("lib/dtutils.file")
local os = require("os")

local script_data = {}

script_data.name = "Delete RAW+JPEG"
script_data.module_name = "delete_raw_jpeg"
script_data.destroy = nil        -- function to destory the script
script_data.destroy_method = nil -- set to hide for libs since we can't destroy them commpletely yet, otherwise leave as nil
script_data.restart = nil        -- how to restart the (lib) script after it's been hidden - i.e. make it visible again
script_data.show = nil           -- only required for libs since the destroy_method only hides them

-- translation

-- https://www.darktable.org/lua-api/index.html#darktable_gettext
local gettext = dt.gettext

gettext.bindtextdomain("moduleExample", dt.configuration.config_dir .. "/lua/locale/")

local function _(msgid)
  return gettext.dgettext("moduleExample", msgid)
end


local TRASH_DIRECTORY = os.getenv("HOME") .. "/.local/share/Trash/files"
local USE_TRASH = df.check_if_file_exists(TRASH_DIRECTORY .. "/")

-- Fetches to JPEG equivalent of a given image
local function find_jpeg(image)
  local test_filepath = df.sanitize_filename(df.chop_filetype(tostring(image)))
  local command = "mv " .. test_filepath .. "* \'" .. TRASH_DIRECTORY .. "\'"

  local output = io.popen(command)
  local exit_code = output:read("*all") -- not really exit code but rather command output. I'll deal with naming later
  output:close()
  if string.len(exit_code) then
    dt.database.delete(image)
  end
  return string.len(exit_code) == 0
end

local function delete_files()
  local selected_images = dt.gui.selection()
  for _, image in pairs(selected_images) do
    local jpeg = find_jpeg(image)
  end
end

-- declare a local namespace and a couple of variables we'll need to install the module
local mE = {
  widgets = {},
  event_registered = false,
  module_istalled = false,
}

local function install_module()
  if not mE.module_installed then
    -- https://www.darktable.org/lua-api/index.html#darktable_register_lib
    dt.register_lib(
      script_data.module_name,
      script_data.name,
      true,                                                                       -- expandable
      false,                                                                      -- resetable
      { [dt.gui.views.lighttable] = { "DT_UI_CONTAINER_PANEL_RIGHT_CENTER", 100 } }, -- containers
      -- https://www.darktable.org/lua-api/types_lua_box.html
      dt
      .new_widget("box") -- widget
      ({
        orientation = "vertical",
        dt.new_widget("button")({
          label = _("Delete files"),
          clicked_callback = delete_files
        }),
        table.unpack(mE.widgets),
      }),
      nil, -- view_enter
      nil -- view_leave
    )
    mE.module_installed = true
  end
end

-- script_manager integration to allow a script to be removed
-- without restarting darktable
local function destroy()
  dt.gui.libs[script_data.module_name].visible = false -- we haven't figured out how to destroy it yet, so we hide it for now
end

local function restart()
  dt.gui.libs[script_data.module_name].visible = true -- the user wants to use it again, so we just make it visible and it shows up in the UI
end

-- ... and tell dt about it all

if dt.gui.current_view().id == "lighttable" then -- make sure we are in lighttable view
  install_module()                               -- register the lib
else
  if not mE.event_registered then                -- if we are not in lighttable view then register an event to signal when we might be
    -- https://www.darktable.org/lua-api/index.html#darktable_register_event
    dt.register_event(
      script_data.module_name,
      "view-changed",                                                     -- we want to be informed when the view changes
      function(event, old_view, new_view)
        if new_view.name == "lighttable" and old_view.name == "darkroom" then -- if the view changes from darkroom to lighttable
          install_module()                                                -- register the lib
        end
      end
    )
    mE.event_registered = true --  keep track of whether we have an event handler installed
  end
end


-- set the destroy routine so that script_manager can call it when
-- it's time to destroy the script and then return the data to
-- script_manager
script_data.destroy = destroy
script_data.restart = restart       -- only required for lib modules until we figure out how to destroy them
script_data.destroy_method = "hide" -- tell script_manager that we are hiding the lib so it knows to use the restart function
script_data.show = restart          -- if the script was "off" when darktable exited, the module is hidden, so force it to show on start

return script_data
