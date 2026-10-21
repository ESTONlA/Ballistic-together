local Journal={}
function Journal.create()
    local self={next=0,seen=0,pending={},nonce=nil}
    function self:push(kind,body)
        assert(kind:match('^[SHIRQ]$')and #body<=140 and not body:find('[\r\n|]'),'Invalid range event')
        if #self.pending>=64 then return nil,'Range connection is catching up.'end
        self.next=self.next+1;self.pending[#self.pending+1]=self.next..'|'..kind..'|'..body
        return self.next
    end
    function self:out(ack)
        if ack then local pending={};for _,event in ipairs(self.pending)do if tonumber(event:match('^(%d+)|'))>math.min(ack,self.next)then pending[#pending+1]=event end end;self.pending=pending end
        local lines,size={},0
        for _,event in ipairs(self.pending)do if size+#event+1>2000 then break end;lines[#lines+1]=event;size=size+#event+1 end
        return table.concat(lines,'\n')
    end
    function self:receive(data,nonce,apply)
        if self.nonce~=nonce then self.nonce,self.seen=nonce,0 end
        for line in data:gmatch('[^\n]+')do
            local id,kind,body=line:match('^(%d+)|([SHIRQ])|([^|]*)$');id=tonumber(id)
            if not id or id>10000000 or #body>140 then return false end
            if id==self.seen+1 then
                if apply(kind,body,id)==false then return false end
                self.seen=id
            elseif id>self.seen then return false end
        end
        return true
    end
    return self
end
return Journal
