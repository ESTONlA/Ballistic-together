local R=require('shared.runtime')
local Effects={}
function Effects.create()
    local self={objects={},shots={}}
    function self:clear()
        if self.world==R.worldKey()then
            for _,item in ipairs(self.objects)do
                if R.valid(item.object)then
                    if item.actor then item.object:K2_DestroyActor()else item.object:K2_DestroyComponent(nil)end
                end
            end
        end
        self.objects,self.shots={},{}
    end
    function self:track(object,actor,lifetime)
        if not R.valid(object)then return end
        self.objects[#self.objects+1]={object=object,actor=actor,untilTime=R.gameplay():GetRealTimeSeconds(R.world())+lifetime}
    end
    function self:update()
        if self.world~=R.worldKey()then self:clear();self.world=R.worldKey()end
        local now=R.gameplay():GetRealTimeSeconds(R.world());local remaining={}
        for _,item in ipairs(self.objects)do
            if now>=item.untilTime or #remaining>=64 then
                if R.valid(item.object)then if item.actor then item.object:K2_DestroyActor()else item.object:K2_DestroyComponent(nil)end end
            else remaining[#remaining+1]=item end
        end
        self.objects=remaining
        for id,shot in pairs(self.shots)do if now-shot.time>4 then self.shots[id]=nil end end
    end
    function self:niagara(path,position,rotation,lifetime)
        local asset=LoadAsset(path)
        if not R.valid(asset)then return end
        local library=StaticFindObject('/Script/Niagara.Default__NiagaraFunctionLibrary')
        local effect=library:SpawnSystemAtLocation(R.world(),asset,position,rotation or {Pitch=0,Yaw=0,Roll=0},{X=1,Y=1,Z=1},true,true,0,false)
        self:track(effect,false,lifetime or 2)
        return effect
    end
    function self:beam(start,finish)
        local x,y,z=finish.X-start.X,finish.Y-start.Y,finish.Z-start.Z
        local length=math.sqrt(x*x+y*y+z*z)
        if length<1 or length>100000 then return end
        local actor=R.world():SpawnActor(StaticFindObject('/Script/Engine.StaticMeshActor'),
            {X=(start.X+finish.X)/2,Y=(start.Y+finish.Y)/2,Z=(start.Z+finish.Z)/2},
            StaticFindObject('/Script/Engine.Default__KismetMathLibrary'):FindLookAtRotation(start,finish))
        if not R.valid(actor)then return end
        actor:SetReplicates(false);actor:SetActorEnableCollision(false);actor:SetMobility(2)
        local mesh=LoadAsset('/Engine/BasicShapes/Cube.Cube')
        actor.StaticMeshComponent:SetStaticMesh(mesh)
        local material=LoadAsset('/Engine/EngineMaterials/EmissiveMeshMaterial.EmissiveMeshMaterial')
        if R.valid(material)then actor.StaticMeshComponent:SetMaterial(0,material)end
        actor:SetActorScale3D({X=length/100,Y=0.008,Z=0.008})
        self:track(actor,true,0.12)
        return actor
    end
    function self:shot(id,start,finish)
        self:update()
        local direction=StaticFindObject('/Script/Engine.Default__KismetMathLibrary'):FindLookAtRotation(start,finish)
        self:niagara('/Game/VFX/MuzzleFlash/MuzzleFlash.MuzzleFlash',start,direction,0.5)
        self.shots[id]={start=start,beam=self:beam(start,finish),time=R.gameplay():GetRealTimeSeconds(R.world())}
    end
    function self:impact(id,position)
        self:update()
        self:niagara('/Game/VFX/Impacts/Impact_Concrete.Impact_Concrete',position,nil,2)
        local shot=self.shots[id]
        if shot then
            if R.valid(shot.beam)then shot.beam:K2_DestroyActor()end
            shot.beam=self:beam(shot.start,position)
        end
    end
    return self
end
return Effects
