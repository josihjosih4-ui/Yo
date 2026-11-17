--[[
AETHER // TINY SKIES AIRCRAFT SCANNER V2
PASSIVE CUSTOM AIRCRAFT DIAGNOSTICS
Place: 111410533261470
1. Run in Tiny Skies at the hangar. Press SAVE BASELINE.
2. Spawn an aircraft and fly. Press SCAN IN FLIGHT.
3. Press COPY REPORT, paste the report back in ChatGPT.
Safe scan: no hooks, weapon inputs, or remote invocations.
Captures camera attachment, teams, workspace candidate models/parts,
UI state, custom ownership attributes, and movement sample.
]]

local Players=game:GetService("Players")
local UserInputService=game:GetService("UserInputService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local LP=Players.LocalPlayer
if not LP then return end
local scope=_G
if type(getgenv)=="function" then
    local ok,t=pcall(getgenv)
    if ok and type(t)=="table" then scope=t end
end
if type(scope.AETHER_SCANNER_V2_CLOSE)=="function" then
    pcall(scope.AETHER_SCANNER_V2_CLOSE)
end
local alive=true
local running=false
local connections={}
local baseline=nil
local latestReport=""
local latestText=""
local UI=LP:WaitForChild("PlayerGui")
local theme={
    base=Color3.fromRGB(17,20,27),
    raised=Color3.fromRGB(29,34,43),
    line=Color3.fromRGB(58,68,82),
    text=Color3.fromRGB(243,246,249),
    muted=Color3.fromRGB(157,170,184),
    aqua=Color3.fromRGB(91,201,216),
    gold=Color3.fromRGB(235,186,102)
}
local function wire(sig,fn)
    local c=sig:Connect(fn)
    connections[#connections+1]=c
    return c
end
local function create(kind,parent,props)
    local o=Instance.new(kind)
    for k,v in pairs(props or {}) do o[k]=v end
    o.Parent=parent
    return o
end
local function rounded(o,r)
    create("UICorner",o,{CornerRadius=UDim.new(0,r)})
    return o
end
local gui=create("ScreenGui",UI,{
    Name="Aether_AircraftScanner_V2",ResetOnSpawn=false,
    DisplayOrder=210,IgnoreGuiInset=false
})
local panel=rounded(create("Frame",gui,{
    AnchorPoint=Vector2.new(.5,.5),
    Position=UDim2.fromScale(.5,.48),
    Size=UDim2.fromOffset(342,359),
    BackgroundColor3=theme.base,BorderSizePixel=0,Active=true
}),14)
create("UIStroke",panel,{Color=theme.line,Thickness=1})
local scale=create("UIScale",panel,{Scale=1})
local function resize()
    local cam=workspace.CurrentCamera
    if cam then
        local size=cam.ViewportSize
        scale.Scale=math.clamp(math.min((size.X-22)/342,(size.Y-90)/359),.62,1)
    end
end
resize()
if workspace.CurrentCamera then
    wire(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"),resize)
end
local header=rounded(create("Frame",panel,{
    Position=UDim2.fromOffset(0,0),Size=UDim2.new(1,0,0,62),
    BackgroundColor3=theme.raised,BorderSizePixel=0
}),14)
create("TextLabel",header,{
    Position=UDim2.fromOffset(15,9),Size=UDim2.new(1,-65,0,23),
    BackgroundTransparency=1,Text="AETHER / AIRCRAFT SCAN",
    Font=Enum.Font.GothamBold,TextSize=15,
    TextColor3=theme.text,TextXAlignment=Enum.TextXAlignment.Left
})
create("TextLabel",header,{
    Position=UDim2.fromOffset(15,33),Size=UDim2.new(1,-65,0,16),
    BackgroundTransparency=1,Text="V2  •  CUSTOM VEHICLE INSPECTION",
    Font=Enum.Font.GothamMedium,TextSize=10,
    TextColor3=theme.muted,TextXAlignment=Enum.TextXAlignment.Left
})
local close=rounded(create("TextButton",header,{
    Position=UDim2.new(1,-41,0,17),Size=UDim2.fromOffset(27,27),
    BackgroundColor3=theme.base,BorderSizePixel=0,
    Text="X",Font=Enum.Font.GothamBold,TextSize=13,TextColor3=theme.text
}),7)
local info=create("TextLabel",panel,{
    Position=UDim2.fromOffset(15,69),Size=UDim2.new(1,-30,0,45),
    BackgroundTransparency=1,
    Text="Save a hangar baseline. Spawn and fly an aircraft, then scan again to identify its objects.",
    TextWrapped=true,Font=Enum.Font.Gotham,TextSize=11,
    TextColor3=theme.muted,TextXAlignment=Enum.TextXAlignment.Left
})
local function button(s,x,y,w,bg)
    return rounded(create("TextButton",panel,{
        Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(w,39),
        BackgroundColor3=bg,BorderSizePixel=0,
        Text=s,TextColor3=bg==theme.aqua and theme.base or theme.text,
        Font=Enum.Font.GothamBold,TextSize=10
    }),8)
end
local baseButton=button("SAVE BASELINE",14,126,151,theme.raised)
local flightButton=button("SCAN IN FLIGHT",177,126,151,theme.aqua)
local copyButton=button("COPY FULL REPORT",14,174,314,theme.raised)
local state=create("TextLabel",panel,{
    Position=UDim2.fromOffset(14,223),Size=UDim2.new(1,-28,0,35),
    BackgroundTransparency=1,Text="Ready • waiting for baseline",
    Font=Enum.Font.GothamSemibold,TextSize=11,
    TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,
    TextColor3=theme.gold
})
local preview=rounded(create("TextBox",panel,{
    Position=UDim2.fromOffset(14,266),Size=UDim2.new(1,-28,0,79),
    Text="",BackgroundColor3=theme.raised,BorderSizePixel=0,
    Font=Enum.Font.Code,TextSize=10,TextWrapped=true,
    TextEditable=false,MultiLine=true,
    TextColor3=theme.muted,ClearTextOnFocus=false,
    TextXAlignment=Enum.TextXAlignment.Left,
    TextYAlignment=Enum.TextYAlignment.Top
}),7)

local function fmt(value)
    if typeof(value)=="Vector3" then
        return string.format("%.1f,%.1f,%.1f",value.X,value.Y,value.Z)
    end
    if typeof(value)=="CFrame" then return fmt(value.Position) end
    local str=tostring(value)
    str=str:gsub("[\r\n\t]+"," ")
    return #str>130 and str:sub(1,127).."..." or str
end
local function fullname(obj)
    if not obj then return "nil" end
    local ok,v=pcall(function()return obj:GetFullName()end)
    return fmt(ok and v or obj.Name)
end
local function push(lines,entry)
    lines[#lines+1]=entry
end
local keys={
    "Owner","OwnerUserId","Pilot","PilotId","PilotUserId",
    "Player","PlayerName","Driver","Team","TeamName","Faction",
    "Vehicle","VehicleId","VehicleName","Controller","Crew",
    "Health","HP","MaxHealth","Weapon","Target","Speed"
}
local function attributesOf(obj)
    if not obj then return "" end
    local ok,a=pcall(function()return obj:GetAttributes()end)
    if not ok or type(a)~="table" then return "" end
    local names={}
    for k in pairs(a) do
        local low=k:lower()
        for _,w in ipairs(keys) do
            if low:find(w:lower(),1,true) then
                names[#names+1]=k
                break
            end
        end
    end
    table.sort(names)
    local out={}
    for i=1,math.min(#names,7) do
        local k=names[i]
        out[#out+1]=fmt(k).."="..fmt(a[k])
    end
    return table.concat(out,"; ")
end
local function refsOf(model)
    if not model then return "" end
    local bits={}
    for _,o in ipairs(model:GetChildren()) do
        if o:IsA("ObjectValue") or o:IsA("StringValue") or o:IsA("IntValue") then
            local name=o.Name:lower()
            if name:find("pilot",1,true) or name:find("owner",1,true) or
                name:find("team",1,true) or name:find("player",1,true) or
                name:find("controller",1,true) then
                bits[#bits+1]=o.Name.."="..fmt(o.Value)
                if #bits>=5 then break end
            end
        end
    end
    return table.concat(bits,"; ")
end
local function isCandidate(name)
    local k=name:lower()
    for _,word in ipairs({
        "jet","plane","aircraft","airplane","fighter","heli","chopper",
        "vehicle","craft","body","wing","cockpit","pilot","flight",
        "projectile","bullet","missile","munition","fuselage","engine",
        "turbine","gun","target","player","spawned","unit","air"
    }) do
        if k:find(word,1,true) then return true end
    end
    return false
end
local function userAssociation(obj,playerNames)
    local target=obj
    local depth=0
    while target and depth<4 do
        local name=target.Name:lower()
        for _,key in ipairs(playerNames) do
            if #key>=4 and name:find(key,1,true) then
                return true
            end
        end
        target=target.Parent
        depth=depth+1
    end
    return false
end
local function objInfo(inst)
    if inst:IsA("BasePart") then
        local v=inst.AssemblyLinearVelocity
        return "position="..fmt(inst.Position)..
            " speed="..string.format("%.1f",v.Magnitude)..
            " anchored="..tostring(inst.Anchored)
    elseif inst:IsA("Model") then
        local ok,cf=pcall(function()return inst:GetPivot()end)
        local root=inst.PrimaryPart
        return "pivot="..(ok and fmt(cf.Position) or "unknown")..
            " root="..(root and root.Name or "none")
    end
    return ""
end
local function getSnapshot(stage)
    local output={}
    local snapshot={
        stage=stage,models={},parts={},camera="",labels={}
    }
    local cam=workspace.CurrentCamera
    push(output,"=== AETHER AIRCRAFT SCAN V2: "..stage.." ===")
    push(output,"PlaceId="..game.PlaceId..
        " | Expected=111410533261470")
    push(output,"Team="..(LP.Team and LP.Team.Name or "nil")..
        " | Neutral="..tostring(LP.Neutral))
    push(output,"Local Character="..tostring(LP.Character~=nil))
    if cam then
        snapshot.camera="type="..cam.CameraType.Name..
            " subject="..fullname(cam.CameraSubject)..
            " pos="..fmt(cam.CFrame.Position)..
            " focus="..fmt(cam.Focus.Position)
        push(output,"Camera: "..snapshot.camera)
    end
    local cameraPos=cam and cam.CFrame.Position or Vector3.zero
    push(output,"== REPLICATED PLAYER TEAMS ==")
    local names={}
    for _,p in ipairs(Players:GetPlayers()) do
        names[#names+1]=p.Name:lower()
        local relation="UNKNOWN"
        if p==LP then relation="SELF"
        elseif LP.Team and p.Team then
            relation=p.Team==LP.Team and "FRIENDLY" or "ENEMY"
        elseif LP.Neutral and p.Neutral then relation="FFA" end
        push(output,fmt(p.Name).." ["..relation.."] team="..
            (p.Team and p.Team.Name or "nil")..
            " char="..tostring(p.Character~=nil))
    end
    push(output,"== WORKSPACE ROOT CHILDREN ==")
    for i,v in ipairs(workspace:GetChildren()) do
        if i>65 then break end
        push(output,"ROOT "..v.ClassName.." "..fmt(v.Name)..
            " children="..#v:GetChildren())
    end
    push(output,"== REPLICATED STORAGE ROOT CHILDREN ==")
    for i,v in ipairs(ReplicatedStorage:GetChildren()) do
        if i>40 then break end
        push(output,"REPL "..v.ClassName.." "..fmt(v.Name)..
            " children="..#v:GetChildren())
    end
    push(output,"== NEARBY / PLAYER-RELATED CANDIDATE MODELS ==")
    local models,parts,fast,inspected={},{},{},0
    local partByModel={}
    local all=workspace:GetDescendants()
    for i,v in ipairs(all) do
        inspected=inspected+1
        if v:IsA("Model") then
            local relevant=isCandidate(v.Name) or
                userAssociation(v,names) or attributesOf(v)~=""
            local root=v.PrimaryPart or v:FindFirstChildWhichIsA("BasePart",true)
            local dist=root and (root.Position-cameraPos).Magnitude or math.huge
            local rel=dist<1100 or relevant
            if rel then
                local speed=root and root.AssemblyLinearVelocity.Magnitude or 0
                local score=(relevant and 3 or 0)+(dist<500 and 2 or 0)+
                    (speed>12 and 3 or 0)+(attributesOf(v)~="" and 2 or 0)+
                    (userAssociation(v,names) and 4 or 0)
                local entry={
                    obj=v,path=fullname(v),score=score,dist=dist,
                    speed=speed,attr=attributesOf(v),refs=refsOf(v),
                    part=root and root.Name or "none",
                    pivot=objInfo(v)
                }
                models[#models+1]=entry
                snapshot.models[entry.path]={
                    name=v.Name,position=root and root.Position or nil,
                    speed=speed,dist=dist,score=score
                }
            end
        elseif v:IsA("BasePart") then
            local velocity=v.AssemblyLinearVelocity.Magnitude
            local dist=(v.Position-cameraPos).Magnitude
            if velocity>30 and dist<2400 and not v.Anchored then
                fast[#fast+1]={path=fullname(v),velocity=velocity,
                    dist=dist,root=v.AssemblyRootPart and v.AssemblyRootPart.Name or "nil"}
            end
            if (dist<500 and not v.Anchored and velocity>4) or
                (isCandidate(v.Name) and dist<1400) then
                parts[#parts+1]={path=fullname(v),part=v,
                    score=(velocity>10 and 5 or 0)+(dist<300 and 3 or 0)
                        +(isCandidate(v.Name) and 2 or 0),dist=dist,
                    speed=velocity
                }
            end
        end
        if i%420==0 then task.wait() end
        if inspected>=14000 then break end
    end
    local function compare(a,b)
        if a.score~=b.score then return a.score>b.score end
        return a.dist<b.dist
    end
    table.sort(models,compare)
    table.sort(parts,compare)
    table.sort(fast,function(a,b)return a.velocity>b.velocity end)
    push(output,"Workspace inspected="..inspected..
        " models matching="..#models..
        " interesting parts="..#parts..
        " fast parts="..#fast)
    for i=1,math.min(#models,30) do
        local d=models[i]
        push(output,"MODEL "..d.path..
            " | d="..math.floor(d.dist==math.huge and -1 or d.dist)..
            " speed="..math.floor(d.speed)..
            " root="..d.part..
            " score="..d.score)
        if d.attr~="" then push(output," attrs: "..d.attr) end
        if d.refs~="" then push(output," refs: "..d.refs) end
    end
    push(output,"== MOVING PARTS NEAR CAMERA ==")
    for i=1,math.min(#fast,16) do
        local d=fast[i]
        push(output,"FAST "..d.path..
            " speed="..string.format("%.1f",d.velocity)..
            " dist="..math.floor(d.dist).." assembly="..d.root)
    end
    push(output,"== OTHER NEARBY PART CANDIDATES ==")
    for i=1,math.min(#parts,16) do
        local d=parts[i]
        push(output,"PART "..d.path.." | "..objInfo(d.part))
    end
    push(output,"== LOCAL HUD / AIRCRAFT INTERFACE ==")
    for _,root in ipairs(UI:GetChildren()) do
        if root~=gui and (root:IsA("ScreenGui") or root:IsA("Folder")) then
            local low=root.Name:lower()
            if low:find("tiny",1,true) or low:find("air",1,true) then
                push(output,"HUD ROOT "..root.Name..
                    " enabled="..tostring(root:IsA("ScreenGui") and root.Enabled))
            end
        end
    end
    local textLabels={}
    for i,v in ipairs(UI:GetDescendants()) do
        if v~=gui and not v:IsDescendantOf(gui) then
            if v:IsA("TextLabel") or v:IsA("TextButton") then
                local name=v.Name:lower()
                local value=v.Text:lower()
                if isCandidate(name) or
                    value:find("gun",1,true) or
                    value:find("missile",1,true) or
                    value:find("fire",1,true) or
                    value:find("target",1,true) or
                    value:find("speed",1,true) or
                    value:find("altitude",1,true) or
                    value:find("locked",1,true) then
                    textLabels[#textLabels+1]={
                        path=fullname(v),
                        text=fmt(v.Text),
                        visible=v.Visible
                    }
                end
            end
        end
        if i%400==0 then task.wait() end
        if i>=6000 then break end
    end
    for i=1,math.min(#textLabels,26)do
        local v=textLabels[i]
        push(output,"HUD "..v.path.." text="..v.text..
            " visible="..tostring(v.visible))
    end
    snapshot.labels=textLabels
    push(output,"== LOCALLY VISIBLE COMBAT REMOTES (NAMES ONLY) ==")
    local remotes=ReplicatedStorage:FindFirstChild("Remotes")
    if remotes then
        for _,name in ipairs({"FireWeapon","GunHit","Strike","Missile",
            "Flare","Jammer","TailStrike","Crash"}) do
            local remote=remotes:FindFirstChild(name)
            push(output,name.."="..(remote and remote.ClassName or "MISSING"))
        end
    else push(output,"Remotes folder not visible") end
    push(output,"No weapon remote invoked. No hook installed.")
    snapshot.output=output
    return snapshot
end
local function reportDiff(a,b)
    local add={}
    local removed={}
    local movement={}
    for path,data in pairs(b.models) do
        if not a.models[path] then
            add[#add+1]=path
        else
            local before=a.models[path]
            if data.position and before.position then
                local displacement=(data.position-before.position).Magnitude
                if displacement>=15 then
                    movement[#movement+1]={path=path,d=displacement,
                        speed=data.speed}
                end
            end
        end
    end
    for path in pairs(a.models) do
        if not b.models[path] then removed[#removed+1]=path end
    end
    table.sort(add)
    table.sort(removed)
    table.sort(movement,function(x,y)return x.d>y.d end)
    local output={
        "== BEFORE / IN-FLIGHT COMPARISON ==",
        "Baseline camera: "..a.camera,
        "Flight camera: "..b.camera,
        "New candidate models: "..#add,
    }
    for i=1,math.min(#add,30) do
        push(output,"NEW "..add[i])
    end
    push(output,"Missing candidate models: "..#removed)
    for i=1,math.min(#removed,15) do
        push(output,"GONE "..removed[i])
    end
    push(output,"Candidate models moved >=15 studs: "..#movement)
    for i=1,math.min(#movement,20) do
        local d=movement[i]
        push(output,"MOVED "..d.path..
            " distance="..math.floor(d.d)..
            " speed="..math.floor(d.speed))
    end
    return output
end
local function perform(which)
    if not alive or running then return end
    running=true
    baseButton.Text="BUSY..."
    flightButton.Text="BUSY..."
    state.Text=which=="baseline" and "Saving your hangar state..." or
        "Analyzing the in-flight world..."
    task.spawn(function()
        local ok,snapshot=pcall(getSnapshot,which=="baseline" and
            "HANGAR BASELINE" or "IN-FLIGHT")
        if not alive then return end
        running=false
        baseButton.Text="SAVE BASELINE"
        flightButton.Text="SCAN IN FLIGHT"
        if not ok then
            state.Text="Scan error. Try again."
            latestText=tostring(snapshot)
            preview.Text=latestText
            return
        end
        if which=="baseline" then
            baseline=snapshot
            latestReport=table.concat(snapshot.output,"\n")
            latestText="Hangar baseline saved.\nSpawn and fly your plane, then press SCAN IN FLIGHT.\nBaseline includes camera, model and HUD state."
            preview.Text=latestText
            state.Text="Baseline saved • now spawn an aircraft"
        else
            local output={}
            for _,l in ipairs(snapshot.output) do push(output,l) end
            if baseline then
                local changes=reportDiff(baseline,snapshot)
                push(output,"")
                for _,l in ipairs(changes) do push(output,l) end
            else
                push(output,"")
                push(output,"No baseline saved (single in-flight scan).")
            end
            latestReport=table.concat(output,"\n")
            latestText="In-flight scan completed.\n"..(baseline and
                "Comparison included.\n" or "No baseline; still useful.\n")..
                "Press COPY FULL REPORT and send it here."
            preview.Text=latestText
            state.Text="Flight scan complete • copy the report"
            print("[AETHER AIRCRAFT SCANNER V2] "..latestReport)
        end
    end)
end
wire(baseButton.Activated,function()perform("baseline")end)
wire(flightButton.Activated,function()perform("flight")end)
wire(copyButton.Activated,function()
    if latestReport=="" then
        state.Text="Save a baseline or complete a flight scan first."
        return
    end
    local clip=type(setclipboard)=="function" and setclipboard or
        (type(toclipboard)=="function" and toclipboard or nil)
    if clip then
        local ok=pcall(clip,latestReport)
        state.Text=ok and "Full report copied • paste it here" or
            "Clipboard failed • select the text below"
        if not ok then
            preview.TextEditable=true
            preview.Text=latestReport
        end
    else
        state.Text="No clipboard API • select text manually"
        preview.TextEditable=true
        preview.Text=latestReport
    end
end)
local dragging=false
local pointer,initial,origin
wire(header.InputBegan,function(input)
    if input.UserInputType==Enum.UserInputType.Touch
        or input.UserInputType==Enum.UserInputType.MouseButton1 then
        dragging=true
        pointer=input
        initial=input.Position
        origin=panel.Position
        local event
        event=input.Changed:Connect(function()
            if input.UserInputState==Enum.UserInputState.End then
                dragging=false
                if event then event:Disconnect() end
            end
        end)
    end
end)
wire(UserInputService.InputChanged,function(input)
    if not dragging or not initial or not origin then return end
    if input~=pointer and input.UserInputType~=Enum.UserInputType.MouseMovement then return end
    local d=input.Position-initial
    panel.Position=UDim2.new(origin.X.Scale,origin.X.Offset+d.X,
        origin.Y.Scale,origin.Y.Offset+d.Y)
end)
local function closeScanner()
    if not alive then return end
    alive=false
    for _,c in ipairs(connections)do pcall(function()c:Disconnect()end)end
    pcall(function()gui:Destroy()end)
    if scope.AETHER_SCANNER_V2_CLOSE==closeScanner then
        scope.AETHER_SCANNER_V2_CLOSE=nil
    end
end
wire(close.Activated,closeScanner)
scope.AETHER_SCANNER_V2_CLOSE=closeScanner
if game.PlaceId~=111410533261470 then
    state.Text="Wrong game PlaceId • expected Tiny Skies"
end
print("[AETHER AIRCRAFT SCANNER V2] Ready; no hooks and no remote calls.")
