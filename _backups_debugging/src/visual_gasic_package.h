#ifndef VISUAL_GASIC_PACKAGE_H
#define VISUAL_GASIC_PACKAGE_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/classes/http_request.hpp>
#include <godot_cpp/classes/json.hpp>
#include <map>
#include <vector>

using namespace godot;

/**
 * VisualGasic Package Manager
 * 
 * Provides comprehensive package management capabilities:
 * - Dependency resolution with semantic versioning
 * - Package installation and removal
 * - Registry management (public and private)
 * - Build system integration
 * - Version management and updates
 * - Package publishing and sharing
 */
class VisualGasicPackage : public RefCounted {
    GDCLASS(VisualGasicPackage, RefCounted)

public:
    // Package System Structures
    struct Version {
        int major = 0;
        int minor = 0;
        int patch = 0;
        String prerelease;
        String build;
        
        String to_string() const {
            String version_str = String::num(major) + "." + String::num(minor) + "." + String::num(patch);
            if (!prerelease.is_empty()) {
                version_str += "-" + prerelease;
            }
            if (!build.is_empty()) {
                version_str += "+" + build;
            }
            return version_str;
        }
        
        bool is_compatible_with(const Version& other) const {
            return major == other.major && (minor > other.minor || 
                   (minor == other.minor && patch >= other.patch));
        }
    };
    
    struct Dependency {
        String name;
        String version_constraint; // e.g., "^1.2.0", ">=2.0.0", "~1.1.0"
        bool is_dev_dependency = false;
        bool is_optional = false;
        Dictionary options;
    };
    
    struct PackageInfo {
        String name;
        Version version;
        String description;
        String author;
        String license;
        String homepage;
        String repository;
        Array keywords;
        Vector<Dependency> dependencies;
        Vector<Dependency> dev_dependencies;
        Dictionary scripts;
        Dictionary exports; // Public API exports
        String main_file;
        Array files; // Files to include in package
        Dictionary metadata;
    };
    
    struct Registry {
        String name;
        String url;
        String auth_token;
        bool is_default = false;
        bool is_private = false;
        Dictionary config;
    };
    
    struct InstallationResult {
        bool success = false;
        String message;
        Array installed_packages;
        Array failed_packages;
        Dictionary dependency_tree;
    };

private:
    // Package Manager State
    Dictionary installed_packages;
    Dictionary package_cache;
    Vector<Registry> registries;
    String workspace_root;
    String packages_directory;
    
    // Configuration
    Dictionary config;
    bool offline_mode = false;
    bool strict_ssl = true;
    int timeout_seconds = 30;
    
    // HTTP Client for registry operations
    HTTPRequest* http_client = nullptr;

public:
    VisualGasicPackage();
    ~VisualGasicPackage();
    
    // Package Manager Lifecycle
    bool initialize(const String& workspace_path);
    void shutdown();
    
    // Registry Management
    void add_registry(const String& name, const String& url, const String& auth_token = "");
    void remove_registry(const String& name);
    Array get_registries();
    bool set_default_registry(const String& name);
    
    // Package Installation
    InstallationResult install_package(const String& package_name, const String& version_constraint = "");
    InstallationResult install_packages(const Array& package_specs);
    bool uninstall_package(const String& package_name);
    InstallationResult update_package(const String& package_name, const String& version_constraint = "");
    InstallationResult update_all_packages();
    
    // Dependency Management
    Dictionary resolve_dependencies(const Array& root_dependencies);
    bool check_dependency_conflicts(const Dictionary& dependency_tree);
    Array get_dependency_graph(const String& package_name);
    Dictionary get_outdated_packages();
    
    // Package Information
    Dictionary get_package_info(const String& package_name, const String& version = "");
    Array search_packages(const String& query, int limit = 50);
    Dictionary get_installed_packages();
    bool is_package_installed(const String& package_name, const String& version = "");
    
    // Package Creation and Publishing
    Dictionary create_package_template(const String& name, const String& template_type = "library");
    bool validate_package_manifest(const String& manifest_path);
    Dictionary build_package(const String& package_path);
    Dictionary publish_package(const String& package_path, const String& registry_name = "");
    
    // Project Integration
    Dictionary initialize_project(const String& project_path);
    bool add_dependency(const String& package_name, const String& version_constraint = "");
    bool remove_dependency(const String& package_name);
    Dictionary get_project_dependencies();
    
    // Cache Management
    void clear_cache();
    Dictionary get_cache_info();
    bool clean_unused_packages();

protected:
    static void _bind_methods();

private:
    // Internal Package Operations
    PackageInfo download_package_info(const String& package_name, const String& version, const Registry& registry);
    bool download_and_extract_package(const PackageInfo& package, const String& install_path);
    bool verify_package_integrity(const String& package_path, const String& expected_hash = "");
    
    // Dependency Resolution
    Dictionary resolve_dependency_tree(const Vector<Dependency>& root_deps, Dictionary& visited, Dictionary& resolved);
    bool satisfies_constraint(const Version& version, const String& constraint);
    Version find_best_version(const String& package_name, const String& constraint, const Registry& registry);
    
    // Version Management
    Version parse_version(const String& version_string);
    bool is_version_constraint_valid(const String& constraint);
    Array get_available_versions(const String& package_name, const Registry& registry);
    
    // File System Operations
    bool create_directory_structure(const String& base_path);
    bool copy_package_files(const String& source_path, const String& dest_path, const Array& files);
    bool create_package_manifest(const String& path, const PackageInfo& info);
    PackageInfo load_package_manifest(const String& manifest_path);
    
    // Registry Communication
    Dictionary query_registry(const Registry& registry, const String& endpoint, const Dictionary& params = Dictionary());
    bool authenticate_with_registry(const Registry& registry);
    
    // Validation
    bool is_package_name_valid(const String& name);
    bool is_version_valid(const String& version);
    Dictionary validate_dependencies(const Vector<Dependency>& dependencies);
    
    // Utility Functions
    String get_packages_cache_path();
    String get_package_install_path(const String& package_name, const String& version);
    String generate_lock_file_content(const Dictionary& resolved_dependencies);
    bool update_lock_file(const Dictionary& resolved_dependencies);
    Dictionary load_lock_file();
    
    // Error Handling
    void log_error(const String& message);
    void log_warning(const String& message);
    void log_info(const String& message);
};

#endif // VISUAL_GASIC_PACKAGE_H