-- HyperLED plugin "Klipper Status Display": draws the state of a Klipper 3D printer on the segment.
--
-- Copyright (c) 2026 Dennis Guse
-- Licensed under the EUPL, Version 1.2 (see the LICENSE file of this repository).
--
--   idle      a dim colour
--   heating   a bar that fills as the heaters approach their targets, breathing
--   printing  a bar that fills with the print progress
--   paused    breathing
--   done      a steady colour (until the printer goes idle)
--   error     fast flashing
--
-- v.* are the values the plugin reads (see "values" in the plugin file), settings.* its settings; the
-- colours in settings are numbers 0xRRGGBB. The bar grows in the direction settings.direction names
-- (ltr, rtl, both = from both ends to the middle, center = from the middle outwards). On a panel, or
-- a plain strip, it follows the x axis. A strip that hangs on the larger matrix canvas of a Master
-- lies on that canvas row by row, so there the bar follows the order of the LEDs instead; HyperLED
-- says which is which in settings._layout ("grid", "snake", "rows"), settings._leds and
-- settings._first, and the plugin needs no setting for it. If this script cannot run (a Slave without
-- script support, an error), the rules of the plugin show the state with plain effects instead.

local floor, ceil, min, max = math.floor, math.ceil, math.min, math.max

-- How bright the picture of this plugin is, 5 to 100 percent of what the colours say. It dims only
-- this plugin's colours; the brightness of the segment, set where it always is, comes on top of it.
-- (Set in update(): settings and v are empty while the script loads and in init().)
local level = 1

local function rgb(c)
  return floor(((c // 65536) % 256) * level), floor(((c // 256) % 256) * level), floor((c % 256) * level)
end

local function scaled(c, k)
  local r, g, b = rgb(c)
  return floor(r * k), floor(g * k), floor(b * k)
end

-- 0 to 1 and back, once every two seconds: no sin(), so it stays cheap and never drifts
local function pulse(t)
  local p = (t % 2000) / 1000
  if p > 1 then p = 2 - p end
  return p
end

-- How far a heater is on its way to its target, 0 to 1; nil when it is not asked to heat.
local function heaterShare(temp, target)
  if temp == nil or target == nil or target <= 0 then return nil end
  local s = temp / target
  if s < 0 then s = 0 elseif s > 1 then s = 1 end
  return s
end

-- The heaters of the printer: up to four extruders (a printer with several tools has several) and the
-- bed. The plugin reads the temperature of each (e0 to e3, bed) and how far it is below its target
-- (g0 to g3, bed_gap); an extruder the printer does not have is simply not there (nil).
local TEMPS = { "e0", "e1", "e2", "e3", "bed" }
local GAPS = { "g0", "g1", "g2", "g3", "bed_gap" }

local mode, share = "idle", 0
local shareMode = nil

-- A bar only grows while a mode lasts. The progress the printer reports can step back a little (it comes
-- from the last M73 or, without one, from the position in the file), and a heater can pass another
-- one: the end of the bar would then jump forward and back by several LEDs, which looks like
-- flickering. So a fall of less than 30 percent points is ignored and said in the log of the script
-- (the last message shows in the plugin's live values); a bigger fall, or another mode, starts anew.
local function keep(value)
  if mode == shareMode and value < share and share - value < 0.3 then
    if share - value >= 0.01 then log("bar would fall from " .. floor(share * 100) .. " to " .. floor(value * 100) .. " %") end
    return
  end
  share = value
  shareMode = mode
end

-- Whether the pixel at the growing end of the bar breathes while printing (a setting, off unless
-- asked for; read in update()).
local headBreath = false

-- How many pictures a second a mode needs. Only what moves by itself (breathing, flashing) needs
-- many; a bar that merely changes with the progress, or a steady colour, needs very few. Every
-- picture is sent to the LEDs again, and on some strips each one is a chance for a stray flicker, so
-- the breathing end of the bar gets five a second, not ten.
local function rate(m)
  if m == "heating" or m == "paused" or m == "error" then return 10 end
  if m == "printing" and headBreath then return 5 end
  return 2
end
fps = rate(mode)

-- What the values say, worked out when new values arrive rather than in every frame.
function update()
  level = max(5, min(100, settings.brightness or 100)) / 100
  headBreath = settings.head_pulse == true
  local state = v.state
  local margin = settings.heat_margin or 10
  -- Is a heater that is asked to heat more than `margin` below its target, and how far along is the
  -- one that is furthest behind? (target = temperature + gap)
  local heating, lowest = false, nil
  for i = 1, #TEMPS do
    local temp, gap = v[TEMPS[i]], v[GAPS[i]]
    if gap ~= nil and gap > margin then heating = true end
    if temp ~= nil and gap ~= nil then
      local s = heaterShare(temp, temp + gap)
      if s ~= nil and (lowest == nil or s < lowest) then lowest = s end
    end
  end
  if state == "error" then
    mode = "error"
  elseif state == "paused" then
    mode = "paused"
  elseif state == "complete" and settings.show_done and v.idle ~= "Idle" then
    mode = "done"
  elseif heating and (state == "standby" or (state == "printing" and (v.duration or 0) < 2)) then
    -- before the first extrusion (print_duration is 0 until then) or while preheating by hand
    mode = "heating"
    keep(lowest or 0)
  elseif state == "printing" then
    mode = "printing"
    local value = (v.progress or 0) / 100
    if value < 0 then value = 0 elseif value > 1 then value = 1 end
    keep(value)
  else
    mode = "idle"
  end
  fps = rate(mode)
end

-- The part of pixel x (0 to 1) that lies between a and b.
local function span(x, a, b)
  local lo = max(a, x)
  local hi = min(b, x + 1)
  if hi > lo then return hi - lo end
  return 0
end

-- How much of position i (0 to 1) a bar of length len covers on a line of n positions, growing in the
-- direction dir. The ends of the bar are partly covered positions, so the bar grows smoothly even on
-- a short strip.
local function cover(i, len, dir, n)
  if dir == "rtl" then return span(i, n - len, n) end
  if dir == "both" then return min(1, span(i, 0, len / 2) + span(i, n - len / 2, n)) end
  if dir == "center" then return span(i, (n - len) / 2, (n + len) / 2) end
  return span(i, 0, len)
end

-- The pixel(s) at the growing end(s) of a bar of length len on a line of n; -1 where there is none.
local function heads(len, dir, n)
  if len >= n then return -1, -1 end
  if dir == "rtl" then return floor(n - len), -1 end
  if dir == "both" then return ceil(len / 2) - 1, floor(n - len / 2) end
  if dir == "center" then return floor((n - len) / 2), ceil((n + len) / 2) - 1 end
  return ceil(len) - 1, -1
end

-- A bar over the whole segment. While the picture says "bar" at least one LED is lit, so a print that
-- has only just started does not look like a dark strip. breathing: the whole bar breathes (heating);
-- headPulse: only the pixel(s) at its growing end do (printing), so the print is seen to be alive.
local function bar(c, t, breathing, headPulse)
  local k = breathing and (0.35 + 0.65 * pulse(t)) or 1
  local kh = headPulse and (0.3 + 0.7 * pulse(t)) or 1
  local dir = settings.direction or "ltr"
  local layout = settings._layout or "grid"
  if layout == "grid" then
    -- the x axis is the line; every row draws the same
    local len = max(1, share * W)
    local h1, h2 = heads(len, dir, W)
    for x = 0, W - 1 do
      local f = cover(x, len, dir, W)
      local r, g, b = scaled(c, k * f * ((x == h1 or x == h2) and kh or 1))
      for y = 0, H - 1 do px(x, y, r, g, b) end
    end
  else
    -- the line is the chain of LEDs: n of them, laid row by row on the canvas from LED `first` on,
    -- the odd rows backwards when the chain snakes
    local n = settings._leds or 0
    if n < 1 or n > W * H then n = W * H end
    local first = settings._first or 0
    local len = max(1, share * n)
    local snake = layout == "snake"
    local h1, h2 = heads(len, dir, n)
    for j = 0, n - 1 do
      local f = cover(j, len, dir, n)
      local i = first + j
      local row = i // W
      local x = i % W
      if snake and row % 2 == 1 then x = W - 1 - x end
      local r, g, b = scaled(c, k * f * ((j == h1 or j == h2) and kh or 1))
      px(x, row, r, g, b)
    end
  end
end

function frame(t)
  if mode == "error" then
    if (t // 250) % 2 == 0 then fill(rgb(settings.c_error or 0xFF0000)) else clear() end
  elseif mode == "paused" then
    fill(scaled(settings.c_pause or 0xFFC800, 0.15 + 0.85 * pulse(t)))
  elseif mode == "done" then
    fill(rgb(settings.c_done or 0x00C8FF))
  elseif mode == "heating" then
    bar(settings.c_heat or 0xFF7A00, t, true)
  elseif mode == "printing" then
    bar(settings.c_print or 0x00D060, t, false, headBreath)
  else
    fill(rgb(settings.c_idle or 0x001A33))
  end
end
