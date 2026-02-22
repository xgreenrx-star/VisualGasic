#ifndef VISUAL_GASIC_ANDROID_BRIDGE_H
#define VISUAL_GASIC_ANDROID_BRIDGE_H

// VGAndroidBridge — JNI bridge for Android platform APIs
// Only compiled when building for Android (ANDROID_ENABLED / __ANDROID__).
//
// Usage in VisualGasic:
//   If VGSystem.OsName = "Android" Then
//       Dim android As New VGAndroidBridge
//       Print "SDK: " & CStr(android.SdkVersion)
//       Print "Package: " & android.PackageName
//       android.ShowToast "Hello from VG!", 1
//       android.Vibrate 300
//
//       ' Permissions
//       If Not android.HasPermission("android.permission.CAMERA") Then
//           android.RequestPermission "android.permission.CAMERA"
//       End If
//
//       ' Intents
//       android.OpenUrl "https://visualgasic.org"
//       android.ShareText "Check out VisualGasic!"
//   End If

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>

using namespace godot;

class VGAndroidBridge : public RefCounted {
    GDCLASS(VGAndroidBridge, RefCounted);

    String last_error;

protected:
    static void _bind_methods();

public:
    VGAndroidBridge();
    ~VGAndroidBridge();

    // --- Device Info ---
    static int get_sdk_version();
    static String get_device_model();
    static String get_device_manufacturer();
    static String get_android_version();
    static String get_package_name();
    static String get_app_version();
    static String get_device_id();

    // --- Permissions ---
    static bool has_permission(const String &p_permission);
    static void request_permission(const String &p_permission);
    static void request_permissions(const Array &p_permissions);
    static Array get_granted_permissions();

    // --- Intents ---
    static void open_url(const String &p_url);
    static void share_text(const String &p_text, const String &p_title = "");
    static void send_email(const String &p_to, const String &p_subject, const String &p_body);
    static void open_app_settings();

    // --- UI Feedback ---
    static void show_toast(const String &p_message, int p_duration = 0);
    static void vibrate(int p_ms = 200);

    // --- Storage ---
    static String get_external_storage_path();
    static String get_cache_dir();
    static String get_files_dir();

    // --- Sensors ---
    static Dictionary get_battery_info();  // level, status, charging

    // --- System ---
    static bool is_android();
    static void keep_screen_on(bool p_enabled);

    String get_last_error() const { return last_error; }
};

#endif // VISUAL_GASIC_ANDROID_BRIDGE_H
