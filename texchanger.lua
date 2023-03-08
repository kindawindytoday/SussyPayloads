local findActiveAvatar = function()
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
local findAvatarBody = function(avatar)
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
local replaceHair = function()
  local currAvatar = findActiveAvatar()
  local currBody = findAvatarBody(currAvatar)
  local texture = CS.UnityEngine.Texture2D(2048, 2048)
  local image = CS.System.IO.File.ReadAllBytes("sdcard/Windy/tex_test/hair.png") -- hair.png
  CS.UnityEngine.ImageConversion.LoadImage(texture, image)
  local renderer = currBody:GetComponent(typeof(CS.UnityEngine.SkinnedMeshRenderer))
  renderer.materials[0].mainTexture = texture
  CS.MoleMole.ActorUtils.ShowMessage("Hair Texture Applied!")
end
local replaceBody = function()
  local currAvatar = findActiveAvatar()
  local currBody = findAvatarBody(currAvatar)
  local texture = CS.UnityEngine.Texture2D(2048, 2048)
  local image = CS.System.IO.File.ReadAllBytes("sdcard/Windy/tex_test/body.png") -- body.png
  CS.UnityEngine.ImageConversion.LoadImage(texture, image)
  local renderer = currBody:GetComponent(typeof(CS.UnityEngine.SkinnedMeshRenderer))
  renderer.materials[1].mainTexture = texture
  CS.MoleMole.ActorUtils.ShowMessage("Body Texture Applied!")
end
local replaceBody2 = function()
  local currAvatar = findActiveAvatar()
  local currBody = findAvatarBody(currAvatar)
  local texture = CS.UnityEngine.Texture2D(2048, 2048)
  local image = CS.System.IO.File.ReadAllBytes("sdcard/Windy/tex_test/body.png") -- 2nd body (something like another texture on body)
  CS.UnityEngine.ImageConversion.LoadImage(texture, image)
  local renderer = currBody:GetComponent(typeof(CS.UnityEngine.SkinnedMeshRenderer))
  renderer.materials[2].mainTexture = texture
  CS.MoleMole.ActorUtils.ShowMessage("2nd Body Texture Applied!")
end
local replaceTexture = function()
  replaceHair()
  replaceBody()
  replaceBody2()
end

replaceTexture()