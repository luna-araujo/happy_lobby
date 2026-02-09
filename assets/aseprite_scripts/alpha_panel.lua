-- Alpha Panel
-- Dockable panel to show current FG alpha/layer and map labels to alpha values.

local function dirname(path)
  return path:match("^(.*[/\\])")
end

local function script_dir()
  local info = debug.getinfo(1, "S")
  local source = info and info.source or ""
  if source:sub(1, 1) == "@" then
    source = source:sub(2)
  end
  return dirname(source) or "./"
end

local MAP_FILE = app.fs.userConfigPath .. "/alpha_map.lua"
local LEGACY_MAP_FILE = script_dir() .. "alpha_map.lua"
local clamp_alpha
local normalize_map
local save_map
local ensure_map_file

local function lua_escape(s)
  s = s:gsub("\\", "\\\\")
  s = s:gsub("\"", "\\\"")
  s = s:gsub("\n", "\\n")
  s = s:gsub("\r", "\\r")
  s = s:gsub("\t", "\\t")
  return s
end

local function serialize_map(map)
  local lines = {}
  table.insert(lines, "return {")
  for _, item in ipairs(map) do
    local label = lua_escape(tostring(item.label))
    local alpha = clamp_alpha(tonumber(item.alpha) or 0)
    table.insert(lines, string.format("  { label = \"%s\", alpha = %d },", label, alpha))
  end
  table.insert(lines, "}")
  return table.concat(lines, "\n")
end

save_map = function(map)
  local f = io.open(MAP_FILE, "w")
  if not f then
    app.alert("Failed to write alpha_map.lua.")
    return false
  end
  f:write(serialize_map(map))
  f:close()
  return true
end

ensure_map_file = function()
  local f = io.open(MAP_FILE, "r")
  if f then
    f:close()
    return true
  end
  local legacy = io.open(LEGACY_MAP_FILE, "r")
  if legacy then
    legacy:close()
    local ok, data = pcall(dofile, LEGACY_MAP_FILE)
    if ok and type(data) == "table" then
      local normalized = normalize_map(data)
      if #normalized > 0 then
        return save_map(normalized)
      end
    end
  end
  return save_map({
    { label = "Solid", alpha = 255 },
  })
end

clamp_alpha = function(v)
  if v < 0 then return 0 end
  if v > 255 then return 255 end
  return math.floor(v + 0.5)
end

normalize_map = function(raw)
  local out = {}
  if type(raw) == "table" then
    local is_array = false
    local n = raw.n or #raw
    if n and n > 0 then
      is_array = true
      for i = 1, n do
        local item = raw[i]
        if type(item) == "table" and item.label ~= nil and item.alpha ~= nil then
          table.insert(out, { label = tostring(item.label), alpha = clamp_alpha(tonumber(item.alpha) or 0) })
        end
      end
    end
    if not is_array then
      for _, item in pairs(raw) do
        if type(item) == "table" and item.label ~= nil and item.alpha ~= nil then
          table.insert(out, { label = tostring(item.label), alpha = clamp_alpha(tonumber(item.alpha) or 0) })
        end
      end
    end
  end
  return out
end

local function load_map()
  ensure_map_file()
  local f = io.open(MAP_FILE, "r")
  if not f then
    return {
      { label = "Solid", alpha = 255 },
    }
  end
  f:close()
  local ok, data = pcall(dofile, MAP_FILE)
  if not ok then
    app.alert("alpha_map.lua is invalid: " .. tostring(data))
    return {
      { label = "Solid", alpha = 255 },
    }
  end
  if type(data) ~= "table" then
    app.alert("alpha_map.lua must return a table. Using defaults.")
    return {
      { label = "Solid", alpha = 255 },
    }
  end
  local normalized = normalize_map(data)
  if #normalized == 0 then
    return {
      { label = "Solid", alpha = 255 },
    }
  end
  return normalized
end

local map = load_map()

local function map_labels()
  local labels = {}
  for i, item in ipairs(map) do
    labels[i] = item.label
  end
  return labels
end

local function find_map_index_by_label(label)
  for i, item in ipairs(map) do
    if item.label == label then
      return i
    end
  end
  return nil
end

local function set_fg_alpha(alpha)
  local c = app.fgColor
  c.alpha = clamp_alpha(alpha)
  app.fgColor = c
end

local dlg
local editor_dlg
local updating_ui = false
local listener_site
local listener_fg

local function current_alpha_text()
  local c = app.fgColor
  local label = nil
  for _, item in ipairs(map) do
    if item.alpha == c.alpha then
      label = item.label
      break
    end
  end
  if label then
    return tostring(c.alpha) .. " (" .. label .. ")"
  end
  return tostring(c.alpha)
end

local function current_layer_text()
  local site = app.site
  local layer = site and site.layer or nil
  if layer == nil then
    return "(none)"
  end
  return layer.name
end

local function sync_combo_to_alpha()
  local alpha = app.fgColor.alpha
  for _, item in ipairs(map) do
    if item.alpha == alpha then
      dlg:modify{ id = "map_select", option = item.label }
      return
    end
  end
end

local function update_status()
  if not dlg then return end
  updating_ui = true
  dlg:modify{ id = "layer_alpha", text = "Layer: " .. current_layer_text() .. " | Alpha: " .. current_alpha_text() }
  sync_combo_to_alpha()
  updating_ui = false
end

local function refresh_map_ui()
  if not dlg then return end
  updating_ui = true
  dlg:modify{ id = "map_select", options = map_labels() }
  updating_ui = false
end

dlg = Dialog{ title = "Alpha Panel", onclose = function()
  -- Detach listeners on close.
  if listener_site then app.events:off(listener_site) end
  if listener_fg then app.events:off(listener_fg) end
end }

dlg:label{ id = "layer_alpha", text = "Layer: " .. current_layer_text() .. " | Alpha: " .. current_alpha_text() }
dlg:newrow()

dlg:combobox{
  id = "map_select",
  label = "Map",
  options = map_labels(),
  onchange = function()
    if updating_ui then return end
    local label = dlg.data.map_select
    local idx = find_map_index_by_label(label)
    if idx then
      set_fg_alpha(map[idx].alpha)
      update_status()
    end
  end
}

dlg:newrow()
dlg:button{
  id = "open_editor",
  text = "Edit Map",
  onclick = function()
    if editor_dlg then
      editor_dlg:show{ wait = false }
      return
    end

    editor_dlg = Dialog{ title = "Alpha Map Editor", onclose = function()
      editor_dlg = nil
    end }

    editor_dlg:entry{ id = "map_label", label = "Label", text = "" }
    editor_dlg:newrow()
    editor_dlg:entry{ id = "map_alpha", label = "Alpha (0-255)", text = "" }
    editor_dlg:newrow()

    editor_dlg:button{
      id = "map_save",
      text = "Add/Update",
      onclick = function()
        local label = tostring(editor_dlg.data.map_label or ""):gsub("^%s+", ""):gsub("%s+$", "")
        local alpha_str = tostring(editor_dlg.data.map_alpha or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if label == "" then
          app.alert("Label is required.")
          return
        end
        local alpha = tonumber(alpha_str)
        if not alpha then
          app.alert("Alpha must be a number (0-255).")
          return
        end
        alpha = clamp_alpha(alpha)
        local idx = find_map_index_by_label(label)
        if idx then
          map[idx].alpha = alpha
        else
          table.insert(map, { label = label, alpha = alpha })
        end
        save_map(map)
        refresh_map_ui()
        dlg:modify{ id = "map_select", option = label }
        update_status()
      end
    }

    editor_dlg:button{
      id = "map_remove",
      text = "Remove",
      onclick = function()
        local label = dlg.data.map_select
        local idx = find_map_index_by_label(label)
        if not idx then return end
        table.remove(map, idx)
        save_map(map)
        refresh_map_ui()
        update_status()
      end
    }

    editor_dlg:show{ wait = false }
  end
}

dlg:show{ wait = false }

-- Listeners for live updates.
listener_site = app.events:on("sitechange", function() update_status() end)
listener_fg = app.events:on("fgcolorchange", function() update_status() end)

update_status()
