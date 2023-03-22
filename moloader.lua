-- config
-- >>>
local moFilePath = "D:/genshin/windy/dust2.mo"

local TextPath = "D:/genshin/windy/dust2.png"

local PlayerPosition = true

local TypeRotation = 0 -- 0 - CustomRotate | 1 - CameraRotate | 2 - PlayerRotate

local CreateCollider = true

local ModelPosition = {0.0,300.0,0.0} -- If PlayerPosition = true then does nothing

local ModelRotation = {0.0,0.0,0.0} -- If TypeRotation == 1 or 2 then does nothing

local ModelScale = {5.0,5.0,-5.0}

local TextureScale = {1024,1024}
-- <<<

local function list_length( t )
 
    local len = 0
    for _,_ in pairs( t ) do
        len = len + 1
    end
 
    return len
end

local function jsonlua()
	local json = { _version = "0.1.2" }

	-------------------------------------------------------------------------------
	-- Encode
	-------------------------------------------------------------------------------

	local encode

	local escape_char_map = {
	  [ "\\" ] = "\\",
	  [ "\"" ] = "\"",
	  [ "\b" ] = "b",
	  [ "\f" ] = "f",
	  [ "\n" ] = "n",
	  [ "\r" ] = "r",
	  [ "\t" ] = "t",
	}

	local escape_char_map_inv = { [ "/" ] = "/" }
	for k, v in pairs(escape_char_map) do
	  escape_char_map_inv[v] = k
	end


	local function escape_char(c)
	  return "\\" .. (escape_char_map[c] or string.format("u%04x", c:byte()))
	end


	local function encode_nil(val)
	  return "null"
	end


	local function encode_table(val, stack)
	  local res = {}
	  stack = stack or {}

	  -- Circular reference?
	  if stack[val] then error("circular reference") end

	  stack[val] = true

	  if rawget(val, 1) ~= nil or next(val) == nil then
		-- Treat as array -- check keys are valid and it is not sparse
		local n = 0
		for k in pairs(val) do
		  if type(k) ~= "number" then
			error("invalid table: mixed or invalid key types")
		  end
		  n = n + 1
		end
		if n ~= #val then
		  error("invalid table: sparse array")
		end
		-- Encode
		for i, v in ipairs(val) do
		  table.insert(res, encode(v, stack))
		end
		stack[val] = nil
		return "[" .. table.concat(res, ",") .. "]"

	  else
		-- Treat as an object
		for k, v in pairs(val) do
		  if type(k) ~= "string" then
			error("invalid table: mixed or invalid key types")
		  end
		  table.insert(res, encode(k, stack) .. ":" .. encode(v, stack))
		end
		stack[val] = nil
		return "{" .. table.concat(res, ",") .. "}"
	  end
	end


	local function encode_string(val)
	  return '"' .. val:gsub('[%z\1-\31\\"]', escape_char) .. '"'
	end


	local function encode_number(val)
	  -- Check for NaN, -inf and inf
	  if val ~= val or val <= -math.huge or val >= math.huge then
		error("unexpected number value '" .. tostring(val) .. "'")
	  end
	  return string.format("%.14g", val)
	end


	local type_func_map = {
	  [ "nil"     ] = encode_nil,
	  [ "table"   ] = encode_table,
	  [ "string"  ] = encode_string,
	  [ "number"  ] = encode_number,
	  [ "boolean" ] = tostring,
	}


	encode = function(val, stack)
	  local t = type(val)
	  local f = type_func_map[t]
	  if f then
		return f(val, stack)
	  end
	  error("unexpected type '" .. t .. "'")
	end


	function json.encode(val)
	  return ( encode(val) )
	end


	-------------------------------------------------------------------------------
	-- Decode
	-------------------------------------------------------------------------------

	local parse

	local function create_set(...)
	  local res = {}
	  for i = 1, select("#", ...) do
		res[ select(i, ...) ] = true
	  end
	  return res
	end

	local space_chars   = create_set(" ", "\t", "\r", "\n")
	local delim_chars   = create_set(" ", "\t", "\r", "\n", "]", "}", ",")
	local escape_chars  = create_set("\\", "/", '"', "b", "f", "n", "r", "t", "u")
	local literals      = create_set("true", "false", "null")

	local literal_map = {
	  [ "true"  ] = true,
	  [ "false" ] = false,
	  [ "null"  ] = nil,
	}


	local function next_char(str, idx, set, negate)
	  for i = idx, #str do
		if set[str:sub(i, i)] ~= negate then
		  return i
		end
	  end
	  return #str + 1
	end


	local function decode_error(str, idx, msg)
	  local line_count = 1
	  local col_count = 1
	  for i = 1, idx - 1 do
		col_count = col_count + 1
		if str:sub(i, i) == "\n" then
		  line_count = line_count + 1
		  col_count = 1
		end
	  end
	  error( string.format("%s at line %d col %d", msg, line_count, col_count) )
	end


	local function codepoint_to_utf8(n)
	  -- http://scripts.sil.org/cms/scripts/page.php?site_id=nrsi&id=iws-appendixa
	  local f = math.floor
	  if n <= 0x7f then
		return string.char(n)
	  elseif n <= 0x7ff then
		return string.char(f(n / 64) + 192, n % 64 + 128)
	  elseif n <= 0xffff then
		return string.char(f(n / 4096) + 224, f(n % 4096 / 64) + 128, n % 64 + 128)
	  elseif n <= 0x10ffff then
		return string.char(f(n / 262144) + 240, f(n % 262144 / 4096) + 128,
						   f(n % 4096 / 64) + 128, n % 64 + 128)
	  end
	  error( string.format("invalid unicode codepoint '%x'", n) )
	end


	local function parse_unicode_escape(s)
	  local n1 = tonumber( s:sub(1, 4),  16 )
	  local n2 = tonumber( s:sub(7, 10), 16 )
	   -- Surrogate pair?
	  if n2 then
		return codepoint_to_utf8((n1 - 0xd800) * 0x400 + (n2 - 0xdc00) + 0x10000)
	  else
		return codepoint_to_utf8(n1)
	  end
	end


	local function parse_string(str, i)
	  local res = ""
	  local j = i + 1
	  local k = j

	  while j <= #str do
		local x = str:byte(j)

		if x < 32 then
		  decode_error(str, j, "control character in string")

		elseif x == 92 then -- `\`: Escape
		  res = res .. str:sub(k, j - 1)
		  j = j + 1
		  local c = str:sub(j, j)
		  if c == "u" then
			local hex = str:match("^[dD][89aAbB]%x%x\\u%x%x%x%x", j + 1)
					 or str:match("^%x%x%x%x", j + 1)
					 or decode_error(str, j - 1, "invalid unicode escape in string")
			res = res .. parse_unicode_escape(hex)
			j = j + #hex
		  else
			if not escape_chars[c] then
			  decode_error(str, j - 1, "invalid escape char '" .. c .. "' in string")
			end
			res = res .. escape_char_map_inv[c]
		  end
		  k = j + 1

		elseif x == 34 then -- `"`: End of string
		  res = res .. str:sub(k, j - 1)
		  return res, j + 1
		end

		j = j + 1
	  end

	  decode_error(str, i, "expected closing quote for string")
	end


	local function parse_number(str, i)
	  local x = next_char(str, i, delim_chars)
	  local s = str:sub(i, x - 1)
	  local n = tonumber(s)
	  if not n then
		decode_error(str, i, "invalid number '" .. s .. "'")
	  end
	  return n, x
	end


	local function parse_literal(str, i)
	  local x = next_char(str, i, delim_chars)
	  local word = str:sub(i, x - 1)
	  if not literals[word] then
		decode_error(str, i, "invalid literal '" .. word .. "'")
	  end
	  return literal_map[word], x
	end


	local function parse_array(str, i)
	  local res = {}
	  local n = 1
	  i = i + 1
	  while 1 do
		local x
		i = next_char(str, i, space_chars, true)
		-- Empty / end of array?
		if str:sub(i, i) == "]" then
		  i = i + 1
		  break
		end
		-- Read token
		x, i = parse(str, i)
		res[n] = x
		n = n + 1
		-- Next token
		i = next_char(str, i, space_chars, true)
		local chr = str:sub(i, i)
		i = i + 1
		if chr == "]" then break end
		if chr ~= "," then decode_error(str, i, "expected ']' or ','") end
	  end
	  return res, i
	end


	local function parse_object(str, i)
	  local res = {}
	  i = i + 1
	  while 1 do
		local key, val
		i = next_char(str, i, space_chars, true)
		-- Empty / end of object?
		if str:sub(i, i) == "}" then
		  i = i + 1
		  break
		end
		-- Read key
		if str:sub(i, i) ~= '"' then
		  decode_error(str, i, "expected string for key")
		end
		key, i = parse(str, i)
		-- Read ':' delimiter
		i = next_char(str, i, space_chars, true)
		if str:sub(i, i) ~= ":" then
		  decode_error(str, i, "expected ':' after key")
		end
		i = next_char(str, i + 1, space_chars, true)
		-- Read value
		val, i = parse(str, i)
		-- Set
		res[key] = val
		-- Next token
		i = next_char(str, i, space_chars, true)
		local chr = str:sub(i, i)
		i = i + 1
		if chr == "}" then break end
		if chr ~= "," then decode_error(str, i, "expected '}' or ','") end
	  end
	  return res, i
	end


	local char_func_map = {
	  [ '"' ] = parse_string,
	  [ "0" ] = parse_number,
	  [ "1" ] = parse_number,
	  [ "2" ] = parse_number,
	  [ "3" ] = parse_number,
	  [ "4" ] = parse_number,
	  [ "5" ] = parse_number,
	  [ "6" ] = parse_number,
	  [ "7" ] = parse_number,
	  [ "8" ] = parse_number,
	  [ "9" ] = parse_number,
	  [ "-" ] = parse_number,
	  [ "t" ] = parse_literal,
	  [ "f" ] = parse_literal,
	  [ "n" ] = parse_literal,
	  [ "[" ] = parse_array,
	  [ "{" ] = parse_object,
	}


	parse = function(str, idx)
	  local chr = str:sub(idx, idx)
	  local f = char_func_map[chr]
	  if f then
		return f(str, idx)
	  end
	  decode_error(str, idx, "unexpected character '" .. chr .. "'")
	end


	function json.decode(str)
	  if type(str) ~= "string" then
		error("expected argument of type string, got " .. type(str))
	  end
	  local res, idx = parse(str, next_char(str, 1, space_chars, true))
	  idx = next_char(str, idx, space_chars, true)
	  if idx <= #str then
		decode_error(str, idx, "trailing garbage")
	  end
	  return res
	end


	return json
end

local function DowMO()
	
	local MoPath = CS.UnityEngine.GameObject.Find("/BigWorld(Clone)/MoModels")
	if MoPath == nil then
		MoPath = CS.UnityEngine.GameObject("MoModels")
		CS.UnityEngine.Object:DontDestroyOnLoad(MoPath)
		MoPath.transform:SetParent(CS.UnityEngine.GameObject.Find("/BigWorld(Clone)").transform)
		MoPath.transform.localPosition = CS.UnityEngine.Vector3(0,0,0)
		CS.MoleMole.ActorUtils.ShowMessage("MoPath created")	
	else
		CS.MoleMole.ActorUtils.ShowMessage("MoPath exists")
	end
	
	local WorldPath = CS.UnityEngine.GameObject.Find("/BigWorld(Clone)").transform.gameObject
	
	local newObject = CS.UnityEngine.GameObject.CreatePrimitive(CS.UnityEngine.PrimitiveType.Cube)
	
	newObject.transform:SetParent(MoPath.transform)
	
	-- local ObjPath = newObject
	-- local path = "/" .. ObjPath.transform.name
	-- while ObjPath.transform.parent ~= nil do
        -- ObjPath = ObjPath.transform.parent.gameObject
        -- path = "/" .. ObjPath.name .. path
    -- end
	-- CS.MoleMole.ActorUtils.ShowMessage(path)
	
	local worldpos = WorldPath.transform.localPosition
	

	if PlayerPosition then
		local PlayerPos = CS.MoleMole.ActorUtils.GetAvatarPos()
		newObject.transform.localPosition = CS.UnityEngine.Vector3(PlayerPos[0]-worldpos.x,PlayerPos[1],PlayerPos[2]-worldpos.z)
	else	
		newObject.transform.localPosition = CS.UnityEngine.Vector3(ModelPosition[1]-worldpos.x,ModelPosition[2],ModelPosition[3]-worldpos.z)
	end
	
	if TypeRotation == 1 then
		local CameraRot = CS.MoleMole.ActorUtils.GetCameraEuler()
		newObject.transform.rotation = CS.UnityEngine.Quaternion.Euler(CameraRot[0],CameraRot[1],CameraRot[2])
	elseif TypeRotation == 2 then
		local PlayerRot = CS.MoleMole.ActorUtils.GetAvatarForward()
		newObject.transform.rotation = CS.UnityEngine.Quaternion.Euler(PlayerRot[0],PlayerRot[1],PlayerRot[2])
	else
		newObject.transform.rotation = CS.UnityEngine.Quaternion.Euler(ModelRotation[1],ModelRotation[2],ModelRotation[3])
	end
	
	newObject.transform.localScale = CS.UnityEngine.Vector3(ModelScale[1],ModelScale[2],ModelScale[3])

	
	local jsonString = CS.System.IO.File.ReadAllText(moFilePath)
			
	local json = jsonlua()
	
	local data = json.decode(jsonString)
		
	local VertexArray = CS.UnityEngine.Vector3[list_length(data.VertexArray)]
	local UVArray = CS.UnityEngine.Vector3[list_length(data.UVArray)]
	local NormalArray = CS.UnityEngine.Vector3[list_length(data.NormalArray)]
	local TriangleArray = CS.UnityEngine.Vector3[list_length(data.TriangleArray)]
	local VertexArray = {}
	local UVArray = {}
	local NormalArray = {}
	local TriangleArray = {}
	
	local start_nul = 1
	
	local i = start_nul
	
	for k,items in pairs(data.VertexArray) do
		VertexArray[i] = CS.UnityEngine.Vector3(items.x, items.y, items.z)
		i = i + 1
	end
	
	i = start_nul
	for k,items in pairs(data.UVArray) do
		UVArray[i] = CS.UnityEngine.Vector2(items.x, items.y)
		i = i + 1
	end
	
	i = start_nul
	for k,items in pairs(data.NormalArray) do
		NormalArray[i] = CS.UnityEngine.Vector3(items.x, items.y, items.z)
		i = i + 1
	end
	
	i = start_nul
	for k,items in pairs(data.TriangleArray) do
		TriangleArray[i] = items
		i = i + 1
	end
	
	local mesh = CS.UnityEngine.Mesh()
	mesh.vertices = VertexArray
	mesh.triangles = TriangleArray
	if list_length( UVArray ) > 0 then
		mesh.uv = UVArray
	end
	if list_length(NormalArray) > 0 then
		mesh.normals = NormalArray
	end
	
	mesh:RecalculateBounds()

	local meshFilter = newObject:GetComponent(typeof(CS.UnityEngine.MeshFilter))
	meshFilter.mesh = mesh
	

	newObject:GetComponent(typeof(CS.UnityEngine.BoxCollider)).enabled = false
	
	if CreateCollider then
		newObject:AddComponent(typeof(CS.UnityEngine.MeshCollider))
		newObject.layer = 8
	end

	local _fileData = CS.System.IO.File.ReadAllBytes(TextPath)
	local _tex = CS.UnityEngine.Texture2D(TextureScale[1], TextureScale[2])
	CS.UnityEngine.ImageConversion.LoadImage(_tex, _fileData)

	newObject:GetComponent(typeof(CS.UnityEngine.MeshRenderer)).materials[0].mainTexture = _tex
	
	
	CS.MoleMole.ActorUtils.ShowMessage(".mo Loaded")
end

local function onError(error)
    --CS.UnityEngine.GameObject.Find("/BetaWatermarkCanvas(Clone)/Panel/TxtUID"):GetComponent("Text").text = tostring(error)
	CS.MoleMole.ActorUtils.ShowMessage(tostring(error))
end

xpcall(DowMO, onError)
