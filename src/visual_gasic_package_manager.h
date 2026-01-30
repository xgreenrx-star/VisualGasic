#ifndef VISUAL_GASIC_PACKAGE_MANAGER_H
#define VISUAL_GASIC_PACKAGE_MANAGER_H

#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/templates/hash_map.hpp>
#include <godot_cpp/templates/hash_set.hpp>
#include <godot_cpp/templates/vector.hpp>

using namespace godot;

struct PackageInfo {
    String name;
    String version;
    String description;
    String author;
    Vector<String> dependencies;
    Vector<String> files;
};

class VisualGasicPackageManager {
public:
    VisualGasicPackageManager();
    ~VisualGasicPackageManager();

    void initialize();
    bool register_package(const PackageInfo &info);
    bool install_package(const String &name, const String &version = "");
    bool uninstall_package(const String &name);
    Vector<PackageInfo> list_installed_packages() const;
    bool is_package_installed(const String &name, const String &version = "") const;

private:
    HashMap<String, PackageInfo> registry;
    HashMap<String, PackageInfo> installed;
    bool initialized = false;

    String make_key(const String &name, const String &version) const;
    String resolve_version(const String &name, const String &version) const;
    bool install_internal(const String &name, const String &version, HashSet<String> &stack);
};

#endif
