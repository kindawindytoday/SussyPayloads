-- V1 
local GM = {}

local GameObject = CS.UnityEngine.GameObject
local Object = CS.UnityEngine.Object
local Vector2 = CS.UnityEngine.Vector2
local Vector3 = CS.UnityEngine.Vector3
local Quaternion = CS.UnityEngine.Quaternion
local Color = CS.UnityEngine.Color
local Resources = CS.UnityEngine.Resources
local Time = CS.UnityEngine.Time
local Application = CS.UnityEngine.Application
local RenderSettings = CS.UnityEngine.RenderSettings
local Input = CS.UnityEngine.Input
local KeyCode = CS.UnityEngine.KeyCode
local WaitForSeconds = CS.UnityEngine.WaitForSeconds
local Camera = CS.UnityEngine.Camera
local AudioListener = CS.UnityEngine.AudioListener
local Renderer = CS.UnityEngine.Renderer
local Image = CS.UnityEngine.UI.Image
local Text = CS.UnityEngine.UI.Text
local Button = CS.UnityEngine.UI.Button
local InputField = CS.UnityEngine.UI.InputField
local RectTransform = CS.UnityEngine.RectTransform
local Font = CS.UnityEngine.Font
local LuaManager = CS.MoleMole.LuaManager
local ActorUtils = CS.MoleMole.ActorUtils

GM.cfg = {
    panel_name = "GM_FPV_Tool_Panel",
    fpv_cam_name = "GMSelectedBoneFPVCamera",
    old_cam_name = "MainCamera(Clone)",
    head_path = table.concat({
        "Bip001", "Bip001 Pelvis", "Bip001 Spine", "Bip001 Spine1",
        "Bip001 Spine2", "Bip001 Neck", "Bip001 Head"
    }, "/"),
    bone_names = { "Bip001 Head", "Head", "head", "Bip001 Neck", "Neck", "Bip001 Spine2", "Spine2" },
    local_offset = Vector3(0.0, 0.12, 0.22),
    fov = 68,
    near_clip = 0.02,
    mouse_sensitivity = 2.5,
    yaw_limit = 90,
    pitch_limit = 45,
    sensitive_pitch_down = 28,
    hide_face_in_fpv = true,
    max_items_per_column = 10,
}

GM.state = {
    panel = nil,
    avatar_list = nil,
    monster_list = nil,
    avatar_search = nil,
    monster_search = nil,
    selected_go = nil,
    selected_source_go = nil,
    selected_is_avatar = false,
    selected_bone = nil,
    selected_label = "None",
    selected_text = nil,
    angle_text = nil,
    fpv_enabled = false,
    old_cam = nil,
    fpv_cam = nil,
    yaw = 0,
    pitch = 0,
    hidden_renderers = nil,
    face_hidden_renderers = nil,
    acc_value = 1.0,
    fps_value = 60,
    next_list_refresh = 0,
}

local font = nil
local function ui_font()
    if font == nil then
        font = Resources.GetBuiltinResource(typeof(Font), "Arial.ttf")
    end
    return font
end

local function show(msg)
    if ActorUtils and ActorUtils.ShowMessage then
        ActorUtils.ShowMessage(tostring(msg))
    end
end

local function clamp(v, min_v, max_v)
    if v < min_v then return min_v end
    if v > max_v then return max_v end
    return v
end

local function lower(s)
    if s == nil then return "" end
    return string.lower(tostring(s))
end

function GM:set_rect(go, size, pos)
    local rt = go:GetComponent(typeof(RectTransform))
    if rt == nil then rt = go:AddComponent(typeof(RectTransform)) end
    rt.sizeDelta = size
    rt.localPosition = pos
    rt.localScale = Vector3.one
    return rt
end

function GM:add_image(go, color)
    local img = go:GetComponent(typeof(Image))
    if img == nil then img = go:AddComponent(typeof(Image)) end
    img.color = color
    return img
end

function GM:create_text(name, parent, value, size, pos, font_size, color, align)
    local go = GameObject(name)
    go.transform:SetParent(parent.transform, false)
    self:set_rect(go, size, pos)
    local txt = go:AddComponent(typeof(Text))
    txt.font = ui_font()
    txt.text = value or ""
    txt.fontSize = font_size or 16
    txt.color = color or Color(1, 1, 1, 1)
    txt.alignment = align or CS.UnityEngine.TextAnchor.MiddleCenter
    return go, txt
end

function GM:create_button(name, parent, label, size, pos, callback)
    local go = GameObject(name)
    go.transform:SetParent(parent.transform, false)
    self:set_rect(go, size, pos)
    self:add_image(go, Color(0.88, 0.88, 0.88, 0.95))
    local btn = go:AddComponent(typeof(Button))
    if callback then btn.onClick:AddListener(callback) end
    self:create_text(name .. "_Text", go, label, size, Vector3(0, 0, 0), 15, Color(0, 0, 0, 1))
    return go, btn
end

function GM:create_input(name, parent, placeholder, size, pos, on_change)
    local go = GameObject(name)
    go.transform:SetParent(parent.transform, false)
    self:set_rect(go, size, pos)
    self:add_image(go, Color(1, 1, 1, 0.92))

    local input = go:AddComponent(typeof(InputField))
    local text_go, text = self:create_text(name .. "_Text", go, "", Vector2(size.x - 18, size.y), Vector3(6, 0, 0), 14, Color(0, 0, 0, 1), CS.UnityEngine.TextAnchor.MiddleLeft)
    local ph_go, ph = self:create_text(name .. "_Placeholder", go, placeholder, Vector2(size.x - 18, size.y), Vector3(6, 0, 0), 14, Color(0.45, 0.45, 0.45, 1), CS.UnityEngine.TextAnchor.MiddleLeft)
    input.textComponent = text
    input.placeholder = ph
    if on_change then input.onValueChanged:AddListener(on_change) end
    return go, input
end

function GM:clear_children(parent_go)
    if not parent_go then return end
    local tf = parent_go.transform
    for i = tf.childCount - 1, 0, -1 do
        Object.Destroy(tf:GetChild(i).gameObject)
    end
end

function GM:find_child_go(root_go, path)
    if not root_go then return nil end
    local tf = root_go.transform:Find(path)
    if tf then return tf.gameObject end
    return nil
end

function GM:find_named_transform(tf, names)
    if not tf then return nil end
    for i = 1, #names do
        if tf.name == names[i] then return tf end
    end
    for i = 0, tf.childCount - 1 do
        local found = self:find_named_transform(tf:GetChild(i), names)
        if found then return found end
    end
    return nil
end

function GM:get_root(path)
    return GameObject.Find(path)
end

function GM:get_avatar_model(item_go)
    if item_go == nil then return nil end
    local offset_dummy = self:find_child_go(item_go, "OffsetDummy")
    if offset_dummy and offset_dummy.transform.childCount > 0 then
        local base_name = item_go.name
        if #base_name >= 7 and base_name:sub(-7) == "(Clone)" then
            base_name = base_name:sub(1, #base_name - 7)
        end
        local model = self:find_child_go(offset_dummy, base_name)
        if model then return model end
        return offset_dummy.transform:GetChild(0).gameObject
    end
    return item_go
end

function GM:get_bind_bone(go, is_avatar)
    if go == nil then return nil end
    local root = go
    if is_avatar then root = self:get_avatar_model(go) end
    if root == nil then return nil end

    local head = self:find_child_go(root, self.cfg.head_path)
    if head then return head.transform, root end

    local named = self:find_named_transform(root.transform, self.cfg.bone_names)
    if named then return named, root end

    return root.transform, root
end
function GM:find_active_avatar_item()
    local avatar_root = GameObject.Find("/EntityRoot/AvatarRoot")
    if not avatar_root then return nil end
    for i = 0, avatar_root.transform.childCount - 1 do
        local child = avatar_root.transform:GetChild(i).gameObject
        if child.activeInHierarchy then return child end
    end
    return nil
end

function GM:auto_switch_inactive_avatar()
    if not self.state.fpv_enabled then return end
    if not self.state.selected_is_avatar then return end

    local source = self.state.selected_source_go or self.state.selected_go
    if source and source.activeInHierarchy then return end

    local active = self:find_active_avatar_item()
    if not active then return end

    local bone, model = self:get_bind_bone(active, true)
    if not bone then return end

    self:restore_renderers()
    self:restore_face_renderers()
    self.state.selected_source_go = active
    self.state.selected_is_avatar = true
    self.state.selected_go = model or active
    self.state.selected_bone = bone
    self.state.selected_label = "Avatar: " .. active.name .. " / " .. bone.name
    self.state.yaw = 0
    self.state.pitch = 0

    if self.state.selected_text then
        self.state.selected_text.text = "Selected: " .. self.state.selected_label
    end
end


function GM:collect_direct_children(root_path, filter_text)
    local result = {}
    local root = self:get_root(root_path)
    if root == nil then return result end

    local f = lower(filter_text)
    for i = 0, root.transform.childCount - 1 do
        local child = root.transform:GetChild(i).gameObject
        local name = child.name or "<unnamed>"
        if f == "" or string.find(lower(name), f, 1, true) ~= nil then
            table.insert(result, child)
        end
    end
    return result
end

function GM:set_selected(go, is_avatar)
    local bone, model = self:get_bind_bone(go, is_avatar)
    if bone == nil then
        show("No bind bone found")
        return
    end

    self:restore_renderers()
    self.state.selected_source_go = go
    self.state.selected_is_avatar = is_avatar
    self.state.selected_go = model or go
    self.state.selected_bone = bone
    self.state.selected_label = (is_avatar and "Avatar: " or "Monster: ") .. go.name .. " / " .. bone.name
    self.state.yaw = 0
    self.state.pitch = 0

    if self.state.selected_text then
        self.state.selected_text.text = "Selected: " .. self.state.selected_label
    end

    show("Selected " .. go.name)
    self:update_angle_text()
    self:enable_fpv()
end

function GM:get_active_avatar_position()
    local avatar = self:find_active_avatar_item()
    if not avatar then return nil end
    local model = self:get_avatar_model(avatar)
    if model then return model.transform.position end
    return avatar.transform.position
end

function GM:get_distance_to_active_avatar(go)
    local avatar_pos = self:get_active_avatar_position()
    if not avatar_pos or not go then return nil end
    return Vector3.Distance(avatar_pos, go.transform.position)
end
function GM:create_item_button(parent, go, is_avatar, y)
    local prefix = is_avatar and "A" or "M"
    local active_mark = go.activeInHierarchy and "* " or "  "
    local dist_text = ""
    if not is_avatar then
        local distance = self:get_distance_to_active_avatar(go)
        if distance then dist_text = string.format(" [%.1fm]", distance) end
    end
    local label = active_mark .. go.name .. dist_text
    self:create_button(prefix .. "_Item_" .. tostring(y), parent, label, Vector2(268, 28), Vector3(0, y, 0), function()
        GM:set_selected(go, is_avatar)
    end)
end

function GM:refresh_lists()
    if not self.state.avatar_list or not self.state.monster_list then return end
    self:clear_children(self.state.avatar_list)
    self:clear_children(self.state.monster_list)

    local avatar_filter = self.state.avatar_search and self.state.avatar_search.text or ""
    local monster_filter = self.state.monster_search and self.state.monster_search.text or ""
    local avatars = self:collect_direct_children("/EntityRoot/AvatarRoot", avatar_filter)
    local monsters = self:collect_direct_children("/EntityRoot/MonsterRoot", monster_filter)

    local max_count = self.cfg.max_items_per_column
    for i = 1, math.min(#avatars, max_count) do
        self:create_item_button(self.state.avatar_list, avatars[i], true, 126 - (i - 1) * 32)
    end
    for i = 1, math.min(#monsters, max_count) do
        self:create_item_button(self.state.monster_list, monsters[i], false, 126 - (i - 1) * 32)
    end
end

function GM:resolve_old_camera()
    local old = self.state.old_cam
    if old then return old end
    old = GameObject.Find(self.cfg.old_cam_name)
    if not old and Camera.main then old = Camera.main.gameObject end
    self.state.old_cam = old
    return old
end

function GM:set_camera_enabled(go, enabled)
    if not go then return end
    local cam = go:GetComponent(typeof(Camera))
    if cam then cam.enabled = enabled end
    local listener = go:GetComponent(typeof(AudioListener))
    if listener then listener.enabled = enabled end
end

function GM:disable_cinemachine_brain(go)
    if not go then return end
    local ok, brain = pcall(function()
        return go:GetComponent(typeof(CS.Cinemachine.CinemachineBrain))
    end)
    if ok and brain then
        brain.enabled = false
    end
end
function GM:prepare_fpv_camera()
    local old_cam = self:resolve_old_camera()
    if not old_cam then return nil end

    local fpv_cam = self.state.fpv_cam or GameObject.Find(self.cfg.fpv_cam_name)
    if not fpv_cam then
        fpv_cam = Object.Instantiate(old_cam)
        fpv_cam.name = self.cfg.fpv_cam_name
    end
    self.state.fpv_cam = fpv_cam

    local cam = fpv_cam:GetComponent(typeof(Camera))
    if cam then
        cam.enabled = true
        cam.fieldOfView = self.cfg.fov
        cam.nearClipPlane = self.cfg.near_clip
    end
    local listener = fpv_cam:GetComponent(typeof(AudioListener))
    if listener then listener.enabled = true end
    fpv_cam:SetActive(true)
    fpv_cam.tag = "MainCamera"
    self:disable_cinemachine_brain(fpv_cam)
    return fpv_cam
end

function GM:get_body_base_rotation()
    local go = self.state.selected_go
    if not go then return Quaternion.identity end
    local fwd = go.transform.forward
    fwd.y = 0
    if fwd.sqrMagnitude < 0.000001 then fwd = Vector3.forward end
    return Quaternion.LookRotation(fwd.normalized, Vector3.up)
end

function GM:enable_fpv()
    if self.state.selected_bone == nil then
        show("Select an Avatar or Monster first")
        return
    end

    local fpv_cam = self:prepare_fpv_camera()
    local old_cam = self:resolve_old_camera()
    if not fpv_cam or not old_cam then
        show("Camera not found")
        return
    end

    fpv_cam.transform:SetParent(nil, true)
    self:set_camera_enabled(old_cam, false)
    old_cam.tag = "Untagged"
    self.state.fpv_enabled = true
    self:hide_face_renderers()
    show("FPV enabled")
end

function GM:disable_fpv()
    if not self.state.fpv_enabled then return end
    self:restore_renderers()
    self:restore_face_renderers()

    local fpv_cam = self.state.fpv_cam or GameObject.Find(self.cfg.fpv_cam_name)
    if fpv_cam then Object.Destroy(fpv_cam) end
    self.state.fpv_cam = nil

    local old_cam = self:resolve_old_camera()
    if old_cam then
        self:set_camera_enabled(old_cam, true)
        old_cam:SetActive(true)
        old_cam.tag = "MainCamera"
    end

    self.state.fpv_enabled = false
    show("FPV disabled")
end

function GM:toggle_fpv()
    if self.state.fpv_enabled then self:disable_fpv() else self:enable_fpv() end
end

function GM:restore_renderers()
    local cache = self.state.hidden_renderers
    if cache then
        for i = 1, #cache do
            if cache[i] then cache[i].enabled = true end
        end
    end
    self.state.hidden_renderers = nil
end

function GM:is_face_renderer(renderer)
    if renderer == nil then return false end
    local n = lower(renderer.gameObject.name)
    return string.find(n, "face", 1, true) ~= nil
end

function GM:hide_face_renderers()
    if not self.cfg.hide_face_in_fpv then return end
    if self.state.face_hidden_renderers ~= nil then return end
    local selected = self.state.selected_go
    if not selected then return end

    local cache = {}
    local renderers = selected:GetComponentsInChildren(typeof(Renderer), true)
    if renderers then
        for i = 0, renderers.Length - 1 do
            local r = renderers[i]
            if r.enabled and self:is_face_renderer(r) then
                table.insert(cache, r)
                r.enabled = false
            end
        end
    end
    self.state.face_hidden_renderers = cache
end

function GM:restore_face_renderers()
    local cache = self.state.face_hidden_renderers
    if cache then
        for i = 1, #cache do
            if cache[i] then cache[i].enabled = true end
        end
    end
    self.state.face_hidden_renderers = nil
end
function GM:update_sensitive_hide()
    -- Full-body renderer hiding is intentionally disabled.
    -- Only face renderers are hidden by hide_face_renderers().
    if self.state.hidden_renderers ~= nil then
        self:restore_renderers()
    end
end

function GM:update_fpv_camera()
    if not self.state.fpv_enabled then return end
    self:auto_switch_inactive_avatar()
    local fpv_cam = self.state.fpv_cam
    local bone = self.state.selected_bone
    if not fpv_cam or not bone then return end

    local mx = Input.GetAxis("Mouse X") * self.cfg.mouse_sensitivity * 100 * Time.deltaTime
    local my = Input.GetAxis("Mouse Y") * self.cfg.mouse_sensitivity * 100 * Time.deltaTime
    self.state.yaw = clamp(self.state.yaw + mx, -self.cfg.yaw_limit, self.cfg.yaw_limit)
    self.state.pitch = clamp(self.state.pitch - my, -self.cfg.pitch_limit, self.cfg.pitch_limit)

    local base_rot = self:get_body_base_rotation()
    local yaw_rot = Quaternion.AngleAxis(self.state.yaw, Vector3.up)
    local pitch_rot = Quaternion.AngleAxis(self.state.pitch, Vector3.right)

    fpv_cam.transform.position = bone.position + (base_rot * self.cfg.local_offset)
    fpv_cam.transform.rotation = base_rot * yaw_rot * pitch_rot
    self:update_angle_text()
    self:update_sensitive_hide()

    local old_cam = self:resolve_old_camera()
    if old_cam then self:set_camera_enabled(old_cam, false) end
end

function GM:clone_active_avatar()
    local avatar_root = GameObject.Find("/EntityRoot/AvatarRoot")
    if not avatar_root then return end
    for i = 0, avatar_root.transform.childCount - 1 do
        local avatar = avatar_root.transform:GetChild(i).gameObject
        if avatar.activeInHierarchy then
            local model = self:get_avatar_model(avatar)
            if model then
                local clone = Object.Instantiate(model)
                clone.name = model.name .. "_GMClone"
                clone.transform.position = model.transform.position
                clone.transform.rotation = model.transform.rotation
                show("Avatar cloned")
            end
            return
        end
    end
end

function GM:update_angle_text()
    if not self.state.angle_text then return end
    self.state.angle_text.text = string.format(
        "Yaw: %.1f / %d    Pitch: %.1f / %d",
        self.state.yaw or 0,
        self.cfg.yaw_limit or 0,
        self.state.pitch or 0,
        self.cfg.pitch_limit or 0
    )
end

function GM:change_yaw_limit(delta)
    self.cfg.yaw_limit = clamp((self.cfg.yaw_limit or 90) + delta, 10, 180)
    self.state.yaw = clamp(self.state.yaw or 0, -self.cfg.yaw_limit, self.cfg.yaw_limit)
    self:update_angle_text()
    show("Yaw limit " .. tostring(self.cfg.yaw_limit))
end

function GM:change_pitch_limit(delta)
    self.cfg.pitch_limit = clamp((self.cfg.pitch_limit or 70) + delta, 10, 180)
    self.state.pitch = clamp(self.state.pitch or 0, -self.cfg.pitch_limit, self.cfg.pitch_limit)
    self:update_angle_text()
    show("Pitch limit " .. tostring(self.cfg.pitch_limit))
end
function GM:goto_selected_monster()
    if self.state.selected_is_avatar then
        show("Select a monster first")
        return
    end

    local target = self.state.selected_source_go or self.state.selected_go
    if not target then
        show("No monster selected")
        return
    end

    local pos = target.transform.position
    local forward = target.transform.forward
    if forward.sqrMagnitude < 0.000001 then forward = Vector3.forward end

    local target_pos = pos - forward.normalized * 2.0
    target_pos.y = pos.y
    ActorUtils.SetAvatarPos(target_pos)
    show("Goto " .. target.name)
end
function GM:build_panel()
    local canvas = GameObject.Find("/Canvas") or GameObject.Find("Canvas")
    if not canvas then
        show("Canvas not found")
        return nil
    end

    local existing = GameObject.Find(self.cfg.panel_name)
    if existing then Object.Destroy(existing) end

    local panel = GameObject(self.cfg.panel_name)
    panel.transform:SetParent(canvas.transform, false)
    self:set_rect(panel, Vector2(620, 520), Vector3(0, 0, 0))
    self:add_image(panel, Color(0.05, 0.06, 0.07, 0.88))
    self.state.panel = panel

    self:create_text("GM_Title", panel, "GM FPV Tool", Vector2(580, 34), Vector3(0, 232, 0), 20, Color(1, 1, 1, 1))
    local _, selected_text = self:create_text("GM_Selected", panel, "Selected: None", Vector2(560, 22), Vector3(0, 204, 0), 14, Color(0.82, 0.92, 1, 1))
    self.state.selected_text = selected_text
    local _, angle_text = self:create_text("GM_Angle", panel, "Yaw: 0.0 / 90    Pitch: 0.0 / 70", Vector2(560, 22), Vector3(0, 181, 0), 14, Color(1, 0.92, 0.62, 1))
    self.state.angle_text = angle_text
    self:update_angle_text()

    self:create_button("GM_FPV_Toggle", panel, "Toggle FPV", Vector2(105, 30), Vector3(-250, 148, 0), function() GM:toggle_fpv() end)
    self:create_button("GM_Goto", panel, "Goto", Vector2(70, 30), Vector3(-158, 148, 0), function() GM:goto_selected_monster() end)
    self:create_button("GM_Refresh", panel, "Refresh", Vector2(82, 30), Vector3(-78, 148, 0), function() GM:refresh_lists() end)
    self:create_button("GM_Clone", panel, "Clone", Vector2(70, 30), Vector3(4, 148, 0), function() GM:clone_active_avatar() end)
    self:create_button("GM_Time", panel, "Time", Vector2(70, 30), Vector3(82, 148, 0), function()
        GM.state.acc_value = GM.state.acc_value + 0.5
        if GM.state.acc_value > 5 then GM.state.acc_value = 1 end
        Time.timeScale = GM.state.acc_value
        show("TimeScale " .. tostring(GM.state.acc_value))
    end)
    self:create_button("GM_FPS", panel, "FPS", Vector2(60, 30), Vector3(150, 148, 0), function()
        GM.state.fps_value = GM.state.fps_value + 30
        if GM.state.fps_value > 180 then GM.state.fps_value = 30 end
        Application.targetFrameRate = GM.state.fps_value
        show("FPS " .. tostring(GM.state.fps_value))
    end)

    self:create_button("GM_Yaw_Minus", panel, "Yaw -", Vector2(62, 26), Vector3(-270, -198, 0), function() GM:change_yaw_limit(-10) end)
    self:create_button("GM_Yaw_Plus", panel, "Yaw +", Vector2(62, 26), Vector3(-198, -198, 0), function() GM:change_yaw_limit(10) end)
    self:create_button("GM_Pitch_Minus", panel, "Pitch -", Vector2(70, 26), Vector3(-270, -232, 0), function() GM:change_pitch_limit(-10) end)
    self:create_button("GM_Pitch_Plus", panel, "Pitch +", Vector2(70, 26), Vector3(-194, -232, 0), function() GM:change_pitch_limit(10) end)
    self:create_text("Avatar_Column_Title", panel, "AvatarRoot", Vector2(260, 24), Vector3(-155, 122, 0), 16, Color(1, 1, 1, 1))
    self:create_text("Monster_Column_Title", panel, "EntityRoot/MonsterRoot", Vector2(260, 24), Vector3(155, 122, 0), 15, Color(1, 1, 1, 1))

    local _, avatar_search = self:create_input("Avatar_Search", panel, "Search avatar", Vector2(260, 30), Vector3(-155, 92, 0), function() GM:refresh_lists() end)
    local _, monster_search = self:create_input("Monster_Search", panel, "Search monster", Vector2(260, 30), Vector3(155, 92, 0), function() GM:refresh_lists() end)
    self.state.avatar_search = avatar_search
    self.state.monster_search = monster_search

    local avatar_list = GameObject("Avatar_List")
    avatar_list.transform:SetParent(panel.transform, false)
    self:set_rect(avatar_list, Vector2(270, 340), Vector3(-155, -80, 0))
    local monster_list = GameObject("Monster_List")
    monster_list.transform:SetParent(panel.transform, false)
    self:set_rect(monster_list, Vector2(270, 340), Vector3(155, -80, 0))
    self.state.avatar_list = avatar_list
    self.state.monster_list = monster_list

    panel:SetActive(false)
    self:refresh_lists()
    return panel
end

function GM:toggle_panel()
    if self.state.panel == nil then self:build_panel() end
    if self.state.panel then
        self.state.panel:SetActive(not self.state.panel.activeSelf)
        if self.state.panel.activeSelf then self:refresh_lists() end
    end
end

function GM:hook_gm_button()
    local btn_go = GameObject.Find("/Canvas/Pages/InLevelMainPage/GrpMainPage/GrpMainBtn/GrpMainToggle/GrpTopPanel/BtnGm")
    if btn_go then
        Object.DontDestroyOnLoad(btn_go)
        btn_go:SetActive(true)
        local btn = btn_go:GetComponent(typeof(Button))
        if btn then btn.onClick:AddListener(function() GM:toggle_panel() end) end
    else
        show("BtnGm not found; panel opened directly")
        if self.state.panel then self.state.panel:SetActive(true) end
    end
end

function GM:update_live_lists()
    local panel = self.state.panel
    if not panel or not panel.activeSelf then return end
    if Time.time < self.state.next_list_refresh then return end
    self.state.next_list_refresh = Time.time + 0.5
    self:refresh_lists()
end
function GM:start_loop()
    local mgr = LuaManager()
    local function loop_once()
        GM:update_fpv_camera()
        GM:update_angle_text()
        GM:update_live_lists()
        mgr:YieldCallback(WaitForSeconds(0), loop_once)
    end
    mgr:YieldCallback(WaitForSeconds(0), loop_once)
end

function GM:init()
    self:build_panel()
    self:hook_gm_button()
    self:start_loop()
    show("GM FPV Tool loaded")
end

local function on_error(err)
    show("GM FPV error: " .. tostring(err))
end

xpcall(function() GM:init() end, on_error)

return GM








