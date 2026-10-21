local Wire = {}
local limits={64,64,8,2000,450,2200,8,8,200,1800}
function Wire.pack(fields)
    local out={}
    for i,limit in ipairs(limits)do local value=tostring(fields[i]or'');assert(#value<=limit and not value:find('\0',1,true),'Range data exceeds limit');out[#out+1]=#value..':'..value end
    return table.concat(out)
end
function Wire.unpack(data)
    if type(data)~='string'or #data>7000 then return nil end
    local values,offset={},1
    for i,limit in ipairs(limits)do
        local stop=data:find(':',offset,true);if not stop or stop-offset>4 then return nil end
        local length=data:sub(offset,stop-1);if not length:match('^%d+$')then return nil end
        length=tonumber(length);if length>limit or stop+length>#data then return nil end
        values[i]=data:sub(stop+1,stop+length);offset=stop+length+1
    end
    if offset~=#data+1 or not values[1]:match('^[%w_]*$')or not values[2]:match('^[%w_-]*$')then return nil end
    for _,i in ipairs({3,7,8})do if not values[i]:match('^%d+$')then return nil end end
    return {level=values[1],epoch=values[2],ack=tonumber(values[3]),events=values[4],round=values[5],targets=values[6],batch=tonumber(values[7]),batchAck=tonumber(values[8]),pose=values[9],motion=values[10]}
end
function Wire.numbers(value,count,maximum)
    if type(value)~='string'or value==''or value:sub(1,1)==','or value:sub(-1)==','or value:find(',,',1,true)then return nil end
    local result={};for part in value:gmatch('[^,]+')do local n=tonumber(part);if not n or n~=n or math.abs(n)>(maximum or 10000000)then return nil end;result[#result+1]=n end
    return #result==count and result or nil
end
function Wire.hash(value)
    local hash=2166136261
    for i=1,#value do hash=((hash~value:byte(i))*16777619)&0xffffffff end
    return string.format('%08x',hash)
end
return Wire
