local Http, Players = game:GetService("HttpService"), game:GetService("Players")
local CoreGui, Workspace = game:GetService("CoreGui"), game:GetService("Workspace")
local request = request or http_request or (syn and syn.request) or (fluxus and fluxus.request) --意义不明eq
if not request then return end

local fmt, inst, spawn = string.format, table.insert, task.spawn
local encode, decode = Http.UrlEncode, Http.JSONDecode
local API = "https://clients5.google.com/translate_a/t?client=dict-chrome-ex&sl=auto&tl=zh-CN&q="

local Cache, Queue, Locks = {}, {}, setmetatable({}, {__mode = "k"})

local function Hook(obj)
    if not (obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox")) then return end
    if Locks[obj] then return end

    local function Run()
        local txt = obj.Text
        if #txt < 2 or txt:gsub("[%d%s%p]", "") == "" then return end

        local vars = {}
        local skel = txt:gsub("[%+$%-¥]?%d+[%d%.%,:]*[%d%%]*", function(m) inst(vars, m); return "{n}" end)

        if Cache[skel] then
            local i = 0
            local final = Cache[skel]:gsub("%s?{[nN]}%s?", function() i=i+1; return vars[i] or "" end)
            if obj.Text ~= final then
                Locks[obj] = true; obj.Text = final; Locks[obj] = nil
            end
            return
        end

        if Queue[skel] then inst(Queue[skel], {obj, vars}); return end
        Queue[skel] = { {obj, vars} }

        spawn(function()
            local s, r = pcall(request, {Url = API .. encode(Http, skel), Method = "GET"})
            if s and r.StatusCode == 200 then
                local d = decode(Http, r.Body)
                local res = (type(d)=="table") and ((type(d[1])=="string" and d[1]) or (type(d[1])=="table" and d[1][1]))
                if res then
                    Cache[skel] = res
                    for _, item in next, Queue[skel] do
                        local o, v, k = item[1], item[2], 0
                        if o.Parent then
                            local t = res:gsub("%s?{[nN]}%s?", function() k=k+1; return v[k] or "" end)
                            if o.Text ~= t then
                                Locks[o] = true; o.Text = t; Locks[o] = nil
                            end
                        end
                    end
                end
            end
            Queue[skel] = nil
        end)
    end

    Run()
    obj:GetPropertyChangedSignal("Text"):Connect(function() if not Locks[obj] then Run() end end)
end

local Roots = { Players.LocalPlayer:WaitForChild("PlayerGui"), (gethui and gethui()) or CoreGui, Workspace }

for _, root in next, Roots do
    if root then
        spawn(function()
            for _, v in next, root:GetDescendants() do Hook(v) end
            root.DescendantAdded:Connect(Hook)
        end)
    end
end
