
--
--  Editor
--

Editor = {}
Editor.__index = Editor

Editor.startY = 3


--- Create a new editor with no project loaded.
function Editor.new(...)
	local self = setmetatable({}, Editor)
	self:setup(...)
	return self
end


function Editor:setup()
	--- The editor size
	local w, h = term.native().getSize()
	self.width = w
	self.height = h - Editor.startY + 1

	--- The editor's window (for the tab system)
	self.win = window.create(term.native(), 1, Editor.startY, self.width, self.height, false)

	--- The position of the cursor relative to the upper left of the window.
	--- Not absolute within the document.
	--- Start at 1.
	self.cursor = {}
	self.cursor.x = 1
	self.cursor.y = 1

	--- The horizontal and vertical scroll amounts.
	--- Start at 0.
	self.scroll = {}
	self.scroll.x = 0
	self.scroll.y = 0

	--- The text lines to render.
	self.lines = {"Testing", "hello", "lulzzzzzzzzzzzzzzzzzzzz"}

	--- Previous state variables
	self.lastDrawnActiveLine = -1
end


--- Returns the name of the tab
function Editor:name()
	return "test"
end


--- Set the location of the physical cursor to the correct position.
function Editor:restoreCursor()
	term.redirect(self.win)

	local lineWidth = self:currentLineWidth()
	local offset = self:gutterSize()
	local x = math.min(self.cursor.x + offset, lineWidth + offset + 1)
	term.setCursorPos(x, self.cursor.y)
	term.setTextColor(Theme["editor text"])
	term.setCursorBlink(true)

	-- Redraw the highlight in the gutter
	self:redrawActiveLine()
end


--- Returns the size of the gutter.
function Editor:gutterSize()
	return tostring(#self.lines):len() + Theme["gutter separator"]:len()
end


--- Returns the width of the line the cursor is currently on.
function Editor:currentLineWidth()
	return self.lines[self.cursor.y + self.scroll.y]:len()
end


--- Move the cursor to the left by 1.
--- Does not move the physical cursor, only shifts the in memory location.
function Editor:moveCursorLeft()
	self:moveToEndOfLine()

	if self.cursor.x > 1 then
		self.cursor.x = self.cursor.x - 1
	elseif self.scroll.x > 0 then
		self.scroll.x = self.scroll.x - 1
	end
end


--- Move the cursor right by 1.
--- Does not move the physical cursor, only shifts the in memory location.
function Editor:moveCursorRight()
	local width = self.width - self:gutterSize()
	local lineWidth = self:currentLineWidth()

	if lineWidth > width then
		if self.cursor.x < width then
			self.cursor.x = self.cursor.x + 1
		elseif self.scroll.x + self.cursor.x < lineWidth then
			self.scroll.x = self.scroll.x + 1
		end
	else
		if self.cursor.x <= lineWidth then
			self.cursor.x = self.cursor.x + 1
		end
	end
end


--- Move the cursor up 1.
--- Does not move the physical cursor, only shifts the in memory location.
function Editor:moveCursorUp()
	if self.cursor.y > 1 then
		self.cursor.y = self.cursor.y - 1
	elseif self.scroll.y > 0 then
		self.scroll.y = self.scroll.y - 1
	end
end


--- Move the cursor down 1.
--- Does not move the physical cursor, only shifts the in memory location.
function Editor:moveCursorDown()
	if self.cursor.y < math.min(self.height, #self.lines) then
		self.cursor.y = self.cursor.y + 1
	elseif #self.lines > self.height then
		if self.scroll.y + self.cursor.y + self.height < #self.lines then
			self.scroll.y = self.scroll.y + 1
		end
	end
end


--- Move the cursor to the end of the current line.
function Editor:moveToEndOfLine()
	-- Handle the case where the user was beyond the length
	-- of this line on another line and moved up to this
	-- line, and then tries to type
	local lineWidth = self:currentLineWidth()
	if self.cursor.x > lineWidth then
		self.cursor.x = lineWidth + 1
	end
end


--- Move the cursor to the start of the current line.
function Editor:moveToStartOfLine()
	self.cursor.x = 1
	self.scroll.x = 0
end


--- Insert a newline at the cursor position and redraw the line.
function Editor:insertNewline()
	self:moveToEndOfLine()

	-- Split the current line in two
	local x = self.cursor.x + self.scroll.x
	local y = self.cursor.y + self.scroll.y
	local first = self.lines[y]:sub(1, x - 1)
	local second = self.lines[y]:sub(x)

	-- Modify the lines
	self.lines[y] = first
	table.insert(self.lines, y + 1, second)

	-- Redraw
	term.redirect(self.win)
	self:draw()

	-- Set the cursor position
	self:moveCursorDown()
	self:moveToStartOfLine()
	self:restoreCursor()
end


--- Insert a character at the cursor position and redraw the line.
function Editor:insertCharacter(character)
	self:moveToEndOfLine()

	-- Update the line's text
	local x = self.cursor.x + self.scroll.x
	local y = self.cursor.y + self.scroll.y
	self.lines[y] = self.lines[y]:sub(1, x - 1) .. character .. self.lines[y]:sub(x)

	-- Redraw line
	term.redirect(self.win)
	self:fullyDrawLine(self.cursor.y)

	-- Move the cursor
	self:moveCursorRight()
	self:restoreCursor()
end


--- Show the editor's window
function Editor:show()
	term.redirect(self.win)
	self.win.setVisible(true)
	self:draw()
	self:restoreCursor()
end


--- Hide the editor's window
function Editor:hide()
	self.win.setVisible(false)
end


--- Clears the line number at `self.lastDrawnActiveLine` and
--- redraws the active line as the current cursor y position.
--- Updates `self.lastDrawnActiveLine`.
function Editor:redrawActiveLine()
	if self.lastDrawnActiveLine ~= self.cursor.y then
		local x, y = term.getCursorPos()
		self:drawGutter(self.lastDrawnActiveLine)
		self:drawGutter(self.cursor.y)
		term.setCursorPos(x, y)
	end
end


--- Fully renders a line, clearing it, and rendering the text and gutter.
function Editor:fullyDrawLine(y)
	term.setBackgroundColor(Theme["editor background"])
	term.setCursorPos(1, self.cursor.y)
	term.clearLine()
	self:drawLine(self.cursor.y)
	self:drawGutter(self.cursor.y)
end


--- Renders the gutter for a particular line.
--- Does not redirect to the editor's window.
--- `y` is the y value of the line, relative to the top left of the window,
--- not to the entire file.
--- Does not restore the cursor position after rendering.
function Editor:drawGutter(y)
	if y == self.cursor.y then
		term.setBackgroundColor(Theme["gutter background focused"])
		term.setTextColor(Theme["gutter text focused"])
		self.lastDrawnActiveLine = y
	else
		term.setBackgroundColor(Theme["gutter background"])
		term.setTextColor(Theme["gutter text"])
	end

	local size = self:gutterSize()
	local lineNumber = tostring(y + self.scroll.y)
	local padding = string.rep(" ", size - lineNumber:len() - 1)
	lineNumber = padding .. lineNumber .. Theme["gutter separator"]
	term.setCursorPos(1, y)
	term.write(lineNumber)
end


--- Render a single line.
--- Does not redirect to the editor's window.
--- Does not render the gutter on that line.
--- `y` is the y value of the line, relative to the top left of the window,
--- not to the entire file.
--- Does not restore the cursor position after rendering.
function Editor:drawLine(y)
	-- Calculate the text to render
	local text = self.lines[y + self.scroll.y]
	text = text:sub(self.scroll.x)

	-- Render the text
	term.setBackgroundColor(Theme["editor background"])
	term.setTextColor(Theme["editor text"])
	term.setCursorPos(self:gutterSize() + 1, y)
	term.write(text)
end


--- Render the entire editor.
function Editor:draw()
	term.redirect(self.win)

	-- Clear
	term.setBackgroundColor(Theme["editor background"])
	term.clear()

	local lineCount = math.min(#self.lines, self.height)

	-- Iterate over each line
	for y = 1, lineCount do
		self:drawLine(y)
		self:drawGutter(y)
	end

	-- Restore the cursor position
	self:restoreCursor()
end


--- Called when a key event occurs.
function Editor:key(key)
	if key == keys.left then
		self:moveCursorLeft()
		self:restoreCursor()
	elseif key == keys.right then
		self:moveCursorRight()
		self:restoreCursor()
	elseif key == keys.up then
		self:moveCursorUp()
		self:restoreCursor()
	elseif key == keys.down then
		self:moveCursorDown()
		self:restoreCursor()
	elseif key == keys.enter then
		self:insertNewline()
	end
end


--- Called when an event occurs.
function Editor:event(event)
	if event[1] == "key" then
		self:key(event[2])
	elseif event[1] == "char" then
		self:insertCharacter(event[2])
	end
end