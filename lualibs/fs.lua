
--portable filesystem API for LuaJIT
--Written by Cosmin Apreutesei. Public Domain.

local ffi = require'ffi'
setfenv(1, require'fs.common')

if win then
	require'fs.win'
elseif linux or osx then
	require'fs.posix'
else
	error'platform not Windows, Linux or OSX'
end

ffi.metatype(file_ct, {__index = file})
ffi.metatype(stream_ct, {__index = stream})
ffi.metatype(dir_ct, {__index = dir, __gc = dir.close})

return fs
