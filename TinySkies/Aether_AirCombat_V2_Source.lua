--[[
AETHER // TINY SKIES AIR COMBAT v2.0
Target experience: Tiny Skies Fighter Jet & Helicopters (PlaceId 111410533261470)
Enemy-only aircraft & character ESP; predicted lead; optional camera aim lock.
Experimental gun-raycast Silent Aim: opt-in, only if executor supports safe hooks.
No guessed server remotes, no anticheat bypass; no claim that missiles can be redirected.
For Delta iOS mobile controls, public-game shooting uses Click guns / Space weapons.
]]
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local UserInputService=game:GetService("UserInputService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local TweenService=game:GetService("TweenService")
local Workspace=game:GetService("Workspace")
local LP=Players.LocalPlayer
if not LP then return end
local G=_G
if type(getgenv)=="function" then
    local ok,g=pcall(getgenv)
    if ok and type(g)=="table" then G=g end
end
if type(G.AETHER_TINY_SKIES_V2_CLOSE)=="function" then
    pcall(G.AETHER_TINY_SKIES_V2_CLOSE)
end
if game.PlaceId~=111410533261470 then
    warn("[AETHER] Tiny Skies place ID expected 111410533261470, got "..tostring(game.PlaceId))
    return
end

local config={
    esp=true,
    aimLock=false,
    silent=false,
    teamCheck=true,
    visibility=false,
    bulletSpeed=700,
    fov=230,
    maxDist=9000,
    smooth=0.22,
    silentAngle=12
}
local state={
    alive=true,connections={},enemyCache={},targets={},
    target=nil,targetPos=nil,localAircraft=nil,
    focusedName="No enemy locked", hook=false,
    hookAvailable=false,lastScan=0,scanStatus="Waiting for vehicles",
    updateCounter=0
}
local function wire(sig,fn)
    local c=sig:Connect(fn)
    state.connections[#state.connections+1]=c
    return c
end
local function cleanupCache()
    for p,e in pairs(state.enemyCache) do
        if e.highlight then pcall(function()e.highlight:Destroy()end) end
        if e.billboard then pcall(function()e.billboard:Destroy()end) end
        state.enemyCache[p]=nil
    end
end

-- Avoid guessing which players are on the other team.
-- In a neutral/FFA match, other neutral players are opponents.
local function isEnemy(other)
    if not other or other==LP then return false end
    if LP.Team~=nil then
        return other.Team~=nil and other.Team~=LP.Team
    end
    if LP.Neutral and other.Neutral then return true end
    if LP.Team==nil and other.Team==nil then return true end
    return false
end
local function charRoot(other)
    local ch=other and other.Character
    local h=ch and ch:FindFirstChildOfClass("Humanoid")
    if not ch or (h and h.Health<=0) then return nil end
    return ch:FindFirstChild("HumanoidRootPart") or ch.PrimaryPart
end
local function aircraftModel(seat)
    local m=seat:FindFirstAncestorOfClass("Model")
    if not m then return nil end
    -- Keep climbing aircraft subassemblies, but stop at the workspace root.
    local limit=0
    while limit<3 and m.Parent and m.Parent:IsA("Model") do
        m=m.Parent
        limit=limit+1
    end
    return m
end
local function aircraftRoot(model,seat)
    return model and (model.PrimaryPart or
        model:FindFirstChild("HumanoidRootPart",true) or
        model:FindFirstChild("Root",true) or seat) or seat
end
local function ownerOfModel(model)
    if not model then return nil end
    for _,attr in ipairs({"PilotUserId","OwnerUserId","UserId","PilotId"}) do
        local id=model:GetAttribute(attr)
        if typeof(id)=="number" then
            local owner=Players:GetPlayerByUserId(id)
            if owner then return owner end
        end
    end
    for _,attr in ipairs({"PilotName","OwnerName","PlayerName"}) do
        local name=model:GetAttribute(attr)
        if typeof(name)=="string" then
            local owner=Players:FindFirstChild(name)
            if owner then return owner end
        end
    end
    for _,key in ipairs({"Pilot","Owner","Player","Driver"}) do
        local ref=model:FindFirstChild(key)
        if ref and ref:IsA("ObjectValue") and ref.Value then
            if ref.Value:IsA("Player") then return ref.Value end
            if ref.Value:IsA("Model") then
                local hum=ref.Value:FindFirstChildOfClass("Humanoid")
                if hum then
                    local plr=Players:GetPlayerFromCharacter(hum.Parent)
                    if plr then return plr end
                end
            end
        end
    end
    return nil
end
-- Live scan: Tiny Skies aircraft use Workspace.Aircraft/<type>/Root,
-- not player characters or occupied VehicleSeats.
local function rootPart(model)
    local r=model:FindFirstChild("Root")
    if r and r:IsA("BasePart") then return r end
    r=model.PrimaryPart or model:FindFirstChild("WingBox")
    if r and r:IsA("BasePart") then return r end
    r=model:FindFirstChild("Root",true)
    return r and r:IsA("BasePart") and r or nil
end
local pilotKeys={"PilotUserId","OwnerUserId","UserId","PilotId",
    "Pilot","Owner","Player","Driver","PilotName","OwnerName","PlayerName"}
local vehicleKeys={"Aircraft","AircraftName","Plane","Vehicle","VehicleName",
    "Ship","ShipName","Craft"}
local teamKeys={"Team","TeamName","Faction","Side"}
local function field(node,key)
    if not node then return nil end
    local a=node:GetAttribute(key)
    if a~=nil then return a end
    local child=node:FindFirstChild(key)
    if child and (child:IsA("ObjectValue") or child:IsA("StringValue")
        or child:IsA("IntValue") or child:IsA("NumberValue")) then
        return child.Value
    end
    return nil
end
local function playerFor(value)
    if typeof(value)=="Instance" and value:IsA("Player") then return value end
    if type(value)=="number" then return Players:GetPlayerByUserId(value) end
    if type(value)=="string" then
        for _,p in ipairs(Players:GetPlayers()) do
            if value==p.Name or value==tostring(p.UserId) then return p end
        end
    end
    return nil
end
local function rosterPilot(model,counts)
    local roster=ReplicatedStorage:FindFirstChild("Roster")
    if not roster then return nil end
    for _,entry in ipairs(roster:GetChildren()) do
        local pilot=playerFor(entry.Name)
        for _,key in ipairs(pilotKeys) do
            pilot=pilot or playerFor(field(entry,key))
        end
        if pilot then
            for _,key in ipairs(vehicleKeys) do
                local v=field(entry,key)
                if typeof(v)=="Instance" and
                    (v==model or v:IsDescendantOf(model)) then
                    return pilot
                end
                if type(v)=="string" and counts[model.Name]==1 and
                    v==model.Name then return pilot end
            end
            for _,obj in ipairs(entry:GetChildren()) do
                if obj:IsA("ObjectValue") and obj.Value and
                    (obj.Value==model or obj.Value:IsDescendantOf(model)) then
                    return pilot
                end
            end
        end
    end
    return nil
end
local function classifyAircraft(model,root,counts)
    local pilot=ownerOfModel(model) or ownerOfModel(root)
    if not pilot then
        for _,node in ipairs({model,root}) do
            for _,key in ipairs(pilotKeys) do
                pilot=pilot or playerFor(field(node,key))
            end
        end
    end
    pilot=pilot or rosterPilot(model,counts)
    if pilot then
        if pilot==LP then return "SELF",pilot,LP.Team and LP.Team.Name end
        if isEnemy(pilot) then return "ENEMY",pilot,pilot.Team and pilot.Team.Name end
        if LP.Team and pilot.Team==LP.Team then
            return "FRIENDLY",pilot,LP.Team.Name
        end
        return "UNKNOWN",pilot,nil
    end
    -- Do not guess enemies from aircraft names or distance.
    -- A model's team text only counts when it matches an actual team in play.
    if LP.Team then
        for _,node in ipairs({model,root}) do
            for _,key in ipairs(teamKeys) do
                local v=field(node,key)
                if typeof(v)=="Instance" and v:IsA("Team") then v=v.Name end
                if type(v)=="string" then
                    for _,p in ipairs(Players:GetPlayers()) do
                        if p.Team and p.Team.Name:lower()==v:lower() then
                            return p.Team==LP.Team and "FRIENDLY" or "ENEMY",
                                nil,p.Team.Name
                        end
                    end
                end
            end
        end
    end
    return "UNKNOWN",nil,nil
end
local function rebuildTargets()
    local folder=Workspace:FindFirstChild("Aircraft")
    local counts,fresh={},{}
    local nearest,nearestDistance=nil,120
    local own=nil
    local camera=Workspace.CurrentCamera
    local cameraPos=camera and camera.CFrame.Position or Vector3.zero
    local total,unknown,enemies=0,0,0
    if folder then
        for _,m in ipairs(folder:GetChildren()) do
            if m:IsA("Model") then counts[m.Name]=(counts[m.Name] or 0)+1 end
        end
        for _,m in ipairs(folder:GetChildren()) do
            if m:IsA("Model") then
                local root=rootPart(m)
                if root then
                    total=total+1
                    local relation,pilot,team=classifyAircraft(m,root,counts)
                    local dist=(root.Position-cameraPos).Magnitude
                    if dist<nearestDistance then nearest=root;nearestDistance=dist end
                    if relation=="SELF" then own=root end
                    if relation=="ENEMY" then
                        enemies=enemies+1
                        fresh[m]={model=m,root=root,player=pilot,team=team,
                            kind="Aircraft",enemy=true}
                    elseif relation=="UNKNOWN" then unknown=unknown+1 end
                end
            end
        end
    end
    -- Camera proximity is used only to approximate our shooting origin;
    -- it is NEVER used to decide which team an aircraft belongs to.
    state.localAircraft=own or nearest
    state.targets=fresh
    state.lastScan=os.clock()
    state.scanStatus=enemies.." verified enemies / "..total..
        " aircraft / "..unknown.." unlinked"
end

local gui=Instance.new("ScreenGui")
gui.Name="AETHER_AIRCOMBAT_V2"
gui.ResetOnSpawn=false
gui.IgnoreGuiInset=false
gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
gui.DisplayOrder=120
gui.Parent=LP:WaitForChild("PlayerGui")
local over=Instance.new("ScreenGui")
over.Name="AETHER_AIRCOMBAT_V2_OVERLAY"
over.ResetOnSpawn=false
over.IgnoreGuiInset=true
over.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
over.DisplayOrder=110
over.Parent=LP.PlayerGui
local colors={
    base=Color3.fromRGB(17,19,24),
    elevated=Color3.fromRGB(26,30,38),
    input=Color3.fromRGB(37,43,53),
    border=Color3.fromRGB(52,60,72),
    text=Color3.fromRGB(236,241,247),
    muted=Color3.fromRGB(145,156,172),
    accent=Color3.fromRGB(78,187,207),
    danger=Color3.fromRGB(243,112,118),
    green=Color3.fromRGB(100,218,174)
}
local function ui(kind,parent,props)
    local o=Instance.new(kind)
    for k,v in pairs(props or {}) do o[k]=v end
    o.Parent=parent
    return o
end
local function corner(o,r)
    ui("UICorner",o,{CornerRadius=UDim.new(0,r)})
    return o
end
local function stroke(o,weight,color)
    ui("UIStroke",o,{Color=color or colors.border,Thickness=weight or 1})
end
local function label(parent,txt,pos,size,font,sz,clr)
    return ui("TextLabel",parent,{
        BackgroundTransparency=1,Position=pos,Size=size,
        Text=txt,Font=font or Enum.Font.Gotham,TextSize=sz or 12,
        TextColor3=clr or colors.text,TextXAlignment=Enum.TextXAlignment.Left,
        TextTruncate=Enum.TextTruncate.AtEnd
    })
end
local main=corner(ui("Frame",gui,{
    AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.49),
    Size=UDim2.fromOffset(346,408),
    BackgroundColor3=colors.base,BorderSizePixel=0,
    Active=true
}),13)
stroke(main)
local viewScale=ui("UIScale",main,{Scale=1})
local function fit()
    local cam=Workspace.CurrentCamera
    if cam then
        local v=cam.ViewportSize
        viewScale.Scale=math.clamp(math.min((v.X-24)/346,(v.Y-86)/408),.67,1)
    end
end
fit()
if Workspace.CurrentCamera then
    wire(Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"),fit)
end
local header=corner(ui("Frame",main,{
    BackgroundColor3=colors.elevated,BorderSizePixel=0,
    Position=UDim2.fromOffset(0,0),Size=UDim2.new(1,0,0,65)
}),13)
label(header,"AETHER",UDim2.fromOffset(17,11),UDim2.fromOffset(222,24),
    Enum.Font.GothamBold,19)
label(header,"TINY SKIES  /  AIR COMBAT V2",UDim2.fromOffset(17,39),
    UDim2.fromOffset(248,14),Enum.Font.GothamMedium,10,colors.muted)
local close=corner(ui("TextButton",header,{
    Text="X",TextSize=12,Font=Enum.Font.GothamBold,
    TextColor3=colors.text,BackgroundColor3=colors.input,BorderSizePixel=0,
    Position=UDim2.new(1,-40,0,17),Size=UDim2.fromOffset(25,28)
}),7)
local minimize=corner(ui("TextButton",header,{
    Text="-",TextSize=17,Font=Enum.Font.GothamBold,
    TextColor3=colors.text,BackgroundColor3=colors.input,BorderSizePixel=0,
    Position=UDim2.new(1,-71,0,17),Size=UDim2.fromOffset(25,28)
}),7)
local line=ui("Frame",main,{Position=UDim2.fromOffset(13,65),Size=UDim2.new(1,-26,0,2),
    BackgroundColor3=colors.accent,BorderSizePixel=0})
local content=ui("Frame",main,{Position=UDim2.fromOffset(0,68),
    Size=UDim2.new(1,0,1,-68),BackgroundTransparency=1})
local tabs=corner(ui("Frame",content,{
    Position=UDim2.fromOffset(13,9),Size=UDim2.new(1,-26,0,37),
    BackgroundColor3=colors.elevated,BorderSizePixel=0
}),9)
local pages={}
local tabButtons={}
for i,id in ipairs({"COMBAT","ESP","SETTINGS"}) do
    local button=corner(ui("TextButton",tabs,{
        Position=UDim2.new((i-1)/3,3,0,3),Size=UDim2.new(1/3,-6,1,-6),
        Text=id,TextColor3=colors.muted,TextSize=11,
        Font=Enum.Font.GothamBold,BackgroundColor3=colors.elevated,
        BorderSizePixel=0
    }),6)
    tabButtons[id]=button
    pages[id]=ui("Frame",content,{
        Position=UDim2.fromOffset(13,54),Size=UDim2.new(1,-26,1,-62),
        BackgroundTransparency=1,Visible=false
    })
    wire(button.Activated,function()
        for name,pg in pairs(pages)do
            pg.Visible=(id==name)
            tabButtons[name].BackgroundColor3=(id==name) and colors.input or colors.elevated
            tabButtons[name].TextColor3=(id==name) and colors.text or colors.muted
        end
    end)
end
local function showPage(id)
    for name,pg in pairs(pages)do
        pg.Visible=name==id
        tabButtons[name].BackgroundColor3=name==id and colors.input or colors.elevated
        tabButtons[name].TextColor3=name==id and colors.text or colors.muted
    end
end
local function tile(parent,title,y,description)
    local frame=corner(ui("Frame",parent,{
        Position=UDim2.fromOffset(0,y),Size=UDim2.new(1,0,0,65),
        BackgroundColor3=colors.elevated,BorderSizePixel=0
    }),9)
    label(frame,title,UDim2.fromOffset(12,7),UDim2.new(1,-125,0,22),
        Enum.Font.GothamSemibold,13)
    label(frame,description,UDim2.fromOffset(12,33),UDim2.new(1,-24,0,19),
        Enum.Font.Gotham,10,colors.muted)
    return frame
end
local function switch(parent,initial,onChanged)
    local button=corner(ui("TextButton",parent,{
        Position=UDim2.new(1,-65,0,9),Size=UDim2.fromOffset(53,26),
        BackgroundColor3=colors.input,TextColor3=colors.text,
        TextSize=10,Font=Enum.Font.GothamBold,
        BorderSizePixel=0
    }),7)
    local function refresh(v)
        button.Text=v and "ON" or "OFF"
        button.BackgroundColor3=v and colors.accent or colors.input
        button.TextColor3=v and colors.base or colors.muted
    end
    refresh(initial)
    wire(button.Activated,function()
        local new=onChanged()
        refresh(new)
    end)
    return {refresh=refresh,button=button}
end
local combat=pages.COMBAT
local aimCard=tile(combat,"Camera Aim Lock",0,"Steer view toward selected enemy")
local aimToggle=switch(aimCard,false,function()
    config.aimLock=not config.aimLock
    return config.aimLock
end)
local silentCard=tile(combat,"Silent Aim (test)",76,"Gun raycasts only; game-dependent")
local silentToggle
local function enableSilent()
    if state.hook then return true end
    if type(hookmetamethod)~="function"
        or type(getnamecallmethod)~="function"
        or type(newcclosure)~="function"
        or type(checkcaller)~="function" then
        return false
    end
    local old
    local ok,previous=pcall(function()
        return hookmetamethod(game,"__namecall",newcclosure(function(self,...)
            if not state.alive or not config.silent
                or self~=Workspace or checkcaller()
                or getnamecallmethod()~="Raycast" then
                return old(self,...)
            end
            local origin,direction,params=...
            local hit=state.targetPos
            local own=state.localAircraft
            if typeof(origin)~="Vector3" or typeof(direction)~="Vector3"
                or not hit or not own or not own.Parent
                or direction.Magnitude<150 or direction.Magnitude>50000
                or (origin-own.Position).Magnitude>160 then
                return old(self,...)
            end
            local delta=hit-origin
            if delta.Magnitude<3 then return old(self,...) end
            local dot=math.clamp(direction.Unit:Dot(delta.Unit),-1,1)
            local angle=math.deg(math.acos(dot))
            if angle>config.silentAngle then return old(self,...) end
            return old(self,origin,delta.Unit*direction.Magnitude,params)
        end))
    end)
    if ok and type(previous)=="function" then
        old=previous
        state.hook=true
        return true
    end
    return false
end
local info=label(combat,"Target: scanning enemies",UDim2.fromOffset(2,159),
    UDim2.new(1,-4,0,25),Enum.Font.GothamSemibold,12,colors.text)
local aimInfo=label(combat,"No target in aiming circle",UDim2.fromOffset(2,189),
    UDim2.new(1,-4,0,34),Enum.Font.Gotham,11,colors.muted)
local warning=label(combat,"Silent Aim is OFF until you enable it.",UDim2.fromOffset(2,236),
    UDim2.new(1,-4,0,33),Enum.Font.Gotham,11,colors.muted)
silentToggle=switch(silentCard,false,function()
    if config.silent then
        config.silent=false
        warning.Text="Silent Aim disabled."
        return false
    end
    if enableSilent() then
        config.silent=true
        warning.Text="Raycast hook active. Gun hits not yet verified."
        return true
    else
        warning.Text="Unsupported executor hook; Silent Aim unavailable."
        return false
    end
end)

local visuals=pages.ESP
local espCard=tile(visuals,"Enemy aircraft ESP",0,"Enemy team only; aircraft + pilots")
local espToggle=switch(espCard,true,function()
    config.esp=not config.esp
    return config.esp
end)
local teamCard=tile(visuals,"Strict aircraft team filter",77,"Hide allies and unknown aircraft")
label(teamCard,"ENFORCED",UDim2.new(1,-89,0,12),
    UDim2.fromOffset(79,22),Enum.Font.GothamBold,10,colors.green)
local filterCard=tile(visuals,"Line-of-sight filter",154,"Hide targets behind solid geometry")
local visibleToggle=switch(filterCard,false,function()
    config.visibility=not config.visibility
    return config.visibility
end)
local espStatus=label(visuals,"No enemies detected yet",UDim2.fromOffset(2,241),
    UDim2.new(1,-4,0,44),Enum.Font.Gotham,11,colors.muted)

local settings=pages.SETTINGS
local function numberSetting(parent,title,y,key,step,lo,hi,suffix)
    local frame=corner(ui("Frame",parent,{
        Position=UDim2.fromOffset(0,y),Size=UDim2.new(1,0,0,58),
        BackgroundColor3=colors.elevated,BorderSizePixel=0
    }),9)
    label(frame,title,UDim2.fromOffset(10,5),UDim2.new(1,-20,0,18),
        Enum.Font.GothamSemibold,11,colors.muted)
    local val=label(frame,"",UDim2.fromOffset(12,27),UDim2.fromOffset(114,24),
        Enum.Font.GothamBold,14,colors.text)
    local function adjust(delta)
        config[key]=math.clamp(config[key]+delta,lo,hi)
        val.Text=(key=="smooth" and string.format("%.2f",config[key]) or tostring(math.floor(config[key]+.5)))..suffix
    end
    local minus=corner(ui("TextButton",frame,{
        Position=UDim2.new(1,-93,0,23),Size=UDim2.fromOffset(38,29),
        BackgroundColor3=colors.input,BorderSizePixel=0,
        Text="-",Font=Enum.Font.GothamBold,TextSize=17,TextColor3=colors.text
    }),7)
    local plus=corner(ui("TextButton",frame,{
        Position=UDim2.new(1,-48,0,23),Size=UDim2.fromOffset(38,29),
        BackgroundColor3=colors.input,BorderSizePixel=0,
        Text="+",Font=Enum.Font.GothamBold,TextSize=17,TextColor3=colors.text
    }),7)
    wire(minus.Activated,function()adjust(-step)end)
    wire(plus.Activated,function()adjust(step)end)
    adjust(0)
end
numberSetting(settings,"Targeting FOV",0,"fov",30,80,470,"px")
numberSetting(settings,"Maximum target distance",66,"maxDist",500,1000,14000," st")
numberSetting(settings,"Estimated bullet speed",132,"bulletSpeed",100,200,1800," st/s")
numberSetting(settings,"Aim smoothing (more = faster)",198,"smooth",.05,.05,.75,"")
local diagnosticButton=corner(ui("TextButton",settings,{
    Position=UDim2.fromOffset(0,266),Size=UDim2.new(1,0,0,39),
    Text="COPY AIRCRAFT LINK REPORT",Font=Enum.Font.GothamBold,
    TextColor3=colors.text,TextSize=11,
    BackgroundColor3=colors.input,BorderSizePixel=0
}),8)
local function aircraftReport()
    local lines={"AETHER V2 AIRCRAFT LINK REPORT",
        "Place="..game.PlaceId.." | team="..(LP.Team and LP.Team.Name or "nil"),
        state.scanStatus}
    local function describe(node)
        if not node then return end
        local attrs={}
        for key,value in pairs(node:GetAttributes()) do
            local n=key:lower()
            if n:find("pilot",1,true) or n:find("owner",1,true)
                or n:find("team",1,true) or n:find("player",1,true)
                or n:find("vehicle",1,true) or n:find("aircraft",1,true)
                or n:find("ship",1,true) then
                attrs[#attrs+1]=key.."="..tostring(value)
            end
        end
        table.sort(attrs)
        for i=1,math.min(#attrs,10) do
            lines[#lines+1]="  attribute "..attrs[i]
        end
        local n=0
        for _,v in ipairs(node:GetChildren()) do
            if n>=12 then break end
            if v:IsA("ObjectValue") or v:IsA("StringValue")
                or v:IsA("NumberValue") or v:IsA("IntValue") then
                n=n+1
                local raw=v.Value
                if typeof(raw)=="Instance" then raw=raw:GetFullName() end
                lines[#lines+1]="  value "..v.Name.."="..tostring(raw)
            end
        end
    end
    local folder=Workspace:FindFirstChild("Aircraft")
    if folder then
        for _,model in ipairs(folder:GetChildren()) do
            if model:IsA("Model") then
                lines[#lines+1]="AIRCRAFT "..model:GetFullName()
                describe(model)
                describe(rootPart(model))
            end
        end
    end
    local roster=ReplicatedStorage:FindFirstChild("Roster")
    if roster then
        lines[#lines+1]="ROSTER entries="..#roster:GetChildren()
        for i,entry in ipairs(roster:GetChildren()) do
            if i<=24 then
                lines[#lines+1]="ROSTER "..entry:GetFullName().." / "..entry.ClassName
                describe(entry)
            end
        end
    end
    return table.concat(lines,"\n")
end
wire(diagnosticButton.Activated,function()
    if type(setclipboard)~="function" then
        diagnosticButton.Text="NO CLIPBOARD SUPPORT"
        return
    end
    local ok=pcall(setclipboard,aircraftReport())
    diagnosticButton.Text=ok and "COPIED / SEND REPORT" or "COPY FAILED"
end)
-- Projected target/lead point and compact aiming circle.
local aimDot=corner(ui("Frame",over,{
    AnchorPoint=Vector2.new(.5,.5),Size=UDim2.fromOffset(18,18),
    BackgroundTransparency=1,BackgroundColor3=colors.accent,
    Position=UDim2.fromOffset(0,0),Visible=false
}),9)
stroke(aimDot,2,colors.accent)
local nameTag=corner(ui("TextLabel",over,{
    BackgroundColor3=colors.base,
    AnchorPoint=Vector2.new(.5,1),Position=UDim2.fromOffset(0,0),
    Size=UDim2.fromOffset(130,24),Text="",TextSize=12,
    Font=Enum.Font.GothamBold,TextColor3=colors.text,
    BorderSizePixel=0,Visible=false
}),6)
local fovRing=ui("Frame",over,{
    AnchorPoint=Vector2.new(.5,.5),Size=UDim2.fromOffset(200,200),
    BackgroundTransparency=1,Position=UDim2.fromScale(.5,.5),
    Visible=false
})
ui("UICorner",fovRing,{CornerRadius=UDim.new(1,0)})
ui("UIStroke",fovRing,{Thickness=1,Color=colors.accent,Transparency=.65})

local function bindVisual(p,data)
    local old=state.enemyCache[p]
    if old and (old.model~=data.model or not old.model.Parent) then
        if old.highlight then pcall(function()old.highlight:Destroy()end) end
        if old.billboard then pcall(function()old.billboard:Destroy()end) end
        old=nil
        state.enemyCache[p]=nil
    end
    if old then return old end
    local hi=Instance.new("Highlight")
    hi.Name="Aether_EnemyESP"
    hi.Adornee=data.model
    hi.FillColor=colors.danger
    hi.OutlineColor=colors.danger
    hi.FillTransparency=.89
    hi.OutlineTransparency=.13
    hi.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
    hi.Enabled=false
    hi.Parent=gui
    local board=Instance.new("BillboardGui")
    board.Name="Aether_EnemyTag"
    board.Adornee=data.root
    board.Size=UDim2.fromOffset(174,40)
    board.StudsOffsetWorldSpace=Vector3.new(0,5,0)
    board.AlwaysOnTop=true
    board.MaxDistance=config.maxDist
    board.Enabled=false
    board.Parent=gui
    local b=ui("TextLabel",board,{
        Size=UDim2.fromScale(1,1),
        BackgroundTransparency=.2,BackgroundColor3=colors.base,
        TextColor3=colors.danger,Font=Enum.Font.GothamSemibold,
        TextSize=12,TextStrokeTransparency=.8,
        Text="ENEMY",TextWrapped=true
    })
    corner(b,8)
    old={model=data.model,root=data.root,highlight=hi,billboard=board,label=b}
    state.enemyCache[p]=old
    return old
end
local function resetRemovedVisuals()
    for p,e in pairs(state.enemyCache) do
        if not state.targets[p]
            or state.targets[p].model~=e.model then
            if e.highlight then pcall(function()e.highlight:Destroy()end) end
            if e.billboard then pcall(function()e.billboard:Destroy()end) end
            state.enemyCache[p]=nil
        end
    end
end
local function visible(cam,target,model)
    if not config.visibility then return true end
    local cameraPos=cam.CFrame.Position
    local ray=target-cameraPos
    if ray.Magnitude<2 then return true end
    local params=RaycastParams.new()
    params.FilterType=Enum.RaycastFilterType.Exclude
    local ignore={}
    if LP.Character then ignore[#ignore+1]=LP.Character end
    if state.localAircraft and state.localAircraft.Parent then
        ignore[#ignore+1]=state.localAircraft:FindFirstAncestorOfClass("Model") or state.localAircraft
    end
    params.FilterDescendantsInstances=ignore
    local hit=Workspace:Raycast(cameraPos,ray,params)
    return hit==nil or hit.Instance==nil or
        (model and hit.Instance:IsDescendantOf(model))
end
local function predicted(data,from)
    local root=data.root
    if not root or not root.Parent then return nil end
    local position=root.Position
    local vel=root.AssemblyLinearVelocity
    local speed=math.max(200,config.bulletSpeed)
    local flightTime=math.clamp((position-from).Magnitude/speed,0,2.3)
    return position+vel*flightTime
end
local function updateTarget()
    local cam=Workspace.CurrentCamera
    if not cam then return end
    local center=cam.ViewportSize*.5
    local best=nil
    local smallest=config.fov
    local from=state.localAircraft and state.localAircraft.Parent and
        state.localAircraft.Position or cam.CFrame.Position
    for p,data in pairs(state.targets) do
        if data.enemy and data.root and data.root.Parent then
            local point=predicted(data,from)
            if point and (point-from).Magnitude<=config.maxDist then
                local screen,onscreen=cam:WorldToViewportPoint(point)
                local dist=(Vector2.new(screen.X,screen.Y)-center).Magnitude
                if onscreen and dist<smallest and
                    (not config.visibility or visible(cam,point,data.model)) then
                    best=data
                    smallest=dist
                end
            end
        end
    end
    state.target=best
    state.targetPos=best and predicted(best,from) or nil
    if best then
        state.focusedName=best.player and best.player.Name or ((best.team or "ENEMY").." "..best.model.Name)
        local pos=state.targetPos
        local projected=pos and cam:WorldToViewportPoint(pos)
        if projected then
            aimDot.Position=UDim2.fromOffset(projected.X,projected.Y)
            nameTag.Position=UDim2.fromOffset(projected.X,projected.Y-15)
            nameTag.Text=best.player and best.player.DisplayName:sub(1,18) or (best.team or "ENEMY")
        end
        aimDot.Visible=true
        nameTag.Visible=true
    else
        state.focusedName="No enemy within FOV"
        aimDot.Visible=false
        nameTag.Visible=false
    end
    fovRing.Position=UDim2.fromOffset(center.X,center.Y)
    fovRing.Size=UDim2.fromOffset(config.fov*2,config.fov*2)
    fovRing.Visible=config.aimLock
end
local function updateESP()
    local cam=Workspace.CurrentCamera
    if not cam then return end
    local from=cam.CFrame.Position
    local count=0
    for p,data in pairs(state.targets) do
        if data.enemy and data.root and data.root.Parent then
            count=count+1
            local v=bindVisual(p,data)
            local dist=(data.root.Position-from).Magnitude
            local enable=config.esp and dist<=config.maxDist
            v.highlight.Enabled=enable
            v.billboard.Enabled=enable
            if enable then
                v.billboard.Adornee=data.root
                v.billboard.MaxDistance=config.maxDist
                v.label.Text=(data.player and data.player.DisplayName:sub(1,18) or (data.team or "ENEMY")).." / "..data.model.Name.."\n"..math.floor(dist).." st"
            end
        end
    end
    espStatus.Text=state.scanStatus
    resetRemovedVisuals()
end
local function renderAim(dt)
    if not state.alive then return end
    local cam=Workspace.CurrentCamera
    if not cam then return end
    local point=state.targetPos
    if config.aimLock and point and state.target and state.target.enemy then
        local cameraPos=cam.CFrame.Position
        if (point-cameraPos).Magnitude>2 then
            -- Optional camera lock. Flight/mouse steering can override it.
            local dest=CFrame.lookAt(cameraPos,point)
            local blend=1-math.pow(1-config.smooth,math.clamp(dt*60,0,3))
            cam.CFrame=cam.CFrame:Lerp(dest,blend)
        end
    end
end
local function setStatus()
    info.Text=state.target and ("Enemy: "..state.focusedName) or "Target: no enemy selected"
    aimInfo.Text="Aim  "..(config.aimLock and "LOCKED" or "OFF")
        .."  |  Silent  "..(config.silent and "TEST ON" or "OFF")
        .."  |  FOV  "..config.fov
end

wire(Players.PlayerRemoving,function()
    rebuildTargets()
    resetRemovedVisuals()
end)
wire(LP:GetPropertyChangedSignal("Team"),function()
    state.targets={}
    cleanupCache()
    rebuildTargets()
end)
local renderName="AETHER_AIM_V2_"..tostring(LP.UserId)
local function shutdown()
    if not state.alive then return end
    state.alive=false
    config.silent=false;config.aimLock=false;config.esp=false
    pcall(function()RunService:UnbindFromRenderStep(renderName)end)
    for _,c in ipairs(state.connections)do pcall(function()c:Disconnect()end)end
    cleanupCache()
    pcall(function()gui:Destroy()end)
    pcall(function()over:Destroy()end)
    if G.AETHER_TINY_SKIES_V2_CLOSE==shutdown then
        G.AETHER_TINY_SKIES_V2_CLOSE=nil
    end
end
wire(close.Activated,shutdown)
local minimized=false
wire(minimize.Activated,function()
    minimized=not minimized
    content.Visible=not minimized
    main.Size=UDim2.fromOffset(346,minimized and 65 or 408)
    minimize.Text=minimized and "+" or "-"
end)
local dragging=false
local down,origin
local pointer
wire(header.InputBegan,function(input)
    if input.UserInputType==Enum.UserInputType.Touch or
        input.UserInputType==Enum.UserInputType.MouseButton1 then
        dragging=true
        down=input.Position
        origin=main.Position
        pointer=input
        local child
        child=input.Changed:Connect(function()
            if input.UserInputState==Enum.UserInputState.End then
                dragging=false
                if child then child:Disconnect()end
            end
        end)
    end
end)
wire(UserInputService.InputChanged,function(input)
    if not dragging or not down or not origin then return end
    if input~=pointer and input.UserInputType~=Enum.UserInputType.MouseMovement then return end
    local delta=input.Position-down
    main.Position=UDim2.new(origin.X.Scale,origin.X.Offset+delta.X,
        origin.Y.Scale,origin.Y.Offset+delta.Y)
end)
showPage("COMBAT")
rebuildTargets()
local tickAt=0
local updateAt=0
-- A single lightweight render connection; ESP and target discovery are throttled.
RunService:BindToRenderStep(renderName,Enum.RenderPriority.Camera.Value+1,function(dt)
    if not state.alive then return end
    local t=os.clock()
    if t-tickAt>.13 then
        tickAt=t
        updateTarget()
        setStatus()
    end
    if t-updateAt>.35 then
        updateAt=t
        updateESP()
    end
    if t-state.lastScan>5 then
        rebuildTargets()
    end
    renderAim(dt)
end)
G.AETHER_TINY_SKIES_V2_CLOSE=shutdown
print("[AETHER V2] Real aircraft detected. Unknown team links remain hidden.")
