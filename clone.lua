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

local function clone()
	local avatar = findActiveAvatar()
	local position = avatar.transform.position
	local rotation = avatar.transform.rotation
	local offsetDummy = CS.UnityEngine.GameObject.Find("OffsetDummy")
	local child = offsetDummy.transform:GetChild(0)
	local animator = child:GetComponent("Animator")
	animator.enabled = false
	local newAvatar = CS.UnityEngine.GameObject.Instantiate(child)
	newAvatar.transform.position = position
	newAvatar.transform.rotation = rotation
	animator.enabled = true
end

local function onError(error)
	CS.MoleMole.ActorUtils.ShowMessage(tostring(error))
end

xpcall(clone, onError)
