local function findActiveAvatar()
    local avatarRoot = CS.UnityEngine.GameObject.Find("/EntityRoot/AvatarRoot")
    if avatarRoot.transform.childCount == 0 then
        return
    end
    for i = 0, avatarRoot.transform.childCount - 1 do
        local avatar = avatarRoot.transform:GetChild(i)
        if avatar.gameObject.activeInHierarchy then
            return avatar.gameObject
        end
    end
end

local function findAvatarBody(avatar)
    for i = 0, avatar.transform.childCount - 1 do
        local transform = avatar.transform:GetChild(i)
        if transform.name == "OffsetDummy" then
            for j = 0, transform.childCount - 1 do
                local child = transform:GetChild(j)
                for k = 0, child.transform.childCount - 1 do
                    local body = child.transform:GetChild(k)
                    if body.name == "Body" then
                        return body.gameObject
                    end
                end
            end
        end
    end
end
local function createPrimitive()
    local nowAvatar = findActiveAvatar()
    local nowBody = findAvatarBody(nowAvatar)
    local primitive = CS.UnityEngine.GameObject.CreatePrimitive(CS.UnityEngine.PrimitiveType.Plane);
    primitive.transform.localScale = CS.UnityEngine.Vector3(3.2,1,1.8);
    primitive.transform.localRotation = CS.UnityEngine.Quaternion(0.5, 0.5,-0.5, 0.5);
    local position = nowBody.transform.position
    primitive.transform.position = CS.UnityEngine.Vector3(position.x, position.y + 5, position.z);
    local browser = primitive:AddComponent(typeof(CS.ZenFulcrum.EmbeddedBrowser.Browser));
    browser._url = "https://google.com";
    browser._width = 1920;
    browser._height = 1080;
end
function start()
    createPrimitive()
	CS.UnityEngine.GameObject.Find("/BetaWatermarkCanvas(Clone)/Panel/TxtUID"):GetComponent("Text").text = "sob"
end

start()
