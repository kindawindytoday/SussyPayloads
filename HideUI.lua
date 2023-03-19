function Update()
    if CS.UnityEngine.GameObject.Find("/UICamera"):GetComponent("Camera").enabled == true then
        CS.UnityEngine.GameObject.Find("/UICamera"):GetComponent("Camera").enabled = false
    else
        CS.UnityEngine.GameObject.Find("/UICamera"):GetComponent("Camera").enabled = true
    end
  end
Update()
