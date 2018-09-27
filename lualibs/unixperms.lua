
--UNIX permissions string parser and formatter.
--Written by Cosmin Apreutesei. Public Domain.

local bit = require'bit'

local function oct(s)
	return tonumber(s, 8)
end

local function octs(n)
	return string.format('%05o', n)
end

local bitmasks = {
	ox = 2^0,
	ow = 2^1,
   ['or'] = 2^2,
	gx = 2^3,
	gw = 2^4,
	gr = 2^5,
	ux = 2^6,
	uw = 2^7,
	ur = 2^8,
	ot = 2^9 + 2^0,
	oT = 2^9,
	gs = 2^10 + 2^3,
	gS = 2^10,
	us = 2^11 + 2^6,
	uS = 2^11,
}

local masks = {o = oct'01007', g = oct'02070', u = oct'04700'}
local function bits(who, what)
	local bits, mask = 0, 0
	for c1 in who:gmatch'.' do
		for c2 in what:gmatch'.' do
			bits = bit.bor(bits, bitmasks[c1..c2] or 0)
		end
		mask = bit.bor(mask, masks[c1])
	end
	return bits, mask
end

--set one or more bits of a value without affecting other bits.
local function setbits(bits, mask, over)
	return bit.bor(bits, bit.band(over, bit.bnot(mask)))
end

local all = oct'07777'
local function string_parser(s)
	if s:find'^0[0-7]+$' then --octal, don't compose
		local n = oct(s)
		return function(base)
			return n, false
		end
	end
	assert(not s:find'[^-+=ugorwxstST0, ]', 'invalid permissions string')
	local t, push = {}, table.insert
	s:gsub('([ugo]*)([-+=]?)([rwxstST0]+)', function(who, how, what)
		if who == '' then
			if what:find'[rwx0]'
				or (what:find'[sS]' and what:find'[tT]')
			then
				who = 'ugo'
			elseif what:find'[sS]' then
				who = 'ug'
			elseif what:find'[tT]' then
				who = 'o'
			else
				assert(false)
			end
		end
		local bits1, mask1 = bits(who, what)
		if how == '' or how == '=' then
			push(t, function(mode, mask)
				mode = setbits(bits1, mask1, mode)
				mask = bit.bor(mask1, mask)
				return mode, mask
			end)
		elseif how == '-' then
			push(t, function(mode, mask)
				return bit.band(bit.bnot(bits1), mode), mask
			end)
		elseif how == '+' then
			push(t, function(mode, mask)
				return bit.bor(bits1, mode), mask
			end)
		end
	end)
	return function(base)
		local mode, mask = base, 0
		for i=1,#t do
			local f = t[i]
			mode, mask = f(mode, mask)
		end
		return mode, mask ~= all
	end
end

local cache = {} -- {s -> parse(base)}

local function parse_string(s, base)
	local parse = cache[s]
	if not parse then
		parse = string_parser(s)
		cache[s] = parse
	end
	return parse(base)
end

local function parse(s, base)
	base = oct(base or 0)
	if type(s) == 'string' then
		return parse_string(s, base)
	else --number, pass-through
		return s, false
	end
end

local function s(b, suid, Suid)
	local x = bit.band(b, 1) ~= 0
		and (suid or 'x')
		or (Suid or '-')
	local w = bit.band(b, 2) ~= 0 and 'w' or '-'
	local r = bit.band(b, 4) ~= 0 and 'r' or '-'
	return string.format('%s%s%s', r, w, x)
end
local function long(mode)
	local o = bit.band(bit.rshift(mode, 0), 7)
	local g = bit.band(bit.rshift(mode, 3), 7)
	local u = bit.band(bit.rshift(mode, 6), 7)
	local st = bit.band(bit.rshift(mode, 9), 1) ~= 0
	local sg = bit.band(bit.rshift(mode, 10), 1) ~= 0
	local su = bit.band(bit.rshift(mode, 11), 1) ~= 0
	return string.format('%s%s%s',
		s(u, su and 's', su and 'S'),
		s(g, sg and 's', sg and 'S'),
		s(o, st and 't', st and 'T'))
end

local function format(mode, style)
	return
		(not style or style:find'^o') and octs(mode)
		or style:find'^l' and long(mode)
end

return {
	parse = parse,
	format = format,
}
