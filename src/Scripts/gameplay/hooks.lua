local R=require('shared.runtime')
local Hooks={registered={},calls={}}
local function unwrap(value)
    if value==nil then return nil end
    local ok,result=pcall(function()return value:get()end)
    return ok and result or value
end
function Hooks.install(engine)
    Hooks.engine=engine
    local function hook(path,callback)
        local fn=StaticFindObject(path)
        if not R.valid(fn)then return end
        local address=tostring(fn:GetAddress())
        if Hooks.registered[path]and Hooks.registered[path].address==address then return end
        local handler=function(context,...)
                Hooks.calls[path]=(Hooks.calls[path]or 0)+1
                local args=table.pack(...)
                local success,message=pcall(function()
                    for i=1,args.n do args[i]=unwrap(args[i])end
                    callback(Hooks.engine,unwrap(context),table.unpack(args,1,args.n))
                end)
                if not success and not Hooks.errors[path]then Hooks.errors[path]=true;R.log('Range hook: '..path..' '..tostring(message))end
            end
        local ok,first,second=pcall(RegisterHook,path,handler)
        if ok then Hooks.registered[path]={handler=handler,first=first,second=second,address=address} else R.log('Range hook unavailable: '..tostring(first))end
    end
    Hooks.errors=Hooks.errors or{}
    hook('/Game/BlueprintLogic/Weapons/A_WeaponBase.A_WeaponBase_C:ProcessBulletFired',function(e,weapon,cartridge,force,gas,location,direction,barrel,powder,pressure,kind,bullets)e:localShot(weapon,barrel,bullets,cartridge)end)
    hook('/Script/Ballistic.C_BulletBase:RegisterHit',function(e,bullet,info)e:localImpact(bullet,info)end)
    local function track(e,actor,info,player,velocity,stance,bullet)e:trackHit(actor,player,bullet)end
    hook('/Game/BlueprintLogic/Targets/TargetBase.TargetBase_C:Hit',track)
    hook('/Game/BlueprintLogic/Targets/CharacterTargets/CharacterTargetBase.CharacterTargetBase_C:Hit',track)
    local function hit(e,actor,valid,player,info,energy,velocity,bonus,unlock,breaking)if valid then e:localHit(actor,player,info,energy,velocity,breaking)end end
    hook('/Game/BlueprintLogic/Targets/TargetBase.TargetBase_C:OnHit',hit)
    hook('/Game/BlueprintLogic/Targets/CharacterTargets/CharacterTargetBase.CharacterTargetBase_C:OnHit',hit)
    hook('/Game/BlueprintLogic/Weapons/A_WeaponBase.A_WeaponBase_C:ReleaseMagazine',function(e,weapon)e:reload(weapon)end)
    hook('/Game/BlueprintLogic/Weapons/Parts/Base_BoxMagazine.Base_BoxMagazine_C:OnSnappedToSlot',function(e,part)if R.valid(part.ParentWeapon)then e:reload(part.ParentWeapon,true)end end)
end
return Hooks
