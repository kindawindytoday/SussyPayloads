local DUMP_FOLDER = "C:/dump"
local DUMP_LOG_FILE = DUMP_FOLDER .. "/dump.log"
local DUMP_CS_FILE = DUMP_FOLDER .. "/dump.cs"

local log = io.open(DUMP_LOG_FILE, "w")

local SYSTEM_NAMES = {
    ["System.Int32"] = "int",
    ["System.UInt32"] = "uint",
    ["System.Int16"] = "short",
    ["System.UInt16"] = "ushort",
    ["System.Int64"] = "long",
    ["System.UInt64"] = "ulong",
    ["System.Byte"] = "byte",
    ["System.SByte"] = "sbyte",
    ["System.Boolean"] = "bool",
    ["System.Single"] = "float",
    ["System.Double"] = "double",
    ["System.String"] = "string",
    ["System.Char"] = "char",
    ["System.Object"] = "object",
    ["System.Void"] = "void"
}

local TypeAttributes = CS.System.Reflection.TypeAttributes

local function get_type_visibility_string(type)
    local visibility = type.Attributes & TypeAttributes.VisibilityMask
    if (visibility == TypeAttributes.Public) --
    or (visibility == TypeAttributes.NestedPublic) then
        return "public "
    elseif (visibility == TypeAttributes.NotPublic) --
    or (visibility == TypeAttributes.NestedFamANDAssem) --
    or (visibility == TypeAttributes.NestedAssembly) then
        return "internal "
    elseif (visibility == TypeAttributes.NestedPrivate) then
        return "private "
    elseif (visibility == TypeAttributes.NestedFamily) then
        return "protected "
    elseif (visibility == TypeAttributes.NestedFamORAssem) then
        return "protected internal "
    else
        return ""
    end
end

local function get_type_string(type)
    local out = get_type_visibility_string(type)
    local attributes = type.Attributes
    if (attributes & TypeAttributes.Abstract).value__ ~= 0 --
    and (attributes & TypeAttributes.Sealed).value__ ~= 0 then
        out = out .. "static "
    elseif (attributes & TypeAttributes.Abstract).value__ ~= 0 --
    and (attributes & TypeAttributes.Interface).value__ == 0 then
        out = out .. "abstract "
    elseif (attributes & TypeAttributes.Sealed).value__ ~= 0 --
    and (not type.IsEnum or not type.IsValueType) then
        out = out .. "sealed "
    end
    if (attributes & TypeAttributes.Interface).value__ ~= 0 then
        out = out .. "interface "
    elseif type.IsEnum then
        out = out .. "enum "
    elseif type.IsValueType then
        out = out .. "struct "
    else
        out = out .. "class "
    end
    return out
end

local function get_reflected_type(type)
    local name = type.Name
    if type.ReflectedType ~= nil --
    and not type.ReflectedType.IsGenericType then
        name = get_reflected_type(type.ReflectedType) .. "." .. name
    end
    return name
end

local function get_runtime_type_name(type, alias)
    if type.IsArray then
        local out = get_runtime_type_name(type:GetElementType(), alias)
        out = out .. "["
        for i = 2, type:GetArrayRank() do
            out = out .. ","
        end
        out = out .. "]"
        return out
    elseif type.IsPointer then
        return get_runtime_type_name(type:GetElementType(), alias) .. "*"
    elseif type.IsByRef then
        return get_runtime_type_name(type:GetElementType(), alias) .. "&"
    elseif type.IsGenericType then
        local name = type:GetGenericTypeDefinition().Name
        local pos = name:find("`")
        if pos ~= nil then
            name = name:sub(1, pos - 1)
        end
        local generic_args = type:GetGenericArguments()
        name = name .. "<"
        for i = 0, generic_args.Length - 1 do
            if i ~= 0 then
                name = name .. ", "
            end
            name = name .. get_runtime_type_name(generic_args[i], alias)
        end
        name = name .. ">"
        return name
    else
        if alias and type.Namespace == "System" then
            local name = SYSTEM_NAMES[type.FullName]
            if name ~= nil then
                return name
            end
        end
        return get_reflected_type(type)
    end
end

local function get_runtime_type_name_alias(type)
    return get_runtime_type_name(type, true)
end

local FieldAttributes = CS.System.Reflection.FieldAttributes

local function get_field_type_string(field)
    local out = ""
    local access = field.Attributes & FieldAttributes.FieldAccessMask
    if (access == FieldAttributes.Private) then
        out = out .. "private "
    elseif (access == FieldAttributes.Public) then
        out = out .. "public "
    elseif (access == FieldAttributes.Family) then
        out = out .. "protected "
    elseif (access == FieldAttributes.Assembly) --
    or (access == FieldAttributes.FamANDAssem) then
        out = out .. "internal "
    elseif (access == FieldAttributes.FamORAssem) then
        out = out .. "protected internal "
    end
    if field.IsLiteral then
        out = out .. "const "
    else
        if field.IsStatic then
            out = out .. "static "
        end
        if field.IsInitOnly then
            out = out .. "readonly "
        end
    end
    return out
end

local MethodAttributes = CS.System.Reflection.MethodAttributes

local function get_method_type_string(method)
    local out = ""
    local attributes = method.Attributes
    local access = attributes & MethodAttributes.MemberAccessMask
    if (access == MethodAttributes.Private) then
        out = out .. "private "
    elseif (access == MethodAttributes.Public) then
        out = out .. "public "
    elseif (access == MethodAttributes.Family) then
        out = out .. "protected "
    elseif (access == MethodAttributes.Assembly) --
    or (access == MethodAttributes.FamANDAssem) then
        out = out .. "internal "
    elseif (access == MethodAttributes.FamORAssem) then
        out = out .. "protected internal "
    end
    if (attributes & MethodAttributes.Static).value__ ~= 0 then
        out = out .. "static "
    end
    if (attributes & MethodAttributes.Abstract).value__ ~= 0 then
        out = out .. "abstract "
        if (attributes & MethodAttributes.VtableLayoutMask) == MethodAttributes.ReuseSlot then
            out = out .. "override "
        end
    elseif (attributes & MethodAttributes.Final).value__ ~= 0 then
        if (attributes & MethodAttributes.VtableLayoutMask) == MethodAttributes.ReuseSlot then
            out = out .. "sealed override "
        end
    elseif (attributes & MethodAttributes.Virtual).value__ ~= 0 then
        if (attributes & MethodAttributes.VtableLayoutMask) == MethodAttributes.NewSlot then
            out = out .. "virtual "
        else
            out = out .. "override "
        end
    end
    if (attributes & MethodAttributes.PinvokeImpl).value__ ~= 0 then
        out = out .. "extern "
    end
    return out
end

local function do_dump_csharp_field(file, field)
    file:write(get_field_type_string(field))
    file:write(get_runtime_type_name_alias(field.FieldType) .. " ")
    file:write(field.Name)
    if field.IsLiteral then
        local value = field:GetRawConstantValue()
        if field.FieldType.FullName == "System.String" then
            -- TODO: fix utf-8 encoding
            file:write(string.format(" = \"%s\";", value))
        elseif field.FieldType.FullName == "System.Char" then
            file:write(string.format(" = '\\x%X';", value))
        else
            file:write(string.format(" = %s;", value))
        end
    else
        local value = field:GetFieldOffset()
        if value & 0x8000000000000000 ~= 0 then
            value = -value
        end
        value = value + 0x10
        if value < 0 then
            file:write(string.format("; // -0x%X", value))
        else
            file:write(string.format("; // 0x%X", value))
        end
    end
    file:write("\n")
end

local function do_dump_csharp_property(file, property)
    if property.CanRead then
        local method = property:GetGetMethod(true)
        if method ~= nil then
            file:write(get_method_type_string(method))
        else
            log:write("property " .. property.Name .. " has no getter\n")
            file:write(get_type_visibility_string(property.PropertyType))
        end
    elseif property.CanWrite then
        local method = property:GetSetMethod(true)
        if method ~= nil then
            file:write(get_method_type_string(method))
        else
            log:write("property " .. property.Name .. " has no setter\n")
            file:write(get_type_visibility_string(property.PropertyType))
        end
    else
        file:write(get_type_visibility_string(property.PropertyType))
    end
    file:write(get_runtime_type_name_alias(property.PropertyType) .. " ")
    file:write(property.Name .. " { ")
    if property.CanRead then
        file:write("get; ")
    end
    if property.CanWrite then
        file:write("set; ")
    end
    file:write("}\n")
end

local function do_dump_csharp_method(file, type, method, rva, is_ctor)
    if is_ctor then
        file:write(get_method_type_string(method))
        file:write("void " .. method.Name)
    else
        file:write(get_method_type_string(method))
        file:write(get_runtime_type_name_alias(method.ReturnType) .. " ")
        file:write(method.Name)
        local arguments = method:GetGenericArguments()
        if arguments.Length > 0 then
            file:write("<")
            for i = 0, arguments.Length - 1 do
                local argument = arguments[i]
                if i ~= 0 then
                    file:write(", ")
                end
                file:write(get_runtime_type_name_alias(argument))
            end
            file:write(">")
        end
    end
    file:write("(")
    local parameters = method:GetParameters()
    for i = 0, parameters.Length - 1 do
        local parameter = parameters[i]
        if i ~= 0 then
            file:write(", ")
        end
        local name = get_runtime_type_name_alias(parameter.ParameterType)
        local pos = name:find("&")
        if pos ~= nil then
            name = name:sub(1, pos - 1)
            if parameter.IsIn then
                name = "in " .. name
            elseif parameter.IsOut then
                name = "out " .. name
            else
                name = "ref " .. name
            end
        else
            if parameter.IsIn then
                name = "[In] " .. name
            end
            if parameter.IsOut then
                name = "[Out] " .. name
            end
        end
        file:write(name .. " " .. parameter.Name)
        local status, err = pcall(function()
            if parameter.IsOptional then
                local type = parameter.ParameterType
                local value = parameter.DefaultValue
                if type.IsEnum then
                    if value.value__ == nil then
                        file:write(" = 0")
                    else
                        file:write(string.format(" = %d", value.value__))
                    end
                else
                    if type.FullName == "System.String" then
                        -- TODO: fix utf-8 encoding
                        file:write(string.format(" = \"%s\"", value))
                    elseif type.FullName == "System.Char" then
                        file:write(string.format(" = '\\x%X'", value))
                    else
                        file:write(string.format(" = %s", value))
                    end
                end
            end
        end)
        if not status then
            log:write(err .. "\n")
        end
    end
    file:write(") { }")
    if rva ~= nil then
        file:write(" // RVA: " .. rva)
    end
    file:write("\n")
    if not is_ctor then
        local generic_method = method:GetGenericMethodDefinition_impl()
        if generic_method ~= nil then
            file:write("\t/* GenericMethodDefinition :\n")
            file:write("\t |\n")
            file:write("\t */\n")
        end
    end
end

local flags = CS.System.Reflection.BindingFlags.Instance | --
CS.System.Reflection.BindingFlags.Static | --
CS.System.Reflection.BindingFlags.Public | --
CS.System.Reflection.BindingFlags.NonPublic

local function do_dump_csharp_type(file, type, index, rvas)
    file:write(string.format("// TypeDefIndex: %d\n", index))
    file:write(string.format("// Module: %s\n", type.Module.name))
    local namespace = type.Namespace
    if namespace == nil then
        file:write("// Namespace:\n")
    else
        file:write(string.format("// Namespace: %s\n", namespace))
    end
    local index = 2

    local attributes = type:GetCustomAttributes(true)
    for i = 0, attributes.Length - 1 do
        local text = get_runtime_type_name(attributes[i]:GetType())
        file:write(string.format("[%s]\n", text))
    end

    file:write(get_type_string(type) .. get_runtime_type_name(type, false))
    if not type.IsEnum then
        local once = false
        local base_type = type.BaseType
        if base_type ~= nil then
            local name = get_runtime_type_name_alias(base_type)
            if name ~= "object" and name ~= "ValueType" then
                once = true
            end
            if once then
                file:write(" : " .. name)
            end
        end
        local interfaces = type:GetInterfaces()
        if interfaces.Length > 0 then
            for i = 0, interfaces.Length - 1 do
                local interface = interfaces[i]
                local name = get_runtime_type_name_alias(interface)
                if interface.FullName ~= nil then
                    local full = interface.FullName
                    if base_type ~= nil then
                        local base_interfaces = base_type:GetInterfaces()
                        for i = 0, base_interfaces.Length - 1 do
                            local base_interface = base_interfaces[i]
                            if base_interface.FullName == interface.FullName then
                                goto continue
                            end
                        end
                    end
                end
                if not once then
                    once = true
                    file:write(" : " .. name)
                else
                    file:write(", " .. name)
                end
                ::continue::
            end
        end
    end

    file:write("\n{")

    local fields = type:GetFields(flags)
    if fields.Length > 0 then
        local once = false
        for j = 0, fields.Length - 1 do
            local field = fields[j]
            if field.DeclaringType == type then
                if not once then
                    file:write("\n")
                    file:write("\t// Fields\n")
                    once = true
                end
                local attributes = field:GetCustomAttributes(true)
                for i = 0, attributes.Length - 1 do
                    local text = get_runtime_type_name(attributes[i]:GetType())
                    file:write(string.format("\t[%s]\n", text))
                end
                file:write("\t")
                do_dump_csharp_field(file, field)
            end
        end
    end

    local properties = type:GetProperties(flags)
    if properties.Length > 0 then
        local once = false
        for j = 0, properties.Length - 1 do
            local property = properties[j]
            if property.DeclaringType == type then
                if not once then
                    file:write("\n")
                    file:write("\t// Properties\n")
                    once = true
                end
                local attributes = property:GetCustomAttributes(true)
                for i = 0, attributes.Length - 1 do
                    local text = get_runtime_type_name(attributes[i]:GetType())
                    file:write(string.format("\t[%s]\n", text))
                end
                file:write("\t")
                do_dump_csharp_property(file, property)
            end
        end
    end

    local constructors = type:GetConstructors(flags)
    if constructors.Length > 0 then
        local once = false
        for j = 0, constructors.Length - 1 do
            local constructor = constructors[j]
            if constructor.DeclaringType == type then
                if not once then
                    file:write("\n")
                    file:write("\t// Constructors\n")
                    once = true
                end
                local attributes = constructor:GetCustomAttributes(true)
                for i = 0, attributes.Length - 1 do
                    local text = get_runtime_type_name(attributes[i]:GetType())
                    file:write(string.format("\t[%s]\n", text))
                end
                file:write("\t")
                do_dump_csharp_method(file, type, constructor, rvas[index], true)
                index = index + 1
            end
        end
    end

    local methods = type:GetMethods(flags)
    if methods.Length > 0 then
        local once = false
        for j = 0, methods.Length - 1 do
            local method = methods[j]
            if method.DeclaringType == type then
                if not once then
                    file:write("\n")
                    file:write("\t// Methods\n")
                    once = true
                end
                local attributes = method:GetCustomAttributes(true)
                for i = 0, attributes.Length - 1 do
                    local text = get_runtime_type_name(attributes[i]:GetType())
                    file:write(string.format("\t[%s]\n", text))
                end
                file:write("\t")
                do_dump_csharp_method(file, type, method, rvas[index], false)
                index = index + 1
            end
        end
    end

    file:write("}\n")
end

local function split(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t={}
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
        table.insert(t, str)
    end
    return t
end

local function get_rvas(index)
    return {}
    -- return split(CS.MiHoYo.SDK.SDKUtil.RSAEncrypt("get_rva", string.format("%d", index)), ";")
end

local function do_dump_csharp()
    local file = io.open(DUMP_CS_FILE, "w")

    local assemblies = CS.System.AppDomain.CurrentDomain:GetAssemblies()
    for i = 0, assemblies.Length - 1 do
        local assembly = assemblies[i]
        file:write(string.format("// Assembly %d: %s\n", i, assembly:ToString()))
    end

    local index = 0

    for i = 0, assemblies.Length - 1 do
        local assembly = assemblies[i]
        local types = assembly:GetTypes()
        log:write(string.format("dumping types in assembly %d: %s, total: %d\n", --
        i, assembly:ToString(), types.Length))
        for j = 0, types.Length - 1 do
            local type = types[j]
            file:write("\n")
            local rvas = {}
            while true do
                rvas = get_rvas(index)
                if rvas[1] ~= "<Module>" then
                    break
                end
                file:write(string.format("// TypeDefIndex: %d\n", index))
                file:write(string.format("// Module: %s\n", type.Module.name))
                local namespace = type.Namespace
                if namespace == nil then
                    file:write("// Namespace:\n")
                else
                    file:write(string.format("// Namespace: %s\n", namespace))
                end
                file:write("internal class <Module>\n{}\n\n")
                index = index + 1
            end
            do_dump_csharp_type(file, type, index, rvas)
            index = index + 1
        end
    end

    file:close()
end

local function main()
    log:write("start dumping csharp to " .. DUMP_CS_FILE .. "\n")
    do_dump_csharp()
    log:write("dumping csharp done\n")
end

local function on_error(error)
    log:write("dumping csharp failed, error: " .. error .. "\n")
end

xpcall(main, on_error)

log:close()