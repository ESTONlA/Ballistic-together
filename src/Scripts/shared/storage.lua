local Storage = {}
local source = debug.getinfo(1, 'S').source:gsub('^@', ''):gsub('\\', '/')
Storage.directory = assert(source:match('^(.*)/Scripts/shared/storage.lua$')) .. '/Native/'
local function path(name)
    assert(name:match('^[%w_-]+%.[%w]+$'), 'Invalid local data filename')
    return Storage.directory .. name
end
function Storage.read(name, limit)
    local file = io.open(path(name), 'rb')
    if not file then return '' end
    local value = file:read((limit or 24576) + 1) or ''; file:close()
    return #value <= (limit or 24576) and value or ''
end
function Storage.write(name, value)
    local destination = path(name)
    local file = assert(io.open(destination .. '.tmp', 'wb'))
    file:write(value); file:close()
    os.remove(destination)
    assert(os.rename(destination .. '.tmp', destination))
end
return Storage
