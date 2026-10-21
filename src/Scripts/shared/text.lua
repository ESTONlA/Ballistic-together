local Text = {}
function Text.clean(value, limit)
    local text = tostring(value or ''):gsub('[%c<>]', ' '):gsub('%s+', ' '):match('^%s*(.-)%s*$')
    text = text:sub(1, limit or 180)
    while #text > 0 and not utf8.len(text) do text = text:sub(1, -2) end
    return text
end
return Text
