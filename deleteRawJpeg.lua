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

-- TODO: This may not play well with translations, however I'm not using them at the moment
-- Figure out a way to support translations
local labels = {
	delete_button = {
		default = "Delete files",
		prompt = "Confirm deletion of %d file(s)"
	},
	cancel_button = {
		default = "Cancel"
	},
	toast = {
		no_images = "No images selected"
	}
}


-- https://www.darktable.org/lua-api/index.html#darktable_gettext
local gettext = dt.gettext

gettext.bindtextdomain("moduleExample", dt.configuration.config_dir .. "/lua/locale/")

local function _(msgid)
  return gettext.dgettext("moduleExample", msgid)
end


local TRASH_DIRECTORY = os.getenv("HOME") .. "/.local/share/Trash/files"
local USE_TRASH = df.check_if_file_exists(TRASH_DIRECTORY .. "/")

local function execute_command(command)
  local output = io.popen(command)
  local exit_code = output:read("*all") -- not really exit code but rather command output. I'll deal with naming later
  output:close()
  return string.len(exit_code) == 0
end

--- Fetches to JPEG equivalent of a given image
--- @param image any: Target file to remove
local function remove(image)
  local test_filepath = df.sanitize_filename(df.chop_filetype(tostring(image)))
  local remove_command = "mv " .. test_filepath .. "* \'" .. TRASH_DIRECTORY .. "\'"

  local is_removed = execute_command(remove_command)
  if is_removed then
    dt.database.delete(image)
  end
  return is_removed
end

local confirmed = false

--- Resets plugin state and hides the cancel button.
--- @param delete_button any: Button that doubles as confirmation prompt.
--- @param cancel_button any: Cancel button to hide.
local function reset_confirmation(delete_button, cancel_button)
  confirmed = false
  delete_button.label = labels.delete_button.default
  cancel_button.visible = false
end

--- @param delete_button any: Starts the deletion process and doubles as a confirmation prompt.
--- @param cancel_button any: Appears when delete_button is showing a confirmation prompt. Cancels the process.
local function process_selection(delete_button, cancel_button)
  local selected_images = dt.gui.selection()
  local image_count = #selected_images

  if image_count == 0 then
    dt.print_toast(labels.toast.no_images)
    reset_confirmation(delete_button, cancel_button)
    return
  end

  if not confirmed then
    confirmed = true
    delete_button.label = string.format(labels.delete_button.prompt, image_count)
    cancel_button.visible = true
    return
  end

  local job = dt.gui.create_job('Removing '..image_count..' image(s)', true)
  local percent_step = 1 / image_count

  for _, image in pairs(selected_images) do
    local is_removed = remove(image)
    if not is_removed then
      dt.print(_("Error removing " ..image.name))
    end
    job.percent = job.percent + percent_step
  end

  job.valid = false
  dt.print(_("Removed " ..image_count.. " image(s)"))
  dt.gui.libs.collect.filter(dt.gui.libs.collect.filter())
  reset_confirmation(delete_button, cancel_button)
end

-- declare a local namespace and a couple of variables we'll need to install the module
local mE = {
  widgets = {},
  event_registered = false,
  module_istalled = false,
}

local function install_module()
  if not mE.module_installed then
    local cancel_button = dt.new_widget("button")({
      label = labels.cancel_button.default,
      visible = false,
    })

    local delete_button = dt.new_widget("button")({
      label = labels.delete_button.default,
    })

    delete_button.clicked_callback = function() process_selection(delete_button, cancel_button) end
    cancel_button.clicked_callback = function() reset_confirmation(delete_button, cancel_button) end

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
        delete_button,
        cancel_button,
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
