#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <string>
#include <mutex>
#include <map>
#include <cstdlib>

namespace {
HMODULE module;
std::wstring root;
std::mutex gate;
bool registered = false;
std::string published;
using Interface = void* (__cdecl*)();
using GetId = uint64_t (__cdecl*)(void*);
using LoggedOn = bool (__cdecl*)(void*);
using Presence = bool (__cdecl*)(void*, const char*, const char*);
using Overlay = void (__cdecl*)(void*, const char*);
using OverlayEnabled = bool (__cdecl*)(void*);
Interface friendsApi, userApi, utilsApi;
GetId getId;
LoggedOn loggedOn;
Presence presence;
Overlay overlay;
OverlayEnabled overlayEnabled;

std::wstring path(const wchar_t* name) { return root + name; }
void write(const wchar_t* name, const std::string& value) {
    static std::map<std::wstring, std::string> previous;
    const auto found = previous.find(name);
    if (found != previous.end() && found->second == value) return;
    const auto temp = path(name) + L".tmp";
    FILE* f = nullptr;
    if (_wfopen_s(&f, temp.c_str(), L"wb") != 0) return;
    fwrite(value.data(), 1, value.size(), f);
    fclose(f);
    if (MoveFileExW(temp.c_str(), path(name).c_str(), MOVEFILE_REPLACE_EXISTING)) previous[name] = value;
}
void status(const char* value) { write(L"status.txt", value); }
bool address(const char* value) {
    if (!value || strnlen_s(value, 256) != 28 || strncmp(value, "steam.", 6) != 0) return false;
    for (int i = 6; i < 23; ++i) if (value[i] < '0' || value[i] > '9') return false;
    const auto id = std::strtoull(value + 6, nullptr, 10);
    return id > 76561197960265728ULL && id <= 76561202255233023ULL && strcmp(value + 23, ":7777") == 0;
}
struct JoinRequest { uint64_t friendId; char connect[256]; };
static_assert(sizeof(JoinRequest) == 264);
class JoinCallback {
public:
    virtual void Run(void* payload) {
        const auto* request = static_cast<JoinRequest*>(payload);
        if (!request || !address(request->connect)) return;
        std::lock_guard<std::mutex> lock(gate);
        write(L"accepted.txt", std::to_string(GetTickCount64()) + "\n" + request->connect);
    }
    virtual void Run(void* payload, bool failure, uint64_t) { if (!failure) Run(payload); }
    virtual int GetCallbackSizeBytes() { return sizeof(JoinRequest); }
    uint8_t flags = 0;
    int callbackId = 337;
} callback;
using Register = void (__cdecl*)(JoinCallback*, int);
Register registerCallback;
template<class T> T symbol(HMODULE steam, const char* name) {
    return reinterpret_cast<T>(GetProcAddress(steam, name));
}
bool initialize() {
    if (registered) {
        if (userApi() && friendsApi() && loggedOn(userApi())) { status("ready"); return true; }
        status("Steam login was lost. Reconnect Steam before inviting."); return false;
    }
    HMODULE steam = GetModuleHandleW(L"steam_api64.dll");
    if (!steam) { status("Steam API is not loaded. Start the game through Steam."); return false; }
    friendsApi = symbol<Interface>(steam, "SteamAPI_SteamFriends_v017");
    userApi = symbol<Interface>(steam, "SteamAPI_SteamUser_v023");
    utilsApi = symbol<Interface>(steam, "SteamAPI_SteamUtils_v010");
    getId = symbol<GetId>(steam, "SteamAPI_ISteamUser_GetSteamID");
    loggedOn = symbol<LoggedOn>(steam, "SteamAPI_ISteamUser_BLoggedOn");
    presence = symbol<Presence>(steam, "SteamAPI_ISteamFriends_SetRichPresence");
    overlay = symbol<Overlay>(steam, "SteamAPI_ISteamFriends_ActivateGameOverlayInviteDialogConnectString");
    overlayEnabled = symbol<OverlayEnabled>(steam, "SteamAPI_ISteamUtils_IsOverlayEnabled");
    registerCallback = symbol<Register>(steam, "SteamAPI_RegisterCallback");
    if (!friendsApi || !userApi || !utilsApi || !getId || !loggedOn || !presence || !overlay || !overlayEnabled || !registerCallback) {
        status("Bundled Steam API is missing an invite export."); return false;
    }
    if (!userApi() || !friendsApi() || !utilsApi() || !loggedOn(userApi())) {
        status("Steam is not logged in for this game process. Launch through Steam."); return false;
    }
    registerCallback(&callback, 337);
    registered = true;
    write(L"identity.txt", std::to_string(getId(userApi())));
    status("ready");
    return true;
}
std::string ownAddress() { return "steam." + std::to_string(getId(userApi())) + ":7777"; }
bool publish() {
    if (!initialize()) return false;
    const auto target = ownAddress();
    if (!address(target.c_str())) { status("Steam returned an invalid local player ID."); return false; }
    if (!presence(friendsApi(), "connect", target.c_str())) { status("Steam rejected join information."); return false; }
    published = target;
    status("ready");
    return true;
}
#include "lobby_channel.inc"
}

extern "C" __declspec(dllexport) int bt_initialize(void*) {
    std::lock_guard<std::mutex> lock(gate);
    if (root.empty()) {
        wchar_t filename[32768];
        DWORD length = GetModuleFileNameW(module, filename, 32768);
        if (!length || length >= 32768) return 0;
        root = std::wstring(filename, length);
        root.resize(root.find_last_of(L"\\/") + 1);
        HMODULE pinned;
        GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_PIN,
            reinterpret_cast<LPCWSTR>(&bt_initialize), &pinned);
        DeleteFileW(path(L"accepted.txt").c_str());
        DeleteFileW(path(L"identity.txt").c_str());
        DeleteFileW(path(L"lobby-in.txt").c_str());
        DeleteFileW(path(L"lobby-out.txt").c_str());
    }
    initialize();
    return 0;
}
extern "C" __declspec(dllexport) int bt_publish(void*) {
    std::lock_guard<std::mutex> lock(gate);
    publish();
    return 0;
}
extern "C" __declspec(dllexport) int bt_invite(void*) {
    std::lock_guard<std::mutex> lock(gate);
    if (!publish()) return 0;
    if (!overlayEnabled(utilsApi())) { status("Enable the Steam Overlay for this game, then try Invite friends again."); return 0; }
    overlay(friendsApi(), published.c_str());
    status("ready");
    return 0;
}
extern "C" __declspec(dllexport) int bt_clear(void*) {
    std::lock_guard<std::mutex> lock(gate);
    if (registered && !published.empty() && userApi() && friendsApi()) {
        presence(friendsApi(), "connect", "");
        published.clear();
    }
    return 0;
}
extern "C" __declspec(dllexport) int bt_lobby(void*) {
    std::lock_guard<std::mutex> lock(gate);
    LobbyChannel::pump();
    return 0;
}
extern "C" __declspec(dllexport) int bt_copyid(void*) {
    std::lock_guard<std::mutex> lock(gate);
    if (!initialize()) { write(L"clipboard-status.txt", "Steam identity unavailable."); return 0; }
    const auto value = std::to_wstring(getId(userApi()));
    const auto bytes = (value.size() + 1) * sizeof(wchar_t);
    const auto memory = GlobalAlloc(GMEM_MOVEABLE, bytes);
    if (!memory) return 0;
    const auto data = GlobalLock(memory);
    if (!data) { GlobalFree(memory); return 0; }
    memcpy(data, value.c_str(), bytes); GlobalUnlock(memory);
    bool copied = false;
    if (OpenClipboard(nullptr)) {
        if (EmptyClipboard() && SetClipboardData(CF_UNICODETEXT, memory)) copied = true;
        CloseClipboard();
    }
    if (!copied) GlobalFree(memory);
    write(L"clipboard-status.txt", copied ? "Steam ID copied." : "Clipboard is busy. Try again.");
    return 0;
}
#pragma comment(lib, "user32.lib")
BOOL WINAPI DllMain(HINSTANCE instance, DWORD reason, LPVOID) {
    if (reason == DLL_PROCESS_ATTACH) { module = instance; DisableThreadLibraryCalls(instance); }
    return TRUE;
}

#ifdef BT_SELF_TEST
int main() {
    if (!address("steam.76561198000000000:7777") || !address("steam.76561200000000000:7777") ||
        address("steam.76561197960265728:7777") || address("steam.76561202255233024:7777") || address("steam.76561198000000000:7777?listen") ||
        address("127.0.0.1:7777") || address("steam.76561198000000000:7778")) return 1;
    wchar_t cwd[32768]; GetCurrentDirectoryW(32768, cwd); root = std::wstring(cwd) + L"\\";
    JoinRequest request{76561198000000000ULL, "steam.76561198000000000:7777"};
    callback.Run(&request);
    FILE* f = nullptr; _wfopen_s(&f, path(L"accepted.txt").c_str(), L"rb");
    if (!f) return 2;
    char result[128]{}; fread(result, 1, sizeof(result) - 1, f); fclose(f);
    if (!strstr(result, "\nsteam.76561198000000000:7777")) return 3;
    DeleteFileW(path(L"accepted.txt").c_str());
    LobbyChannel::host = 76561198000000000ULL;
    LobbyChannel::peer = 76561198000000001ULL;
    LobbyChannel::epoch = 42;
    const std::string packet = "BT020 76561198000000000 42 1\ngear";
    if (!LobbyChannel::ingest(LobbyChannel::peer, packet, LobbyChannel::host, 100)) return 4;
    if (LobbyChannel::ingest(76561198000000002ULL, packet, LobbyChannel::host, 100)) return 5;
    if (LobbyChannel::ingest(LobbyChannel::peer, "BT020 76561198000000000 41 1\ngear", LobbyChannel::host, 100)) return 6;
    if (LobbyChannel::ingest(LobbyChannel::peer, "BT020 76561198000000000 42 7\ngear", LobbyChannel::host, 100)) return 7;
    puts("PASS lobby metadata sender/session validation and stale-session rejection");
    static int sendMode = -1;
    static uint32_t sendBytes = 0;
    static bool permitSend = true;
    LobbyChannel::networking = []() -> void* { return reinterpret_cast<void*>(1); };
    LobbyChannel::send = [](void*, uint64_t, const void*, uint32_t size, int mode, int) -> bool {
        sendMode = mode; sendBytes = size; return permitSend;
    };
    LobbyChannel::PeerState state{};
    LobbyChannel::transmit(std::string(20000, 'x'), &state, 1000);
    if (sendMode != 2 || sendBytes != 20000 || LobbyChannel::sentCount != 1) return 9;
    LobbyChannel::transmit(std::string(20000, 'x'), &state, 1100);
    if (LobbyChannel::sentCount != 1) return 10;
    state.queuedBytes = 60000;
    LobbyChannel::transmit(std::string(20000, 'y'), &state, 1200);
    if (LobbyChannel::sentCount != 1 || LobbyChannel::pressureCount != 1) return 11;
    state.queuedBytes = 0;
    LobbyChannel::transmit(std::string(20000, 'y'), &state, 1300);
    if (LobbyChannel::sentCount != 2) return 12;
    LobbyChannel::transmit(std::string(20000, 'y'), &state, 2400);
    if (LobbyChannel::sentCount != 3) return 13;
    permitSend = false;
    LobbyChannel::transmit(std::string(20000, 'z'), &state, 2600);
    if (LobbyChannel::failedCount != 1 || LobbyChannel::sentCount != 3 || LobbyChannel::lastSent[0] != 'y') return 14;
    permitSend = true;
    LobbyChannel::transmit(std::string(20000, 'z'), &state, 2800);
    if (LobbyChannel::sentCount != 4 || LobbyChannel::lastSent[0] != 'z') return 15;
    puts("PASS large snapshots use reliable delivery, duplicate pacing, queue backpressure and recovery");
    const auto bundled = LoadLibraryW(L"../../../../Engine/Binaries/ThirdParty/Steamworks/Steamv161/Win64/steam_api64.dll");
    if (bundled) {
        for (const char* name : {"SteamAPI_SteamNetworking_v006", "SteamAPI_ISteamNetworking_SendP2PPacket",
            "SteamAPI_ISteamNetworking_IsP2PPacketAvailable", "SteamAPI_ISteamNetworking_ReadP2PPacket",
            "SteamAPI_ISteamNetworking_AcceptP2PSessionWithUser", "SteamAPI_ISteamNetworking_CloseP2PChannelWithUser",
            "SteamAPI_ISteamNetworking_GetP2PSessionState"}) {
            if (!GetProcAddress(bundled, name)) return 8;
        }
        FreeLibrary(bundled);
        puts("PASS bundled Steam API exports required by lobby metadata");
    }
    puts("PASS strict Steam address validation and accepted-invite callback handoff");
    return 0;
}
#endif
