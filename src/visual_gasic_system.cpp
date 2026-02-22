// ============================================================================
// VGSystem — Cross-platform system information queries
// ============================================================================
#include "visual_gasic_system.h"

#include <godot_cpp/variant/utility_functions.hpp>

#ifdef _WIN32
    #define WIN32_LEAN_AND_MEAN
    #include <windows.h>
    #include <lmcons.h>    // UNLEN
    #include <pdh.h>       // performance data (optional)
    #include <shlobj.h>
#else
    #include <unistd.h>
    #include <sys/utsname.h>
    #include <sys/sysinfo.h>
    #include <sys/statvfs.h>
    #include <pwd.h>
    #include <limits.h>
    #include <time.h>
    #ifdef __APPLE__
        #include <sys/sysctl.h>
        #include <mach/mach.h>
        #include <mach/mach_time.h>
    #endif
#endif

#include <cstdlib>
#include <cstring>
#include <ctime>

using namespace godot;

VGSystem::VGSystem() {}
VGSystem::~VGSystem() {}

// ─── Host Info ─────────────────────────────────────────────────────────────

String VGSystem::get_hostname() {
#ifdef _WIN32
    char buf[MAX_COMPUTERNAME_LENGTH + 1];
    DWORD size = sizeof(buf);
    if (GetComputerNameA(buf, &size)) return String(buf);
    return "unknown";
#else
    char buf[256];
    if (gethostname(buf, sizeof(buf)) == 0) return String(buf);
    return "unknown";
#endif
}

String VGSystem::get_username() {
#ifdef _WIN32
    char buf[UNLEN + 1];
    DWORD size = UNLEN + 1;
    if (GetUserNameA(buf, &size)) return String(buf);
    return "unknown";
#else
    struct passwd *pw = getpwuid(getuid());
    if (pw) return String(pw->pw_name);
    const char *user = getenv("USER");
    return user ? String(user) : String("unknown");
#endif
}

int VGSystem::get_process_id() {
#ifdef _WIN32
    return (int)GetCurrentProcessId();
#else
    return (int)getpid();
#endif
}

// ─── CPU ───────────────────────────────────────────────────────────────────

int VGSystem::get_cpu_count() {
#ifdef _WIN32
    SYSTEM_INFO si;
    GetSystemInfo(&si);
    return (int)si.dwNumberOfProcessors;
#elif defined(__APPLE__)
    int count = 0;
    size_t sz = sizeof(count);
    sysctlbyname("hw.logicalcpu", &count, &sz, nullptr, 0);
    return count > 0 ? count : 1;
#else
    long n = sysconf(_SC_NPROCESSORS_ONLN);
    return n > 0 ? (int)n : 1;
#endif
}

String VGSystem::get_cpu_name() {
#ifdef _WIN32
    HKEY hKey;
    if (RegOpenKeyExA(HKEY_LOCAL_MACHINE,
            "HARDWARE\\DESCRIPTION\\System\\CentralProcessor\\0",
            0, KEY_READ, &hKey) == ERROR_SUCCESS) {
        char buf[256];
        DWORD size = sizeof(buf);
        if (RegQueryValueExA(hKey, "ProcessorNameString", nullptr, nullptr,
                (LPBYTE)buf, &size) == ERROR_SUCCESS) {
            RegCloseKey(hKey);
            return String(buf);
        }
        RegCloseKey(hKey);
    }
    return "Unknown";
#elif defined(__APPLE__)
    char buf[256];
    size_t sz = sizeof(buf);
    if (sysctlbyname("machdep.cpu.brand_string", buf, &sz, nullptr, 0) == 0)
        return String(buf);
    return "Unknown";
#else
    // Parse /proc/cpuinfo
    FILE *f = fopen("/proc/cpuinfo", "r");
    if (!f) return "Unknown";
    char line[512];
    while (fgets(line, sizeof(line), f)) {
        if (strncmp(line, "model name", 10) == 0) {
            char *colon = strchr(line, ':');
            if (colon) {
                colon++;
                while (*colon == ' ' || *colon == '\t') colon++;
                // Trim trailing newline
                char *nl = strchr(colon, '\n');
                if (nl) *nl = '\0';
                String result(colon);
                fclose(f);
                return result;
            }
        }
    }
    fclose(f);
    return "Unknown";
#endif
}

String VGSystem::get_architecture() {
#ifdef _WIN32
    SYSTEM_INFO si;
    GetNativeSystemInfo(&si);
    switch (si.wProcessorArchitecture) {
        case PROCESSOR_ARCHITECTURE_AMD64: return "x86_64";
        case PROCESSOR_ARCHITECTURE_ARM:   return "arm";
        case PROCESSOR_ARCHITECTURE_ARM64: return "arm64";
        case PROCESSOR_ARCHITECTURE_INTEL: return "x86";
        default: return "unknown";
    }
#else
    struct utsname uts;
    if (uname(&uts) == 0) return String(uts.machine);
    return "unknown";
#endif
}

// ─── Memory ────────────────────────────────────────────────────────────────

int64_t VGSystem::get_total_memory() {
#ifdef _WIN32
    MEMORYSTATUSEX ms;
    ms.dwLength = sizeof(ms);
    if (GlobalMemoryStatusEx(&ms)) return (int64_t)ms.ullTotalPhys;
    return 0;
#elif defined(__APPLE__)
    int64_t mem = 0;
    size_t sz = sizeof(mem);
    sysctlbyname("hw.memsize", &mem, &sz, nullptr, 0);
    return mem;
#else
    struct sysinfo si;
    if (sysinfo(&si) == 0) return (int64_t)si.totalram * si.mem_unit;
    return 0;
#endif
}

int64_t VGSystem::get_free_memory() {
#ifdef _WIN32
    MEMORYSTATUSEX ms;
    ms.dwLength = sizeof(ms);
    if (GlobalMemoryStatusEx(&ms)) return (int64_t)ms.ullAvailPhys;
    return 0;
#elif defined(__APPLE__)
    mach_port_t host = mach_host_self();
    vm_size_t page_size;
    host_page_size(host, &page_size);
    vm_statistics64_data_t vm_stat;
    mach_msg_type_number_t count = HOST_VM_INFO64_COUNT;
    if (host_statistics64(host, HOST_VM_INFO64, (host_info64_t)&vm_stat, &count) == KERN_SUCCESS) {
        return (int64_t)(vm_stat.free_count + vm_stat.inactive_count) * page_size;
    }
    return 0;
#else
    struct sysinfo si;
    if (sysinfo(&si) == 0) return (int64_t)si.freeram * si.mem_unit;
    return 0;
#endif
}

int64_t VGSystem::get_used_memory() {
    int64_t total = get_total_memory();
    int64_t free_mem = get_free_memory();
    return total - free_mem;
}

double VGSystem::get_memory_usage_percent() {
    int64_t total = get_total_memory();
    if (total <= 0) return 0.0;
    int64_t used = get_used_memory();
    return (double)used / (double)total * 100.0;
}

// ─── Disk ──────────────────────────────────────────────────────────────────

int64_t VGSystem::get_free_disk_space(const String &p_path) {
    CharString path_utf8 = p_path.utf8();
#ifdef _WIN32
    ULARGE_INTEGER free_bytes;
    if (GetDiskFreeSpaceExA(path_utf8.get_data(), &free_bytes, nullptr, nullptr))
        return (int64_t)free_bytes.QuadPart;
    return -1;
#else
    struct statvfs st;
    if (statvfs(path_utf8.get_data(), &st) == 0)
        return (int64_t)st.f_bavail * st.f_frsize;
    return -1;
#endif
}

int64_t VGSystem::get_total_disk_space(const String &p_path) {
    CharString path_utf8 = p_path.utf8();
#ifdef _WIN32
    ULARGE_INTEGER total_bytes;
    if (GetDiskFreeSpaceExA(path_utf8.get_data(), nullptr, &total_bytes, nullptr))
        return (int64_t)total_bytes.QuadPart;
    return -1;
#else
    struct statvfs st;
    if (statvfs(path_utf8.get_data(), &st) == 0)
        return (int64_t)st.f_blocks * st.f_frsize;
    return -1;
#endif
}

double VGSystem::get_disk_usage_percent(const String &p_path) {
    int64_t total = get_total_disk_space(p_path);
    if (total <= 0) return 0.0;
    int64_t free_space = get_free_disk_space(p_path);
    if (free_space < 0) return 0.0;
    return (double)(total - free_space) / (double)total * 100.0;
}

// ─── OS ────────────────────────────────────────────────────────────────────

String VGSystem::get_os_name() {
#ifdef _WIN32
    return "Windows";
#elif defined(__APPLE__)
    return "macOS";
#elif defined(__ANDROID__)
    return "Android";
#else
    return "Linux";
#endif
}

String VGSystem::get_os_version() {
#ifdef _WIN32
    OSVERSIONINFOA osvi;
    ZeroMemory(&osvi, sizeof(osvi));
    osvi.dwOSVersionInfoSize = sizeof(osvi);
    // GetVersionExA is deprecated but works for display
    #pragma warning(suppress: 4996)
    GetVersionExA(&osvi);
    return String::num(osvi.dwMajorVersion) + "." + String::num(osvi.dwMinorVersion) +
           "." + String::num(osvi.dwBuildNumber);
#elif defined(__APPLE__)
    char buf[64];
    size_t sz = sizeof(buf);
    if (sysctlbyname("kern.osproductversion", buf, &sz, nullptr, 0) == 0)
        return String(buf);
    return "unknown";
#else
    struct utsname uts;
    if (uname(&uts) == 0) return String(uts.release);
    return "unknown";
#endif
}

String VGSystem::get_os_full() {
    return get_os_name() + " " + get_os_version() + " (" + get_architecture() + ")";
}

String VGSystem::get_endianness() {
    union { uint32_t i; char c[4]; } test = { 0x01020304 };
    return test.c[0] == 1 ? "big" : "little";
}

double VGSystem::get_uptime() {
#ifdef _WIN32
    return (double)GetTickCount64() / 1000.0;
#elif defined(__APPLE__)
    struct timeval boottime;
    size_t sz = sizeof(boottime);
    if (sysctlbyname("kern.boottime", &boottime, &sz, nullptr, 0) == 0) {
        struct timeval now;
        gettimeofday(&now, nullptr);
        return (double)(now.tv_sec - boottime.tv_sec);
    }
    return 0.0;
#else
    struct sysinfo si;
    if (sysinfo(&si) == 0) return (double)si.uptime;
    return 0.0;
#endif
}

// ─── Environment ───────────────────────────────────────────────────────────

String VGSystem::get_env(const String &p_name) {
    CharString name_utf8 = p_name.utf8();
    const char *val = getenv(name_utf8.get_data());
    return val ? String(val) : String();
}

void VGSystem::set_env(const String &p_name, const String &p_value) {
    CharString name_utf8 = p_name.utf8();
    CharString value_utf8 = p_value.utf8();
#ifdef _WIN32
    SetEnvironmentVariableA(name_utf8.get_data(), value_utf8.get_data());
#else
    setenv(name_utf8.get_data(), value_utf8.get_data(), 1);
#endif
}

bool VGSystem::has_env(const String &p_name) {
    CharString name_utf8 = p_name.utf8();
    return getenv(name_utf8.get_data()) != nullptr;
}

Dictionary VGSystem::get_all_env() {
    Dictionary result;
#ifdef _WIN32
    char *env_block = GetEnvironmentStringsA();
    if (env_block) {
        const char *p = env_block;
        while (*p) {
            String entry(p);
            int eq = entry.find("=");
            if (eq > 0) {
                result[entry.left(eq)] = entry.substr(eq + 1);
            }
            p += strlen(p) + 1;
        }
        FreeEnvironmentStringsA(env_block);
    }
#else
    extern char **environ;
    for (char **ep = environ; *ep; ep++) {
        String entry(*ep);
        int eq = entry.find("=");
        if (eq > 0) {
            result[entry.left(eq)] = entry.substr(eq + 1);
        }
    }
#endif
    return result;
}

// ─── Locale ────────────────────────────────────────────────────────────────

String VGSystem::get_locale() {
    const char *lc = setlocale(LC_ALL, nullptr);
    if (lc) return String(lc);
    const char *lang = getenv("LANG");
    return lang ? String(lang) : String("C");
}

String VGSystem::get_language() {
    const char *lang = getenv("LANGUAGE");
    if (!lang) lang = getenv("LANG");
    if (!lang) lang = getenv("LC_ALL");
    if (lang) {
        // Extract language code: "en_US.UTF-8" → "en"
        String s(lang);
        int us = s.find("_");
        if (us > 0) return s.left(us);
        int dot = s.find(".");
        if (dot > 0) return s.left(dot);
        return s;
    }
    return "en";
}

String VGSystem::get_timezone() {
#ifdef _WIN32
    TIME_ZONE_INFORMATION tzi;
    if (GetTimeZoneInformation(&tzi) != TIME_ZONE_ID_INVALID) {
        // Convert wide char timezone name
        char buf[64];
        WideCharToMultiByte(CP_UTF8, 0, tzi.StandardName, -1, buf, 64, nullptr, nullptr);
        return String(buf);
    }
#else
    time_t t = time(nullptr);
    struct tm *lt = localtime(&t);
    if (lt && lt->tm_zone) return String(lt->tm_zone);
#endif
    return "UTC";
}

int VGSystem::get_timezone_offset() {
    time_t t = time(nullptr);
    struct tm *lt = localtime(&t);
    if (lt) {
#ifdef _WIN32
        TIME_ZONE_INFORMATION tzi;
        GetTimeZoneInformation(&tzi);
        return -(int)tzi.Bias;  // Bias is in minutes, negative for east
#else
        return (int)(lt->tm_gmtoff / 60);  // seconds → minutes
#endif
    }
    return 0;
}

// ─── Aggregate ─────────────────────────────────────────────────────────────

Dictionary VGSystem::get_system_info() {
    Dictionary info;
    info["hostname"] = get_hostname();
    info["username"] = get_username();
    info["pid"] = get_process_id();
    info["cpu_count"] = get_cpu_count();
    info["cpu_name"] = get_cpu_name();
    info["architecture"] = get_architecture();
    info["total_memory"] = get_total_memory();
    info["free_memory"] = get_free_memory();
    info["memory_usage_percent"] = get_memory_usage_percent();
    info["os_name"] = get_os_name();
    info["os_version"] = get_os_version();
    info["os_full"] = get_os_full();
    info["endianness"] = get_endianness();
    info["uptime"] = get_uptime();
    info["locale"] = get_locale();
    info["language"] = get_language();
    info["timezone"] = get_timezone();
    info["timezone_offset"] = get_timezone_offset();
    return info;
}

// ─── Godot Bindings ────────────────────────────────────────────────────────

void VGSystem::_bind_methods() {
    // Host
    ClassDB::bind_static_method("VGSystem", D_METHOD("Hostname"), &VGSystem::get_hostname);
    ClassDB::bind_static_method("VGSystem", D_METHOD("Username"), &VGSystem::get_username);
    ClassDB::bind_static_method("VGSystem", D_METHOD("ProcessId"), &VGSystem::get_process_id);

    // CPU
    ClassDB::bind_static_method("VGSystem", D_METHOD("CpuCount"), &VGSystem::get_cpu_count);
    ClassDB::bind_static_method("VGSystem", D_METHOD("CpuName"), &VGSystem::get_cpu_name);
    ClassDB::bind_static_method("VGSystem", D_METHOD("Architecture"), &VGSystem::get_architecture);

    // Memory
    ClassDB::bind_static_method("VGSystem", D_METHOD("TotalMemory"), &VGSystem::get_total_memory);
    ClassDB::bind_static_method("VGSystem", D_METHOD("FreeMemory"), &VGSystem::get_free_memory);
    ClassDB::bind_static_method("VGSystem", D_METHOD("UsedMemory"), &VGSystem::get_used_memory);
    ClassDB::bind_static_method("VGSystem", D_METHOD("MemoryUsagePercent"), &VGSystem::get_memory_usage_percent);

    // Disk
    ClassDB::bind_static_method("VGSystem", D_METHOD("FreeDiskSpace", "path"), &VGSystem::get_free_disk_space);
    ClassDB::bind_static_method("VGSystem", D_METHOD("TotalDiskSpace", "path"), &VGSystem::get_total_disk_space);
    ClassDB::bind_static_method("VGSystem", D_METHOD("DiskUsagePercent", "path"), &VGSystem::get_disk_usage_percent);

    // OS
    ClassDB::bind_static_method("VGSystem", D_METHOD("OsName"), &VGSystem::get_os_name);
    ClassDB::bind_static_method("VGSystem", D_METHOD("OsVersion"), &VGSystem::get_os_version);
    ClassDB::bind_static_method("VGSystem", D_METHOD("OsFull"), &VGSystem::get_os_full);
    ClassDB::bind_static_method("VGSystem", D_METHOD("Endianness"), &VGSystem::get_endianness);
    ClassDB::bind_static_method("VGSystem", D_METHOD("Uptime"), &VGSystem::get_uptime);

    // Environment
    ClassDB::bind_static_method("VGSystem", D_METHOD("GetEnv", "name"), &VGSystem::get_env);
    ClassDB::bind_static_method("VGSystem", D_METHOD("SetEnv", "name", "value"), &VGSystem::set_env);
    ClassDB::bind_static_method("VGSystem", D_METHOD("HasEnv", "name"), &VGSystem::has_env);
    ClassDB::bind_static_method("VGSystem", D_METHOD("GetAllEnv"), &VGSystem::get_all_env);

    // Locale
    ClassDB::bind_static_method("VGSystem", D_METHOD("GetLocale"), &VGSystem::get_locale);
    ClassDB::bind_static_method("VGSystem", D_METHOD("GetLanguage"), &VGSystem::get_language);
    ClassDB::bind_static_method("VGSystem", D_METHOD("GetTimezone"), &VGSystem::get_timezone);
    ClassDB::bind_static_method("VGSystem", D_METHOD("GetTimezoneOffset"), &VGSystem::get_timezone_offset);

    // Aggregate
    ClassDB::bind_static_method("VGSystem", D_METHOD("GetSystemInfo"), &VGSystem::get_system_info);
}
