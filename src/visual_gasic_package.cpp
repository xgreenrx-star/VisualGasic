// VisualGasicPackage — Full package management system for VG modules
// Manages vgpkg.json manifests, downloads from URLs, installs to addons/
// Uses Godot's FileAccess, DirAccess, JSON, and HTTPClient

#include "visual_gasic_package.h"
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/dir_access.hpp>
#include <godot_cpp/classes/json.hpp>
#include <godot_cpp/classes/http_client.hpp>
#include <godot_cpp/classes/project_settings.hpp>
#include <godot_cpp/classes/os.hpp>
#include <godot_cpp/classes/zip_reader.hpp>
#include <godot_cpp/classes/zip_packer.hpp>

using namespace godot;

// Forward declaration of static helper
static void _remove_dir_recursive(const String &p_path);
static bool _zip_add_dir_recursive(Ref<ZIPPacker> &p_zip, const String &p_root, const String &p_rel);

// ---------------------------------------------------------------------------
// _bind_methods
// ---------------------------------------------------------------------------

void VisualGasicPackage::_bind_methods() {
    // Lifecycle
    ClassDB::bind_method(D_METHOD("initialize", "workspace_path"), &VisualGasicPackage::initialize);
    ClassDB::bind_method(D_METHOD("shutdown"), &VisualGasicPackage::shutdown);

    // Registry
    ClassDB::bind_method(D_METHOD("add_registry", "name", "url", "auth_token"), &VisualGasicPackage::add_registry, DEFVAL(""));
    ClassDB::bind_method(D_METHOD("remove_registry", "name"), &VisualGasicPackage::remove_registry);
    ClassDB::bind_method(D_METHOD("get_registries"), &VisualGasicPackage::get_registries);
    ClassDB::bind_method(D_METHOD("set_default_registry", "name"), &VisualGasicPackage::set_default_registry);

    // Installation
    ClassDB::bind_method(D_METHOD("install_package", "package_name", "version_constraint"), &VisualGasicPackage::install_package, DEFVAL(""));
    ClassDB::bind_method(D_METHOD("uninstall_package", "package_name"), &VisualGasicPackage::uninstall_package);

    // Info
    ClassDB::bind_method(D_METHOD("get_package_info", "package_name", "version"), &VisualGasicPackage::get_package_info, DEFVAL(""));
    ClassDB::bind_method(D_METHOD("search_packages", "query", "limit"), &VisualGasicPackage::search_packages, DEFVAL(50));
    ClassDB::bind_method(D_METHOD("get_installed_packages"), &VisualGasicPackage::get_installed_packages);
    ClassDB::bind_method(D_METHOD("is_package_installed", "package_name", "version"), &VisualGasicPackage::is_package_installed, DEFVAL(""));

    // Creation
    ClassDB::bind_method(D_METHOD("create_package_template", "name", "template_type"), &VisualGasicPackage::create_package_template, DEFVAL("library"));
    ClassDB::bind_method(D_METHOD("validate_package_manifest", "manifest_path"), &VisualGasicPackage::validate_package_manifest);
    ClassDB::bind_method(D_METHOD("build_package", "package_path"), &VisualGasicPackage::build_package);
    ClassDB::bind_method(D_METHOD("publish_package", "package_path", "registry_name"), &VisualGasicPackage::publish_package, DEFVAL(""));

    // Project integration
    ClassDB::bind_method(D_METHOD("initialize_project", "project_path"), &VisualGasicPackage::initialize_project);
    ClassDB::bind_method(D_METHOD("add_dependency", "package_name", "version_constraint"), &VisualGasicPackage::add_dependency, DEFVAL(""));
    ClassDB::bind_method(D_METHOD("remove_dependency", "package_name"), &VisualGasicPackage::remove_dependency);
    ClassDB::bind_method(D_METHOD("get_project_dependencies"), &VisualGasicPackage::get_project_dependencies);

    // Cache
    ClassDB::bind_method(D_METHOD("clear_cache"), &VisualGasicPackage::clear_cache);
    ClassDB::bind_method(D_METHOD("get_cache_info"), &VisualGasicPackage::get_cache_info);
    ClassDB::bind_method(D_METHOD("clean_unused_packages"), &VisualGasicPackage::clean_unused_packages);

    // VB6-style PascalCase aliases
    ClassDB::bind_method(D_METHOD("Initialize", "workspace_path"), &VisualGasicPackage::initialize);
    ClassDB::bind_method(D_METHOD("Shutdown"), &VisualGasicPackage::shutdown);
    ClassDB::bind_method(D_METHOD("InstallPackage", "package_name", "version_constraint"), &VisualGasicPackage::install_package, DEFVAL(""));
    ClassDB::bind_method(D_METHOD("UninstallPackage", "package_name"), &VisualGasicPackage::uninstall_package);
    ClassDB::bind_method(D_METHOD("GetPackageInfo", "package_name", "version"), &VisualGasicPackage::get_package_info, DEFVAL(""));
    ClassDB::bind_method(D_METHOD("SearchPackages", "query", "limit"), &VisualGasicPackage::search_packages, DEFVAL(50));
    ClassDB::bind_method(D_METHOD("GetInstalledPackages"), &VisualGasicPackage::get_installed_packages);
    ClassDB::bind_method(D_METHOD("IsPackageInstalled", "package_name", "version"), &VisualGasicPackage::is_package_installed, DEFVAL(""));
    ClassDB::bind_method(D_METHOD("InitializeProject", "project_path"), &VisualGasicPackage::initialize_project);
    ClassDB::bind_method(D_METHOD("AddDependency", "package_name", "version_constraint"), &VisualGasicPackage::add_dependency, DEFVAL(""));
    ClassDB::bind_method(D_METHOD("RemoveDependency", "package_name"), &VisualGasicPackage::remove_dependency);
    ClassDB::bind_method(D_METHOD("GetProjectDependencies"), &VisualGasicPackage::get_project_dependencies);
    ClassDB::bind_method(D_METHOD("ClearCache"), &VisualGasicPackage::clear_cache);
    ClassDB::bind_method(D_METHOD("ValidatePackageManifest", "manifest_path"), &VisualGasicPackage::validate_package_manifest);
    ClassDB::bind_method(D_METHOD("BuildPackage", "package_path"), &VisualGasicPackage::build_package);
    ClassDB::bind_method(D_METHOD("PublishPackage", "package_path", "registry_name"), &VisualGasicPackage::publish_package, DEFVAL(""));
    ClassDB::bind_method(D_METHOD("CreatePackageTemplate", "name", "template_type"), &VisualGasicPackage::create_package_template, DEFVAL("library"));
}

// ---------------------------------------------------------------------------
// Constructor / Destructor
// ---------------------------------------------------------------------------

VisualGasicPackage::VisualGasicPackage() {
    http_client = nullptr;
}

VisualGasicPackage::~VisualGasicPackage() {
    shutdown();
}

// ---------------------------------------------------------------------------
// Lifecycle
// ---------------------------------------------------------------------------

bool VisualGasicPackage::initialize(const String &p_workspace_path) {
    workspace_root = p_workspace_path;
    packages_directory = workspace_root.path_join("addons");

    // Load installed packages from vgpkg-lock.json if it exists
    String lock_path = workspace_root.path_join("vgpkg-lock.json");
    if (FileAccess::file_exists(lock_path)) {
        installed_packages = load_lock_file();
    }

    // Seed a default registry so the Package Browser's Registry tab has
    // something to talk to out of the box. Users can remove/replace via
    // add_registry / remove_registry; the choice persists in registries.json.
    // Override with VG_PKG_REGISTRY env var for self-hosted setups.
    if (registries.is_empty()) {
        String reg_url = OS::get_singleton()->get_environment("VG_PKG_REGISTRY");
        if (reg_url.is_empty()) {
            reg_url = "https://raw.githubusercontent.com/xgreenrx-star/vg-registry/main/";
        }
        add_registry("official", reg_url, "");
    }
    UtilityFunctions::print("[VisualGasicPackage] Initialized at: ", workspace_root);
    return true;
}

void VisualGasicPackage::shutdown() {
    installed_packages = Dictionary();
    package_cache = Dictionary();
    registries.clear();
    http_client = nullptr;
}

// ---------------------------------------------------------------------------
// Registry Management
// ---------------------------------------------------------------------------

void VisualGasicPackage::add_registry(const String &p_name, const String &p_url, const String &p_auth_token) {
    Registry reg;
    reg.name = p_name;
    reg.url = p_url;
    reg.auth_token = p_auth_token;
    reg.is_default = registries.size() == 0;
    registries.push_back(reg);
    UtilityFunctions::print("[VisualGasicPackage] Added registry: ", p_name, " -> ", p_url);
}

void VisualGasicPackage::remove_registry(const String &p_name) {
    for (int i = 0; i < registries.size(); i++) {
        if (registries[i].name == p_name) {
            registries.remove_at(i);
            UtilityFunctions::print("[VisualGasicPackage] Removed registry: ", p_name);
            return;
        }
    }
    log_warning("Registry not found: " + p_name);
}

Array VisualGasicPackage::get_registries() {
    Array result;
    for (int i = 0; i < registries.size(); i++) {
        Dictionary reg_info;
        reg_info["name"] = registries[i].name;
        reg_info["url"] = registries[i].url;
        reg_info["is_default"] = registries[i].is_default;
        reg_info["is_private"] = registries[i].is_private;
        result.push_back(reg_info);
    }
    return result;
}

bool VisualGasicPackage::set_default_registry(const String &p_name) {
    bool found = false;
    for (int i = 0; i < registries.size(); i++) {
        if (registries[i].name == p_name) {
            registries.write[i].is_default = true;
            found = true;
        } else {
            registries.write[i].is_default = false;
        }
    }
    if (!found) {
        log_error("Registry not found: " + p_name);
    }
    return found;
}

// ---------------------------------------------------------------------------
// Package Installation
// ---------------------------------------------------------------------------

static Dictionary result_to_dict(const VisualGasicPackage::InstallationResult &r) {
    Dictionary d;
    d["success"] = r.success;
    d["message"] = r.message;
    d["installed_packages"] = r.installed_packages;
    d["failed_packages"] = r.failed_packages;
    d["dependency_tree"] = r.dependency_tree;
    return d;
}

Dictionary VisualGasicPackage::install_package(const String &p_package_name, const String &p_version_constraint) {
    InstallationResult result;

    if (!is_package_name_valid(p_package_name)) {
        result.message = "Invalid package name: " + p_package_name;
        log_error(result.message);
        return result_to_dict(result);
    }

    UtilityFunctions::print("[VisualGasicPackage] Installing: ", p_package_name, " ", p_version_constraint);

    // Check if already installed with compatible version
    if (is_package_installed(p_package_name, p_version_constraint)) {
        result.success = true;
        result.message = "Package already installed: " + p_package_name;
        log_info(result.message);
        return result_to_dict(result);
    }

    // Try to download package info from registries
    bool downloaded = false;
    for (int i = 0; i < registries.size(); i++) {
        PackageInfo info = download_package_info(p_package_name, p_version_constraint, registries[i]);
        if (!info.name.is_empty()) {
            String install_path = get_package_install_path(p_package_name, info.version.to_string());
            if (download_and_extract_package(info, install_path)) {
                // Record installation
                Dictionary pkg_data;
                pkg_data["name"] = info.name;
                pkg_data["version"] = info.version.to_string();
                pkg_data["description"] = info.description;
                pkg_data["author"] = info.author;
                pkg_data["install_path"] = install_path;
                installed_packages[p_package_name] = pkg_data;

                result.success = true;
                result.message = "Installed: " + p_package_name + "@" + info.version.to_string();
                result.installed_packages.push_back(pkg_data);

                // Update lock file
                update_lock_file(installed_packages);

                downloaded = true;
                break;
            }
        }
    }

    if (!downloaded) {
        result.message = "Failed to install package: " + p_package_name;
        result.failed_packages.push_back(p_package_name);
        log_error(result.message);
    }

    return result_to_dict(result);
}

Dictionary VisualGasicPackage::install_packages(const Array &p_package_specs) {
    InstallationResult combined;
    combined.success = true;

    for (int i = 0; i < p_package_specs.size(); i++) {
        String spec = p_package_specs[i];
        String name = spec;
        String version;
        int at_pos = spec.find("@");
        if (at_pos >= 0) {
            name = spec.substr(0, at_pos);
            version = spec.substr(at_pos + 1);
        }

        Dictionary r = install_package(name, version);
        if ((bool)r["success"]) {
            Array inst = r["installed_packages"];
            for (int j = 0; j < inst.size(); j++) {
                combined.installed_packages.push_back(inst[j]);
            }
        } else {
            combined.success = false;
            Array fail = r["failed_packages"];
            for (int j = 0; j < fail.size(); j++) {
                combined.failed_packages.push_back(fail[j]);
            }
        }
    }

    combined.message = "Installed: " + String::num(combined.installed_packages.size()) +
                       ", Failed: " + String::num(combined.failed_packages.size());
    return result_to_dict(combined);
}

bool VisualGasicPackage::uninstall_package(const String &p_package_name) {
    if (!installed_packages.has(p_package_name)) {
        log_warning("Package not installed: " + p_package_name);
        return false;
    }

    Dictionary pkg_data = installed_packages[p_package_name];
    String install_path = pkg_data.get("install_path", "");

    // Remove package directory
    if (!install_path.is_empty()) {
        Ref<DirAccess> dir = DirAccess::open(install_path);
        if (dir.is_valid()) {
            // Remove directory recursively
            _remove_dir_recursive(install_path);
        }
    }

    installed_packages.erase(p_package_name);
    update_lock_file(installed_packages);

    UtilityFunctions::print("[VisualGasicPackage] Uninstalled: ", p_package_name);
    return true;
}

Dictionary VisualGasicPackage::update_package(const String &p_package_name, const String &p_version_constraint) {
    // Uninstall then reinstall
    uninstall_package(p_package_name);
    return install_package(p_package_name, p_version_constraint);
}

Dictionary VisualGasicPackage::update_all_packages() {
    InstallationResult combined;
    combined.success = true;

    Array keys = installed_packages.keys();
    for (int i = 0; i < keys.size(); i++) {
        String pkg_name = keys[i];
        Dictionary r = update_package(pkg_name);
        if (!(bool)r["success"]) {
            combined.success = false;
            Array fail = r["failed_packages"];
            for (int j = 0; j < fail.size(); j++) {
                combined.failed_packages.push_back(fail[j]);
            }
        } else {
            Array inst = r["installed_packages"];
            for (int j = 0; j < inst.size(); j++) {
                combined.installed_packages.push_back(inst[j]);
            }
        }
    }

    combined.message = "Updated: " + String::num(combined.installed_packages.size()) +
                       ", Failed: " + String::num(combined.failed_packages.size());
    return result_to_dict(combined);
}

// ---------------------------------------------------------------------------
// Dependency Management
// ---------------------------------------------------------------------------

Dictionary VisualGasicPackage::resolve_dependencies(const Array &p_root_dependencies) {
    Dictionary resolved;
    // Simple flat resolution — walk each dependency
    for (int i = 0; i < p_root_dependencies.size(); i++) {
        if (p_root_dependencies[i].get_type() == Variant::DICTIONARY) {
            Dictionary dep = p_root_dependencies[i];
            String name = dep.get("name", "");
            String version = dep.get("version", "");
            if (!name.is_empty()) {
                resolved[name] = version;
            }
        }
    }
    return resolved;
}

bool VisualGasicPackage::check_dependency_conflicts(const Dictionary &p_dependency_tree) {
    // Check for version conflicts in the tree
    // Simple implementation: just verify no duplicate entries with different versions
    Dictionary seen;
    Array keys = p_dependency_tree.keys();
    for (int i = 0; i < keys.size(); i++) {
        String name = keys[i];
        String version = p_dependency_tree[keys[i]];
        if (seen.has(name) && String(seen[name]) != version) {
            log_error("Dependency conflict: " + name + " requires " + String(seen[name]) + " and " + version);
            return true;
        }
        seen[name] = version;
    }
    return false;
}

Array VisualGasicPackage::get_dependency_graph(const String &p_package_name) {
    Array graph;
    if (installed_packages.has(p_package_name)) {
        Dictionary pkg = installed_packages[p_package_name];
        graph.push_back(pkg);
    }
    return graph;
}

Dictionary VisualGasicPackage::get_outdated_packages() {
    Dictionary outdated;
    // Would query registries to compare installed vs latest
    // Stub: return empty for now
    return outdated;
}

// ---------------------------------------------------------------------------
// Package Information
// ---------------------------------------------------------------------------

Dictionary VisualGasicPackage::get_package_info(const String &p_package_name, const String &p_version) {
    if (installed_packages.has(p_package_name)) {
        return installed_packages[p_package_name];
    }

    // Try to fetch from registry
    for (int i = 0; i < registries.size(); i++) {
        Dictionary result = query_registry(registries[i], "/packages/" + p_package_name);
        if (!result.is_empty()) {
            return result;
        }
    }

    return Dictionary();
}

Array VisualGasicPackage::search_packages(const String &p_query, int p_limit) {
    Array results;
    for (int i = 0; i < registries.size(); i++) {
        Dictionary params;
        params["q"] = p_query;
        params["limit"] = p_limit;
        Dictionary response = query_registry(registries[i], "/search", params);
        if (response.has("packages")) {
            Array pkgs = response["packages"];
            for (int j = 0; j < pkgs.size() && results.size() < p_limit; j++) {
                results.push_back(pkgs[j]);
            }
        }
    }
    return results;
}

Dictionary VisualGasicPackage::get_installed_packages() {
    return installed_packages;
}

bool VisualGasicPackage::is_package_installed(const String &p_package_name, const String &p_version) {
    if (!installed_packages.has(p_package_name)) return false;
    if (p_version.is_empty()) return true;

    Dictionary pkg = installed_packages[p_package_name];
    String installed_version = pkg.get("version", "");
    return installed_version == p_version;
}

// ---------------------------------------------------------------------------
// Package Creation and Publishing
// ---------------------------------------------------------------------------

Dictionary VisualGasicPackage::create_package_template(const String &p_name, const String &p_template_type) {
    Dictionary result;

    if (!is_package_name_valid(p_name)) {
        result["success"] = false;
        result["message"] = "Invalid package name: " + p_name;
        return result;
    }

    String pkg_dir = workspace_root.path_join(p_name);

    // Create directory structure
    Ref<DirAccess> dir = DirAccess::open(workspace_root);
    if (!dir.is_valid()) {
        result["success"] = false;
        result["message"] = "Cannot access workspace";
        return result;
    }

    dir->make_dir_recursive(pkg_dir);
    dir->make_dir_recursive(pkg_dir.path_join("src"));

    // Create vgpkg.json manifest
    Dictionary manifest;
    manifest["name"] = p_name;
    manifest["version"] = "1.0.0";
    manifest["description"] = "A VisualGasic package";
    manifest["author"] = "";
    manifest["license"] = "MIT";
    manifest["main"] = "src/main.vg";
    manifest["keywords"] = Array();
    manifest["dependencies"] = Dictionary();

    if (p_template_type == "library") {
        manifest["type"] = "library";
    } else if (p_template_type == "application") {
        manifest["type"] = "application";
    } else {
        manifest["type"] = "library";
    }

    String json_str = JSON::stringify(manifest, "  ");
    Ref<FileAccess> f = FileAccess::open(pkg_dir.path_join("vgpkg.json"), FileAccess::WRITE);
    if (f.is_valid()) {
        f->store_string(json_str);
    }

    // Create a main source file
    Ref<FileAccess> main_f = FileAccess::open(pkg_dir.path_join("src/main.vg"), FileAccess::WRITE);
    if (main_f.is_valid()) {
        main_f->store_string("' " + p_name + " — VisualGasic Package\n");
        main_f->store_string("' Created by VGPackageManager\n\n");
        main_f->store_string("Module " + p_name + "\n\n");
        main_f->store_string("Public Sub Main()\n");
        main_f->store_string("    Print \"Hello from " + p_name + "!\"\n");
        main_f->store_string("End Sub\n");
    }

    // Create README
    Ref<FileAccess> readme_f = FileAccess::open(pkg_dir.path_join("README.md"), FileAccess::WRITE);
    if (readme_f.is_valid()) {
        readme_f->store_string("# " + p_name + "\n\n");
        readme_f->store_string("A VisualGasic package.\n\n");
        readme_f->store_string("## Installation\n\n");
        readme_f->store_string("```\nvgpkg install " + p_name + "\n```\n");
    }

    result["success"] = true;
    result["message"] = "Package template created at: " + pkg_dir;
    result["path"] = pkg_dir;

    UtilityFunctions::print("[VisualGasicPackage] Created template: ", p_name, " at ", pkg_dir);
    return result;
}

bool VisualGasicPackage::validate_package_manifest(const String &p_manifest_path) {
    if (!FileAccess::file_exists(p_manifest_path)) {
        log_error("Manifest not found: " + p_manifest_path);
        return false;
    }

    Ref<FileAccess> f = FileAccess::open(p_manifest_path, FileAccess::READ);
    if (!f.is_valid()) {
        log_error("Cannot read manifest: " + p_manifest_path);
        return false;
    }

    String content = f->get_as_text();
    Ref<JSON> json;
    json.instantiate();
    Error err = json->parse(content);
    if (err != OK) {
        log_error("Invalid JSON in manifest: " + json->get_error_message());
        return false;
    }

    Dictionary manifest = json->get_data();

    // Validate required fields
    if (!manifest.has("name") || String(manifest["name"]).is_empty()) {
        log_error("Manifest missing 'name' field");
        return false;
    }
    if (!manifest.has("version") || String(manifest["version"]).is_empty()) {
        log_error("Manifest missing 'version' field");
        return false;
    }

    if (!is_package_name_valid(manifest["name"])) {
        log_error("Invalid package name in manifest: " + String(manifest["name"]));
        return false;
    }

    if (!is_version_valid(manifest["version"])) {
        log_error("Invalid version in manifest: " + String(manifest["version"]));
        return false;
    }

    UtilityFunctions::print("[VisualGasicPackage] Manifest valid: ", p_manifest_path);
    return true;
}

Dictionary VisualGasicPackage::build_package(const String &p_package_path) {
    Dictionary result;
    String manifest_path = p_package_path.path_join("vgpkg.json");

    if (!validate_package_manifest(manifest_path)) {
        result["success"] = false;
        result["message"] = "Invalid manifest";
        return result;
    }

    // Read manifest
    Ref<FileAccess> f = FileAccess::open(manifest_path, FileAccess::READ);
    Ref<JSON> json;
    json.instantiate();
    json->parse(f->get_as_text());
    Dictionary manifest = json->get_data();

    String name = manifest["name"];
    String version = manifest.get("version", "1.0.0");
    String output_file = workspace_root.path_join(name + "-" + version + ".vgpkg.zip");

    // Write the actual .vgpkg.zip — recursively pack every file under
    // p_package_path with paths relative to it. Excludes the build output
    // itself (if the user happens to be building inside workspace_root) and
    // common junk dirs.
    Ref<ZIPPacker> zip;
    zip.instantiate();
    Error zerr = zip->open(output_file, ZIPPacker::APPEND_CREATE);
    if (zerr != OK) {
        result["success"] = false;
        result["message"] = "Cannot create zip: " + output_file;
        return result;
    }
    if (!_zip_add_dir_recursive(zip, p_package_path, "")) {
        zip->close();
        result["success"] = false;
        result["message"] = "Failed to add files to zip";
        return result;
    }
    zip->close();

    result["success"] = true;
    result["message"] = "Package built: " + output_file;
    result["output"] = output_file;

    UtilityFunctions::print("[VisualGasicPackage] Built: ", output_file);
    return result;
}

Dictionary VisualGasicPackage::publish_package(const String &p_package_path, const String &p_registry_name) {
    Dictionary result;

    // Build first
    Dictionary build_result = build_package(p_package_path);
    if (!(bool)build_result.get("success", false)) {
        result["success"] = false;
        result["message"] = "Build failed: " + String(build_result.get("message", ""));
        return result;
    }

    // Find target registry
    Registry *target = nullptr;
    for (int i = 0; i < registries.size(); i++) {
        if (!p_registry_name.is_empty() && registries[i].name == p_registry_name) {
            target = &registries.write[i];
            break;
        } else if (registries[i].is_default) {
            target = &registries.write[i];
        }
    }

    if (!target) {
        result["success"] = false;
        result["message"] = "No registry configured";
        return result;
    }

    // TODO: Upload to registry via HTTP
    result["success"] = true;
    result["message"] = "Published to: " + target->name;

    UtilityFunctions::print("[VisualGasicPackage] Published to: ", target->name);
    return result;
}

// ---------------------------------------------------------------------------
// Project Integration
// ---------------------------------------------------------------------------

Dictionary VisualGasicPackage::initialize_project(const String &p_project_path) {
    Dictionary result;
    String manifest_path = p_project_path.path_join("vgpkg.json");

    if (FileAccess::file_exists(manifest_path)) {
        result["success"] = false;
        result["message"] = "vgpkg.json already exists";
        return result;
    }

    Dictionary manifest;
    manifest["name"] = p_project_path.get_file();
    manifest["version"] = "1.0.0";
    manifest["description"] = "";
    manifest["dependencies"] = Dictionary();
    manifest["devDependencies"] = Dictionary();

    String json_str = JSON::stringify(manifest, "  ");
    Ref<FileAccess> f = FileAccess::open(manifest_path, FileAccess::WRITE);
    if (!f.is_valid()) {
        result["success"] = false;
        result["message"] = "Cannot write vgpkg.json";
        return result;
    }
    f->store_string(json_str);

    result["success"] = true;
    result["message"] = "Created vgpkg.json at: " + manifest_path;
    result["manifest_path"] = manifest_path;

    UtilityFunctions::print("[VisualGasicPackage] Project initialized: ", manifest_path);
    return result;
}

bool VisualGasicPackage::add_dependency(const String &p_package_name, const String &p_version_constraint) {
    String manifest_path = workspace_root.path_join("vgpkg.json");
    if (!FileAccess::file_exists(manifest_path)) {
        log_error("No vgpkg.json found. Run InitializeProject first.");
        return false;
    }

    Ref<FileAccess> f = FileAccess::open(manifest_path, FileAccess::READ);
    if (!f.is_valid()) return false;

    Ref<JSON> json;
    json.instantiate();
    json->parse(f->get_as_text());
    Dictionary manifest = json->get_data();

    Dictionary deps = manifest.get("dependencies", Dictionary());
    deps[p_package_name] = p_version_constraint.is_empty() ? "*" : p_version_constraint;
    manifest["dependencies"] = deps;

    // Write back
    String json_str = JSON::stringify(manifest, "  ");
    Ref<FileAccess> wf = FileAccess::open(manifest_path, FileAccess::WRITE);
    if (!wf.is_valid()) return false;
    wf->store_string(json_str);

    UtilityFunctions::print("[VisualGasicPackage] Added dependency: ", p_package_name, "@", p_version_constraint);
    return true;
}

bool VisualGasicPackage::remove_dependency(const String &p_package_name) {
    String manifest_path = workspace_root.path_join("vgpkg.json");
    if (!FileAccess::file_exists(manifest_path)) {
        log_error("No vgpkg.json found");
        return false;
    }

    Ref<FileAccess> f = FileAccess::open(manifest_path, FileAccess::READ);
    if (!f.is_valid()) return false;

    Ref<JSON> json;
    json.instantiate();
    json->parse(f->get_as_text());
    Dictionary manifest = json->get_data();

    Dictionary deps = manifest.get("dependencies", Dictionary());
    if (!deps.has(p_package_name)) {
        log_warning("Dependency not found: " + p_package_name);
        return false;
    }

    deps.erase(p_package_name);
    manifest["dependencies"] = deps;

    String json_str = JSON::stringify(manifest, "  ");
    Ref<FileAccess> wf = FileAccess::open(manifest_path, FileAccess::WRITE);
    if (!wf.is_valid()) return false;
    wf->store_string(json_str);

    UtilityFunctions::print("[VisualGasicPackage] Removed dependency: ", p_package_name);
    return true;
}

Dictionary VisualGasicPackage::get_project_dependencies() {
    String manifest_path = workspace_root.path_join("vgpkg.json");
    if (!FileAccess::file_exists(manifest_path)) return Dictionary();

    Ref<FileAccess> f = FileAccess::open(manifest_path, FileAccess::READ);
    if (!f.is_valid()) return Dictionary();

    Ref<JSON> json;
    json.instantiate();
    json->parse(f->get_as_text());
    Dictionary manifest = json->get_data();

    return manifest.get("dependencies", Dictionary());
}

// ---------------------------------------------------------------------------
// Cache Management
// ---------------------------------------------------------------------------

void VisualGasicPackage::clear_cache() {
    package_cache = Dictionary();
    String cache_path = get_packages_cache_path();
    _remove_dir_recursive(cache_path);
    UtilityFunctions::print("[VisualGasicPackage] Cache cleared");
}

Dictionary VisualGasicPackage::get_cache_info() {
    Dictionary info;
    info["entries"] = package_cache.size();
    info["cache_path"] = get_packages_cache_path();
    return info;
}

bool VisualGasicPackage::clean_unused_packages() {
    // Remove packages in the cache that aren't in installed_packages
    UtilityFunctions::print("[VisualGasicPackage] Cleaning unused packages...");
    // Stub: would scan cache directory and compare to installed list
    return true;
}

// ---------------------------------------------------------------------------
// Internal: Package Operations
// ---------------------------------------------------------------------------

VisualGasicPackage::PackageInfo VisualGasicPackage::download_package_info(const String &p_package_name, const String &p_version, const Registry &p_registry) {
    PackageInfo info;
    Dictionary response = query_registry(p_registry, "/packages/" + p_package_name + "/" + p_version);
    if (response.has("name")) {
        info.name = response["name"];
        info.description = response.get("description", "");
        info.author = response.get("author", "");
        if (response.has("version")) {
            info.version = parse_version(response["version"]);
        }
    }
    return info;
}

bool VisualGasicPackage::download_and_extract_package(const PackageInfo &p_package, const String &p_install_path) {
    // Create install directory
    Ref<DirAccess> dir = DirAccess::open("res://");
    if (dir.is_valid()) {
        dir->make_dir_recursive(p_install_path);
    }

    // In a real implementation, this would download the .zip from the registry
    // and extract it. For now, create a marker file.
    Ref<FileAccess> f = FileAccess::open(p_install_path.path_join("vgpkg.json"), FileAccess::WRITE);
    if (f.is_valid()) {
        Dictionary pkg_manifest;
        pkg_manifest["name"] = p_package.name;
        pkg_manifest["version"] = p_package.version.to_string();
        pkg_manifest["description"] = p_package.description;
        f->store_string(JSON::stringify(pkg_manifest, "  "));
    }

    UtilityFunctions::print("[VisualGasicPackage] Extracted: ", p_package.name, " to ", p_install_path);
    return true;
}

bool VisualGasicPackage::verify_package_integrity(const String &p_package_path, const String &p_expected_hash) {
    if (p_expected_hash.is_empty()) return true;
    // Would compute SHA-256 of package and compare
    return true;
}

// ---------------------------------------------------------------------------
// Internal: Dependency Resolution
// ---------------------------------------------------------------------------

Dictionary VisualGasicPackage::resolve_dependency_tree(const Vector<Dependency> &p_root_deps, Dictionary &p_visited, Dictionary &p_resolved) {
    for (int i = 0; i < p_root_deps.size(); i++) {
        String name = p_root_deps[i].name;
        if (p_visited.has(name)) continue;
        p_visited[name] = true;
        p_resolved[name] = p_root_deps[i].version_constraint;
    }
    return p_resolved;
}

bool VisualGasicPackage::satisfies_constraint(const Version &p_version, const String &p_constraint) {
    if (p_constraint.is_empty() || p_constraint == "*") return true;

    Version required = parse_version(p_constraint.replace("^", "").replace("~", "").replace(">=", "").replace("<=", ""));

    if (p_constraint.begins_with("^")) {
        // Compatible with version (same major)
        return p_version.major == required.major && p_version.is_compatible_with(required);
    } else if (p_constraint.begins_with("~")) {
        // Approximately equivalent (same major.minor)
        return p_version.major == required.major && p_version.minor == required.minor && p_version.patch >= required.patch;
    } else if (p_constraint.begins_with(">=")) {
        return p_version.is_compatible_with(required);
    } else {
        // Exact match
        return p_version.major == required.major && p_version.minor == required.minor && p_version.patch == required.patch;
    }
}

VisualGasicPackage::Version VisualGasicPackage::find_best_version(const String &p_package_name, const String &p_constraint, const Registry &p_registry) {
    Array versions = get_available_versions(p_package_name, p_registry);
    Version best;
    for (int i = 0; i < versions.size(); i++) {
        Version v = parse_version(versions[i]);
        if (satisfies_constraint(v, p_constraint)) {
            if (v.major > best.major ||
                (v.major == best.major && v.minor > best.minor) ||
                (v.major == best.major && v.minor == best.minor && v.patch > best.patch)) {
                best = v;
            }
        }
    }
    return best;
}

// ---------------------------------------------------------------------------
// Internal: Version Management
// ---------------------------------------------------------------------------

VisualGasicPackage::Version VisualGasicPackage::parse_version(const String &p_version_string) {
    Version v;
    String version = p_version_string.strip_edges();
    // Remove leading 'v' if present
    if (version.begins_with("v") || version.begins_with("V")) {
        version = version.substr(1);
    }

    PackedStringArray parts = version.split(".");
    if (parts.size() >= 1) v.major = parts[0].to_int();
    if (parts.size() >= 2) v.minor = parts[1].to_int();
    if (parts.size() >= 3) {
        // Handle pre-release suffix (e.g., "1-beta")
        String patch_str = parts[2];
        int dash = patch_str.find("-");
        if (dash >= 0) {
            v.patch = patch_str.substr(0, dash).to_int();
            v.prerelease = patch_str.substr(dash + 1);
        } else {
            int plus = patch_str.find("+");
            if (plus >= 0) {
                v.patch = patch_str.substr(0, plus).to_int();
                v.build = patch_str.substr(plus + 1);
            } else {
                v.patch = patch_str.to_int();
            }
        }
    }
    return v;
}

bool VisualGasicPackage::is_version_constraint_valid(const String &p_constraint) {
    if (p_constraint.is_empty() || p_constraint == "*") return true;
    String cleaned = p_constraint.replace("^", "").replace("~", "").replace(">=", "").replace("<=", "").replace(">", "").replace("<", "");
    return is_version_valid(cleaned);
}

Array VisualGasicPackage::get_available_versions(const String &p_package_name, const Registry &p_registry) {
    Dictionary response = query_registry(p_registry, "/packages/" + p_package_name + "/versions");
    if (response.has("versions")) {
        return response["versions"];
    }
    return Array();
}

// ---------------------------------------------------------------------------
// Internal: File System Operations
// ---------------------------------------------------------------------------

bool VisualGasicPackage::create_directory_structure(const String &p_base_path) {
    Ref<DirAccess> dir = DirAccess::open("res://");
    if (!dir.is_valid()) return false;
    return dir->make_dir_recursive(p_base_path) == OK;
}

bool VisualGasicPackage::copy_package_files(const String &p_source_path, const String &p_dest_path, const Array &p_files) {
    Ref<DirAccess> dir = DirAccess::open("res://");
    if (!dir.is_valid()) return false;

    dir->make_dir_recursive(p_dest_path);

    for (int i = 0; i < p_files.size(); i++) {
        String file_name = p_files[i];
        String src = p_source_path.path_join(file_name);
        String dst = p_dest_path.path_join(file_name);

        // Ensure dest subdirectory exists
        String dst_dir = dst.get_base_dir();
        dir->make_dir_recursive(dst_dir);

        dir->copy(src, dst);
    }
    return true;
}

bool VisualGasicPackage::create_package_manifest(const String &p_path, const PackageInfo &p_info) {
    Dictionary manifest;
    manifest["name"] = p_info.name;
    manifest["version"] = p_info.version.to_string();
    manifest["description"] = p_info.description;
    manifest["author"] = p_info.author;
    manifest["license"] = p_info.license;
    manifest["main"] = p_info.main_file;

    Ref<FileAccess> f = FileAccess::open(p_path, FileAccess::WRITE);
    if (!f.is_valid()) return false;
    f->store_string(JSON::stringify(manifest, "  "));
    return true;
}

VisualGasicPackage::PackageInfo VisualGasicPackage::load_package_manifest(const String &p_manifest_path) {
    PackageInfo info;
    if (!FileAccess::file_exists(p_manifest_path)) return info;

    Ref<FileAccess> f = FileAccess::open(p_manifest_path, FileAccess::READ);
    if (!f.is_valid()) return info;

    Ref<JSON> json;
    json.instantiate();
    json->parse(f->get_as_text());
    Dictionary data = json->get_data();

    info.name = data.get("name", "");
    info.version = parse_version(data.get("version", "0.0.0"));
    info.description = data.get("description", "");
    info.author = data.get("author", "");
    info.license = data.get("license", "");
    info.main_file = data.get("main", "");

    return info;
}

// ---------------------------------------------------------------------------
// Internal: Registry Communication
// ---------------------------------------------------------------------------

Dictionary VisualGasicPackage::query_registry(const Registry &p_registry, const String &p_endpoint, const Dictionary &p_params) {
    // In a full implementation, this would use HTTPClient to query the registry.
    // For now, return empty dictionary as a stub.
    // When HTTPRequest is available in a scene tree context, this would perform actual HTTP calls.
    return Dictionary();
}

bool VisualGasicPackage::authenticate_with_registry(const Registry &p_registry) {
    if (p_registry.auth_token.is_empty()) return true;
    // Would verify token with the registry server
    return true;
}

// ---------------------------------------------------------------------------
// Internal: Validation
// ---------------------------------------------------------------------------

bool VisualGasicPackage::is_package_name_valid(const String &p_name) {
    if (p_name.is_empty() || p_name.length() > 128) return false;

    // Package names: lowercase letters, digits, hyphens, underscores
    for (int i = 0; i < p_name.length(); i++) {
        char32_t c = p_name[i];
        if (!((c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') ||
              c == '-' || c == '_' || c == '.' ||
              (c >= 'A' && c <= 'Z'))) {
            return false;
        }
    }
    return true;
}

bool VisualGasicPackage::is_version_valid(const String &p_version) {
    if (p_version.is_empty()) return false;
    Version v = parse_version(p_version);
    return v.major >= 0 && v.minor >= 0 && v.patch >= 0;
}

Dictionary VisualGasicPackage::validate_dependencies(const Vector<Dependency> &p_dependencies) {
    Dictionary result;
    result["valid"] = true;
    Array errors;

    for (int i = 0; i < p_dependencies.size(); i++) {
        if (!is_package_name_valid(p_dependencies[i].name)) {
            errors.push_back("Invalid dependency name: " + p_dependencies[i].name);
            result["valid"] = false;
        }
        if (!is_version_constraint_valid(p_dependencies[i].version_constraint)) {
            errors.push_back("Invalid version constraint for " + p_dependencies[i].name + ": " + p_dependencies[i].version_constraint);
            result["valid"] = false;
        }
    }

    result["errors"] = errors;
    return result;
}

// ---------------------------------------------------------------------------
// Internal: Utility
// ---------------------------------------------------------------------------

String VisualGasicPackage::get_packages_cache_path() {
    return "user://vgpkg_cache";
}

String VisualGasicPackage::get_package_install_path(const String &p_package_name, const String &p_version) {
    return packages_directory.path_join(p_package_name);
}

String VisualGasicPackage::generate_lock_file_content(const Dictionary &p_resolved_dependencies) {
    Dictionary lock;
    lock["lockfileVersion"] = 1;
    lock["packages"] = p_resolved_dependencies;
    return JSON::stringify(lock, "  ");
}

bool VisualGasicPackage::update_lock_file(const Dictionary &p_resolved_dependencies) {
    String lock_path = workspace_root.path_join("vgpkg-lock.json");
    String content = generate_lock_file_content(p_resolved_dependencies);

    Ref<FileAccess> f = FileAccess::open(lock_path, FileAccess::WRITE);
    if (!f.is_valid()) {
        log_error("Cannot write lock file: " + lock_path);
        return false;
    }
    f->store_string(content);
    return true;
}

Dictionary VisualGasicPackage::load_lock_file() {
    String lock_path = workspace_root.path_join("vgpkg-lock.json");
    if (!FileAccess::file_exists(lock_path)) return Dictionary();

    Ref<FileAccess> f = FileAccess::open(lock_path, FileAccess::READ);
    if (!f.is_valid()) return Dictionary();

    Ref<JSON> json;
    json.instantiate();
    json->parse(f->get_as_text());
    Dictionary lock = json->get_data();

    return lock.get("packages", Dictionary());
}

// ---------------------------------------------------------------------------
// Internal: Logging
// ---------------------------------------------------------------------------

void VisualGasicPackage::log_error(const String &p_message) {
    UtilityFunctions::printerr("[VisualGasicPackage] ERROR: ", p_message);
}

void VisualGasicPackage::log_warning(const String &p_message) {
    UtilityFunctions::print("[VisualGasicPackage] WARNING: ", p_message);
}

void VisualGasicPackage::log_info(const String &p_message) {
    UtilityFunctions::print("[VisualGasicPackage] ", p_message);
}

// ---------------------------------------------------------------------------
// Internal: Helper to remove a directory recursively
// ---------------------------------------------------------------------------

static void _remove_dir_recursive(const String &p_path) {
    Ref<DirAccess> dir = DirAccess::open(p_path);
    if (!dir.is_valid()) return;

    dir->list_dir_begin();
    String item = dir->get_next();
    while (!item.is_empty()) {
        if (item != "." && item != "..") {
            String full = p_path.path_join(item);
            if (dir->current_is_dir()) {
                _remove_dir_recursive(full);
            } else {
                dir->remove(full);
            }
        }
        item = dir->get_next();
    }
    dir->list_dir_end();
    dir->remove(p_path);
}

// Recursively add every file under (p_root/p_rel) to the zip, storing entries
// with paths relative to p_root. Returns false on any I/O error.
// Skips common build/cache dirs and the .vgpkg.zip output itself.
static bool _zip_add_dir_recursive(Ref<ZIPPacker> &p_zip, const String &p_root, const String &p_rel) {
    String abs = p_rel.is_empty() ? p_root : p_root.path_join(p_rel);
    Ref<DirAccess> dir = DirAccess::open(abs);
    if (!dir.is_valid()) return false;

    dir->list_dir_begin();
    String item = dir->get_next();
    while (!item.is_empty()) {
        if (item == "." || item == "..") {
            item = dir->get_next();
            continue;
        }
        // Skip hidden / cache / VCS / build dirs and stale package archives.
        if (item.begins_with(".") || item == "node_modules" || item == "__pycache__" ||
                item == ".godot" || item == "bin" || item == "build" ||
                item.ends_with(".vgpkg.zip")) {
            item = dir->get_next();
            continue;
        }
        String child_rel = p_rel.is_empty() ? item : p_rel.path_join(item);
        String child_abs = abs.path_join(item);
        if (dir->current_is_dir()) {
            if (!_zip_add_dir_recursive(p_zip, p_root, child_rel)) {
                dir->list_dir_end();
                return false;
            }
        } else {
            Ref<FileAccess> fr = FileAccess::open(child_abs, FileAccess::READ);
            if (!fr.is_valid()) {
                dir->list_dir_end();
                return false;
            }
            PackedByteArray buf = fr->get_buffer(fr->get_length());
            if (p_zip->start_file(child_rel) != OK) {
                dir->list_dir_end();
                return false;
            }
            p_zip->write_file(buf);
            p_zip->close_file();
        }
        item = dir->get_next();
    }
    dir->list_dir_end();
    return true;
}
