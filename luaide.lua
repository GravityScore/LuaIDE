
--  
--  Lua IDE
--  Made by GravityScore and 1lann
--  


-- To Do:
-- - Fix/Test updating
-- - Highlighting disappears as scrollx increases

-- 1.1:
-- - Print file


--  -------- Variables

-- Version
local version = "1.0"
local args = {...}

-- Updating
local autoupdate = true

-- Editing
local w, h = term.getSize()
local highlightSyntax = true
local tabWidth = 2

local autosaveInterval = 20
local allowEditorEvent = true
local keyboardShortcutTimeout = 0.4

-- Clipboard
local clipboard = nil

-- Theme
local theme = {}

-- Events
local event_distract = "luaide_distractionEvent"

-- Locations
local updateURL = "https://raw.github.com/GravityScore/LuaIDE/master/luaide.lua"
local ideLocation = "/" .. shell.getRunningProgram()


--  -------- Theme

local defaultTheme = {
	background = "gray",
	backgroundHighlight = "lightGray",
	prompt = "cyan",
	promptHighlight = "lightBlue",
	err = "pink",
	errHighlight = "red",

	editorBackground = "gray",
	editorLineHightlight = "lightBlue",
	editorLineNumbers = "gray",
	editorLineNumbersHighlight = "lightGray",
	editorError = "pink",
	editorErrorHighlight = "red",

	textColor = "white",
	conditional = "yellow",
	constant = "orange",
	["function"] = "cyan",
	string = "red",
	comment = "lime"
}

-- Load theme
theme = defaultTheme


--  -------- Drawing

local function centerPrint(text, ny)
	local x, y = term.getCursorPos()
	term.setCursorPos(math.ceil(w/2 - text:len()/2) + 1, ny or y)
	print(text)
end

local function title(t)
	term.setTextColor(colors[theme.textColor])
	term.setBackgroundColor(colors[theme.background])
	term.clear()

	term.setBackgroundColor(colors[theme.backgroundHighlight])
	for i = 2, 4 do term.setCursorPos(1, i) term.clearLine() end
	term.setCursorPos(3, 3)
	term.write(t)
end

local function centerRead(wid, begt)
	if not begt then begt = "" end
	term.setTextColor(colors[theme.textColor])
	term.setBackgroundColor(colors[theme.promptHighlight])
	for i = 8, 10 do
		term.setCursorPos(w/2 - wid/2, i)
		term.write(string.rep(" ", wid))
	end
	term.setCursorPos(w/2 - wid/2 + 1, 9)
	term.write("> " .. begt)
	return read():gsub("^%s*(.-)%s*$", "%1")
end


--  -------- Prompt

local function prompt(list, dir)
	local function draw(sel)
		for i, v in ipairs(list) do
			if i == sel then term.setBackgroundColor(v.highlight or colors[theme.promptHighlight])
			else term.setBackgroundColor(v.bg or colors[theme.prompt]) end
			term.setTextColor(v.tc or colors[theme.textColor])
			for i = -1, 1 do
				term.setCursorPos(v[2], v[3] + i)
				term.write(string.rep(" ", v[1]:len() + 4))
			end

			term.setCursorPos(v[2], v[3])
			if i == sel then 
				term.setBackgroundColor(v.highlight or colors[theme.promptHighlight])
				term.write(" > ")
			else term.write(" - ") end
			term.write(v[1] .. " ")
		end
	end

	local key1 = 200
	if dir == "horizontal" then key1 = 203 end
	local key2 = 208
	if dir == "horizontal" then key2 = 205 end

	local sel = 1
	draw(sel)

	while true do
		local e, but, x, y = os.pullEvent()
		if e == "key" and but == 28 then
			return list[sel][1]
		elseif e == "key" and but == key1 and sel > 1 then
			sel = sel - 1
			draw(sel)
		elseif e == "key" and but == key2 and ((err == true and sel < #list - 1) or (sel < #list)) then
			sel = sel + 1
			draw(sel)
		elseif e == "mouse_click" then
			for i, v in ipairs(list) do
				if x >= v[2] and x <= v[2] + v[1]:len() + 2 and y == v[3] then
					return list[i][1]
				end
			end
		end
	end
end

local function scrollingPrompt(list)
	local function draw(items, sel)
		for i, v in ipairs(items) do
			local bg = colors[theme.prompt]
			local bghigh = colors[theme.promptHighlight]
			if v:find("Back") or v:find("Return") then
				bg = colors[theme.err]
				bghigh = colors[theme.errHighlight]
			end

			if i == sel then term.setBackgroundColor(bghigh)
			else term.setBackgroundColor(bg) end
			term.setTextColor(colors[theme.textColor])
			for x = -1, 1 do
				term.setCursorPos(3, (i * 4) + x + 4)
				term.write(string.rep(" ", w - 13))
			end

			term.setCursorPos(3, i * 4 + 4)
			if i == sel then 
				term.setBackgroundColor(bghigh)
				term.write(" > ")
			else term.write(" - ") end
			term.write(v .. " ")
		end
	end

	local function updateDisplayList(items, loc, len)
		local ret = {}
		for i = 1, len do
			local item = items[i + loc - 1]
			if item then table.insert(ret, item) end
		end
		return ret
	end

	-- Variables
	local sel = 1
	local loc = 1
	local len = 3
	local disList = updateDisplayList(list, loc, len)
	draw(disList, sel)

	-- Loop
	while true do
		local e, key, x, y = os.pullEvent()

		if e == "mouse_click" then
			for i, v in ipairs(disList) do
				if x >= 3 and x <= w - 13 and y == i * 4 + 5 then
					return v
				end
			end
		elseif e == "key" and key == 200 then
			if sel > 1 then 
				sel = sel - 1 
				draw(disList, sel)
			elseif loc > 1 then
				loc = loc - 1
				disList = updateDisplayList(list, loc, len)
				draw(disList, sel)
			end
		elseif e == "key" and key == 208 then
			if sel < len then 
				sel = sel + 1 
				draw(disList, sel)
			elseif loc + len - 1 < #list then
				loc = loc + 1
				disList = updateDisplayList(list, loc, len)
				draw(disList, sel)
			end
		elseif e == "key" and key == 28 then
			return disList[sel]
		end
	end
end

function monitorKeyboardShortcuts()
	local sTimer, seTimer = nil, nil
	local allowChar = false
	local shiftPressed = false
	while true do
		local event, char = os.pullEvent()
		if event == "key" and char == 42 then
			shiftPressed = true
			seTimer = os.startTimer(keyboardShortcutTimeout)
		elseif event == "key" and char == 29 then
			allowEditorEvent = false
			allowChar = true
			sTimer = os.startTimer(keyboardShortcutTimeout)
		elseif event == "key" and allowChar then
			local name = nil
			for k, v in pairs(keys) do
				if v == char then
					if shiftPressed then os.queueEvent("shortcut", "ctrl shift", k:lower())
					else os.queueEvent("shortcut", "ctrl", k:lower()) end
					sleep(0.01)
					allowEditorEvent = true
				end
			end
		elseif event == "timer" and char == sTimer then
			allowEditorEvent = true
			allowChar = false
		elseif event == "timer" and char == seTimer then
			shiftPressed = false
		end
	end
end


--  -------- Saving and Loading

local function saveFile(path, lines)
	-- Create encasing directories
	local dir = path:sub(1, path:len() - fs.getName(path):len())
	if not(fs.exists(dir)) then fs.makeDir(dir) end

	-- Save
	if not fs.isDir(path) and not fs.isReadOnly(path) then
		local a = ""
		for _, v in pairs(lines) do a = a .. v .. "\n" end

		local f = io.open(path, "w")
		f:write(a)
		f:close()
		return true
	else return false end
end

local function loadFile(path)
	-- If doesn't exist
	if not fs.exists(path) then
		local f = io.open(path, "w")
		f:write("")
		f:close()
	end

	-- Load
	local l = {}
	if fs.exists(path) and not fs.isDir(path) then
		local f = io.open(path, "r")
		if f then
			local a = f:read("*l")
			while a do
				table.insert(l, a)
				a = f:read("*l")
			end
			f:close()
		end
	else return nil end

	-- Return
	if #l < 1 then table.insert(l, "") end
	return l
end


--  -------- Compiler Errors

-- Error syntax:
-- {filename = "test", line = 4, display = "End Expected", err = "test:4: end expected"}

local helpTips = {
	"A function you tried to call doesn't exist.",
	"You made a typo.",
	"The index of an array is nil.",
	"The wrong variable type was passed.",
	"A function/variable doesn't exist.",
	"You missed an 'end'.",
	"You missed a 'then'.",
}

local errors = {
	["Attempt to call nil."] = {1, 2},
	["Attempt to index nil."] = {3, 2},
	[".+ expected, got .+"] = {4, 2},
	["'end' expected"] = {6, 2},
	["'then' expected"] = {7, 2}
}

local function parseError(e)
	local ret = {filename = "unknown", line = -1, display = "Unknown!", err = e}
	ret.filename = e:sub(1, e:find(":") - 1)
	e = e:sub(e:find(":") + 1) .. "" -- The "" is needed to circumvent a CC bug
	ret.line = e:sub(1, e:find(":") - 1)
	e = e:sub(e:find(":") + 2):gsub("^%s*(.-)%s*$", "%1") .. ""
	ret.display = e:sub(1, 1):upper() .. e:sub(2) .. "."

	return ret
end

local function viewErrorHelp(e)
	title("LuaIDE - Error Help")

	local defTips = {2, 5}
	local tips = nil
	for k, v in pairs(errors) do
		if e.display:find(k) then tips = v break end
	end

	term.setBackgroundColor(colors[theme.err])
	for i = 6, 8 do
		term.setCursorPos(5, i)
		term.write(string.rep(" ", 35))
	end

	term.setBackgroundColor(colors[theme.prompt])
	for i = 10, 18 do
		term.setCursorPos(5, i)
		term.write(string.rep(" ", 46))
	end

	if tips then
		term.setBackgroundColor(colors[theme.err])
		term.setCursorPos(6, 7)
		term.write("Error Help")

		for i, v in ipairs(tips) do
			term.setCursorPos(7, i + 10)
			term.write("- " .. helpTips[v])
		end
	else
		term.setBackgroundColor(colors[theme.err])
		term.setCursorPos(6, 7)
		term.write("No Error Tips Available!")

		term.setBackgroundColor(colors[theme.prompt])
		term.setCursorPos(6, 11)
		term.write("There are no error tips available, but")
		term.setCursorPos(6, 12)
		term.write("you could see if it was any of these:")

		for i, v in ipairs(defTips) do
			term.setCursorPos(7, i + 12)
			term.write("- " .. helpTips[v])
		end
	end

	prompt({{"Back", w - 8, 7}}, "horizontal")
end

local function getCompilerErrors(code)

end


--  -------- Running

local function run(path, lines, useArgs)
	local ar = {}
	if useArgs then
		title("LuaIDE - Run " .. fs.getName(path))
		local s = centerRead(w - 13, fs.getName(path) .. " ")
		for m in string.gmatch(s, "[^ \t]+") do ar[#ar + 1] = m:gsub("^%s*(.-)%s*$", "%1") end
	end

	
	saveFile(path, lines)
	term.setCursorBlink(false)
	term.setBackgroundColor(colors.black)
	term.setTextColor(colors.white)
	term.clear()
	term.setCursorPos(1, 1)
	local fn, err = loadfile(path)
	setfenv(fn, getfenv())
	if not err then
		_, err = pcall(function() fn(unpack(ar)) end)
	end

	term.setBackgroundColor(colors.black)
	term.setTextColor(colors.white)
	print("\n")
	centerPrint("Press any key to return to LuaIDE...")
	while true do
		local e = os.pullEvent()
		if e == "mouse_click" or e == "key" then break end
	end

	-- To prevent key from showing up in editor
	os.queueEvent(event_distract)
	os.pullEvent()

	if err then
		while true do
			title("LuaIDE - Error! D:")

			term.setBackgroundColor(colors[theme.err])
			for i = 6, 8 do
				term.setCursorPos(5, i)
				term.write(string.rep(" ", 40))
			end
			term.setCursorPos(6, 7)
			term.write("The program has crashed! D:")

			term.setBackgroundColor(colors[theme.prompt])
			for i = 10, 14 do
				term.setCursorPos(5, i)
				term.write(string.rep(" ", 40))
			end
			local formattedErr = parseError(err)
			term.setCursorPos(6, 11)
			term.write("Line: " .. formattedErr.line)
			term.setCursorPos(6, 12)
			term.write("Error:")
			term.setCursorPos(7, 13)
			term.write(formattedErr.display)
			
			local opt = prompt({{"Error Help", w/2 - 15, 17}, {"Go To Line", w/2 + 2, 17}}, 
				"horizontal")
			if opt == "Error Help" then
				viewErrorHelp(formattedErr)
			elseif opt == "Go To Line" then
				-- To prevent key from showing up in editor
				os.queueEvent(event_distract)
				os.pullEvent()

				return "go to", tonumber(formattedErr.line)
			end
		end
	end
end


--  -------- Functions

local function goto()
	term.setBackgroundColor(colors[theme.backgroundHighlight])
	term.setCursorPos(2, 1)
	term.clearLine()
	term.write("Line: ")
	local line = read():gsub("^%s*(.-)%s*$", "%1")

	local num = tonumber(line)
	if num and num > 0 then return num
	else
		term.setCursorPos(2, 1)
		term.clearLine()
		term.write("Not a line number!")
		sleep(1.6)
		return nil
	end
end

--[[local incrementIndent = {"if", "do", "repeat", "function"}
local decrementIndent = {"end", "until"}
local specialIndent = {"elseif", "else"}

local function reindent(l)
	if highlightSyntax then
		local ret = {}
		local curIndent = 0

		for i, v in ipairs(l) do
			-- Remove and add
			ret[i] = v:gsub("^%s*(.-)", "%1")
			--ret[i] = string.rep(" ", curIndent * tabWidth) .. ret[i]
		end

		return ret
	else
		return l
	end
end]]


--  -------- Menu

local keywords = {
	["and"] = "conditional",
	["break"] = "conditional",
	["do"] = "conditional",
	["else"] = "conditional",
	["elseif"] = "conditional",
	["end"] = "conditional",
	["for"] = "conditional",
	["function"] = "conditional",
	["if"] = "conditional",
	["in"] = "conditional",
	["local"] = "conditional",
	["not"] = "conditional",
	["or"] = "conditional",
	["repeat"] = "conditional",
	["return"] = "conditional",
	["then"] = "conditional",
	["until"] = "conditional",
	["while"] = "conditional",
	["pairs"] = "conditional",
	["ipairs"] = "conditional",

	["true"] = "constant",
	["false"] = "constant",
	["nil"] = "constant",

	["(?![\.:])print"] = "function",
	["(?![\.:])write"] = "function",
	["sleep"] = "function",
	["loadstring"] = "function",
	["loadfile"] = "function",
	["dofile"] = "function",
	["rawset"] = "function",
	["rawget"] = "function",
	["setfenv"] = "function",
	["getfenv"] = "function",
}

local menu = {
	[1] = {"File",
		"New File  ^+N",
		"Open File ^+O",
		"Save File ^+S",
		"Close     ^+W",
		"Print     ^+P",
		"Quit      ^+Q"
	}, [2] = {"Edit",
		"Cut Line   ^+X",
		"Copy Line  ^+C",
		"Paste Line ^+V",
		"Delete Line",
		"Clear Line"
	}, [3] = {"Functions",
		"Go To Line   ^+G",
		"Re-Indent    ^+I",
		"Toggle Colouring"
	}, [4] = {"Run",
		"Run Program       ^+R",
		"Run w/ Args ^+Shift+R"
	}
}

local shortcuts = {
	-- File
	["ctrl n"] = "New File  ^+N",
	["ctrl o"] = "Open File ^+O",
	["ctrl s"] = "Save File ^+S",
	["ctrl w"] = "Close     ^+W",
	["ctrl p"] = "Print     ^+P",
	["ctrl q"] = "Quit      ^+Q",

	-- Edit
	["ctrl x"] = "Cut Line   ^+X",
	["ctrl c"] = "Copy Line  ^+C",
	["ctrl v"] = "Paste Line ^+V",
	["0"] = "Delete Line",
	["0"] = "Clear Line",

	-- Functions
	["ctrl g"] = "Go To Line   ^+G",
	["ctrl i"] = "Re-Indent    ^+I",
	["0"] = "Toggle Colouring",

	-- Run
	["ctrl r"] = "Run Program       ^+R",
	["ctrl shift r"] = "Run w/ Args ^+Shift+R"
}

local menuFunctions = {
	-- File
	["New File  ^+N"] = function(path, lines) saveFile(path, lines) return "new" end,
	["Open File ^+O"] = function(path, lines) saveFile(path, lines) return "open" end,
	["Save File ^+S"] = function(path, lines) saveFile(path, lines) end,
	["Close     ^+W"] = function(path, lines) saveFile(path, lines) return "menu" end,
	["Print     ^+P"] = function(path, lines) saveFile(path, lines) return "not implemented" end,
	["Quit      ^+Q"] = function(path, lines) saveFile(path, lines) return "exit" end,

	-- Edit
	["Cut Line   ^+X"] = function(path, lines, y) 
		clipboard = lines[y] table.remove(lines, y) return nil, lines end,
	["Copy Line  ^+C"] = function(path, lines, y) clipboard = lines[y] end,
	["Paste Line ^+X"] = function(path, lines, y) 
		table.insert(lines, y, clipboard) return nil, lines end,
	["Delete Line"] = function(path, lines, y) table.remove(lines, y) return nil, lines end,
	["Clear Line"] = function(path, lines, y) lines[y] = "" return nil, lines, "cursor" end,

	-- Functions
	["Go To Line   ^+G"] = function() return nil, "go to", goto() end,
	["Re-Indent    ^+I"] = function(path, lines) 
		local a = reindent(lines) saveFile(path, lines) return "not implemented" end,
	["Toggle Colouring"] = function() highlightSyntax = not highlightSyntax end,

	-- Run
	["Run Program       ^+R"] = function(path, lines) 
		saveFile(path, lines) 
		return nil, run(path, lines, false)
	end,
	["Run w/ Args ^+Shift+R"] = function(path, lines) 
		saveFile(path, lines) 
		return nil, run(path, lines, true) 
	end,
}

local function drawMenu(open)
	term.setCursorPos(1, 1)
	term.setTextColor(colors[theme.textColor])
	term.setBackgroundColor(colors[theme.backgroundHighlight])
	term.clearLine()
	local curX = 0
	for _, v in pairs(menu) do
		term.setCursorPos(3 + curX, 1)
		term.write(v[1])
		curX = curX + v[1]:len() + 3
	end

	if open then
		local it = {}
		local x = 1
		for _, v in pairs(menu) do
			if open == v[1] then 
				it = v
				break
			end
			x = x + v[1]:len() + 3
		end
		x = x + 1

		local items = {}
		for i = 2, #it do
			table.insert(items, it[i])
		end

		local len = 1
		for _, v in pairs(items) do
			if v:len() + 2 > len then len = v:len() + 2 end
		end

		for i, v in ipairs(items) do
			term.setCursorPos(x, i + 1)
			term.write(string.rep(" ", len))
			term.setCursorPos(x + 1, i + 1)
			term.write(v)
		end
		term.setCursorPos(x, #items + 2)
		term.write(string.rep(" ", len))
		return items, len
	end
end

local function triggerMenu(cx, cy)
	-- Determine clicked menu
	local curX = 0
	local open = nil
	for _, v in pairs(menu) do
		if cx >= curX + 3 and cx <= curX + v[1]:len() + 2 then 
			open = v[1]
			break
		end
		curX = curX + v[1]:len() + 3
	end
	local menux = curX + 2
	if not open then return false end

	-- Flash menu item
	term.setCursorBlink(false)
	term.setCursorPos(menux, 1)
	term.setBackgroundColor(colors[theme.background])
	term.write(string.rep(" ", open:len() + 2))
	term.setCursorPos(menux + 1, 1)
	term.write(open)
	sleep(0.1)
	local items, len = drawMenu(open)

	local ret = true

	-- Pull events on menu
	local ox, oy = term.getCursorPos()
	while type(ret) ~= "string" do
		local e, but, x, y = os.pullEvent()
		if e == "mouse_click" then
			-- If clicked outside menu
			if x < menux - 1 or x > menux + len - 1 then break
			elseif y > #items + 2 then break
			elseif y == 1 then break end

			for i, v in ipairs(items) do
				if y == i + 1 and x >= menux and x <= menux + len - 2 then
					-- Flash when clicked
					term.setCursorPos(menux, y)
					term.setBackgroundColor(colors[theme.background])
					term.write(string.rep(" ", len))
					term.setCursorPos(menux + 1, y)
					term.write(v)
					sleep(0.1)
					drawMenu(open)

					-- Return item
					ret = v
					break
				end
			end
		end
	end

	term.setCursorPos(ox, oy)
	term.setCursorBlink(true)
	return ret
end


--  -------- Editing

local x, y = 0, 0
local edw, edh = 0, h - 1
local offx, offy = 0, 1
local scrollx, scrolly = 0, 0
local lines = {}

local function attemptToHighlight(line, regex, col)
	local match = string.match(line, regex)
	if match then
		if type(col) == "number" then term.setTextColor(col)
		elseif type(col) == "function" then term.setTextColor(col(match)) end
		term.write(match)
		term.setTextColor(colors[theme.textColor])
		return line:sub(match:len() + 1, -1)
	end
	return nil
end

local function writeHighlighted(line)
	if highlightSyntax then
		while line:len() > 0 do	
			line = attemptToHighlight(line, "^%-%-%[%[.-%]%]", colors[theme.comment]) or
				attemptToHighlight(line, "^%-%-.*", colors[theme.comment]) or
				attemptToHighlight(line, "^\".-[^\\]\"", colors[theme.string]) or
				attemptToHighlight(line, "^\'.-[^\\]\'", colors[theme.string]) or
				attemptToHighlight(line, "^%[%[.-%]%]", colors[theme.string]) or
				attemptToHighlight(line, "^[%w_]+", function(match)
					if keywords[match] then return colors[theme[keywords[match]]] end
					return colors[theme.textColor]
				end) or
				attemptToHighlight(line, "^[^%w_]", colors[theme.textColor])
		end
	else term.write(line) end
end

local function draw()
	-- Menu
	term.setTextColor(colors[theme.textColor])
	term.setBackgroundColor(colors[theme.editorBackground])
	term.clear()
	drawMenu()

	-- Line numbers
	offx, offy = tostring(#lines):len() + 1, 1
	edw, edh = w - offx, h - 1

	-- Draw text
	for i = 1, edh do
		local a = lines[scrolly + i]
		if a then
			local ln = string.rep(" ", offx - 1 - tostring(scrolly + i):len()) .. 
				tostring(scrolly + i) .. ":"
			local l = a:sub(scrollx + 1, edw + scrollx + 1)

			term.setCursorPos(1, i + offy)
			if scrolly + i == y then 
				term.setBackgroundColor(colors[theme.editorLineHightlight])
				term.clearLine()
			end

			term.setCursorPos(1, i + offy)
			if scrolly + i == y then term.setBackgroundColor(colors[theme.editorLineNumbersHighlight])
			else term.setBackgroundColor(colors[theme.editorLineNumbers]) end
			term.write(ln)

			if scrolly + i == y then term.setBackgroundColor(colors[theme.editorLineHightlight])
			else term.setBackgroundColor(colors[theme.editorBackground]) end
			writeHighlighted(l)
		end
	end
end

local function drawLine(...)
	local ls = {...}
	offx = tostring(#lines):len() + 1
	for _, ly in pairs(ls) do
		local a = lines[ly]
		if a then
			local ln = string.rep(" ", offx - 1 - tostring(ly):len()) .. 
				tostring(ly) .. ":"
			local l = a:sub(scrollx + 1, edw + scrollx + 1)

			term.setCursorPos(1, ly - scrolly + offy)
			if ly == y then term.setBackgroundColor(colors[theme.editorLineHightlight])
			else term.setBackgroundColor(colors[theme.editorBackground]) end
			term.clearLine()

			term.setCursorPos(1, ly - scrolly + offy)
			if ly == y then term.setBackgroundColor(colors[theme.editorLineNumbersHighlight])
			else term.setBackgroundColor(colors[theme.editorLineNumbers]) end
			term.write(ln)

			if ly == y then term.setBackgroundColor(colors[theme.editorLineHightlight])
			else term.setBackgroundColor(colors[theme.editorBackground]) end
			writeHighlighted(l)
		end
	end
end

local function cursorLoc(x, y, force)
	local sx, sy = x - scrollx, y - scrolly
	local redraw = false
	if sx < 1 then
		scrollx = x - 1
		sx = 1
		redraw = true
	elseif sx > edw then
		scrollx = x - edw
		sx = edw
		redraw = true
	end if sy < 1 then
		scrolly = y - 1
		sy = 1
		redraw = true
	elseif sy > edh then
		scrolly = y - edh
		sy = edh
		redraw = true
	end if redraw or force then 
		draw() 
	end
	term.setCursorPos(sx + offx, sy + offy)
end

local function executeMenuItem(a, path)
	if type(a) == "string" and menuFunctions[a] then
		local opt, nl, gtln = menuFunctions[a](path, lines, y)
		if type(opt) == "string" then term.setCursorBlink(false) return opt end
		if type(nl) == "table" then
			if #lines < 1 then table.insert(lines, "") end
			y = math.min(y, #lines)
			x = math.min(x, lines[y]:len() + 1)
			lines = nl
		elseif type(nl) == "string" then
			if nl == "go to" and gtln then
				x, y = 1, math.min(#lines, gtln)
				cursorLoc(x, y)
			end
		end
	end
	term.setCursorBlink(true)
	draw()
	term.setCursorPos(x - scrollx + offx, y - scrolly + offy)
end

local function edit(path)
	-- Variables
	x, y = 1, 1
	offx, offy = 0, 1
	scrollx, scrolly = 0, 0
	lines = loadFile(path)
	if not lines then return "menu" end

	-- Clocks
	local autosaveClock = os.clock()
	local scrollClock = os.clock() -- To prevent redraw flicker

	-- Draw
	draw()
	term.setCursorPos(x + offx, y + offy)
	term.setCursorBlink(true)
	
	-- Main loop
	while true do
		local e, key, cx, cy = os.pullEvent()
		if e == "key" and allowEditorEvent then
			if key == 200 and y > 1 then
				-- Up
				x, y = math.min(x, lines[y - 1]:len() + 1), y - 1
				drawLine(y, y + 1)
				cursorLoc(x, y)
			elseif key == 208 and y < #lines then
				-- Down
				x, y = math.min(x, lines[y + 1]:len() + 1), y + 1
				drawLine(y, y - 1)
				cursorLoc(x, y)
			elseif key == 203 and x > 1 then
				-- Left
				x = x - 1
				local force = false
				if y - scrolly + offy < offy + 1 then force = true end
				cursorLoc(x, y, force)
			elseif key == 205 and x < lines[y]:len() + 1 then
				-- Right
				x = x + 1
				local force = false
				if y - scrolly + offy < offy + 1 then force = true end
				cursorLoc(x, y, force)
			elseif key == 28 or key == 156 then
				-- Enter
				local _, spaces = lines[y]:find("^[ ]+")
				if not spaces then spaces = 0 end
				local oldLine = lines[y]

				lines[y] = lines[y]:sub(1, x - 1)
				table.insert(lines, y + 1, string.rep(" ", spaces) .. oldLine:sub(x, -1))

				x, y = spaces + 1, y + 1
				drawLine(y, y - 1)
				cursorLoc(x, y, true)
			elseif key == 14 then
				-- Backspace
				if x > 1 then
					lines[y] = lines[y]:sub(1, x - 2) .. lines[y]:sub(x, -1)
					drawLine(y)
					x = x - 1
					cursorLoc(x, y)
				elseif y > 1 then
					local prevLen = lines[y - 1]:len() + 1
					lines[y - 1] = lines[y - 1] .. lines[y]
					table.remove(lines, y)
					x, y = prevLen, y - 1
					drawLine(y + 1, y)
					cursorLoc(x, y, true)
				end
			elseif key == 199 then
				-- Home
				x = 1
				local force = false
				if y - scrolly + offy < offy + 1 then force = true end
				cursorLoc(x, y, force)
			elseif key == 207 then
				-- End
				x = lines[y]:len() + 1
				local force = false
				if y - scrolly + offy < offy + 1 then force = true end
				cursorLoc(x, y, force)
			elseif key == 211 then
				-- Forward Delete
				if x < lines[y]:len() + 1 then
					lines[y] = lines[y]:sub(1, x - 1) .. lines[y]:sub(x + 1)
					local force = false
					if y - scrolly + offy < offy + 1 then force = true end
					drawLine(y)
					cursorLoc(x, y, force)
				elseif y < #lines then
					lines[y] = lines[y] .. lines[y + 1]
					table.remove(lines, y + 1)
					draw()
					cursorLoc(x, y)
				end
			elseif key == 15 then
				-- Tab
				lines[y] = string.rep(" ", tabWidth) .. lines[y]
				x = x + 2
				local force = false
				if y - scrolly + offy < offy + 1 then force = true end
				drawLine(y)
				cursorLoc(x, y, force)
			end
		elseif e == "char" and allowEditorEvent then
			lines[y] = lines[y]:sub(1, x - 1) .. key .. lines[y]:sub(x, -1)
			x = x + key:len()
			local force = false
			if y - scrolly + offy < offy + 1 then force = true end
			drawLine(y)
			cursorLoc(x, y, force)
		elseif e == "mouse_click" and key == 1 then
			if cy > 1 then
				local oldy = y
				y = math.min(math.max(scrolly + cy - offy, 1), #lines)
				x = math.min(math.max(scrollx + cx - offx, 1), lines[y]:len() + 1)
				if oldy ~= y then drawLine(oldy, y) end
				cursorLoc(x, y)
			else
				local a = triggerMenu(cx, cy)
				if a then 
					local opt = executeMenuItem(a, path)
					if opt then return opt end
				end
			end
		elseif e == "shortcut" then
			local a = shortcuts[key .. " " .. cx]
			if a then
				local parent = nil
				local curx = 0
				for i, mv in ipairs(menu) do
					for _, iv in pairs(mv) do
						if iv == a then
							parent = menu[i][1]
							break
						end
					end
					if parent then break end
					curx = curx + mv[1]:len() + 3
				end
				local menux = curx + 2

				-- Flash menu item
				term.setCursorBlink(false)
				term.setCursorPos(menux, 1)
				term.setBackgroundColor(colors[theme.background])
				term.write(string.rep(" ", parent:len() + 2))
				term.setCursorPos(menux + 1, 1)
				term.write(parent)
				sleep(0.1)
				drawMenu()

				-- Execute item
				local opt = executeMenuItem(a, path)
				if opt then return opt end
			end
		elseif e == "mouse_scroll" then
			if key == -1 and scrolly > 0 then
				scrolly = scrolly - 1
				if os.clock() - scrollClock > 0.0005 then
					draw()
					term.setCursorPos(x - scrollx + offx, y - scrolly + offy)
				end
				scrollClock = os.clock()
			elseif key == 1 and scrolly < #lines - edh then
				scrolly = scrolly + 1
				if os.clock() - scrollClock > 0.0005 then
					draw()
					term.setCursorPos(x - scrollx + offx, y - scrolly + offy)
				end
				scrollClock = os.clock()
			end
		end

		-- Autosave
		if os.clock() - autosaveClock > autosaveInterval then
			saveFile(path, lines)
			autosaveClock = os.clock()
		end
	end

	return "menu"
end


--  -------- Open File

local function newFile()
	local wid = w - 13

	-- Get name
	title("Lua IDE - New File")
	local name = "/" .. centerRead(wid, "/")

	-- Clear
	title("Lua IDE - New File")
	term.setTextColor(colors[theme.textColor])
	term.setBackgroundColor(colors[theme.promptHighlight])
	for i = 8, 10 do
		term.setCursorPos(w/2 - wid/2, i)
		term.write(string.rep(" ", wid))
	end
	term.setCursorPos(1, 9)
	if fs.isDir(name) then
		centerPrint("Cannot Edit a Directory!")
		sleep(1.6)
		return "menu"
	elseif fs.exists(name) then
		centerPrint("File Already Exists!")
		local opt = prompt({{"Open", w/2 - 9, 14}, {"Cancel", w/2 + 2, 14}}, "horizontal")
		if opt == "Open" then
			return "edit", name
		elseif opt == "Cancel" then
			return "menu"
		end
	else
		return "edit", name
	end
end

local function openFile()
	local wid = w - 13

	-- Get name
	title("Lua IDE - Open File")
	local name = "/" .. centerRead(wid, "/")

	-- Clear
	title("Lua IDE - New File")
	term.setTextColor(colors[theme.textColor])
	term.setBackgroundColor(colors[theme.promptHighlight])
	for i = 8, 10 do
		term.setCursorPos(w/2 - wid/2, i)
		term.write(string.rep(" ", wid))
	end
	term.setCursorPos(1, 9)
	if fs.isDir(name) then
		centerPrint("Cannot Open a Directory!")
		sleep(1.6)
		return "menu"
	elseif not fs.exists(name) then
		centerPrint("File Doesn't Exist!")
		local opt = prompt({{"Create", w/2 - 11, 14}, {"Cancel", w/2 + 2, 14}}, "horizontal")
		if opt == "Create" then
			return "edit", name
		elseif opt == "Cancel" then
			return "menu"
		end
	else
		return "edit", name
	end
end


--  -------- Settings

local function update()
	local function draw(status)
		title("LuaIDE - Update")
		term.setBackgroundColor(colors[theme.prompt])
		term.setTextColor(colors[theme.textColor])
		for i = 8, 10 do 
			term.setCursorPos(w/2 - (status:len() + 4), i)
			write(string.rep(" ", status:len() + 4))
		end
		term.setCursorPos(w/2 - (status:len() + 4), 9)
		term.write(" - " .. status .. " ")

		term.setBackgroundColor(colors[theme.errHighlight])
		for i = 8, 10 do 
			term.setCursorPos(w/2 + 2, i)
			term.write(string.rep(" ", 10))
		end
		term.setCursorPos(w/2 + 2, 9)
		term.write(" > Cancel ")
	end

	if not http then
		draw("HTTP API Disabled!")
		sleep(1.6)
		return "settings"
	end

	draw("Updating...")
	os.pullEvent("key")
	local tID = os.startTimer(10)
	http.request(updateURL)
	while true do
		local e, but, x, y = os.pullEvent()
		if (e == "key" and but == 28) or 
				(e == "mouse_click" and x >= w/2 + 2 and x <= w/2 + 12 and y == 9) then
			draw("Cancelled")
			sleep(1.6)
			break
		elseif e == "http_success" then
			draw("Update Found")
			sleep(1.6)
--[[
			local f = io.open(ideLocation, "w")
			f:write(x.readAll())
			f:close()
]]--

			draw("Click to Exit")
			while true do
				local e = os.pullEvent()
				if e == "mouse_click" or e == "key" then break end
			end
			return "exit"
		elseif e == "http_failure" or (e == "timer" and but == tID) then
			draw("Update Failed!")
			sleep(1.6)
			break
		end
	end

	return "settings"
end

local function changeTheme()
	title("LuaIDE - Theme")

	local opt = scrollingPrompt("Back", "Default", "Dusk", "Dawn")
	if opt == "Default" then
		theme = defaultTheme
	elseif opt == "Dusk" then

	elseif opt == "Dawn" then

	end
end

local function settings()
	title("LuaIDE - Settings")

	local opt = prompt({{"Change Theme", w/2 - 17, 8}, {"Check for Updates", w/2 - 22, 13}, 
		{"Disable Live Errors", w/2 + 2, 8}, {"Return to Menu", w/2 + 2, 13, 
		bg = colors[theme.err], highlight = colors[theme.errHighlight]}})
	if opt == "Change Theme" then
		changeTheme()
		return "settings"
	elseif opt == "Check for Updates" then
		return update()
	elseif opt == "Disable Live Errors" then
		return "menu"
	elseif opt == "Return to Menu" then
		return "menu"
	end
end


--  -------- Menu

local function menu()
	title("Welcome to LuaIDE " .. version)

	local opt = prompt({{"New File", w/2 - 13, 8}, {"Open File", w/2 - 14, 13}, 
		{"Settings", w/2 + 2, 8}, {"Exit IDE", w/2 + 2, 13, bg = colors[theme.err], 
		highlight = colors[theme.errHighlight]}})
	if opt == "New File" then
		return "new"
	elseif opt == "Open File" then
		return "open"
	elseif opt == "Settings" then
		return "settings"
	elseif opt == "Exit IDE" then
		return "exit"
	end
end


--  -------- Main

local function main(arguments)
	local opt, data = "menu", nil

	-- Check arguments
	if type(arguments) == "table" and #arguments > 0 then
		local f = "/" .. shell.resolve(arguments[1])
		if fs.isDir(f) then print("Cannot edit a directory.") end
		opt, data = "edit", f
	end

	-- Main run loop
	while true do
		-- Menu
		if opt == "menu" then opt = menu() end

		-- Other
		if opt == "new" then
			opt, data = newFile()
		elseif opt == "open" then
			opt, data = openFile()
		elseif opt == "settings" then
			opt = settings()
		end if opt == "exit" then
			break
		end

		-- Edit
		if opt == "edit" and data then
			opt = edit(data)
		end
	end
end

-- Advanced Comptuer Only
if not term.isColor or not term.isColor() then
	print("Advanced Comptuer Required!")
	print("Normal Comptuer Support Coming Soon!")
	error()
end

-- Run
theme = defaultTheme
local _, err = pcall(function() 
	parallel.waitForAny(function() main(args) end, monitorKeyboardShortcuts)
end)

-- Catch errors
if err and not err:find("Terminated") then
	term.setCursorBlink(false)
	title("LuaIDE - Crash! D:")

	term.setBackgroundColor(colors[theme.err])
	for i = 6, 8 do
		term.setCursorPos(5, i)
		term.write(string.rep(" ", 36))
	end
	term.setCursorPos(6, 7)
	term.write("LuaIDE Has Crashed! D:")

	term.setBackgroundColor(colors[theme.background])
	term.setCursorPos(2, 10)
	print(err)

	term.setBackgroundColor(colors[theme.prompt])
	local _, cy = term.getCursorPos()
	for i = cy + 1, cy + 4 do
		term.setCursorPos(5, i)
		term.write(string.rep(" ", 36))
	end
	term.setCursorPos(6, cy + 2)
	term.write("Please report this error to 1lann")
	term.setCursorPos(6, cy + 3)
	term.write("or GravityScore! ")
	
	term.setBackgroundColor(colors[theme.background])
	if term.isColor and term.isColor() then centerPrint("Click to Exit...", h - 1)
	else centerPrint("Press Any Key to Exit...", h - 1) end
	while true do
		local e = os.pullEvent()
		if e == "key" or e == "mouse_click" then break end
	end

	-- Prevent key from being shown
	os.queueEvent(event_distract)
	os.pullEvent()
end

-- Exit
term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)
term.clear()
centerPrint("Thank You for Using Lua IDE " .. version, 1)
centerPrint("Made by GravityScore and 1lann", 2)
term.setCursorPos(1, 3)