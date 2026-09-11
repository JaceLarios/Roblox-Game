-- Run in the Studio Edit command environment with loadstring available.
-- Uses fake players, MarketplaceService and scheduler; no real purchase or DataStore calls.
-- Expected simulated ownership-outage warnings are part of the test.
local SOURCE = game.ServerScriptService.GamepassService.Source

local config = {DoubleCoins={id=0},ExtraCarry={id=0},AutoCollect={id=0}}
local function signal()
 local s={handlers={}}
 function s:Connect(f) table.insert(self.handlers,f) return {Disconnect=function() end} end
 function s:Fire(...) for _,f in self.handlers do f(...) end end
 return s
end
local players={PlayerRemoving=signal()}
local market={PromptGamePassPurchaseFinished=signal(),calls=0,owns={},fail=false}
function market:UserOwnsGamePassAsync(user,id) self.calls+=1 if self.fail then error("Simulated outage") end return self.owns[id] == true end
local queue={}
local fakeTask={spawn=function(f,...) table.insert(queue,{f=f,args={...}}) end,wait=function() end}
local fakeGame={GetService=function(_,name) if name=="Players" then return players elseif name=="MarketplaceService" then return market else return {WaitForChild=function() return config end} end end}
local fakeInstance={new=function() local e=signal() return {Event=e,Fire=function(_,...)e:Fire(...)end} end}
local factory=assert(loadstring("return function(game, require, Instance, task)\n"..SOURCE.."\nend"))()
local service=factory(fakeGame,function(v)return v end,fakeInstance,fakeTask)
local function player(id)
 local p={UserId=id,Parent=players,attrs={}}
 function p:SetAttribute(k,v) self.attrs[k]=v end
 return p
end
local function drain()
 local jobs=queue queue={}
 for _,job in jobs do job.f(table.unpack(job.args)) end
end
local checks={}
local function check(name,value) assert(value,name) table.insert(checks,name) end
local a=player(1)
service.Init(a) drain()
check("Unconfigured IDs never call Marketplace",market.calls==0)
check("No-pass coin amount unchanged",service.Coins(a,125)==125)
check("Earned capacity unchanged",service.Capacity(a,1)==2 and service.Capacity(a,5)==6)
check("Earned magnet unchanged",service.Radius(a,0)==0 and service.Radius(a,6)==70)
config.DoubleCoins.id=101 config.ExtraCarry.id=102 config.AutoCollect.id=103
market.owns={[101]=true,[102]=true,[103]=true}
local b=player(2) service.Init(b) drain()
check("Join restores ownership",service.Has(b,"DoubleCoins") and service.Has(b,"ExtraCarry") and service.Has(b,"AutoCollect"))
check("Coin multiplier applies once",service.Coins(b,125)==250)
check("Extra slots stack with earned carry",service.Capacity(b,1)==4 and service.Capacity(b,5)==8)
check("Auto-collect starts at 20 and preserves higher earned radius",service.Radius(b,0)==20 and service.Radius(b,1)==20 and service.Radius(b,6)==70)
market.owns={} local c=player(3) service.Init(c) drain()
service.Start() queue={} -- discard only the periodic polling loop in this isolated test
market.PromptGamePassPurchaseFinished:Fire(c,101,false)
check("Cancelled purchase grants nothing",not service.Has(c,"DoubleCoins"))
market.PromptGamePassPurchaseFinished:Fire(c,999,true)
check("Unknown pass grants nothing",not service.Has(c,"DoubleCoins"))
local changes=0 service.Changed:Connect(function()changes+=1 end)
market.PromptGamePassPurchaseFinished:Fire(c,101,true)
market.PromptGamePassPurchaseFinished:Fire(c,101,true)
check("Successful purchase grants once",service.Coins(c,10)==20 and changes==1)
market.fail=true local e=player(4) local before=market.calls service.Init(e) drain()
check("Ownership outage retries without granting",not service.Has(e,"DoubleCoins") and e.attrs.PassStatus_DoubleCoins=="Retry" and market.calls-before==9)
players.PlayerRemoving:Fire(c)
check("Leaving clears session cache",not service.Has(c,"DoubleCoins"))
return checks
