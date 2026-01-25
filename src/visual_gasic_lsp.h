#ifndef VISUAL_GASIC_LSP_H
#define VISUAL_GASIC_LSP_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include "visual_gasic_parser.h"
#include <vector>
#include <map>

using namespace godot;

/**
 * VisualGasic Language Server Protocol Implementation
 * 
 * Provides intelligent code analysis, completion, and navigation:
 * - Real-time syntax analysis
 * - Smart code completion with context awareness
 * - Go-to-definition and find references
 * - Hover documentation
 * - Error diagnostics and suggestions
 * - Symbol indexing across projects
 */
class VisualGasicLSP : public RefCounted {
    GDCLASS(VisualGasicLSP, RefCounted)

public:
    // LSP Data Structures
    struct Position {
        int line = 0;
        int character = 0;
    };
    
    struct Range {
        Position start;
        Position end;
    };
    
    struct Location {
        String uri;
        Range range;
    };
    
    struct Symbol {
        String name;
        String kind; // "function", "variable", "class", "module", etc.
        String detail;
        String documentation;
        Location location;
        String type_info;
        Array parameters; // For functions
        bool is_public = true;
    };
    
    struct Diagnostic {
        Range range;
        String message;
        String severity; // "error", "warning", "info", "hint"
        String code;
        String source = "VisualGasic";
    };
    
    struct CompletionItem {
        String label;
        String kind; // "function", "variable", "keyword", "snippet", etc.
        String detail;
        String documentation;
        String insert_text;
        String filter_text;
        int sort_text_priority = 50;
        bool preselect = false;
    };
    
    struct WorkspaceFolder {
        String uri;
        String name;
        Array symbols;
        Dictionary file_cache;
    };

private:
    // LSP State
    Dictionary workspace_folders;
    Dictionary symbol_index; // Global symbol index
    Dictionary file_diagnostics;
    VisualGasicParser parser;
    
    // Analysis Cache
    Dictionary parse_cache;
    Dictionary completion_cache;
    
    // Configuration
    Dictionary settings;
    bool enable_diagnostics = true;
    bool enable_completion = true;
    bool enable_hover = true;
    bool enable_references = true;

public:
    VisualGasicLSP();
    ~VisualGasicLSP();
    
    // LSP Lifecycle
    bool initialize(const Dictionary& init_params);
    void shutdown();
    
    // Workspace Management
    void add_workspace_folder(const String& uri, const String& name);
    void remove_workspace_folder(const String& uri);
    void index_workspace(const String& workspace_uri);
    
    // Document Management
    void open_document(const String& uri, const String& content);
    void close_document(const String& uri);
    void change_document(const String& uri, const String& content);
    Array get_diagnostics(const String& uri);
    
    // Language Features
    Array get_completions(const String& uri, const Position& position, const String& trigger_character = "");
    Dictionary get_hover_info(const String& uri, const Position& position);
    Array get_definitions(const String& uri, const Position& position);
    Array get_references(const String& uri, const Position& position, bool include_declaration = true);
    Array get_document_symbols(const String& uri);
    Array get_workspace_symbols(const String& query = "");
    
    // Code Actions
    Array get_code_actions(const String& uri, const Range& range);
    Dictionary format_document(const String& uri);
    Dictionary rename_symbol(const String& uri, const Position& position, const String& new_name);
    
    // Analysis
    void analyze_file(const String& uri, const String& content);
    void update_symbol_index(const String& uri, const Array& symbols);
    Array extract_symbols_from_ast(Node* ast_root, const String& uri);
    
    // Configuration
    void update_settings(const Dictionary& new_settings);
    Dictionary get_current_settings();

protected:
    static void _bind_methods();

private:
    // Internal Analysis Methods
    Array analyze_completions_at_position(const String& content, const Position& position);
    CompletionItem create_completion_item(const String& label, const String& kind, 
                                         const String& detail = "", const String& documentation = "");
    Array get_keyword_completions(const String& context);
    Array get_symbol_completions(const String& workspace_uri, const String& prefix);
    Array get_member_completions(const String& object_type, const String& prefix);
    
    // Symbol Resolution
    Symbol resolve_symbol_at_position(const String& uri, const Position& position);
    Array find_symbol_references(const String& symbol_name, const String& workspace_uri);
    String get_symbol_hover_text(const Symbol& symbol);
    
    // Diagnostics
    Array analyze_syntax_errors(const String& content);
    Array analyze_semantic_errors(const String& uri, const String& content);
    Diagnostic create_diagnostic(const Range& range, const String& message, const String& severity);
    
    // Utility Methods
    Position offset_to_position(const String& content, int offset);
    int position_to_offset(const String& content, const Position& position);
    String get_word_at_position(const String& content, const Position& position);
    Range get_word_range_at_position(const String& content, const Position& position);
    
    // Cache Management
    void invalidate_cache(const String& uri);
    void cleanup_old_cache_entries();
    
    // Built-in Symbol Database
    void initialize_builtin_symbols();
    Array get_builtin_functions();
    Array get_builtin_types();
    Array get_builtin_keywords();
};

#endif // VISUAL_GASIC_LSP_H