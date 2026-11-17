--[[
AETHER SHOT TRACE V1 / TINY SKIES (111410533261470)
Diagnostic only. It does not shoot, redirect rays, modify network data,
or make any target suggestions. Captures outgoing FireWeapon/GunHit argument
types during a short window, plus counts of relevant client raycasts.
Use with ordinary gunshots in training or a private match.
Run it after spawning your aircraft, click START TEST, fire 2-3 normal gun
shots, then copy the report and send it back to the developer.
The one-time namecall observer cannot be uninstalled by standard Luau;
it becomes a no-op forwarding wrapper once the test ends.
]]

local Players=game:GetService("Players")
local Workspace=game:GetService("Workspace")
local RunService=game:GetService("RunService")
local UIS=game:GetService("UserInputService")
local LP=Players.LocalPlayer
if not LP then return end

local global=_G
if type(getgenv)=="function" then
    local good,env=pcall(getgenv)
    if good and type(env)=="table" then global=env end
end
if type(global.AETHER_SHOT_TRACE_CLOSE)=="function" then
    pcall(global.AETHER_SHOT_TRACE_CLOSE)
end
local active=true
local observing=false
local installed=false
local registered={}
local report=""
local captureCount=0
local hookError=""
local counters={Raycast=0,LongRaycast=0,FireWeapon=0,GunHit=0,Strike=0}
local samples={FireWeapon={},GunHit={},Strike={},Raycast={}}
local function wire(sig,cb)
    local c=sig:Connect(cb)
    registered[#registered+1]=c
    return c
end
local function make(class,parent,props)
    local o=Instance.new(class)
    for k,v in pairs(props or {}) do o[k]=v end
    o.Parent=parent
    return o
end
local pal={
    bg=Color3.fromRGB(15,18,24),
    pane=Color3.fromRGB(27,33,42),
    text=Color3.fromRGB(241,244,249),
    muted=Color3.fromRGB(154,168,186),
    border=Color3.fromRGB(59,71,88),
    cyan=Color3.fromRGB(85,192,211),
    yellow=Color3.fromRGB(241,188,103)
}
local gui=make("ScreenGui",LP:WaitForChild("PlayerGui"),{
    Name="AETHER_SHOT_TRACE_V1",
    ResetOnSpawn=false,IgnoreGuiInset=false,DisplayOrder=230
})
local main=make("Frame",gui,{
    Position=UDim2.new(.5,-161,.48,-148),
    Size=UDim2.fromOffset(322,296),
    BackgroundColor3=pal.bg,BorderSizePixel=0,Active=true
})
make("UICorner",main,{CornerRadius=UDim.new(0,13)})
make("UIStroke",main,{Thickness=1,Color=pal.border})
local uiscale=make("UIScale",main,{Scale=1})
local function resize()
    local cam=Workspace.CurrentCamera
    if cam then
        local s=cam.ViewportSize
        uiscale.Scale=math.min(1,math.max(.62,math.min((s.X-22)/322,(s.Y-88)/296)))
    end
end
resize()
if Workspace.CurrentCamera then
    wire(Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"),resize)
end
local head=make("Frame",main,{
    Size=UDim2.new(1,0,0,62),BackgroundColor3=pal.pane,BorderSizePixel=0
})
make("UICorner",head,{CornerRadius=UDim.new(0,13)})
local title=make("TextLabel",head,{
    Position=UDim2.fromOffset(14,10),Size=UDim2.new(1,-56,0,22),
    BackgroundTransparency=1,Text="AETHER / SHOT TRACE",
    Font=Enum.Font.GothamBold,TextSize=15,
    TextColor3=pal.text,TextXAlignment=Enum.TextXAlignment.Left
})
local sub=make("TextLabel",head,{
    Position=UDim2.fromOffset(14,34),Size=UDim2.new(1,-56,0,15),
    BackgroundTransparency=1,Text="SILENT AIM DIAGNOSTIC  /  V1",
    Font=Enum.Font.GothamMedium,TextSize=10,
    TextColor3=pal.muted,TextXAlignment=Enum.TextXAlignment.Left
})
local close=make("TextButton",head,{
    Position=UDim2.new(1,-38,0,16),Size=UDim2.fromOffset(26,27),
    Text="X",Font=Enum.Font.GothamBold,TextSize=12,
    TextColor3=pal.text,BackgroundColor3=pal.bg,BorderSizePixel=0
})
make("UICorner",close,{CornerRadius=UDim.new(0,7)})
local details=make("TextLabel",main,{
    Position=UDim2.fromOffset(14,75),Size=UDim2.new(1,-28,0,45),
    BackgroundTransparency=1,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,
    Text="Start test, fire 2-3 normal GUN shots in flight, then copy the report. No requests are modified.",
    Font=Enum.Font.Gotham,TextSize=11,TextColor3=pal.muted
})
local start=make("TextButton",main,{
    Position=UDim2.fromOffset(14,130),Size=UDim2.fromOffset(139,40),
    Text="START TEST",Font=Enum.Font.GothamBold,TextSize=11,
    TextColor3=pal.bg,BackgroundColor3=pal.cyan,BorderSizePixel=0
})
make("UICorner",start,{CornerRadius=UDim.new(0,8)})
local copy=make("TextButton",main,{
    Position=UDim2.fromOffset(168,130),Size=UDim2.fromOffset(140,40),
    Text="COPY REPORT",Font=Enum.Font.GothamBold,TextSize=11,
    TextColor3=pal.text,BackgroundColor3=pal.pane,BorderSizePixel=0
})
make("UICorner",copy,{CornerRadius=UDim.new(0,8)})
local status=make("TextLabel",main,{
    Position=UDim2.fromOffset(14,182),Size=UDim2.new(1,-28,0,29),
    Text="Ready. Test lasts 12 seconds.",BackgroundTransparency=1,
    TextColor3=pal.yellow,Font=Enum.Font.GothamMedium,TextSize=11,
    TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=true
})
local preview=make("TextBox",main,{
    Position=UDim2.fromOffset(14,218),Size=UDim2.new(1,-28,0,64),
    Text="",TextColor3=pal.muted,TextSize=10,
    Font=Enum.Font.Code,TextWrapped=true,MultiLine=true,
    TextEditable=false,ClearTextOnFocus=false,
    TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,
    BackgroundColor3=pal.pane,BorderSizePixel=0
})
make("UICorner",preview,{CornerRadius=UDim.new(0,7)})
local function clip(v)
    local s=tostring(v)
    if #s>115 then s=s:sub(1,112).."..." end
    return s:gsub("[\r\n\t]+"," ")
end
local function basic(v)
    local typ=typeof(v)
    if typ=="Vector3" then
        return string.format("Vector3(%.1f,%.1f,%.1f)",v.X,v.Y,v.Z)
    end
    if typ=="Vector2" then
        return string.format("Vector2(%.1f,%.1f)",v.X,v.Y)
    end
    if typ=="CFrame" then
        local p=v.Position
        return string.format("CFrame[pos %.1f,%.1f,%.1f]",p.X,p.Y,p.Z)
    end
    if typ=="Instance" then
        local ok,name=pcall(function()return v:GetFullName()end)
        return "Instance("..clip(ok and name or v.Name)..")"
    end
    if typ=="number" then
        return string.format("number(%.4g)",v)
    end
    if typ=="boolean" then
        return "boolean("..tostring(v)..")"
    end
    if typ=="string" then
        return "string(len="..#v..", value="..clip(v)..")"
    end
    if typ=="table" then
        local summary={}
        local count=0
        local ok=pcall(function()
            for k,x in pairs(v) do
                count=count+1
                if #summary<8 then
                    local ktype=type(k)
                    local safeKey=ktype=="string" and clip(k) or "["..ktype.."]"
                    summary[#summary+1]=safeKey..":"..typeof(x)
                end
            end
        end)
        return "table(keys="..(ok and count or "?").."; "..table.concat(summary,",")..")"
    end
    return typ
end
local function summarizeArgs(args)
    local output={}
    for i=1,math.min(args.n,9) do
        output[#output+1]="arg"..i.."="..basic(args[i])
    end
    if args.n>9 then output[#output+1]="+"..(args.n-9).." more args" end
    return table.concat(output," | ")
end
local function addSample(name,summary)
    local dest=samples[name]
    if dest and #dest<4 then dest[#dest+1]=summary end
end
local function reportString()
    local output={
        "=== AETHER SHOT TRACE V1 ===",
        "PlaceId="..tostring(game.PlaceId),
        "Expected=111410533261470",
        "LocalTeam="..(LP.Team and LP.Team.Name or "nil"),
        "Method=read-only __namecall observer (passthrough)",
        "Note: samples captured during normal manual gunfire",
        "HookInstalled="..tostring(installed),
        "HookError="..hookError,
    }
    for _,name in ipairs({"FireWeapon","GunHit","Strike","Raycast","LongRaycast"}) do
        output[#output+1]=name.." calls="..tostring(counters[name])
        local arr=samples[name]
        if arr then
            for i,v in ipairs(arr) do
                output[#output+1]="  sample "..i..": "..v
            end
        end
    end
    local cam=Workspace.CurrentCamera
    if cam then
        output[#output+1]="CameraType="..cam.CameraType.Name
        output[#output+1]="CameraPosition="..basic(cam.CFrame.Position)
    end
    local a=Workspace:FindFirstChild("Aircraft")
    if a then
        output[#output+1]="AircraftCount="..#a:GetChildren()
        for _,m in ipairs(a:GetChildren()) do
            if m:IsA("Model") then
                local r=m:FindFirstChild("Root")
                if r and r:IsA("BasePart") then
                    output[#output+1]="Aircraft="..clip(m.Name)
                        .."; speed="..string.format("%.1f",r.AssemblyLinearVelocity.Magnitude)
                end
            end
        end
    end
    output[#output+1]="Interpretation: remote and raycast traces identify only client calls."
    output[#output+1]="They DO NOT prove that a server accepts client-specified hits."
    return table.concat(output,"\n")
end
local function stopTest()
    if not active or not observing then return end
    observing=false
    report=reportString()
    preview.Text="Test finished.\n"..counters.FireWeapon.." FireWeapon calls, "..
        counters.GunHit.." GunHit calls, "..counters.LongRaycast..
        " long raycasts.\nPress COPY REPORT."
    status.Text="Done. Copy the diagnostic report."
    start.Text="START AGAIN"
end
local function install()
    if installed then return true end
    if type(hookmetamethod)~="function" or
        type(getnamecallmethod)~="function" or
        type(newcclosure)~="function" or
        type(checkcaller)~="function" then
        hookError="Missing Delta hook APIs"
        return false
    end
    local old
    local ok,original=pcall(function()
        return hookmetamethod(game,"__namecall",newcclosure(function(self,...)
            if not active or not observing or checkcaller() then
                return old(self,...)
            end
            local method=getnamecallmethod()
            if method=="FireServer" and
                (self.Name=="FireWeapon" or self.Name=="GunHit" or
                 self.Name=="Strike") then
                local name=self.Name
                local args=table.pack(...)
                counters[name]=counters[name]+1
                addSample(name,summarizeArgs(args))
            elseif self==Workspace and method=="Raycast" then
                local from,direction=...
                if typeof(from)=="Vector3" and typeof(direction)=="Vector3" then
                    counters.Raycast=counters.Raycast+1
                    if direction.Magnitude>100 then
                        counters.LongRaycast=counters.LongRaycast+1
                        if #samples.Raycast<4 then
                            addSample("Raycast","origin="..basic(from)..
                                " direction="..basic(direction)..
                                " length="..string.format("%.0f",direction.Magnitude))
                        end
                    end
                end
            end
            return old(self,...)
        end))
    end)
    if not ok or type(original)~="function" then
        hookError="Unable to install observer: "..clip(original)
        return false
    end
    old=original
    installed=true
    hookError=""
    return true
end
wire(start.Activated,function()
    if observing then
        stopTest()
        return
    end
    if game.PlaceId~=111410533261470 then
        status.Text="Wrong game. Launch this inside Tiny Skies."
        return
    end
    if not install() then
        status.Text="Observer unsupported. Copy report for details."
        report=reportString()
        return
    end
    captureCount=captureCount+1
    counters={Raycast=0,LongRaycast=0,FireWeapon=0,GunHit=0,Strike=0}
    samples={FireWeapon={},GunHit={},Strike={},Raycast={}}
    observing=true
    status.Text="12-second test active. Fire 2-3 NORMAL gun shots."
    start.Text="STOP TEST"
    preview.Text="Observing unmodified gunfire. No aim adjustment."
    local testNum=captureCount
    task.delay(12,function()
        if active and observing and testNum==captureCount then
            stopTest()
        end
    end)
end)
wire(copy.Activated,function()
    if report=="" then
        status.Text="Complete the test before copying."
        return
    end
    local fn=type(setclipboard)=="function" and setclipboard or
        (type(toclipboard)=="function" and toclipboard or nil)
    if fn then
        local ok=pcall(fn,report)
        status.Text=ok and "Copied. Paste the report into chat." or
            "Clipboard failed. Select text below."
        if not ok then
            preview.Text=report
            preview.TextEditable=true
        end
    else
        status.Text="Clipboard unsupported. Select text below."
        preview.Text=report
        preview.TextEditable=true
    end
end)
local dragging=false
local pointer,origin,down
wire(head.InputBegan,function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 or
        input.UserInputType==Enum.UserInputType.Touch then
        dragging=true
        pointer=input
        origin=main.Position
        down=input.Position
        local conn
        conn=input.Changed:Connect(function()
            if input.UserInputState==Enum.UserInputState.End then
                dragging=false
                if conn then conn:Disconnect() end
            end
        end)
    end
end)
wire(UIS.InputChanged,function(input)
    if not dragging or not origin or not down then return end
    if input~=pointer and input.UserInputType~=Enum.UserInputType.MouseMovement then
        return
    end
    local d=input.Position-down
    main.Position=UDim2.new(origin.X.Scale,origin.X.Offset+d.X,
        origin.Y.Scale,origin.Y.Offset+d.Y)
end)
local function closeTrace()
    if not active then return end
    observing=false
    active=false
    for _,conn in ipairs(registered) do
        pcall(function()conn:Disconnect()end)
    end
    pcall(function()gui:Destroy()end)
    if global.AETHER_SHOT_TRACE_CLOSE==closeTrace then
        global.AETHER_SHOT_TRACE_CLOSE=nil
    end
end
wire(close.Activated,closeTrace)
global.AETHER_SHOT_TRACE_CLOSE=closeTrace
print("[AETHER TRACE] Diagnostic loaded. Fire only after START TEST.")
