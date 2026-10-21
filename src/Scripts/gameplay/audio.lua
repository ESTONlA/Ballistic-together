local R=require('shared.runtime')
local Audio={}
Audio.shots={'Shot_9mm','Shot_556mm','Shot_762mm','Shot_762x39','Shot_22LR','Shot_12GA','Shot_357Mag','Shot_44Mag',
    'Shot_50BMG','Shot_17Fireball','Shot_41Rocketball','Shot_AirPellet','Shot_BlackPowder','Shot_Supressed_S','Shot_Supressed_M','Shot_Supressed_L'}
Audio.handling={'Release_mag_rifle_Cue','Release_mag_pistol_Cue','Insert_mag_rifle_Cue','Insert_mag_pistol_Cue'}
function Audio.classify(name,suppressed,black)
    name=(name or''):lower():gsub('[%s%p]','')
    if suppressed then
        if name:find('22lr',1,true)or name:find('9mm',1,true)or name:find('9x19',1,true)then return 14 end
        return name:find('50bmg',1,true)and 16 or 15
    end
    if black then return 13 end
    local aliases={{'762x39',4},{'556',2},{'762',3},{'22lr',5},{'12ga',6},{'12gauge',6},{'357',7},{'44mag',8},{'50bmg',9},{'17fireball',10},{'41rocket',11},{'airpellet',12}}
    for _,pair in ipairs(aliases)do if name:find(pair[1],1,true)then return pair[2]end end
    return 1
end
function Audio.capture(weapon,cartridge)
    local name=R.name(cartridge)
    local suppressed,black=false,false
    pcall(function()name=name..' '..cartridge.DisplayName:ToString();black=cartridge.isBlackPowder end)
    pcall(function()suppressed=weapon.SoundReduction>0.1 end)
    return Audio.classify(name,suppressed,black)
end
function Audio.handlingId(weapon,insert)
    local name=R.name(weapon):lower()
    pcall(function()name=name..' '..weapon.WeaponName:ToString():lower()end)
    local pistol=name:find('pistol',1,true)or name:find('luger',1,true)or name:find('1911',1,true)or name:find('glock',1,true)
    return (insert and 3 or 1)+(pistol and 1 or 0)
end
function Audio.play(kind,id,position)
    local list=kind=='shot'and Audio.shots or Audio.handling
    if type(id)~='number'or id%1~=0 or not list[id]then return false end
    local folder=kind=='shot'and '/Game/SFX/Cues/Shots/'or'/Game/SFX/Cues/Manipulation/Generic/'
    local sound=LoadAsset(folder..list[id]..'.'..list[id])
    if not R.valid(sound)or not sound:IsA(StaticFindObject('/Script/Engine.SoundBase'))then return false end
    local attenuation=LoadAsset('/Game/SFX/Cues/Shots/_ShotsAttenuation._ShotsAttenuation')
    R.gameplay():PlaySoundAtLocation(R.world(),sound,position,{Pitch=0,Yaw=0,Roll=0},kind=='shot'and 0.8 or 0.5,1,0,attenuation,nil,nil,nil)
    return true
end
return Audio
