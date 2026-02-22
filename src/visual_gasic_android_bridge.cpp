// ============================================================================
// VGAndroidBridge — JNI bridge for Android platform APIs
// On non-Android platforms all methods return safe defaults / no-ops.
// ============================================================================
#include "visual_gasic_android_bridge.h"

#include <godot_cpp/variant/utility_functions.hpp>

#if defined(__ANDROID__) || defined(ANDROID_ENABLED)
    #include <jni.h>
    #include <android/log.h>
    #include <sys/system_properties.h>

    // Forward-declare the JNI env helper — Godot provides this in its Android
    // runtime; for GDExtension we obtain it via the OS singleton.
    static JavaVM *g_jvm = nullptr;

    static JNIEnv *get_jni_env() {
        JNIEnv *env = nullptr;
        if (g_jvm) {
            int status = g_jvm->GetEnv((void **)&env, JNI_VERSION_1_6);
            if (status == JNI_EDETACHED) {
                g_jvm->AttachCurrentThread(&env, nullptr);
            }
        }
        return env;
    }

    // Called by Godot's loader — stash the VM pointer
    extern "C" JNIEXPORT jint JNI_OnLoad(JavaVM *vm, void * /*reserved*/) {
        g_jvm = vm;
        return JNI_VERSION_1_6;
    }

    // Helper: get an Android system property
    static String android_prop(const char *key) {
        char buf[PROP_VALUE_MAX];
        int len = __system_property_get(key, buf);
        if (len > 0) return String(buf);
        return "";
    }
#endif

using namespace godot;

VGAndroidBridge::VGAndroidBridge() {}
VGAndroidBridge::~VGAndroidBridge() {}

// ─── Device Info ───────────────────────────────────────────────────────────

int VGAndroidBridge::get_sdk_version() {
#if defined(__ANDROID__)
    return atoi(android_prop("ro.build.version.sdk").utf8().get_data());
#else
    return 0;
#endif
}

String VGAndroidBridge::get_device_model() {
#if defined(__ANDROID__)
    return android_prop("ro.product.model");
#else
    return "Not Android";
#endif
}

String VGAndroidBridge::get_device_manufacturer() {
#if defined(__ANDROID__)
    return android_prop("ro.product.manufacturer");
#else
    return "Not Android";
#endif
}

String VGAndroidBridge::get_android_version() {
#if defined(__ANDROID__)
    return android_prop("ro.build.version.release");
#else
    return "";
#endif
}

String VGAndroidBridge::get_package_name() {
#if defined(__ANDROID__)
    // Use Godot's OS singleton to fetch package name
    // Fallback: use JNI to call getPackageName()
    JNIEnv *env = get_jni_env();
    if (!env) return "";
    // Get current activity class
    jclass activity_thread = env->FindClass("android/app/ActivityThread");
    if (!activity_thread) return "";
    jmethodID current_at = env->GetStaticMethodID(activity_thread, "currentActivityThread",
                                                   "()Landroid/app/ActivityThread;");
    jobject at = env->CallStaticObjectMethod(activity_thread, current_at);
    jmethodID get_app = env->GetMethodID(activity_thread, "getApplication",
                                          "()Landroid/app/Application;");
    jobject app = env->CallObjectMethod(at, get_app);
    if (!app) return "";
    jclass context_class = env->FindClass("android/content/Context");
    jmethodID get_pkg = env->GetMethodID(context_class, "getPackageName", "()Ljava/lang/String;");
    jstring pkg = (jstring)env->CallObjectMethod(app, get_pkg);
    const char *pkg_str = env->GetStringUTFChars(pkg, nullptr);
    String result(pkg_str);
    env->ReleaseStringUTFChars(pkg, pkg_str);
    return result;
#else
    return "";
#endif
}

String VGAndroidBridge::get_app_version() {
#if defined(__ANDROID__)
    return android_prop("ro.build.display.id");
#else
    return "";
#endif
}

String VGAndroidBridge::get_device_id() {
#if defined(__ANDROID__)
    return android_prop("ro.serialno");
#else
    return "";
#endif
}

// ─── Permissions ───────────────────────────────────────────────────────────

bool VGAndroidBridge::has_permission(const String &p_permission) {
#if defined(__ANDROID__)
    JNIEnv *env = get_jni_env();
    if (!env) return false;
    // ContextCompat.checkSelfPermission
    jclass activity_thread = env->FindClass("android/app/ActivityThread");
    if (!activity_thread) return false;
    jmethodID current_at = env->GetStaticMethodID(activity_thread, "currentActivityThread",
                                                   "()Landroid/app/ActivityThread;");
    jobject at = env->CallStaticObjectMethod(activity_thread, current_at);
    jmethodID get_app = env->GetMethodID(activity_thread, "getApplication",
                                          "()Landroid/app/Application;");
    jobject ctx = env->CallObjectMethod(at, get_app);
    if (!ctx) return false;

    jclass compat = env->FindClass("androidx/core/content/ContextCompat");
    if (!compat) {
        // Fallback without AndroidX
        jclass context_class = env->FindClass("android/content/Context");
        jmethodID check = env->GetMethodID(context_class, "checkSelfPermission",
                                            "(Ljava/lang/String;)I");
        CharString perm_utf8 = p_permission.utf8();
        jstring perm = env->NewStringUTF(perm_utf8.get_data());
        jint result = env->CallIntMethod(ctx, check, perm);
        env->DeleteLocalRef(perm);
        return result == 0; // PERMISSION_GRANTED
    }
    jmethodID check = env->GetStaticMethodID(compat, "checkSelfPermission",
                                              "(Landroid/content/Context;Ljava/lang/String;)I");
    CharString perm_utf8 = p_permission.utf8();
    jstring perm = env->NewStringUTF(perm_utf8.get_data());
    jint res = env->CallStaticIntMethod(compat, check, ctx, perm);
    env->DeleteLocalRef(perm);
    return res == 0;
#else
    (void)p_permission;
    return true; // Non-Android always has "permission"
#endif
}

void VGAndroidBridge::request_permission(const String &p_permission) {
    Array arr;
    arr.push_back(p_permission);
    request_permissions(arr);
}

void VGAndroidBridge::request_permissions(const Array &p_permissions) {
#if defined(__ANDROID__)
    // Godot 4 handles permission requests through its OS singleton;
    // we'll use that for reliability.
    // Engine::get_singleton()->get_main_loop() would give SceneTree
    // For now, log and let the Godot runtime's permission system handle it.
    for (int i = 0; i < p_permissions.size(); i++) {
        __android_log_print(ANDROID_LOG_INFO, "VGAndroid",
            "Request permission: %s", String(p_permissions[i]).utf8().get_data());
    }
#else
    (void)p_permissions;
#endif
}

Array VGAndroidBridge::get_granted_permissions() {
    Array result;
#if defined(__ANDROID__)
    // Would enumerate runtime permissions — stub for now
#endif
    return result;
}

// ─── Intents ───────────────────────────────────────────────────────────────

void VGAndroidBridge::open_url(const String &p_url) {
#if defined(__ANDROID__)
    JNIEnv *env = get_jni_env();
    if (!env) return;
    jclass intent_class = env->FindClass("android/content/Intent");
    jfieldID action_view = env->GetStaticFieldID(intent_class, "ACTION_VIEW", "Ljava/lang/String;");
    jstring action = (jstring)env->GetStaticObjectField(intent_class, action_view);

    jclass uri_class = env->FindClass("android/net/Uri");
    jmethodID parse = env->GetStaticMethodID(uri_class, "parse", "(Ljava/lang/String;)Landroid/net/Uri;");
    CharString url_utf8 = p_url.utf8();
    jstring url_str = env->NewStringUTF(url_utf8.get_data());
    jobject uri = env->CallStaticObjectMethod(uri_class, parse, url_str);

    jmethodID intent_init = env->GetMethodID(intent_class, "<init>",
        "(Ljava/lang/String;Landroid/net/Uri;)V");
    jobject intent = env->NewObject(intent_class, intent_init, action, uri);

    // Get context and start activity
    jclass at_class = env->FindClass("android/app/ActivityThread");
    jmethodID cur_at = env->GetStaticMethodID(at_class, "currentActivityThread", "()Landroid/app/ActivityThread;");
    jobject at = env->CallStaticObjectMethod(at_class, cur_at);
    jmethodID get_app = env->GetMethodID(at_class, "getApplication", "()Landroid/app/Application;");
    jobject ctx = env->CallObjectMethod(at, get_app);

    jclass ctx_class = env->FindClass("android/content/Context");
    jmethodID start_activity = env->GetMethodID(ctx_class, "startActivity", "(Landroid/content/Intent;)V");

    // Add FLAG_ACTIVITY_NEW_TASK
    jmethodID add_flags = env->GetMethodID(intent_class, "addFlags", "(I)Landroid/content/Intent;");
    env->CallObjectMethod(intent, add_flags, 0x10000000); // FLAG_ACTIVITY_NEW_TASK

    env->CallVoidMethod(ctx, start_activity, intent);

    env->DeleteLocalRef(url_str);
#else
    (void)p_url;
#endif
}

void VGAndroidBridge::share_text(const String &p_text, const String &p_title) {
#if defined(__ANDROID__)
    JNIEnv *env = get_jni_env();
    if (!env) return;

    jclass intent_class = env->FindClass("android/content/Intent");
    jmethodID init = env->GetMethodID(intent_class, "<init>", "()V");
    jobject intent = env->NewObject(intent_class, init);

    jmethodID set_action = env->GetMethodID(intent_class, "setAction", "(Ljava/lang/String;)Landroid/content/Intent;");
    jstring action = env->NewStringUTF("android.intent.action.SEND");
    env->CallObjectMethod(intent, set_action, action);

    jmethodID put_extra = env->GetMethodID(intent_class, "putExtra",
        "(Ljava/lang/String;Ljava/lang/String;)Landroid/content/Intent;");
    jstring extra_text = env->NewStringUTF("android.intent.extra.TEXT");
    CharString text_utf8 = p_text.utf8();
    jstring text = env->NewStringUTF(text_utf8.get_data());
    env->CallObjectMethod(intent, put_extra, extra_text, text);

    jmethodID set_type = env->GetMethodID(intent_class, "setType", "(Ljava/lang/String;)Landroid/content/Intent;");
    jstring mime = env->NewStringUTF("text/plain");
    env->CallObjectMethod(intent, set_type, mime);

    // createChooser
    CharString title_utf8 = p_title.is_empty() ? CharString("Share") : p_title.utf8();
    jstring chooser_title = env->NewStringUTF(title_utf8.get_data());
    jmethodID create_chooser = env->GetStaticMethodID(intent_class, "createChooser",
        "(Landroid/content/Intent;Ljava/lang/CharSequence;)Landroid/content/Intent;");
    jobject chooser = env->CallStaticObjectMethod(intent_class, create_chooser, intent, chooser_title);

    // Start
    jmethodID add_flags = env->GetMethodID(intent_class, "addFlags", "(I)Landroid/content/Intent;");
    env->CallObjectMethod(chooser, add_flags, 0x10000000);

    jclass at_class = env->FindClass("android/app/ActivityThread");
    jmethodID cur_at = env->GetStaticMethodID(at_class, "currentActivityThread", "()Landroid/app/ActivityThread;");
    jobject at = env->CallStaticObjectMethod(at_class, cur_at);
    jmethodID get_app = env->GetMethodID(at_class, "getApplication", "()Landroid/app/Application;");
    jobject ctx = env->CallObjectMethod(at, get_app);
    jclass ctx_class = env->FindClass("android/content/Context");
    jmethodID start_activity = env->GetMethodID(ctx_class, "startActivity", "(Landroid/content/Intent;)V");
    env->CallVoidMethod(ctx, start_activity, chooser);

    env->DeleteLocalRef(action);
    env->DeleteLocalRef(extra_text);
    env->DeleteLocalRef(text);
    env->DeleteLocalRef(mime);
    env->DeleteLocalRef(chooser_title);
#else
    (void)p_text;
    (void)p_title;
#endif
}

void VGAndroidBridge::send_email(const String &p_to, const String &p_subject, const String &p_body) {
    String mailto = "mailto:" + p_to + "?subject=" + p_subject.uri_encode() + "&body=" + p_body.uri_encode();
    open_url(mailto);
}

void VGAndroidBridge::open_app_settings() {
#if defined(__ANDROID__)
    // Open app's settings page
    String pkg = get_package_name();
    open_url("package:" + pkg);
#endif
}

// ─── UI Feedback ───────────────────────────────────────────────────────────

void VGAndroidBridge::show_toast(const String &p_message, int p_duration) {
#if defined(__ANDROID__)
    JNIEnv *env = get_jni_env();
    if (!env) return;

    jclass at_class = env->FindClass("android/app/ActivityThread");
    jmethodID cur_at = env->GetStaticMethodID(at_class, "currentActivityThread", "()Landroid/app/ActivityThread;");
    jobject at = env->CallStaticObjectMethod(at_class, cur_at);
    jmethodID get_app = env->GetMethodID(at_class, "getApplication", "()Landroid/app/Application;");
    jobject ctx = env->CallObjectMethod(at, get_app);

    jclass toast_class = env->FindClass("android/widget/Toast");
    jmethodID make_text = env->GetStaticMethodID(toast_class, "makeText",
        "(Landroid/content/Context;Ljava/lang/CharSequence;I)Landroid/widget/Toast;");
    CharString msg_utf8 = p_message.utf8();
    jstring msg = env->NewStringUTF(msg_utf8.get_data());
    jobject toast = env->CallStaticObjectMethod(toast_class, make_text, ctx, msg, (jint)p_duration);
    jmethodID show = env->GetMethodID(toast_class, "show", "()V");
    env->CallVoidMethod(toast, show);
    env->DeleteLocalRef(msg);
#else
    UtilityFunctions::print("[Toast] ", p_message);
    (void)p_duration;
#endif
}

void VGAndroidBridge::vibrate(int p_ms) {
#if defined(__ANDROID__)
    JNIEnv *env = get_jni_env();
    if (!env) return;

    jclass at_class = env->FindClass("android/app/ActivityThread");
    jmethodID cur_at = env->GetStaticMethodID(at_class, "currentActivityThread", "()Landroid/app/ActivityThread;");
    jobject at = env->CallStaticObjectMethod(at_class, cur_at);
    jmethodID get_app = env->GetMethodID(at_class, "getApplication", "()Landroid/app/Application;");
    jobject ctx = env->CallObjectMethod(at, get_app);

    jclass ctx_class = env->FindClass("android/content/Context");
    jmethodID get_service = env->GetMethodID(ctx_class, "getSystemService",
        "(Ljava/lang/String;)Ljava/lang/Object;");
    jstring vibrator_str = env->NewStringUTF("vibrator");
    jobject vibrator = env->CallObjectMethod(ctx, get_service, vibrator_str);

    jclass vibrator_class = env->FindClass("android/os/Vibrator");
    jmethodID vibrate_method = env->GetMethodID(vibrator_class, "vibrate", "(J)V");
    env->CallVoidMethod(vibrator, vibrate_method, (jlong)p_ms);
    env->DeleteLocalRef(vibrator_str);
#else
    (void)p_ms;
#endif
}

// ─── Storage ───────────────────────────────────────────────────────────────

String VGAndroidBridge::get_external_storage_path() {
#if defined(__ANDROID__)
    return android_prop("EXTERNAL_STORAGE");
#else
    return "";
#endif
}

String VGAndroidBridge::get_cache_dir() {
#if defined(__ANDROID__)
    JNIEnv *env = get_jni_env();
    if (!env) return "";
    jclass at_class = env->FindClass("android/app/ActivityThread");
    jmethodID cur_at = env->GetStaticMethodID(at_class, "currentActivityThread", "()Landroid/app/ActivityThread;");
    jobject at = env->CallStaticObjectMethod(at_class, cur_at);
    jmethodID get_app = env->GetMethodID(at_class, "getApplication", "()Landroid/app/Application;");
    jobject ctx = env->CallObjectMethod(at, get_app);
    if (!ctx) return "";

    jclass ctx_class = env->FindClass("android/content/Context");
    jmethodID get_cache = env->GetMethodID(ctx_class, "getCacheDir", "()Ljava/io/File;");
    jobject cache_file = env->CallObjectMethod(ctx, get_cache);
    jclass file_class = env->FindClass("java/io/File");
    jmethodID get_path = env->GetMethodID(file_class, "getAbsolutePath", "()Ljava/lang/String;");
    jstring path = (jstring)env->CallObjectMethod(cache_file, get_path);
    const char *path_str = env->GetStringUTFChars(path, nullptr);
    String result(path_str);
    env->ReleaseStringUTFChars(path, path_str);
    return result;
#else
    return "";
#endif
}

String VGAndroidBridge::get_files_dir() {
#if defined(__ANDROID__)
    JNIEnv *env = get_jni_env();
    if (!env) return "";
    jclass at_class = env->FindClass("android/app/ActivityThread");
    jmethodID cur_at = env->GetStaticMethodID(at_class, "currentActivityThread", "()Landroid/app/ActivityThread;");
    jobject at = env->CallStaticObjectMethod(at_class, cur_at);
    jmethodID get_app = env->GetMethodID(at_class, "getApplication", "()Landroid/app/Application;");
    jobject ctx = env->CallObjectMethod(at, get_app);
    if (!ctx) return "";

    jclass ctx_class = env->FindClass("android/content/Context");
    jmethodID get_files = env->GetMethodID(ctx_class, "getFilesDir", "()Ljava/io/File;");
    jobject files_obj = env->CallObjectMethod(ctx, get_files);
    jclass file_class = env->FindClass("java/io/File");
    jmethodID get_path = env->GetMethodID(file_class, "getAbsolutePath", "()Ljava/lang/String;");
    jstring path = (jstring)env->CallObjectMethod(files_obj, get_path);
    const char *path_str = env->GetStringUTFChars(path, nullptr);
    String result(path_str);
    env->ReleaseStringUTFChars(path, path_str);
    return result;
#else
    return "";
#endif
}

// ─── Sensors ───────────────────────────────────────────────────────────────

Dictionary VGAndroidBridge::get_battery_info() {
    Dictionary info;
#if defined(__ANDROID__)
    // Read from /sys/class/power_supply/battery/
    FILE *f = fopen("/sys/class/power_supply/battery/capacity", "r");
    if (f) {
        int level = 0;
        if (fscanf(f, "%d", &level) == 1) info["level"] = level;
        fclose(f);
    }
    f = fopen("/sys/class/power_supply/battery/status", "r");
    if (f) {
        char buf[32];
        if (fgets(buf, sizeof(buf), f)) {
            char *nl = strchr(buf, '\n');
            if (nl) *nl = '\0';
            info["status"] = String(buf);
            info["charging"] = String(buf) == "Charging";
        }
        fclose(f);
    }
#else
    info["level"] = 100;
    info["status"] = "Not Android";
    info["charging"] = false;
#endif
    return info;
}

// ─── System ────────────────────────────────────────────────────────────────

bool VGAndroidBridge::is_android() {
#if defined(__ANDROID__)
    return true;
#else
    return false;
#endif
}

void VGAndroidBridge::keep_screen_on(bool p_enabled) {
#if defined(__ANDROID__)
    // Would use WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
    __android_log_print(ANDROID_LOG_INFO, "VGAndroid", "KeepScreenOn: %s",
                        p_enabled ? "true" : "false");
#else
    (void)p_enabled;
#endif
}

// ─── Godot Bindings ────────────────────────────────────────────────────────

void VGAndroidBridge::_bind_methods() {
    // Device Info
    ClassDB::bind_static_method("VGAndroidBridge", D_METHOD("SdkVersion"),         &VGAndroidBridge::get_sdk_version);
    ClassDB::bind_static_method("VGAndroidBridge", D_METHOD("DeviceModel"),        &VGAndroidBridge::get_device_model);
    ClassDB::bind_static_method("VGAndroidBridge", D_METHOD("DeviceManufacturer"), &VGAndroidBridge::get_device_manufacturer);
    ClassDB::bind_static_method("VGAndroidBridge", D_METHOD("AndroidVersion"),     &VGAndroidBridge::get_android_version);
    ClassDB::bind_static_method("VGAndroidBridge", D_METHOD("PackageName"),        &VGAndroidBridge::get_package_name);
    ClassDB::bind_static_method("VGAndroidBridge", D_METHOD("AppVersion"),         &VGAndroidBridge::get_app_version);
    ClassDB::bind_static_method("VGAndroidBridge", D_METHOD("DeviceId"),           &VGAndroidBridge::get_device_id);

    // Permissions
    ClassDB::bind_static_method("VGAndroidBridge", D_METHOD("HasPermission", "permission"),      &VGAndroidBridge::has_permission);
    ClassDB::bind_static_method("VGAndroidBridge", D_METHOD("RequestPermission", "permission"),   &VGAndroidBridge::request_permission);
    ClassDB::bind_static_method("VGAndroidBridge", D_METHOD("RequestPermissions", "permissions"), &VGAndroidBridge::request_permissions);
    ClassDB::bind_static_method("VGAndroidBridge", D_METHOD("GetGrantedPermissions"),             &VGAndroidBridge::get_granted_permissions);

    // Intents
    ClassDB::bind_static_method("VGAndroidBridge", D_METHOD("OpenUrl", "url"),                         &VGAndroidBridge::open_url);
    ClassDB::bind_static_method("VGAndroidBridge", D_METHOD("ShareText", "text", "title"),             &VGAndroidBridge::share_text);
    ClassDB::bind_static_method("VGAndroidBridge", D_METHOD("SendEmail", "to", "subject", "body"),     &VGAndroidBridge::send_email);
    ClassDB::bind_static_method("VGAndroidBridge", D_METHOD("OpenAppSettings"),                        &VGAndroidBridge::open_app_settings);

    // UI
    ClassDB::bind_static_method("VGAndroidBridge", D_METHOD("ShowToast", "message", "duration"), &VGAndroidBridge::show_toast);
    ClassDB::bind_static_method("VGAndroidBridge", D_METHOD("Vibrate", "ms"),                    &VGAndroidBridge::vibrate);

    // Storage
    ClassDB::bind_static_method("VGAndroidBridge", D_METHOD("ExternalStoragePath"), &VGAndroidBridge::get_external_storage_path);
    ClassDB::bind_static_method("VGAndroidBridge", D_METHOD("CacheDir"),            &VGAndroidBridge::get_cache_dir);
    ClassDB::bind_static_method("VGAndroidBridge", D_METHOD("FilesDir"),            &VGAndroidBridge::get_files_dir);

    // Sensors
    ClassDB::bind_static_method("VGAndroidBridge", D_METHOD("GetBatteryInfo"), &VGAndroidBridge::get_battery_info);

    // System
    ClassDB::bind_static_method("VGAndroidBridge", D_METHOD("IsAndroid"),            &VGAndroidBridge::is_android);
    ClassDB::bind_static_method("VGAndroidBridge", D_METHOD("KeepScreenOn", "enabled"), &VGAndroidBridge::keep_screen_on);
}
