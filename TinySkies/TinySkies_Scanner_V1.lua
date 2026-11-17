--[[
AETHER // TINY SKIES SCANNER V1
PASSIVE GAME INSPECTION ONLY
Does not fire remotes, shoot weapons, move the camera, or hook functions.
1. Sit in your aircraft in Tiny Skies.
2. Press SCAN GAME.
3. Press COPY REPORT and paste the output in ChatGPT.
The report cannot establish whether server-side hit validation can be changed.
]]
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local UIS=game:GetService("UserInputService")
local LP=Players.LocalPlayer
if not LP then return end
local env=_G
if type(getgenv)=="function" then
    local ok,e=pcall(getgenv)
    if ok and type(e)=="table" then env=e end
end
if type(env.AETHER_SCANNER_CLOSE)=="function" then
    pcall(env.AETHER_SCANNER_CLOSE)
end
local alive,running=true,false
local conns={}
local report=""
local function wire(sig,fn)
    local c=sig:Connect(fn)
    conns[#conns+1]=c
    return c
end
local function make(class,parent,props)
    local o=Instance.new(class)
    for k,v in pairs(props or {}) do o[k]=v end
    o.Parent=parent
    return o
end
local color={
    bg=Color3.fromRGB(17,20,27),panel=Color3.fromRGB(28,33,44),
    ink=Color3.fromRGB(236,243,250),sub=Color3.fromRGB(157,169,184),
    aqua=Color3.fromRGB(77,191,212),line=Color3.fromRGB(59,68,82)
}
local gui=make("ScreenGui",LP:WaitForChild("PlayerGui"),{
    Name="AetherTinySkiesScanner",ResetOnSpawn=false,DisplayOrder=180
})
local window=make("Frame",gui,{
    Position=UDim2.new(.5,-160,.47,-153),Size=UDim2.fromOffset(320,306),
    BackgroundColor3=color.bg,BorderSizePixel=0,Active=true
})
make("UICorner",window,{CornerRadius=UDim.new(0,13)})
make("UIStroke",window,{Color=color.line,Thickness=1})
local scale=make("UIScale",window,{Scale=1})
local function fit()
    local cam=workspace.CurrentCamera
    if cam then
        local v=cam.ViewportSize
        scale.Scale=math.min(1,math.max(.65,math.min((v.X-22)/320,(v.Y-80)/306)))
    end
end
fit()
if workspace.CurrentCamera then wire(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"),fit) end
local head=make("Frame",window,{
    Size=UDim2.new(1,0,0,57),BackgroundColor3=color.panel,BorderSizePixel=0
})
make("UICorner",head,{CornerRadius=UDim.new(0,13)})
make("TextLabel",head,{
    Position=UDim2.fromOffset(13,7),Size=UDim2.new(1,-55,0,23),
    BackgroundTransparency=1,Text="AETHER  /  SCANNER",Font=Enum.Font.GothamBold,
    TextColor3=color.ink,TextSize=15,TextXAlignment=Enum.TextXAlignment.Left
})
make("TextLabel",head,{
    Position=UDim2.fromOffset(13,32),Size=UDim2.new(1,-50,0,15),
    BackgroundTransparency=1,Text="TINY SKIES  /  PASSIVE CHECK",Font=Enum.Font.Gotham,
    TextColor3=color.sub,TextSize=10,TextXAlignment=Enum.TextXAlignment.Left
})
local close=make("TextButton",head,{
    Position=UDim2.new(1,-37,0,14),Size=UDim2.fromOffset(26,27),
    BackgroundColor3=color.bg,BorderSizePixel=0,Text="X",
    Font=Enum.Font.GothamBold,TextColor3=color.ink,TextSize=12
})
make("UICorner",close,{CornerRadius=UDim.new(0,7)})
local intro=make("TextLabel",window,{
    Position=UDim2.fromOffset(13,67),Size=UDim2.new(1,-26,0,35),
    BackgroundTransparency=1,Text="Sit in your aircraft, then scan. Send the copied report back here.",
    TextWrapped=true,TextColor3=color.sub,TextSize=11,
    Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left
})
local scan=make("TextButton",window,{
    Position=UDim2.fromOffset(13,115),Size=UDim2.fromOffset(141,41),
    BackgroundColor3=color.aqua,BorderSizePixel=0,Text="SCAN GAME",
    TextColor3=color.bg,Font=Enum.Font.GothamBold,TextSize=12
})
make("UICorner",scan,{CornerRadius=UDim.new(0,8)})
local copy=make("TextButton",window,{
    Position=UDim2.fromOffset(165,115),Size=UDim2.fromOffset(142,41),
    BackgroundColor3=color.panel,BorderSizePixel=0,Text="COPY REPORT",
    TextColor3=color.ink,Font=Enum.Font.GothamBold,TextSize=12
})
make("UICorner",copy,{CornerRadius=UDim.new(0,8)})
local status=make("TextLabel",window,{
    Position=UDim2.fromOffset(13,164),Size=UDim2.new(1,-26,0,27),
    BackgroundTransparency=1,Text="Ready. No hooks or network calls.",
    TextWrapped=true,Font=Enum.Font.GothamMedium,TextSize=11,
    TextColor3=color.aqua,TextXAlignment=Enum.TextXAlignment.Left
})
local view=make("TextBox",window,{
    Position=UDim2.fromOffset(13,198),Size=UDim2.new(1,-26,0,94),
    BackgroundColor3=color.panel,BorderSizePixel=0,
    Text="",TextEditable=false,MultiLine=true,TextWrapped=true,
    ClearTextOnFocus=false,TextColor3=color.sub,
    Font=Enum.Font.Code,TextSize=10,
    TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top
})
make("UICorner",view,{CornerRadius=UDim.new(0,7)})
local function clean(v)
    if typeof(v)=="Instance" then v=v.Name end
    local t=tostring(v)
    t=t:gsub("[\r\n\t]+"," ")
    if #t>125 then t=t:sub(1,125).."..." end
    return t
end
local function path(inst)
    if not inst then return "nil" end
    local ok,name=pcall(function()return inst:GetFullName()end)
    return clean(ok and name or inst.Name)
end
local function selectedAttrs(node)
    if not node then return "" end
    local ok,a=pcall(function()return node:GetAttributes()end)
    if not ok then return "" end
    local keys={}
    for k in pairs(a) do
        local n=k:lower()
        if n:find("pilot",1,true) or n:find("owner",1,true) or
            n:find("team",1,true) or n:find("ammo",1,true) or
            n:find("weapon",1,true) or n:find("target",1,true) or
            n:find("speed",1,true) then
            keys[#keys+1]=k
        end
    end
    table.sort(keys)
    local bits={}
    for i=1,math.min(8,#keys)do
        local k=keys[i]
        bits[#bits+1]=k.."="..clean(a[k])
    end
    return table.concat(bits,"; ")
end
local function parentAircraft(seat)
    local m=seat:FindFirstAncestorOfClass("Model")
    local limit=0
    while m and m.Parent and m.Parent:IsA("Model") and limit<3 do
        m=m.Parent;limit=limit+1
    end
    return m
end
local function scanGame()
    if not alive or running then return end
    running=true
    scan.Text="SCANNING"
    status.Text="Reading replicated game state..."
    task.spawn(function()
        local lines={}
        local function out(s)lines[#lines+1]=s end
        local success,failure=pcall(function()
            out("=== AETHER TINY SKIES SCAN V1 ===")
            out("PlaceId="..game.PlaceId)
            out("Expected AETHER V1 PlaceId=111410533261470")
            out("Place match="..tostring(game.PlaceId==111410533261470))
            out("Mode=PASSIVE; no hooks, shots or remote calls")
            out("My team="..clean(LP.Team and LP.Team.Name or "nil")..
                "; Neutral="..tostring(LP.Neutral))
            out("")
            out("== PLAYERS / TEAM DETECTION ==")
            local enemies,teammates,uncertain=0,0,0
            for i,p in ipairs(Players:GetPlayers()) do
                local team=p.Team
                local relation
                if p==LP then relation="SELF"
                elseif LP.Team and team then
                    relation=team==LP.Team and "FRIENDLY" or "ENEMY"
                elseif LP.Neutral and p.Neutral then relation="FFA/NEUTRAL"
                else relation="UNKNOWN" end
                if relation=="ENEMY" then enemies=enemies+1
                elseif relation=="FRIENDLY" then teammates=teammates+1
                elseif p~=LP then uncertain=uncertain+1 end
                out(clean(p.Name).." | "..relation..
                    " | team="..clean(team and team.Name or "nil")..
                    " | char="..tostring(p.Character~=nil))
                if i%20==0 then task.wait() end
            end
            out("Enemy="..enemies.." Friendly="..teammates..
                " Other="..uncertain)
            out("")
            out("== LOCAL AIRCRAFT / WEAPONS ==")
            local ch=LP.Character
            local hum=ch and ch:FindFirstChildOfClass("Humanoid")
            local seat=hum and hum.SeatPart
            out("Seated="..tostring(seat~=nil))
            if seat then
                out("My seat="..path(seat).." ("..seat.ClassName..")")
                local model=parentAircraft(seat)
                out("My vehicle="..path(model))
                out("My vehicle attrs="..selectedAttrs(model))
            end
            local toolCount=0
            for _,obj in ipairs({ch,LP:FindFirstChildOfClass("Backpack")}) do
                if obj then
                    for _,t in ipairs(obj:GetChildren()) do
                        if t:IsA("Tool") and toolCount<16 then
                            toolCount=toolCount+1
                            out("Tool="..path(t).." attrs="..selectedAttrs(t))
                        end
                    end
                end
            end
            out("Tools found="..toolCount)
            out("")
            out("== SEATS, PILOTS AND AIRCRAFT ==")
            local total,occupied,samples,inspected=0,0,0,0
            local combat={}
            for _,inst in ipairs(workspace:GetDescendants()) do
                inspected=inspected+1
                if inst:IsA("VehicleSeat") or inst:IsA("Seat") then
                    total=total+1
                    local h=inst.Occupant
                    local pilot=h and h.Parent and
                        Players:GetPlayerFromCharacter(h.Parent) or nil
                    local model=parentAircraft(inst)
                    if h then occupied=occupied+1 end
                    if h and samples<16 then
                        samples=samples+1
                        out("occupied seat="..path(inst))
                        out(" pilot="..clean(pilot and pilot.Name or "UNRESOLVED")..
                            " | vehicle="..path(model))
                        out(" attrs="..selectedAttrs(model))
                    end
                end
                if #combat<18 then
                    local name=inst.Name:lower()
                    if (name:find("bullet",1,true) or
                        name:find("missile",1,true) or
                        name:find("projectile",1,true) or
                        name:find("damage",1,true) or
                        name:find("hitbox",1,true) or
                        name:find("gun",1,true)) and
                        (inst:IsA("BasePart") or inst:IsA("Model") or
                         inst:IsA("Folder")) then
                        combat[#combat+1]=inst.ClassName.." "..path(inst)
                    end
                end
                if inspected%500==0 then task.wait() end
                if inspected>=20000 then break end
            end
            out("Seats="..total.."; occupied="..occupied..
                "; inspected="..inspected)
            out("Combat-related object samples:")
            for _,n in ipairs(combat) do out(" "..n) end
            out("")
            out("== VISIBLE GAME GUI ==")
            local pg=LP:FindFirstChild("PlayerGui")
            if pg then
                for i,v in ipairs(pg:GetChildren()) do
                    if v~=gui and i<=40 then
                        out(v.ClassName.." "..clean(v.Name))
                    end
                end
                local shown=0
                for _,v in ipairs(pg:GetDescendants()) do
                    if v~=gui and not v:IsDescendantOf(gui) then
                        local name=v.Name:lower()
                        if name:find("ammo",1,true) or name:find("weapon",1,true) or
                            name:find("gun",1,true) or name:find("target",1,true) or
                            name:find("crosshair",1,true) or name:find("missile",1,true)
                            or name:find("shoot",1,true) then
                            shown=shown+1
                            if shown<=18 then
                                local t=(v:IsA("TextLabel") or v:IsA("TextButton")) and v.Text or ""
                                out("HUD="..v.ClassName.." "..path(v).." "..clean(t))
                            end
                        end
                    end
                end
                out("Matching HUD nodes="..shown)
            end
            out("")
            out("== REPLICATED REMOTE NAMES (READ ONLY) ==")
            local remotes=0
            local modules=0
            for _,v in ipairs(ReplicatedStorage:GetDescendants()) do
                if (v:IsA("RemoteFunction") or v:IsA("RemoteEvent"))
                    and remotes<45 then
                    remotes=remotes+1
                    out("REMOTE "..v.ClassName.." "..path(v))
                elseif v:IsA("ModuleScript") and modules<20 then
                    local name=v.Name:lower()
                    if name:find("gun",1,true) or name:find("shoot",1,true) or
                        name:find("bullet",1,true) or name:find("weapon",1,true)
                        or name:find("plane",1,true) or name:find("missile",1,true)
                        then
                        modules=modules+1
                        out("MODULE NAME "..path(v))
                    end
                end
            end
            out("Remotes listed="..remotes.." Modules listed="..modules)
            out("")
            out("== EXECUTOR CAPABILITIES (NOT USED) ==")
            out("hookmetamethod="..tostring(type(hookmetamethod)=="function"))
            out("getnamecallmethod="..tostring(type(getnamecallmethod)=="function"))
            out("newcclosure="..tostring(type(newcclosure)=="function"))
            out("checkcaller="..tostring(type(checkcaller)=="function"))
            out("setclipboard="..tostring(type(setclipboard)=="function"))
            out("")
            out("No server-side damage verification possible from passive scan.")
            out("Send report to compare ESP team and aircraft targeting assumptions.")
        end)
        if not alive then return end
        if not success then out("SCAN ERROR: "..clean(failure)) end
        report=table.concat(lines,"\n")
        view.Text=report
        running=false
        scan.Text="SCAN AGAIN"
        status.Text=success and "Scan done! Copy the report." or
            "Scan partially failed. Copy the report."
        print("[AETHER SCAN] "..report)
    end)
end
wire(scan.Activated,scanGame)
wire(copy.Activated,function()
    if #report==0 then status.Text="Scan first.";return end
    local fn=type(setclipboard)=="function" and setclipboard or
        (type(toclipboard)=="function" and toclipboard or nil)
    if fn then
        local ok=pcall(fn,report)
        status.Text=ok and "Copied. Paste it here." or "Clipboard failed."
    else
        status.Text="No clipboard API. Select report text."
        view.TextEditable=true
    end
end)
local drag=false
local ptr,initial,startPos
wire(head.InputBegan,function(i)
    if i.UserInputType==Enum.UserInputType.Touch or
        i.UserInputType==Enum.UserInputType.MouseButton1 then
        drag=true
        ptr=i
        initial=i.Position
        startPos=window.Position
        local change
        change=i.Changed:Connect(function()
            if i.UserInputState==Enum.UserInputState.End then
                drag=false
                if change then change:Disconnect() end
            end
        end)
    end
end)
wire(UIS.InputChanged,function(i)
    if not drag or not startPos or not initial then return end
    if i~=ptr and i.UserInputType~=Enum.UserInputType.MouseMovement then return end
    local d=i.Position-initial
    window.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,
        startPos.Y.Scale,startPos.Y.Offset+d.Y)
end)
local function closeAll()
    if not alive then return end
    alive=false
    for _,c in ipairs(conns) do pcall(function()c:Disconnect()end) end
    pcall(function()gui:Destroy()end)
    if env.AETHER_SCANNER_CLOSE==closeAll then env.AETHER_SCANNER_CLOSE=nil end
end
wire(close.Activated,closeAll)
env.AETHER_SCANNER_CLOSE=closeAll
if game.PlaceId~=111410533261470 then
    status.Text="Place ID differs from AETHER V1. Scan to check."
end
print("[AETHER] Passive Tiny Skies scanner ready.")
