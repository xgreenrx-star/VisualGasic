#include "visual_gasic_package_manager.h"

VisualGasicPackageManager::VisualGasicPackageManager() = default;
VisualGasicPackageManager::~VisualGasicPackageManager() = default;

void VisualGasicPackageManager::initialize() {
    initialized = true;
}

bool VisualGasicPackageManager::register_package(const PackageInfo &info) {
    if (info.name.is_empty() || info.version.is_empty()) {
        UtilityFunctions::print("Package registration failed: missing name or version");
        return false;
    }
    String key = make_key(info.name, info.version);
    registry[key] = info;
    return true;
}

bool VisualGasicPackageManager::install_package(const String &name, const String &version) {
    if (!initialized) {
        UtilityFunctions::print("Package manager not initialized; call initialize() first");
        return false;
    }
    HashSet<String> stack;
    return install_internal(name, version, stack);
}

bool VisualGasicPackageManager::install_internal(const String &name, const String &version, HashSet<String> &stack) {
    String resolved_version = resolve_version(name, version);
    String key = make_key(name, resolved_version);
    if (!registry.has(key)) {
        UtilityFunctions::print("Package not found: ", name, " ", resolved_version);
        return false;
    }

    if (stack.has(key)) {
        UtilityFunctions::print("Cyclic dependency detected while installing ", name);
        return false;
    }

    stack.insert(key);
    const PackageInfo &pkg = registry[key];

    for (int i = 0; i < pkg.dependencies.size(); i++) {
        String dep_spec = pkg.dependencies[i];
        String dep_name = dep_spec;
        String dep_version;
        int colon = dep_spec.find(":" );
        if (colon >= 0) {
            dep_name = dep_spec.substr(0, colon);
            dep_version = dep_spec.substr(colon + 1, dep_spec.length());
        }
        if (!install_internal(dep_name.strip_edges(), dep_version.strip_edges(), stack)) {
            stack.erase(key);
            return false;
        }
    }

    installed[pkg.name] = pkg;
    stack.erase(key);
    UtilityFunctions::print("Package installed: ", pkg.name, " ", pkg.version);
    return true;
}

bool VisualGasicPackageManager::uninstall_package(const String &name) {
    if (!installed.has(name)) {
        return false;
    }
    installed.erase(name);
    UtilityFunctions::print("Package uninstalled: ", name);
    return true;
}

Vector<PackageInfo> VisualGasicPackageManager::list_installed_packages() const {
    Vector<PackageInfo> result;
    for (const KeyValue<String, PackageInfo> &entry : installed) {
        result.push_back(entry.value);
    }
    return result;
}

bool VisualGasicPackageManager::is_package_installed(const String &name, const String &version) const {
    if (!installed.has(name)) {
        return false;
    }
    if (version.is_empty()) {
        return true;
    }
    return installed[name].version == version;
}

String VisualGasicPackageManager::make_key(const String &name, const String &version) const {
    return name.to_lower() + ":" + version.to_lower();
}

String VisualGasicPackageManager::resolve_version(const String &name, const String &version) const {
    if (!version.is_empty()) {
        return version;
    }
    String selected;
    for (const KeyValue<String, PackageInfo> &entry : registry) {
        if (entry.value.name == name) {
            if (selected.is_empty() || entry.value.version > selected) {
                selected = entry.value.version;
            }
        }
    }
    return selected;
}
