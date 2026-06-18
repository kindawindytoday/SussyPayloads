local colors = {
    "#ff4b4b",
    "#ffa600",
    "#ffee00",
    "#11edb1",
    "#0077ff",
    "#cc33ff"
}
local textGO = CS.UnityEngine.GameObject.Find("/BetaWatermarkCanvas(Clone)/Panel/TxtUID")
local textComp = textGO:GetComponent("Text")

local idx = 1
local function loop_color()
    local color = colors[idx]
    idx = idx % #colors + 1

    textComp.text = string.format("<color=%s>Hello World</color>", color)
    CS.MoleMole.LuaManager():YieldCallback(CS.UnityEngine.WaitForSeconds(1), loop_color, true)
end
loop_color()

