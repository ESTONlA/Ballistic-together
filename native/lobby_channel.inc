namespace LobbyChannel {
constexpr int Channel = 18732;
constexpr size_t Limit = 24576;
using Send = bool (__cdecl*)(void*, uint64_t, const void*, uint32_t, int, int);
using Available = bool (__cdecl*)(void*, uint32_t*, int);
using Receive = bool (__cdecl*)(void*, void*, uint32_t, uint32_t*, uint64_t*, int);
using Accept = bool (__cdecl*)(void*, uint64_t);
using Close = bool (__cdecl*)(void*, uint64_t, int);
Interface networking;
Send send;
Available available;
Receive receive;
Accept accept;
Close close;
uint64_t host = 0, peer = 0, epoch = 0, receivedAt = 0, sentAt = 0;
std::string incoming;
bool started = false;

std::string read(const wchar_t* name) {
    FILE* f = nullptr;
    if (_wfopen_s(&f, path(name).c_str(), L"rb") != 0) return {};
    char buffer[Limit + 1]{};
    const size_t length = fread(buffer, 1, sizeof(buffer), f);
    fclose(f);
    return length > Limit ? std::string{} : std::string(buffer, length);
}
bool steamId(uint64_t id) {
    return id > 76561197960265728ULL && id <= 76561202255233023ULL;
}
struct Request { uint64_t id; };
class RequestCallback {
public:
    virtual void Run(void* payload) {
        const auto* request = static_cast<Request*>(payload);
        std::lock_guard<std::mutex> lock(gate);
        if (request && request->id == peer && peer && networking && networking()) accept(networking(), peer);
    }
    virtual void Run(void* payload, bool failure, uint64_t) { if (!failure) Run(payload); }
    virtual int GetCallbackSizeBytes() { return sizeof(Request); }
    uint8_t flags = 0;
    int callbackId = 1202;
} requestCallback;

bool init() {
    if (started) return true;
    const auto steam = GetModuleHandleW(L"steam_api64.dll");
    networking = symbol<Interface>(steam, "SteamAPI_SteamNetworking_v006");
    send = symbol<Send>(steam, "SteamAPI_ISteamNetworking_SendP2PPacket");
    available = symbol<Available>(steam, "SteamAPI_ISteamNetworking_IsP2PPacketAvailable");
    receive = symbol<Receive>(steam, "SteamAPI_ISteamNetworking_ReadP2PPacket");
    accept = symbol<Accept>(steam, "SteamAPI_ISteamNetworking_AcceptP2PSessionWithUser");
    close = symbol<Close>(steam, "SteamAPI_ISteamNetworking_CloseP2PChannelWithUser");
    if (!networking || !send || !available || !receive || !accept || !close || !networking()) return false;
    using RegisterRequest = void (__cdecl*)(RequestCallback*, int);
    symbol<RegisterRequest>(steam, "SteamAPI_RegisterCallback")(&requestCallback, 1202);
    started = true;
    return true;
}
bool header(const std::string& text, uint64_t& packetHost, uint64_t& packetEpoch, int& ready, size_t& body) {
    const auto end = text.find('\n');
    if (text.size() > Limit || end == std::string::npos || end > 90 || text.find('\0') != std::string::npos) return false;
    unsigned long long a = 0, b = 0;
    int consumed = 0;
    if (sscanf_s(text.substr(0, end).c_str(), "BT020 %llu %llu %d%n", &a, &b, &ready, &consumed) != 3 ||
        static_cast<size_t>(consumed) != end || (ready != 0 && ready != 1) || !steamId(a)) return false;
    packetHost = a; packetEpoch = b; body = end + 1;
    return true;
}
bool ingest(uint64_t sender, const std::string& text, uint64_t localId, uint64_t now) {
    uint64_t packetHost = 0, packetEpoch = 0;
    int ready = 0; size_t body = 0;
    if (!peer || sender != peer || !header(text, packetHost, packetEpoch, ready, body) || packetHost != host) return false;
    if (host == localId) {
        if (packetEpoch != epoch) return false;
    } else {
        if (sender != host || packetEpoch == 0) return false;
        epoch = packetEpoch;
    }
    incoming = std::to_string(sender) + "\n" + std::to_string(ready) + "\n" + text.substr(body);
    receivedAt = now;
    return true;
}
void reset() {
    if (peer && started && networking()) close(networking(), peer, Channel);
    host = peer = epoch = receivedAt = sentAt = 0;
    incoming.clear();
    write(L"lobby-in.txt", "");
}
void pump() {
    if (!registered || !userApi() || !loggedOn(userApi()) || !init()) {
        write(L"lobby-status.txt", "Steam lobby metadata is unavailable. Launch through Steam."); return;
    }
    const auto command = read(L"lobby-out.txt");
    unsigned long long nextHost = 0, nextPeer = 0;
    int ready = 0, consumed = 0;
    const auto end = command.find('\n');
    if (end == std::string::npos || end > 80 || sscanf_s(command.substr(0, end).c_str(),
        "%llu %llu %d%n", &nextHost, &nextPeer, &ready, &consumed) != 3 || static_cast<size_t>(consumed) != end ||
        (ready != 0 && ready != 1)) { reset(); return; }
    const uint64_t localId = getId(userApi());
    if (!nextHost && !nextPeer) { reset(); write(L"lobby-status.txt", "idle"); return; }
    if (!steamId(nextHost) || (nextPeer && (!steamId(nextPeer) || nextPeer == localId)) ||
        (nextHost != localId && nextHost != nextPeer)) { reset(); return; }
    if (host != nextHost || peer != nextPeer) {
        reset(); host = nextHost; peer = nextPeer;
        if (host == localId) epoch = GetTickCount64() ^ localId;
    }
    const auto now = GetTickCount64();
    if (peer && now - sentAt >= 250) {
        accept(networking(), peer);
        const auto packet = "BT020 " + std::to_string(host) + " " + std::to_string(epoch) + " " + std::to_string(ready) + "\n" + command.substr(end + 1);
        if (packet.size() <= Limit) send(networking(), peer, packet.data(), static_cast<uint32_t>(packet.size()), 0, Channel);
        sentAt = now;
    }
    for (int i = 0; i < 16; ++i) {
        uint32_t size = 0;
        if (!available(networking(), &size, Channel)) break;
        if (size > Limit) { write(L"lobby-status.txt", "Rejected oversized lobby packet."); break; }
        char bytes[Limit]; uint32_t length = 0; uint64_t sender = 0;
        if (!receive(networking(), bytes, sizeof(bytes), &length, &sender, Channel)) break;
        ingest(sender, std::string(bytes, length), localId, now);
    }
    write(L"lobby-in.txt", receivedAt && now - receivedAt < 5000 ? incoming : "");
    write(L"lobby-status.txt", "ready");
}
}
