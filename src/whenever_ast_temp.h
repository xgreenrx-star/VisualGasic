// Temporary file to test the AST additions
struct WheneverSectionStatement : Statement {
    Vector<WatcherInfo> watchers;
    
    WheneverSectionStatement() { type = STMT_WHENEVER_SECTION; }
};

struct WheneverSuspendStatement : Statement {
    String variable_name;
    
    WheneverSuspendStatement() { type = STMT_WHENEVER_SUSPEND; }
};

struct WheneverResumeStatement : Statement {
    String variable_name;
    
    WheneverResumeStatement() { type = STMT_WHENEVER_RESUME; }
};

struct WatcherInfo {
    String variable_name;
    String watch_type; // "Changes", "Becomes", "Exceeds"
    String callback_name;
    Variant threshold_value; // For "Becomes", "Exceeds"
};