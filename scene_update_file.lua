-- MIT License
--
-- Copyright (c) Geert Eikelboom, Mark Lagendijk, Andrew Jones
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.
--
-- Original script by Geert Eikelboom
-- Generalized and released on GitHub (with permission of Geert) by Mark Lagendijk
-- Modified to update a text file rather than execute command by Andrew Jones


obs = obslua
settings = {}

-- Script hook for defining the script description
function script_description()
	return [[
Update a text file with either the name of the current 'Program' scene, or a defined override for that scene

]]
end

-- Script hook for defining the settings that can be configured for the script
function script_properties()
	local props = obs.obs_properties_create()

	obs.obs_properties_add_text(props, "file_path", "File path", obs.OBS_TEXT_DEFAULT)
	
	local scenes = obs.obs_frontend_get_scenes()
	
	if scenes ~= nil then
		for _, scene in ipairs(scenes) do
			local scene_name = obs.obs_source_get_name(scene)
			obs.obs_properties_add_bool(props, "scene_custom_" .. scene_name, "Custom preset when '" .. scene_name .. "' is activated")
			obs.obs_properties_add_text(props, "scene_value_" .. scene_name, scene_name .. " preset", obs.OBS_TEXT_DEFAULT)
		end
	end
	
	obs.source_list_release(scenes)
	
	return props
end

-- Script hook that is called whenver the script settings change
function script_update(_settings)	
	settings = _settings
end

-- Script hook that is called when the script is loaded
function script_load(settings)
	obs.obs_frontend_add_event_callback(handle_event)
end

function handle_event(event)
	if event == obs.OBS_FRONTEND_EVENT_SCENE_CHANGED then
		handle_scene_change()	
	end
end

function handle_scene_change()
	local scene = obs.obs_frontend_get_current_scene()
	local scene_name = obs.obs_source_get_name(scene)
	local scene_custom = obs.obs_data_get_bool(settings, "scene_custom_" .. scene_name)
	
	local file_path = obs.obs_data_get_string(settings, "file_path")
	local scene_value = obs.obs_data_get_string(settings, "scene_value_" .. scene_name)
	local preset = ""	
	if scene_custom then	
		preset = scene_value
		obs.script_log(obs.LOG_INFO, "Activating " .. scene_name .. ". Settting preset in " .. file_path .. ":\n  " .. scene_value)
	else
		preset = scene_name
		obs.script_log(obs.LOG_INFO, "Activating " .. scene_name .. ". Settting preset in " .. file_path .. ":\n  " .. scene_name)
	end
	local file = io.open(file_path, "w")
	file:write(preset)
	file:close(file)
	obs.obs_source_release(scene);
end
