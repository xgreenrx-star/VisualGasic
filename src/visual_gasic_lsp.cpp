#include "visual_gasic_lsp.h"
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/dir_access.hpp>

VisualGasicLSP::VisualGasicLSP() {
    workspace_folders.clear();
    symbol_index.clear();
    file_diagnostics.clear();
    parse_cache.clear();
    completion_cache.clear();
    
    // Default settings
    settings["diagnostics.enabled"] = true;
    settings["completion.enabled"] = true;
    settings["completion.auto_import"] = true;
    settings["hover.enabled"] = true;
    settings["references.enabled"] = true;
    settings["format.enabled"] = true;
    settings["symbols.max_results"] = 100;
    
    initialize_builtin_symbols();
}

VisualGasicLSP::~VisualGasicLSP() {
    cleanup_old_cache_entries();
}

void VisualGasicLSP::_bind_methods() {
    ClassDB::bind_method(D_METHOD("initialize"), &VisualGasicLSP::initialize);
    ClassDB::bind_method(D_METHOD("add_workspace_folder"), &VisualGasicLSP::add_workspace_folder);
    ClassDB::bind_method(D_METHOD("open_document"), &VisualGasicLSP::open_document);
    ClassDB::bind_method(D_METHOD("get_completions"), &VisualGasicLSP::get_completions);
    ClassDB::bind_method(D_METHOD("get_diagnostics"), &VisualGasicLSP::get_diagnostics);
    ClassDB::bind_method(D_METHOD("get_hover_info"), &VisualGasicLSP::get_hover_info);
}

bool VisualGasicLSP::initialize(const Dictionary& init_params) {
    UtilityFunctions::print("LSP: Initializing VisualGasic Language Server");
    
    if (init_params.has("workspaceFolders")) {
        Array folders = init_params["workspaceFolders"];
        for (int i = 0; i < folders.size(); i++) {
            Dictionary folder = folders[i];
            if (folder.has("uri") && folder.has("name")) {
                add_workspace_folder(folder["uri"], folder["name"]);
            }
        }
    }
    
    if (init_params.has("initializationOptions")) {
        Dictionary options = init_params["initializationOptions"];
        update_settings(options);
    }
    
    UtilityFunctions::print("LSP: Initialization complete");
    return true;
}

void VisualGasicLSP::shutdown() {
    UtilityFunctions::print("LSP: Shutting down VisualGasic Language Server");
    cleanup_old_cache_entries();
    workspace_folders.clear();
    symbol_index.clear();
    file_diagnostics.clear();
}

void VisualGasicLSP::add_workspace_folder(const String& uri, const String& name) {
    WorkspaceFolder folder;
    folder.uri = uri;
    folder.name = name;
    
    Dictionary folder_dict;
    folder_dict["uri"] = uri;
    folder_dict["name"] = name;
    folder_dict["symbols"] = Array();
    folder_dict["file_cache"] = Dictionary();
    
    workspace_folders[uri] = folder_dict;
    
    UtilityFunctions::print("LSP: Added workspace folder: " + name + " (" + uri + ")");
    
    // Index the workspace in the background
    index_workspace(uri);
}

void VisualGasicLSP::remove_workspace_folder(const String& uri) {
    if (workspace_folders.has(uri)) {
        Dictionary folder = workspace_folders[uri];
        String name = folder["name"];
        workspace_folders.erase(uri);
        UtilityFunctions::print("LSP: Removed workspace folder: " + name);
    }
}

void VisualGasicLSP::index_workspace(const String& workspace_uri) {
    UtilityFunctions::print("LSP: Indexing workspace: " + workspace_uri);
    
    // Convert URI to local path (simplified)
    String local_path = workspace_uri;
    if (local_path.begins_with("file://")) {
        local_path = local_path.substr(7);
    }
    
    // Recursively find .bas files
    Array files_to_index;
    find_source_files(local_path, files_to_index);
    
    // Index each file
    for (int i = 0; i < files_to_index.size(); i++) {
        String file_path = files_to_index[i];
        String file_uri = "file://" + file_path;
        
        Ref<FileAccess> file = FileAccess::open(file_path, FileAccess::READ);
        if (file.is_valid()) {
            String content = file->get_as_text();
            analyze_file(file_uri, content);
        }
    }
    
    UtilityFunctions::print("LSP: Indexed " + String::num(files_to_index.size()) + " files");
}

void VisualGasicLSP::open_document(const String& uri, const String& content) {
    analyze_file(uri, content);
    UtilityFunctions::print("LSP: Opened document: " + uri);
}

void VisualGasicLSP::close_document(const String& uri) {
    invalidate_cache(uri);
    if (file_diagnostics.has(uri)) {
        file_diagnostics.erase(uri);
    }
    UtilityFunctions::print("LSP: Closed document: " + uri);
}

void VisualGasicLSP::change_document(const String& uri, const String& content) {
    invalidate_cache(uri);
    analyze_file(uri, content);
}

Array VisualGasicLSP::get_diagnostics(const String& uri) {
    if (file_diagnostics.has(uri)) {
        return file_diagnostics[uri];
    }
    return Array();
}

Array VisualGasicLSP::get_completions(const String& uri, const Position& position, const String& trigger_character) {
    if (!enable_completion) {
        return Array();
    }
    
    String cache_key = uri + ":" + String::num(position.line) + ":" + String::num(position.character);
    if (completion_cache.has(cache_key)) {
        return completion_cache[cache_key];
    }
    
    // Get document content
    String content = "";
    if (parse_cache.has(uri)) {
        Dictionary doc_info = parse_cache[uri];
        content = doc_info["content"];
    }
    
    Array completions = analyze_completions_at_position(content, position);
    completion_cache[cache_key] = completions;
    
    return completions;
}

Dictionary VisualGasicLSP::get_hover_info(const String& uri, const Position& position) {
    Dictionary hover_info;
    
    if (!enable_hover) {
        return hover_info;
    }
    
    Symbol symbol = resolve_symbol_at_position(uri, position);
    if (!symbol.name.is_empty()) {
        hover_info["contents"] = get_symbol_hover_text(symbol);
        
        Dictionary range_dict;
        range_dict["start"] = Dictionary();
        range_dict["end"] = Dictionary();
        hover_info["range"] = range_dict;
    }
    
    return hover_info;
}

Array VisualGasicLSP::get_definitions(const String& uri, const Position& position) {
    Array definitions;
    
    Symbol symbol = resolve_symbol_at_position(uri, position);
    if (!symbol.name.is_empty()) {
        Dictionary location;
        location["uri"] = symbol.location.uri.is_empty() ? uri : symbol.location.uri;
        
        // Build proper range from symbol location
        Dictionary range_dict;
        Dictionary start_pos;
        start_pos["line"] = symbol.location.line;
        start_pos["character"] = 0;
        Dictionary end_pos;
        end_pos["line"] = symbol.location.line;
        end_pos["character"] = symbol.name.length();
        range_dict["start"] = start_pos;
        range_dict["end"] = end_pos;
        
        location["range"] = range_dict;
        definitions.push_back(location);
    }
    
    return definitions;
}

Array VisualGasicLSP::get_references(const String& uri, const Position& position, bool include_declaration) {
    Array references;
    
    Symbol symbol = resolve_symbol_at_position(uri, position);
    if (!symbol.name.is_empty()) {
        // Find all workspaces that might contain this symbol
        Array workspace_uris = workspace_folders.keys();
        for (int i = 0; i < workspace_uris.size(); i++) {
            String workspace_uri = workspace_uris[i];
            Array refs = find_symbol_references(symbol.name, workspace_uri);
            for (int j = 0; j < refs.size(); j++) {
                references.push_back(refs[j]);
            }
        }
    }
    
    return references;
}

Array VisualGasicLSP::get_document_symbols(const String& uri) {
    Array symbols;
    
    if (parse_cache.has(uri)) {
        Dictionary doc_info = parse_cache[uri];
        if (doc_info.has("symbols")) {
            symbols = doc_info["symbols"];
        }
    }
    
    return symbols;
}

Array VisualGasicLSP::get_workspace_symbols(const String& query) {
    Array results;
    int max_results = settings["symbols.max_results"];
    
    Array workspace_uris = workspace_folders.keys();
    for (int i = 0; i < workspace_uris.size() && results.size() < max_results; i++) {
        String workspace_uri = workspace_uris[i];
        Dictionary workspace = workspace_folders[workspace_uri];
        Array workspace_symbols = workspace["symbols"];
        
        for (int j = 0; j < workspace_symbols.size() && results.size() < max_results; j++) {
            Dictionary symbol = workspace_symbols[j];
            String symbol_name = symbol["name"];
            
            if (query.is_empty() || symbol_name.to_lower().contains(query.to_lower())) {
                results.push_back(symbol);
            }
        }
    }
    
    return results;
}

void VisualGasicLSP::analyze_file(const String& uri, const String& content) {
    Dictionary doc_info;
    doc_info["uri"] = uri;
    doc_info["content"] = content;
    doc_info["timestamp"] = Time::get_singleton()->get_unix_time_from_system();
    
    // Syntax analysis
    Array syntax_errors = analyze_syntax_errors(content);
    Array semantic_errors = analyze_semantic_errors(uri, content);
    
    Array all_diagnostics;
    for (int i = 0; i < syntax_errors.size(); i++) {
        all_diagnostics.push_back(syntax_errors[i]);
    }
    for (int i = 0; i < semantic_errors.size(); i++) {
        all_diagnostics.push_back(semantic_errors[i]);
    }
    
    file_diagnostics[uri] = all_diagnostics;
    
    // Symbol extraction (simplified)
    Array symbols;
    // Parse and extract symbols from content
    // This would involve parsing the AST and extracting function/variable definitions
    
    doc_info["symbols"] = symbols;
    doc_info["diagnostics"] = all_diagnostics;
    
    parse_cache[uri] = doc_info;
    
    // Update workspace symbol index
    String workspace_uri = find_workspace_for_uri(uri);
    if (!workspace_uri.is_empty()) {
        update_symbol_index(workspace_uri, symbols);
    }
}

Array VisualGasicLSP::analyze_completions_at_position(const String& content, const Position& position) {
    Array completions;
    
    // Get context at position
    String word = get_word_at_position(content, position);
    String line_content = get_line_at_position(content, position);
    
    // Add keyword completions
    Array keywords = get_keyword_completions(line_content);
    for (int i = 0; i < keywords.size(); i++) {
        completions.push_back(keywords[i]);
    }
    
    // Add symbol completions
    Array workspace_uris = workspace_folders.keys();
    for (int i = 0; i < workspace_uris.size(); i++) {
        String workspace_uri = workspace_uris[i];
        Array symbols = get_symbol_completions(workspace_uri, word);
        for (int j = 0; j < symbols.size(); j++) {
            completions.push_back(symbols[j]);
        }
    }
    
    // Add built-in function completions
    Array builtins = get_builtin_functions();
    for (int i = 0; i < builtins.size(); i++) {
        Dictionary builtin = builtins[i];
        String name = builtin["name"];
        if (name.to_lower().begins_with(word.to_lower())) {
            CompletionItem item = create_completion_item(name, "function", 
                builtin["detail"], builtin["documentation"]);
            
            Dictionary item_dict;
            item_dict["label"] = item.label;
            item_dict["kind"] = item.kind;
            item_dict["detail"] = item.detail;
            item_dict["documentation"] = item.documentation;
            completions.push_back(item_dict);
        }
    }
    
    return completions;
}

VisualGasicLSP::CompletionItem VisualGasicLSP::create_completion_item(const String& label, const String& kind, 
                                                                     const String& detail, const String& documentation) {
    CompletionItem item;
    item.label = label;
    item.kind = kind;
    item.detail = detail;
    item.documentation = documentation;
    item.insert_text = label;
    item.filter_text = label;
    return item;
}

Array VisualGasicLSP::get_keyword_completions(const String& context) {
    Array completions;
    
    Vector<String> keywords = {
        "Async", "Await", "Task", "Parallel", "Select", "Match", "Case", "When", "Else",
        "If", "Then", "ElseIf", "End", "For", "Next", "While", "Do", "Loop", "Until",
        "Sub", "Function", "Property", "Class", "Module", "Interface", "Inherits",
        "Implements", "Dim", "Const", "Static", "Private", "Public", "Protected",
        "Friend", "Shared", "Overrides", "Overridable", "MustOverride", "NotOverridable",
        "Return", "Exit", "Continue", "Try", "Catch", "Finally", "Throw", "Using",
        "With", "End", "As", "Of", "Where", "Is", "IsNot", "TypeOf", "GetType",
        "DirectCast", "TryCast", "CType", "New", "Me", "MyBase", "MyClass"
    };
    
    for (int i = 0; i < keywords.size(); i++) {
        CompletionItem item = create_completion_item(keywords[i], "keyword");
        
        Dictionary item_dict;
        item_dict["label"] = item.label;
        item_dict["kind"] = item.kind;
        item_dict["sortText"] = "0" + keywords[i]; // High priority
        completions.push_back(item_dict);
    }
    
    return completions;
}

void VisualGasicLSP::initialize_builtin_symbols() {
    // This would populate built-in functions, types, and constants
    // For brevity, just adding a few examples
}

Array VisualGasicLSP::get_builtin_functions() {
    Array functions;
    
    // Example built-in functions
    Dictionary print_func;
    print_func["name"] = "Print";
    print_func["detail"] = "Sub Print(value As Object)";
    print_func["documentation"] = "Prints a value to the console";
    functions.push_back(print_func);
    
    Dictionary len_func;
    len_func["name"] = "Len";
    len_func["detail"] = "Function Len(value As String) As Integer";
    len_func["documentation"] = "Returns the length of a string";
    functions.push_back(len_func);
    
    return functions;
}

// Utility method implementations
String VisualGasicLSP::get_word_at_position(const String& content, const Position& position) {
    Array lines = content.split("\n");
    if (position.line >= lines.size()) {
        return "";
    }
    
    String line = lines[position.line];
    if (position.character >= line.length()) {
        return "";
    }
    
    // Find word boundaries
    int start = position.character;
    int end = position.character;
    
    while (start > 0 && (line[start - 1].is_alnum() || line[start - 1] == '_')) {
        start--;
    }
    
    while (end < line.length() && (line[end].is_alnum() || line[end] == '_')) {
        end++;
    }
    
    return line.substr(start, end - start);
}

String VisualGasicLSP::get_line_at_position(const String& content, const Position& position) {
    Array lines = content.split("\n");
    if (position.line >= lines.size()) {
        return "";
    }
    return lines[position.line];
}

String VisualGasicLSP::find_workspace_for_uri(const String& uri) {
    Array workspace_uris = workspace_folders.keys();
    for (int i = 0; i < workspace_uris.size(); i++) {
        String workspace_uri = workspace_uris[i];
        if (uri.begins_with(workspace_uri)) {
            return workspace_uri;
        }
    }
    return "";
}

void VisualGasicLSP::find_source_files(const String& directory, Array& files) {
    Ref<DirAccess> dir = DirAccess::open(directory);
    if (!dir.is_valid()) {
        return;
    }
    
    dir->list_dir_begin();
    String file_name = dir->get_next();
    
    while (!file_name.is_empty()) {
        String full_path = directory + "/" + file_name;
        
        if (dir->current_is_dir() && !file_name.begins_with(".")) {
            find_source_files(full_path, files);
        } else if (file_name.ends_with(".bas") || file_name.ends_with(".vb")) {
            files.push_back(full_path);
        }
        
        file_name = dir->get_next();
    }
}

// Simplified implementations for other methods
VisualGasicLSP::Symbol VisualGasicLSP::resolve_symbol_at_position(const String& uri, const Position& position) {
    Symbol symbol;
    
    // Try to get cached parse result for this file
    if (parse_cache.has(uri)) {
        Dictionary cached = parse_cache[uri];
        if (cached.has("content")) {
            String content = cached["content"];
            symbol.name = get_word_at_position(content, position);
            
            // Look up symbol in the symbol index
            if (cached.has("symbols")) {
                Array symbols = cached["symbols"];
                for (int i = 0; i < symbols.size(); i++) {
                    Dictionary sym = symbols[i];
                    if (sym.has("name") && String(sym["name"]).nocasecmp_to(symbol.name) == 0) {
                        symbol.type_info = sym.has("type") ? String(sym["type"]) : "Unknown";
                        symbol.documentation = sym.has("doc") ? String(sym["doc"]) : "";
                        if (sym.has("line")) {
                            symbol.location.uri = uri;
                            symbol.location.line = sym["line"];
                        }
                        break;
                    }
                }
            }
        }
    }
    
    return symbol;
}

Array VisualGasicLSP::find_symbol_references(const String& symbol_name, const String& workspace_uri) {
    return Array(); // Simplified
}

String VisualGasicLSP::get_symbol_hover_text(const Symbol& symbol) {
    return symbol.name + " : " + symbol.type_info + "\n" + symbol.documentation;
}

Array VisualGasicLSP::analyze_syntax_errors(const String& content) {
    return Array(); // Simplified - would use actual parser
}

Array VisualGasicLSP::analyze_semantic_errors(const String& uri, const String& content) {
    return Array(); // Simplified - would do semantic analysis
}

void VisualGasicLSP::update_symbol_index(const String& workspace_uri, const Array& symbols) {
    if (workspace_folders.has(workspace_uri)) {
        Dictionary workspace = workspace_folders[workspace_uri];
        workspace["symbols"] = symbols;
        workspace_folders[workspace_uri] = workspace;
    }
}

Array VisualGasicLSP::get_symbol_completions(const String& workspace_uri, const String& prefix) {
    return Array(); // Simplified
}

void VisualGasicLSP::invalidate_cache(const String& uri) {
    if (parse_cache.has(uri)) {
        parse_cache.erase(uri);
    }
    
    // Clear completion cache for this URI
    Array cache_keys = completion_cache.keys();
    for (int i = 0; i < cache_keys.size(); i++) {
        String key = cache_keys[i];
        if (key.begins_with(uri + ":")) {
            completion_cache.erase(key);
        }
    }
}

void VisualGasicLSP::cleanup_old_cache_entries() {
    // Clean up old cache entries based on timestamp
    // Implementation would check timestamps and remove old entries
}

void VisualGasicLSP::update_settings(const Dictionary& new_settings) {
    Array keys = new_settings.keys();
    for (int i = 0; i < keys.size(); i++) {
        String key = keys[i];
        settings[key] = new_settings[key];
    }
}