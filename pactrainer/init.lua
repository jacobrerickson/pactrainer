--Pattern Trainer for Pac-Man
--by Jon Wilson (10yard)
--
--The Pac-Man Trainer is an aid to learning the common patterns for completing boards.
--You follow an on-screen path through each board.  For the pattern to hold,  you must
--stay on track and turn the corners quickly.
--
--The HUD shows information which can help during gameplay.
--On the left of the screen you will see the current level (e.g. "L. 001"),  the current
--pattern (e.g. "P. 1/3"), and the current status (e.g. S. ACE).  The status will change
--if you start falling behind to "OK" and finally "BAD" based on the number of dropped
--movements/frames.  It is still possible to complete the board with a "BAD" status but
--following the path will not guarantee success and you should be more cautious.
--If you die then the pattern will automatically fail and you will see a blinking "FAIL"
--message.  You are on your own to complete the board.
--
--Press P2 button to toggle between the currently available pattern sets.
--
--PACSTRATS set:
--    Use only three patterns to clear boards 1 through 255 and get to the kill screen!
--    Pattern 1 is used on boards 1 through 4
--    Pattern 2 is used on boards 5 through 20
--    Pattern 3 is used on boards 21 through 255
--    All three patterns clear the entire board and get both prizes.
--
--	  More information about following these patterns in the video at:
--	  https://www.youtube.com/watch?v=wKQy8LTTzC4
--
--KILLERCLOWN set:
--    Uses 5 patterns but some of them are very similar so should be easier to learn.
--    These patterns are robust until near to the end of each board.  You may need to
--    freestyle to tidy up some remaining pellets on your own.
--    Pattern 1 is for board 1 only.  It's freestyle near the end if you prefer.
--    Pattern 2 is for boards 2 through 4.  It's a slight variation from pattern 1.
--    Pattern 3 if for boards 5 through 16.
--    Pattern 4 is for boards 17, 19 and 20.  You'll need to freestyle near the end.
--    Pattern 5 is for boards 21 through 255
--
--	  More information about Killerclown's patterns is to be found at
--    https://www.mameworld.info/net/pacman/patterns.html
--
--PERFECT_NRC set:
--    An advanced pattern set for attaining the Perfect Pacman score by NR Chapman
--    There are many patterns.
--
--    The archive web information can be found at
--    https://web.archive.org/web/20061103090947/http://nrchapman.com/pacman/
--
--Minimum start up arguments:
--    mame pacman -plugin pactrainer
--
--Compatible with all MAME versions from at least 0.196
--Works with "pacman" and "puckman" roms only.
-----------------------------------------------------------------------------------------
local exports = {
	name = "pactrainer",
	version = "0.2",
	description = "Pac-Man Pattern Trainer",
	license = "GNU GPLv3",
	author = { name = "Jon Wilson (10yard)" } }

local pactrainer = exports

function pactrainer.startplugin()
	local GREEN, YELLOW, RED = 0xff00ff00, 0xffffff00, 0xffff0000
	local SETS = {"pacstrats", "killerclown", "perfect_nrc"}
	local LAG_PIXELS_DEFAULT = 5
	local FANFARE_LINES = {
		"EPIC FOUR-BAGGER!",
		"WOW NICE FOUR-BAGGER!",
		"JUST LIKE BILLY WOULD DO IT!",
		"It's like I can feel his hand on the stick, guiding me...",
	}

	-- Tier constants: 0=ACE, 1=OK, 2=BAD, 3=FAIL
	local TIER_ACE, TIER_OK, TIER_BAD, TIER_FAIL = 0, 1, 2, 3
	local TIER_DEBOUNCE_FRAMES = 16   -- ~0.27s hold; filters brief tier oscillations
	local MARKER_GRID = 8             -- snap recorded drops to 8px grid
	local MARKER_MIN_SEQ_GAP = 30     -- suppress duplicate drops within N seq
	local TIER_CUE_RATE_FRAMES = 180  -- rate limit tier-change cues to 1 per 3s
	local SOUND_COOLDOWN_FRAMES = 180 -- global gap between any two sounds (~3s)
	local FRIGHT_WINDOW_FRAMES = 480  -- ghost fright period cap for fanfare check

	local mac, cpu, mem, scr
	local plugin_path, data_path
	local patx, paty, pacx, pacy, oldpacx, oldpacy, lagx, lagy
	local mode, level, patid, patgroup, state, pills, oldstate, folder, first
	local seq, switch = 0, 0
	local pattern, group, info = {}, {}, {}
	local loaded, valid, failed, adjusted, lagging, ignore, freestyle, perfect = false, false, false, false, false, false, false, false
	local lag_pixels = LAG_PIXELS_DEFAULT

	-- Tier tracking (features 1, 2, 3)
	local tier_raw, tier_stable, tier_hold = TIER_ACE, TIER_ACE, 0
	local tier_cue_last_frame = -TIER_CUE_RATE_FRAMES

	-- Direction tracked every frame Pac-Man moves. Used at record_breakpoint
	-- time (which fires ~8 frames after the drop, past the debounce window).
	local last_dir = nil

	-- Sound queue. Cues collide often (tier change + fanfare, or two tier changes
	-- in quick succession), so instead of dropping late arrivals we buffer them
	-- and release them one at a time on a cooldown. Priority items (fanfare)
	-- skip the queue and play immediately.
	local last_sound_frame = -SOUND_COOLDOWN_FRAMES
	local sound_queue = {}
	local SOUND_QUEUE_MAX = 2  -- cap so backups don't stack forever

	-- Breakpoint map state. Session-only: markers live in memory during the
	-- current level and are wiped when the level changes or a new game starts.
	-- No files are read or written.
	local markers = {}                  -- {[key]={y,x,seq,count,dir}}
	local markers_level = nil           -- level number the current markers were recorded on
	local last_record_seq = -MARKER_MIN_SEQ_GAP
	local board_start_frame = 0

	-- Four-ghost fanfare state
	local prev_score = 0
	local ghost_run_count = 0           -- ghosts eaten this fright period
	local fright_start_frame = -1
	local fanfare_fired = false
	local prev_pills = 0

	-- MAME output support (may not exist on older MAME)
	local output_api = nil              -- "new" | "old" | nil
	local output_ok = false

	info["pacstrats"] = "Uses only 3 patterns to clear boards 1 through 255."
	info["killerclown"] = "Uses 5 similar patterns that should be easier to learn."
	info["perfect_nrc"] = "An advanced pattern set for attaining a perfect score."

	function get_next(table, id)
		local found = false
		nextid = "pacstrats" -- default
		for k, v in ipairs(table) do
			if found then
				nextid = v
				break
			end
			if v == id then found = true end
		end
		return nextid
	end

	-- Return a writable data path under MAME's homepath, falling back to plugin_path.
	-- The existing active.dat write in the plugin directory breaks on read-only installs.
	local function resolve_data_path()
		local candidates = {}
		local ok, val = pcall(function() return manager.machine.options.entries["homepath"]:value() end)
		if ok and val then table.insert(candidates, val) end
		ok, val = pcall(function() return manager:options().entries["homepath"]:value() end)
		if ok and val then table.insert(candidates, val) end
		for _, entry in ipairs(candidates) do
			-- homepath may be ";"- or ":"-separated. Take first non-empty segment.
			for seg in string.gmatch(entry, "[^;:]+") do
				if seg and #seg > 0 then
					local dir = seg.."/pactrainer"
					local probe = io.open(dir.."/.probe", "w")
					if probe then
						probe:close()
						os.remove(dir.."/.probe")
						return dir
					end
					-- Try to create it
					os.execute('mkdir -p "'..dir..'" 2>/dev/null || mkdir "'..seg..'\\pactrainer" 2>NUL')
					probe = io.open(dir.."/.probe", "w")
					if probe then
						probe:close()
						os.remove(dir.."/.probe")
						return dir
					end
				end
			end
		end
		return plugin_path
	end

	local function detect_output_api()
		if output_api ~= nil then return end
		-- Newer MAME (~0.227+): mac.output:set_value(name, value)
		local ok, out = pcall(function() return mac.output end)
		if ok and out and out.set_value then
			output_api = "new"
			output_ok = true
			return
		end
		-- Older MAME: mac:outputs():set_value(name, value)
		ok, out = pcall(function() return mac:outputs() end)
		if ok and out and out.set_value then
			output_api = "old"
			output_ok = true
			return
		end
		output_api = "none"
		output_ok = false
	end

	local function set_output(name, value)
		if not output_ok then return end
		if output_api == "new" then
			pcall(function() mac.output:set_value(name, value) end)
		elseif output_api == "old" then
			pcall(function() mac:outputs():set_value(name, value) end)
		end
	end

	-- Fire a WAV file through the OS's native player, non-blocking. MAME's Lua API
	-- has no play-sound primitive, so this is a shell-out. Files live in
	-- <plugin_path>/sounds/<name>.wav; missing files silently no-op.
	local is_windows = package.config:sub(1, 1) == "\\" or os.getenv("OS") == "Windows_NT"
	local function play_sound_now(name)
		if not plugin_path or not name then return end
		local path = plugin_path.."/sounds/"..name..".wav"
		local probe = io.open(path, "r")
		if not probe then
			print("pactrainer: no sound file at "..path)
			return
		end
		probe:close()
		if scr then last_sound_frame = scr:frame_number() end
		local cmd
		if is_windows then
			-- On Windows: PowerShell's SoundPlayer.PlaySync() blocks until the WAV
			-- finishes. Wrapping in `start "" /min` detaches it so MAME isn't blocked.
			-- Using .Play() (async) here does not work: PowerShell exits immediately
			-- after Play() returns and the sound thread dies with the process.
			local win_path = string.gsub(path, "/", "\\")
			cmd = 'start "" /min powershell -NoProfile -WindowStyle Hidden -Command "(New-Object Media.SoundPlayer \''..win_path..'\').PlaySync()"'
		else
			-- Try common Unix players in order; the first that exists wins. `&` backgrounds.
			cmd = '(command -v afplay >/dev/null && afplay "'..path..'" || command -v paplay >/dev/null && paplay "'..path..'" || command -v aplay >/dev/null && aplay -q "'..path..'") >/dev/null 2>&1 &'
		end
		local ok, err = pcall(function() os.execute(cmd) end)
		if not ok then
			print("pactrainer: play_sound failed: "..tostring(err))
			print("pactrainer: attempted command: "..cmd)
		end
	end

	-- Public entry point. force=true means "priority" (fanfare): play immediately
	-- without queueing. Regular calls buffer in the queue and get released by
	-- process_sound_queue() one at a time on cooldown. `min_tier` marks a cue
	-- as stale if the player has since recovered to a better tier at release
	-- time — otherwise a tier_ok cue held over the cooldown would fire while
	-- you're already back to ACE and sound like the recovery caused it.
	local function play_sound(name, force, min_tier)
		if force then
			play_sound_now(name)
			return
		end
		if #sound_queue >= SOUND_QUEUE_MAX then return end
		local last = sound_queue[#sound_queue]
		if last and last.name == name then return end
		table.insert(sound_queue, {name=name, min_tier=min_tier})
	end

	local function process_sound_queue()
		if #sound_queue == 0 or not scr then return end
		if scr:frame_number() - last_sound_frame < SOUND_COOLDOWN_FRAMES then return end
		local item = table.remove(sound_queue, 1)
		if item.min_tier and tier_stable < item.min_tier then return end
		play_sound_now(item.name)
	end

	function pactrainer_initialize()
		if type(manager.machine) == "userdata" then
			mac = manager.machine
			plugin_path = manager.plugins["pactrainer"].directory
		else
			mac = manager:machine()
			plugin_path = manager:options().entries["pluginspath"]:value().."/pactrainer"
		end
		if mac then
			if emu.romname() == "pacman" or emu.romname() == "puckman" then
				cpu = mac.devices[":maincpu"]
				mem = cpu.spaces["program"]
				scr = mac.screens[":screen"]
				if not plugin_path then
					plugin_path = "plugins/pactrainer"
				end
				data_path = resolve_data_path()
				detect_output_api()
			--Suppress the error print as we may enable the plugin universally
			--else
			--	print("The Pac-Man trainer works only with 'pacman' and 'puckman' roms.")
			end
		end
	end

	-- Try reading active.dat from data_path first (writable), then fall back to plugin_path.
	local function read_active_folder()
		for _, base in ipairs({data_path, plugin_path}) do
			if base then
				local file = io.open(base.."/patterns/active.dat", "r")
				if not file then file = io.open(base.."/active.dat", "r") end
				if file then
					local val = file:read("*all")
					file:close()
					if val and #val > 2 then return val end
				end
			end
		end
		return nil
	end

	local function write_active_folder(name)
		if data_path then
			local file = io.open(data_path.."/active.dat", "w")
			if file then file:write(name); file:close(); return true end
		end
		local file = io.open(plugin_path.."/patterns/active.dat", "w")
		if file then file:write(name); file:close(); return true end
		return false
	end

	function pactrainer_patterns()
		local content, file, prev_line

		if not folder then
			folder = read_active_folder()
		end
		if not folder or #folder <= 2 then
			folder = get_next(SETS)
		end

		-- Each level can have a pattern but we want as few patterns as possible to help with learning
		-- If a pattern is not found then the previous level patterns is used.  This allows patterns to be grouped.
		-- Typically there will only be a few patterns like 1,2,3,4 are similar,  5-20 are all the same,  21+ are all the same
		pattern = {}
		group = {}
		for l=1, 256 do
			for g=1, 21 do
				file = io.open(plugin_path.."/patterns/"..folder.."/"..tostring(l).."_"..tostring(g)..".dat", "r")
				if file then
					valid = true
					-- store the starting level and group associated with the level
					group[l] = {l, g}

					local _i = 0
					for line in file:lines() do
						if line ~= prev_line then
							pattern[_i + (l * 100000)] = line
							_i = _i + 1
							prev_line = line
						end
					end
					file:close()
					break
				end
			end
			if group[l] == nil then
				group[l] = group[l - 1]  -- use previous pattern for this level
			end
		end
		perfect = string.find(folder, "perfect") ~= nil
		lag_pixels = LAG_PIXELS_DEFAULT + (perfect and 1 or 0)
		loaded = true
	end

	function pattern_toggle()
		-- Check for pattern change when P2 key press is detected
		if mode == 1 then
			if info[folder] then
				mac:popmessage(string.upper(folder).." patterns:\n"..info[folder].."\n(Push P2 to toggle)")
			else
				mac:popmessage(string.upper(folder).." patterns\n(Push P2 to toggle)")
			end
		end
		if scr:frame_number() > switch + 30 and string.sub(integer_to_binary(mem:read_u8(0x5040)), 2, 2) == "0" then
			folder = get_next(SETS, folder)
			pactrainer_patterns()
			if not(mode == 1 and state == 0) then
				mac:popmessage(string.upper(folder).." patterns will be active at next level start.")
			end
			switch = scr:frame_number()
			write_active_folder(folder)
		end
	end

	function reset()
		seq = 0
		failed, lagging, ignore, freestyle = false, false, false, false
		paty, patx = nil, nil
		lagx, lagy = nil, nil
		tier_raw, tier_stable, tier_hold = TIER_ACE, TIER_ACE, 0
		last_dir = nil
		sound_queue = {}
		last_record_seq = -MARKER_MIN_SEQ_GAP
		if scr then board_start_frame = scr:frame_number() end
		ghost_run_count = 0
		fright_start_frame = -1
		fanfare_fired = false
		-- Seed prev_score so the first read this board doesn't produce a huge delta.
		if mem then
			local b0 = mem:read_u8(0x4e80)
			local b1 = mem:read_u8(0x4e81)
			local b2 = mem:read_u8(0x4e82)
			local function bcd(b) return math.floor(b / 16) * 10 + (b % 16) end
			prev_score = bcd(b0) + bcd(b1) * 100 + bcd(b2) * 10000
		end
	end

	function write_bytes(address, b1, b2, b3, b4, b5)
		--write 5 bytes to video memory at starting address
		--horizontal text if offset by -0x20, vertical by 0x01
		if loaded then
			for k, v in ipairs({b1, b2, b3, b4, b5}) do
				if v then
					mem:write_u8(address - ((k - 1) * 0x20), v)
				end
			end
		end
	end

	function integer_to_binary(x)
		local ret = ""
		while x~=1 and x~=0 do
			ret = tostring(x%2) .. ret
			x=math.modf(x/2)
		end
		return string.format("%08d", tostring(x)..ret)
    end

	-- Read Pac-Man Player 1 score. Stored at 0x4E80-0x4E82 as BCD, low byte first.
	-- Each byte packs two decimal digits, so max representable is 999999 (game caps at 3333360).
	local function read_score()
		if not mem then return 0 end
		local b0 = mem:read_u8(0x4e80)  -- ones, tens
		local b1 = mem:read_u8(0x4e81)  -- hundreds, thousands
		local b2 = mem:read_u8(0x4e82)  -- ten-thousands, hundred-thousands
		local function bcd(b) return math.floor(b / 16) * 10 + (b % 16) end
		return bcd(b0) + bcd(b1) * 100 + bcd(b2) * 10000
	end

	local function compute_raw_tier()
		if failed then return TIER_FAIL end
		if lagging then return TIER_BAD end
		if lagx and lagy then
			local mx = math.max(lagx, lagy)
			if mx <= 1 then return TIER_ACE end
			return TIER_OK
		end
		return TIER_ACE
	end

	local function update_tier()
		local raw = compute_raw_tier()
		if raw ~= tier_raw then
			tier_raw = raw
			tier_hold = 1
		else
			tier_hold = tier_hold + 1
		end
		if tier_hold >= TIER_DEBOUNCE_FRAMES and tier_raw ~= tier_stable then
			local prev = tier_stable
			tier_stable = tier_raw
			return prev, tier_stable
		end
		return tier_stable, tier_stable
	end

	-- Wipe markers when the level number changes. Runs each frame; cheap when
	-- level is stable. Covers all cases the user cares about: level advance,
	-- new game (level resets to 1), and MAME restart (memory starts empty).
	local function refresh_markers_for_level()
		if markers_level ~= level then
			markers = {}
			markers_level = level
		end
	end

	local function record_breakpoint()
		if not pacx or not pacy or not seq then return end
		if seq - last_record_seq < MARKER_MIN_SEQ_GAP then return end
		refresh_markers_for_level()
		local sy = math.floor(pacy / MARKER_GRID) * MARKER_GRID
		local sx = math.floor(pacx / MARKER_GRID) * MARKER_GRID
		local key = sy..","..sx
		local m = markers[key]
		if m then
			m.count = m.count + 1
			m.seq = seq
			m.dir = last_dir or m.dir
		else
			markers[key] = {seq=seq, y=sy, x=sx, count=1, dir=last_dir}
		end
		last_record_seq = seq
	end

	-- Arrow shape as a set of relative rectangles {dy1, dx1, dy2, dx2} per direction.
	-- Each shape is a shaft rectangle plus a chevron head built from progressively
	-- narrower rectangles that taper to a 1px tip in the movement direction.
	local ARROW_SHAPES = {
		r = { {-1,-6,1,2},   {-3,2,3,3},   {-2,3,2,4},   {-1,4,1,5},   {0,5,0,7}   },
		l = { {-1,-2,1,6},   {-3,-3,3,-2}, {-2,-4,2,-3}, {-1,-5,1,-4}, {0,-7,0,-5} },
		d = { {-6,-1,2,1},   {2,-3,3,3},   {3,-2,4,2},   {4,-1,5,1},   {5,0,7,0}   },
		u = { {-2,-1,6,1},   {-3,-3,-2,3}, {-4,-2,-3,2}, {-5,-1,-4,1}, {-7,0,-5,0} },
	}

	local function draw_markers()
		if not markers or markers_level ~= level then return end
		for _, m in pairs(markers) do
			local alpha = math.min(255, 90 + m.count * 40)
			local color = (alpha * 0x1000000) + 0xff8000  -- amber, alpha scales with count
			-- Use the same (paty+15, patx-15) offset the path uses so the marker
			-- sits on the drawn path line, not off in gutter tiles.
			local cy, cx = m.y + 15, m.x - 15
			local shape = ARROW_SHAPES[m.dir]
			if shape then
				for _, r in ipairs(shape) do
					scr:draw_box(cy + r[1], cx + r[2], cy + r[3], cx + r[4], color, color)
				end
			else
				scr:draw_box(cy - 2, cx - 2, cy + 3, cx + 3, color, color)
			end
		end
	end

	-- Detect eating all four ghosts on one energizer.
	-- Uses score delta (200/400/800/1600 progression); resets when a new energizer is eaten.
	-- Pills-eaten (0x4E0E) increments by 1 for a dot and by 1 for an energizer, so we watch
	-- the score jump instead of trying to distinguish. When ghost_run_count hits 4, fire once.
	local function update_fanfare()
		if not mem or mode ~= 3 then return end
		local score = read_score()
		local delta = score - prev_score
		prev_score = score

		-- New fright period detection: sub-state briefly enters ghost-eat freeze range,
		-- but the cleanest signal is a +50 score jump (energizer) which starts a fright.
		if delta == 50 then
			ghost_run_count = 0
			fright_start_frame = scr:frame_number()
			fanfare_fired = false
			return
		end
		-- Fright period timeout - reset the count so a later ghost eat during a new
		-- energizer doesn't accidentally chain.
		if fright_start_frame >= 0 and scr:frame_number() - fright_start_frame > FRIGHT_WINDOW_FRAMES then
			ghost_run_count = 0
			fright_start_frame = -1
		end

		if delta == 200 or delta == 400 or delta == 800 or delta == 1600 then
			ghost_run_count = ghost_run_count + 1
			if delta == 1600 and not fanfare_fired then
				fanfare_fired = true
				play_sound("fanfare", true)  -- bypass cooldown; fanfare is rare
				mac:popmessage(FANFARE_LINES[math.random(#FANFARE_LINES)])
			end
		end
	end

	local function tier_name(t)
		if t == TIER_ACE then return "ACE" end
		if t == TIER_OK then return "OK" end
		if t == TIER_BAD then return "BAD" end
		return "FAIL"
	end

	local function on_tier_change(prev, curr)
		-- Fire on tier increase only (getting worse), rate limited.
		if curr <= prev then return end
		local now = scr:frame_number()
		if now - tier_cue_last_frame < TIER_CUE_RATE_FRAMES then return end
		tier_cue_last_frame = now
		-- Play tier_ok / tier_bad / tier_fail wav if present, plus a popmessage backup.
		-- Pass curr as min_tier so a delayed release gets cancelled if the
		-- player has recovered by then.
		play_sound("tier_"..string.lower(tier_name(curr)), false, curr)
		mac:popmessage("Tier: "..tier_name(curr))
	end

	function display_status()
		if loaded then
			local _sub = string.sub
			local _lev = string.format("%03d", level)
			local _grp = string.format("%02d", patgroup)
			local _lag, _s3, _s4, _s5

			--level info
			write_bytes(0x43ac, 0x4c, 0x25, tonumber(_sub(_lev, 1, 1)) + 0x30, tonumber(_sub(_lev, 2, 2)) + 0x30, tonumber(_sub(_lev, 3, 3)) + 0x30)
			--pattern info
			write_bytes(0x43b2, 0x50, 0x25, tonumber(_sub(_grp, 1, 1)) + 0x30, tonumber(_sub(_grp, 2, 2)) + 0x30, 0x40)
			--status info
			if mem:read_u8(0x40cc) ~= 0x53 then
				write_bytes(0x40cc, 0x53, 0x25, 0x41, 0x43, 0x45)
			end
			if lagx or lagy or failed then
				if lagging or failed then
					_s3, _s4, _s5 = 0x42, 0x41, 0x44
				else
					if lagx > lagy then _lag = lagx else _lag = lagy end
					if _lag <= 1 then
						_s3, _s4, _s5 = 0x41, 0x43, 0x45
					else
						_s3, _s4, _s5 = 0x4f, 0x4b, 0x40
					end
				end
				if scr:frame_number() % 30 == 0 then
					write_bytes(0x40cc, 0x53, 0x25, _s3, _s4, _s5)
				end
			end
			-- freestyle time or failed (flash on fail)
			if freestyle then
				write_bytes(0x40cc, 0x53, 0x25, 0x46, 0x3a, 0x53)
				write_bytes(0x40b2, 0x46, 0x52, 0x45, 0x45)
			elseif failed then
				if scr:frame_number() % 40 < 20 then
					write_bytes(0x40b2, 0x46, 0x41, 0x49, 0x4c)
				else
					write_bytes(0x40b2, 0x40, 0x40, 0x40, 0x40)
				end
			end
		end
	end

	function pactrainer_main()
		if mem and not mac.paused then
			if not loaded then
				if  scr:frame_number() > 300 then
					-- Load patterns after pacman has fully booted
					pactrainer_patterns()
					if not valid then
						print("Patterns are not found")
						mac:exit()
					end
				end
			else
				mode = mem:read_u8(0x4e00)
				state = mem:read_u8(0x4e04)
				pacx = mem:read_u8(0x4d09)
				pacy = mem:read_u8(0x4d08)
				level = mem:read_u8(0x4e13) + 1
				pills = mem:read_u8(0x4e0e)

				pattern_toggle()

				if mode == 3 then
					patid, patgroup = group[level][1], group[level][2]

					if (state == 3 and oldstate ~= 3) or state == 36 then
						reset()
					end

					if state == 3 then
						if seq == 0 and pills > 0 then
							failed = true
							seq = 99999
						end
					end

					if not failed then
						first = true
						adjusted = false
						local found_pat = false

						data = pattern[(patid * 100000) + seq]

						--Debugging---------
						--print(data)
						--ignore = true
						--print(pacy, pacx)
						--------------------

						-- Perfect pattern folders should include the term perfect
						-- We won't adjust the path as all ghosts are intended to be eaten
						if perfect then
							ignore = true
						end

						if not (state > 12 and state < 36) then

							if data == "------" then
								-- Ignore lagging behind when turning back on self
								ignore = true
								data = nil
							elseif data == "++++++" then
								-- Reactivate lagging
								ignore = false
								data = nil
							elseif data == "######" then
								-- For partial patterns, turn the path yellow to indicate freestyle to complete the board
								freestyle = true
								data = nil
							elseif data and #data > 6 and string.sub(data, 1, 6) == "REMARK" then
								-- Display an instruction to assist at current pattern position
								mac:popmessage(string.sub(data, 8, #data))
								data = nil
							end

							for _f = seq + 80, seq, -1 do
								local data = pattern[(patid * 100000) + _f]
								if data then
									local py, px = tonumber(string.sub(data, 1, 3)), tonumber(string.sub(data, 4, 6))
									if py and px then
										paty, patx = py, px
										found_pat = true
										if (seq - _f) % 5 == 0 then
											-- draw every 5th line segment

											local _color = GREEN
											if freestyle then
												_color = YELLOW
											elseif lagging then
												_color = RED
											end
											scr:draw_box(paty+15, patx-15, paty+16, patx-16, _color, _color)
											if first then
												scr:draw_box(paty+14, patx-14, paty+17, patx-17, _color, _color)
												first = false
											end
										end
										if not ignore and state == 3 and patx == pacx and paty == pacy and _f - seq > 0 then
											-- Pacman has speeded ahead of pattern (by eating a ghost).  Make an adjustment.
											seq = seq + (_f - seq)
											adjusted = true
										end
									end
								end
							end

							-- Clear stale pattern coords when the lookup window ran off the end
							-- of the pattern. Otherwise paty/patx keep the final coords forever
							-- and the lag check flags a spurious BAD once the player walks away.
							if not found_pat then
								paty, patx = nil, nil
								lagx, lagy = nil, nil
							end

							if state == 3 and (pacx ~= oldpacx or pacy ~= oldpacy) then
								seq = seq + 1
							end

							if state == 3 and paty and patx then
								if state == 3 and (not adjusted and not ignore) or perfect then
									-- Are we behind the pattern?
									lagx = math.abs(patx - pacx)
									lagy = math.abs(paty - pacy)
									if (lagx >= lag_pixels and lagx < 100) or lagy >= lag_pixels then
										lagging = true
									end
								end
							end

							-- Track direction while pac-man is moving. Sticky: keeps the
							-- last known direction across frames where Pac-Man is momentarily
							-- stopped (e.g. hitting a wall). Must run BEFORE oldpac* update.
							if oldpacx and oldpacy then
								local dx, dy = pacx - oldpacx, pacy - oldpacy
								if math.abs(dx) > math.abs(dy) then
									if dx > 0 then last_dir = "r"
									elseif dx < 0 then last_dir = "l" end
								elseif math.abs(dy) > 0 then
									if dy > 0 then last_dir = "d"
									else last_dir = "u" end
								end
							end

							oldpacx, oldpacy = pacx, pacy
						end
					end

					-- Debounced tier drives features 1 (map), 2 (face), 3 (cue).
					-- Skip advancing tier during the ghost-eat freeze so we don't
					-- record a false drop from held lag values.
					if not (state > 12 and state < 36) then
						local prev_tier, curr_tier = update_tier()
						if prev_tier ~= curr_tier then
							if prev_tier == TIER_ACE and curr_tier >= TIER_OK and curr_tier ~= TIER_FAIL then
								-- Record where the player dropped from ACE
								record_breakpoint()
							end
							on_tier_change(prev_tier, curr_tier)
						end
					end
					set_output("pactrainer_face", tier_stable)

					-- Keep marker set fresh for the current level, then render.
					refresh_markers_for_level()
					draw_markers()

					-- Four-ghost fanfare detection
					update_fanfare()

					-- Release one queued sound if the cooldown has expired.
					process_sound_queue()

					display_status()
				else
					reset()
				end
				oldstate = state
			end
		end
	end

	if emu.app_version() >= "0.256" then
		pactrainer_postload = emu.add_machine_post_load_notifier(reset)
		pactrainer_initialize = emu.add_machine_reset_notifier(pactrainer_initialize)
	else
		emu.register_start(function() reset() end)
		emu.register_prestart(function() pactrainer_initialize() end)
	end

	emu.register_frame_done(function() pactrainer_main() end)

end
return exports
