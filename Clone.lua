local findBodyPartWithName = function(model, queryName)
  for i = 0, model.transform.childCount - 1 do
    local child = model.transform:GetChild(i)
    if child.name:find(queryName) then
      return child.gameObject
    end
  end
end
local getOtherAvatarBipLocalRotation = function(avatar)
  for i = 0, avatar.transform.childCount - 1 do
    local checkbip = avatar.transform:GetChild(i)
    if checkbip.name == "Bip001" then
      return checkbip.gameObject.transform.localRotation
    end
  end
end
local getOtherAvatarBipRotation = function(avatar)
  for i = 0, avatar.transform.childCount - 1 do
    local checkbip = avatar.transform:GetChild(i)
    if checkbip.name == "Bip001" then
      return checkbip.gameObject.transform.rotation
    end
  end
end
local findActiveCharacter = function()
  local avatarRoot = CS.UnityEngine.GameObject.Find("/EntityRoot/AvatarRoot")
  if avatarRoot.transform.childCount == 0 then
    return
  end
  for i = 0, avatarRoot.transform.childCount - 1 do
    local getCurrAvatar = avatarRoot.transform:GetChild(i)
    if getCurrAvatar.gameObject.activeInHierarchy then
      return getCurrAvatar.gameObject
    end
  end
end
local findActiveCharacterBody = function(avatar)
  for i = 0, avatar.transform.childCount - 1 do
    local checkbody = avatar.transform:GetChild(i)
    if checkbody.name == "Body" then
      return checkbody.gameObject
    end
  end
end
local findActiveCharacterModel = function()
  local avatarRoot = CS.UnityEngine.GameObject.Find("/EntityRoot/AvatarRoot")
  if avatarRoot.transform.childCount == 0 then
    return
  end
  for i = 0, avatarRoot.transform.childCount - 1 do
    local getCurrAvatar = avatarRoot.transform:GetChild(i)
    if getCurrAvatar.gameObject.activeInHierarchy then
      for j = 0, getCurrAvatar.transform.childCount - 1 do
        local getOffsetDummy = getCurrAvatar.transform:GetChild(j)
        if getOffsetDummy.name:find("OffsetDummy") then
          local getAvatarFromOffsetDummy = getOffsetDummy.transform:GetChild(0)
          return getAvatarFromOffsetDummy.gameObject
        end
      end
    end
  end
end
local findHierarchyPath = function(child)
  local path = "/" .. child.name
  while child.transform.parent ~= nil do
    child = child.transform.parent.gameObject
    path = "/" .. child.name .. path
  end
  return path
end
local swap = function()
  local currAvatarModel = findActiveCharacterModel()
  local clonedModel = CS.UnityEngine.GameObject.Instantiate(currAvatarModel)
  clonedModel.transform.position = currAvatarModel.transform.position
  local avatarRoot = CS.UnityEngine.GameObject.Find("/EntityRoot/AvatarRoot")
  local cloneAvatarRoot = CS.UnityEngine.GameObject.Instantiate(avatarRoot)
  for i = 0, cloneAvatarRoot.transform.childCount - 1 do
    local avatars = cloneAvatarRoot.transform:GetChild(i).gameObject
    avatars:SetActive(false)
  end
  cloneAvatarRoot.transform.parent = CS.UnityEngine.GameObject.Find("/EntityRoot").transform
  local checkIfCloneRootExist = CS.UnityEngine.GameObject.Find("/EntityRoot/CloneRoot")
  if checkIfCloneRootExist ~= nil then
    CS.UnityEngine.Object.Destroy(checkIfCloneRootExist.gameObject)
  end
  cloneAvatarRoot.name = "CloneRoot"
  clonedModel.transform.parent = cloneAvatarRoot.transform
end


swap()