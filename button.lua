local function button()
	local canvas = CS.UnityEngine.GameObject.Find("/Canvas")
	local watermark = CS.UnityEngine.GameObject("watermark")
	watermark.transform:SetParent(canvas.transform)
	watermark.transform.localScale = CS.UnityEngine.Vector3(1, 1, 1)
	local texture = CS.UnityEngine.Texture2D(2048, 2048)
	local image = CS.System.IO.File.ReadAllBytes("D:/button.png")
	CS.UnityEngine.ImageConversion.LoadImage(texture, image)
	local component = watermark:AddComponent(typeof(CS.UnityEngine.UI.Image))
	component.sprite = CS.UnityEngine.Sprite.Create(texture, CS.UnityEngine.Rect(0, 0, 2048, 2048), CS.UnityEngine.Vector2(1, 1))
	local button = watermark:AddComponent(typeof(CS.UnityEngine.UI.Button))
	button.onClick:AddListener(
	function()
		CS.MoleMole.ActorUtils.ShowMessage("button")
	end)
end

local function onError(error)
	CS.MoleMole.ActorUtils.ShowMessage(tostring(error))
end

xpcall(button, onError)