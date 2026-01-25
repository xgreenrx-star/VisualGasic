#ifndef VISUAL_GASIC_AST_H
#define VISUAL_GASIC_AST_H

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/templates/vector.hpp>
#include <godot_cpp/variant/variant.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <stdio.h>

using namespace godot;

// Forward declaration
struct ExpressionNode;

enum StatementType {
    STMT_PRINT,
    STMT_DIM,
    STMT_ASSIGNMENT,
    STMT_IF,
    STMT_FOR,
    STMT_WHILE,
    STMT_DO,
    STMT_CALL,
    STMT_LABEL,
    STMT_GOTO,
    STMT_ON_ERROR,
    STMT_SELECT,
    STMT_OPEN,
    STMT_CLOSE,
    STMT_INPUT, // Input # or Input
    STMT_EXIT,
    STMT_RETURN,
    STMT_CONTINUE,
    STMT_RAISE_EVENT,
    STMT_REDIM,
    STMT_FOR_EACH,
    STMT_WITH,
    STMT_CONST,
    STMT_DO_EVENTS,
    STMT_DATA,
    STMT_READ,
    STMT_RESTORE,
    STMT_LOAD_DATA,
    STMT_SEEK,
    STMT_KILL,
    STMT_NAME,
    STMT_TRY,
    STMT_PASS,
    STMT_RAISE,
    STMT_WHENEVER_SECTION,
    STMT_SUSPEND_WHENEVER,
    STMT_RESUME_WHENEVER,
    STMT_UNKNOWN
};

struct ASTNode {
    virtual ~ASTNode() {}
};

// Expression Nodes
struct ExpressionNode {
    enum Type { LITERAL, VARIABLE, BINARY_OP, UNARY_OP, EXPRESSION_CALL, MEMBER_ACCESS, ARRAY_ACCESS, ME, SUPER, NEW, WITH_CONTEXT, EXPRESSION_IIF } type;
    virtual ~ExpressionNode() {}
    
    virtual ExpressionNode* duplicate() {
        return nullptr; // Base impl returns null or handle unknown types gracefully
    }
};

struct NewNode : public ExpressionNode {
    String class_name;
    Vector<ExpressionNode*> args;
    NewNode() { type = NEW; }
    virtual ~NewNode() {
        for(int i=0; i<args.size(); i++) if(args[i]) delete args[i];
    }
    virtual ExpressionNode* duplicate() override {
        NewNode* n = new NewNode();
        n->class_name = class_name;
        for(int i=0; i<args.size(); i++) n->args.push_back(args[i]->duplicate());
        return n;
    }
};

struct MeNode : public ExpressionNode {
    MeNode() { type = ME; }
    virtual ExpressionNode* duplicate() override { return new MeNode(); }
};

struct SuperNode : public ExpressionNode {
    SuperNode() { type = SUPER; }
    virtual ExpressionNode* duplicate() override { return new SuperNode(); }
};


struct LiteralNode : public ExpressionNode {
    Variant value;
    LiteralNode() { type = LITERAL; }
    virtual ExpressionNode* duplicate() override {
        LiteralNode* l = new LiteralNode();
        l->value = value;
        return l;
    }
};

struct VariableNode : public ExpressionNode {
    String name;
    VariableNode() { type = VARIABLE; }
    virtual ExpressionNode* duplicate() override {
        VariableNode* v = new VariableNode();
        v->name = name;
        return v;
    }
};

struct BinaryOpNode : public ExpressionNode {
    // Legacy String 'op' was causing issues with re-declaration if I added Enum.
    // I will revert to String 'op' for compatibility with Parser/Compiler existing logic
    // but I will add constants for clarity if needed, or just use string literals.
    
    // To support the new parser logic, I will use String op.
    String op; 
    
    ExpressionNode* left;
    ExpressionNode* right;
    
    BinaryOpNode() { type = BINARY_OP; left=nullptr; right=nullptr; op="+"; }
    virtual ~BinaryOpNode() { 
        if(left) delete left;
        if(right) delete right; 
    }
    
    virtual ExpressionNode* duplicate() override {
        BinaryOpNode* b = new BinaryOpNode();
        b->op = op;
        if(left) b->left = left->duplicate();
        if(right) b->right = right->duplicate();
        return b;
    }
};

struct UnaryOpNode : public ExpressionNode {
    String op;
    ExpressionNode* operand;
    UnaryOpNode() { type = UNARY_OP; operand=nullptr; }
    virtual ~UnaryOpNode() {
        if(operand) delete operand;
    }
    virtual ExpressionNode* duplicate() override {
        UnaryOpNode* u = new UnaryOpNode();
        u->op = op;
        if(operand) u->operand = operand->duplicate();
        return u;
    }
};

struct CallExpression : public ExpressionNode {
    ExpressionNode* base_object; // Optional base
    String method_name;
    Vector<ExpressionNode*> arguments;
    CallExpression() { type = EXPRESSION_CALL; base_object=nullptr; }
    virtual ~CallExpression() {
        if (base_object) delete base_object;
        for(int i=0; i<arguments.size(); i++) {
            if (arguments[i]) delete arguments[i];
        }
    }
    virtual ExpressionNode* duplicate() override {
        CallExpression* c = new CallExpression();
        c->method_name = method_name;
        if(base_object) c->base_object = base_object->duplicate();
        for(int i=0; i<arguments.size(); i++) c->arguments.push_back(arguments[i]->duplicate());
        return c;
    }
};

struct IIfNode : public ExpressionNode {
    ExpressionNode* condition;
    ExpressionNode* true_part;
    ExpressionNode* false_part;
    
    IIfNode() { type = EXPRESSION_IIF; condition=nullptr; true_part=nullptr; false_part=nullptr; }
    virtual ~IIfNode() {
        if(condition) delete condition;
        if(true_part) delete true_part;
        if(false_part) delete false_part;
    }
    virtual ExpressionNode* duplicate() override {
         IIfNode* n = new IIfNode();
         if(condition) n->condition = condition->duplicate();
         if(true_part) n->true_part = true_part->duplicate();
         if(false_part) n->false_part = false_part->duplicate();
         return n;
    }
};

struct ArrayAccessNode : public ExpressionNode {
    ExpressionNode* base;
    Vector<ExpressionNode*> indices;
    ArrayAccessNode() { type = ARRAY_ACCESS; base=nullptr; }
    virtual ~ArrayAccessNode() {
        if(base) delete base;
        for(int i=0; i<indices.size(); i++) if(indices[i]) delete indices[i];
    }
    virtual ExpressionNode* duplicate() override {
        ArrayAccessNode* a = new ArrayAccessNode();
        if(base) a->base = base->duplicate();
        for(int i=0; i<indices.size(); i++) a->indices.push_back(indices[i]->duplicate());
        return a;
    }
};

struct MemberAccessNode : public ExpressionNode {
    ExpressionNode* base_object; 
    String member_name;
    
    MemberAccessNode() { type = MEMBER_ACCESS; base_object=nullptr; }
    virtual ~MemberAccessNode() {
        if (base_object) delete base_object;
    }
    virtual ExpressionNode* duplicate() override {
        MemberAccessNode* m = new MemberAccessNode();
        m->member_name = member_name;
        if(base_object) m->base_object = base_object->duplicate();
        return m;
    }
};

struct Statement : public ASTNode {
    StatementType type;
    int line = 0;
    Statement(StatementType t) : type(t) {}
};

struct PrintStatement : public Statement {
    ExpressionNode* expression;
    ExpressionNode* file_number; // Optional, formatted as #N
    PrintStatement() : Statement(STMT_PRINT), expression(nullptr), file_number(nullptr) {}
    virtual ~PrintStatement() { 
        if(expression) delete expression; 
        if(file_number) delete file_number;
    }
};

struct OpenStatement : public Statement {
    enum Mode { MODE_INPUT, MODE_OUTPUT, MODE_APPEND };
    Mode mode;
    ExpressionNode* path;
    ExpressionNode* file_number;
    
    OpenStatement() : Statement(STMT_OPEN), path(nullptr), file_number(nullptr) {}
    ~OpenStatement() {
        if(path) delete path;
        if(file_number) delete file_number;
    }
};

struct CloseStatement : public Statement {
    ExpressionNode* file_number;
    CloseStatement() : Statement(STMT_CLOSE), file_number(nullptr) {}
    ~CloseStatement() {
        if(file_number) delete file_number;
    }
};

struct InputStatement : public Statement {
    ExpressionNode* file_number; // Optional
    Vector<ExpressionNode*> variables; // Targets
    bool is_line_input;
    
    InputStatement() : Statement(STMT_INPUT), file_number(nullptr), is_line_input(false) {}
    ~InputStatement() {
        if(file_number) delete file_number;
        for(int i=0; i<variables.size(); i++) if(variables[i]) delete variables[i];
    }
};

struct ExitStatement : public Statement {
    enum ExitType { EXIT_SUB, EXIT_FUNCTION, EXIT_FOR, EXIT_DO };
    ExitType exit_type;
    ExitStatement() : Statement(STMT_EXIT) {}
};

struct ReturnStatement : public Statement {
    ExpressionNode* return_value;
    ReturnStatement() : Statement(STMT_RETURN) { return_value = nullptr; }
    virtual ~ReturnStatement() { if(return_value) delete return_value; }
};

struct ContinueStatement : public Statement {
    enum LoopType { FOR, DO, WHILE, UNKNOWN } loop_type;
    ContinueStatement() : Statement(STMT_CONTINUE) { loop_type = UNKNOWN; }
};

struct ReDimStatement : public Statement {
    String variable_name;
    Vector<ExpressionNode*> array_sizes;
    bool preserve;
    // Type usually inferred or kept, VB6 doesn't allow changing type on ReDim unless it was Variant. 
    // We can ignore 'As Type' for ReDim for now as parsed.
    
    ReDimStatement() : Statement(STMT_REDIM), preserve(false) {}
    ~ReDimStatement() {
        for(int i=0; i<array_sizes.size(); i++) if(array_sizes[i]) delete array_sizes[i];
    }
};

struct DimStatement : public Statement {
    String variable_name;
    Vector<ExpressionNode*> array_sizes; // Empty if scalar
    String type_name; // "" for Variant/Object, or name of UDT
    ExpressionNode* initializer;
    bool is_static;
    
    DimStatement() : Statement(STMT_DIM) { initializer = nullptr; is_static = false; }
    virtual ~DimStatement() { 
        for(int i=0; i<array_sizes.size(); i++) {
             if (array_sizes[i]) delete array_sizes[i];
        }
        if (initializer) delete initializer;
    }
};

struct ConstStatement : public Statement {
    String name;
    ExpressionNode* value; 
    
    ConstStatement() : Statement(STMT_CONST), value(nullptr) {}
    virtual ~ConstStatement() { if(value) delete value; }
};

struct DoEventsStatement : public Statement {
    DoEventsStatement() : Statement(STMT_DO_EVENTS) {}
};

struct DataStatement : public Statement {
    Vector<ExpressionNode*> values;
    DataStatement() : Statement(STMT_DATA) {}
    ~DataStatement() {
        for(int i=0; i<values.size(); i++) if(values[i]) delete values[i];
    }
};

struct ReadStatement : public Statement {
    Vector<ExpressionNode*> targets;
    ReadStatement() : Statement(STMT_READ) {}
    ~ReadStatement() {
        for(int i=0; i<targets.size(); i++) if(targets[i]) delete targets[i];
    }
};

struct RestoreStatement : public Statement {
    String label_name; // Optional, empty if restoring to start
    RestoreStatement() : Statement(STMT_RESTORE) {}
};

struct AssignmentStatement : public Statement {
    ExpressionNode* target;
    ExpressionNode* value;
    AssignmentStatement() : Statement(STMT_ASSIGNMENT), target(nullptr), value(nullptr) {}
    virtual ~AssignmentStatement() { 
        if(target) delete target;
        if(value) delete value;
    }
};

struct IfStatement : public Statement {
    ExpressionNode* condition;
    Vector<Statement*> then_branch;
    Vector<Statement*> else_branch;
    
    IfStatement() : Statement(STMT_IF), condition(nullptr) {}
    virtual ~IfStatement() { 
        if(condition) delete condition;
        for(int i=0; i<then_branch.size(); i++) delete then_branch[i]; 
        for(int i=0; i<else_branch.size(); i++) delete else_branch[i];
    }
};

struct LoadDataStatement : public Statement {
    ExpressionNode* path_expression;
    LoadDataStatement() : Statement(STMT_LOAD_DATA), path_expression(nullptr) {}
    virtual ~LoadDataStatement() {
        if(path_expression) delete path_expression;
    }
};

struct SeekStatement : public Statement {
    ExpressionNode* file_number;
    ExpressionNode* position;
    
    SeekStatement() : Statement(STMT_SEEK), file_number(nullptr), position(nullptr) {}
    virtual ~SeekStatement() {
        if(file_number) delete file_number;
        if(position) delete position;
    }
};

struct ForStatement : public Statement {
    String variable_name;
    ExpressionNode* from_val;
    ExpressionNode* to_val;
    ExpressionNode* step_val;
    Vector<Statement*> body;
    
    ForStatement() : Statement(STMT_FOR), from_val(nullptr), to_val(nullptr), step_val(nullptr) {}
    virtual ~ForStatement() {
        if(from_val) delete from_val;
        if(to_val) delete to_val;
        if(step_val) delete step_val;
        for(int i=0; i<body.size(); i++) delete body[i];
    }
};

struct WhileStatement : public Statement {
    ExpressionNode* condition;
    Vector<Statement*> body;
    
    WhileStatement() : Statement(STMT_WHILE), condition(nullptr) {}
    virtual ~WhileStatement() {
        if(condition) delete condition;
        for(int i=0; i<body.size(); i++) delete body[i];
    }
};

struct DoStatement : public Statement {
    enum ConditionType { NONE, WHILE, UNTIL };
    ConditionType condition_type;
    bool is_post_condition; // Checked at Loop
    ExpressionNode* condition;
    Vector<Statement*> body;
    
    DoStatement() : Statement(STMT_DO), condition_type(NONE), is_post_condition(false), condition(nullptr) {}
    virtual ~DoStatement() {
        if(condition) delete condition;
        for(int i=0; i<body.size(); i++) delete body[i];
    }
};

struct ForEachStatement : public Statement {
    String variable_name;
    ExpressionNode* collection;
    Vector<Statement*> body;
    
    ForEachStatement() : Statement(STMT_FOR_EACH), collection(nullptr) {}
    virtual ~ForEachStatement() {
        if(collection) delete collection;
        for(int i=0; i<body.size(); i++) delete body[i];
    }
};

struct WithStatement : public Statement {
    ExpressionNode* expression;
    Vector<Statement*> body;
    
    WithStatement() : Statement(STMT_WITH), expression(nullptr) {}
    virtual ~WithStatement() {
        if(expression) delete expression;
        for(int i=0; i<body.size(); i++) delete body[i];
    }
};



struct CallStatement : public Statement {
    ExpressionNode* base_object;
    String method_name;
    Vector<ExpressionNode*> arguments;
    
    CallStatement() : Statement(STMT_CALL), base_object(nullptr) {}
    virtual ~CallStatement() {
        if(base_object) delete base_object;
        for(int i=0; i<arguments.size(); i++) {
            if (arguments[i]) delete arguments[i];
        }
    }
};

struct LabelStatement : public Statement {
    String name;
    LabelStatement() : Statement(STMT_LABEL) {}
};

struct GotoStatement : public Statement {
    String label_name;
    GotoStatement() : Statement(STMT_GOTO) {}
};

struct OnErrorStatement : public Statement {
    enum Mode { RESUME_NEXT, GOTO_LABEL };
    Mode mode;
    String label_name;
    OnErrorStatement() : Statement(STMT_ON_ERROR) {}
};

struct CaseBlock : public ASTNode {
    Vector<ExpressionNode*> values; // Empty for Case Else? Or specific flag?
    bool is_else;
    Vector<Statement*> body;
    
    CaseBlock() : is_else(false) {}
    ~CaseBlock() {
        for(int i=0; i<values.size(); i++) if(values[i]) delete values[i];
        for(int i=0; i<body.size(); i++) if(body[i]) delete body[i];
    }
};

struct SelectStatement : public Statement {
    ExpressionNode* expression;
    Vector<CaseBlock*> cases;
    
    SelectStatement() : Statement(STMT_SELECT), expression(nullptr) {}
    ~SelectStatement() {
        if(expression) delete expression;
        for(int i=0; i<cases.size(); i++) delete cases[i];
    }
};

struct Parameter {
    String name;
    String type_hint; 
    bool is_optional;
    Variant default_value;
    bool is_by_ref;
    bool is_param_array;

    Parameter() : is_optional(false), is_by_ref(true), is_param_array(false) {}
};

struct SubDefinition : public ASTNode {
    enum Type { TYPE_SUB, TYPE_FUNCTION };
    Type type;
    String name;
    Vector<Parameter> parameters;
    String return_type;
    Vector<Statement*> statements;
    Dictionary label_map; // Name -> Index in statements
    
    SubDefinition() : type(TYPE_SUB) {}
    
    ~SubDefinition() {
        for(int i=0; i<statements.size(); i++) if(statements[i]) delete statements[i];
    }
};

struct StructMember {
    String name;
    String type; // "Integer", "String", or UDT name. We might treat simple types as just Variant for now unless we do strict typing.
};

struct StructDefinition : public ASTNode {
    String name;
    Vector<StructMember> members;
};

struct EnumValue {
    String name;
    int value;
};

struct EnumDefinition : public ASTNode {
    String name;
    Vector<EnumValue> values;
};

enum Visibility { VIS_PUBLIC, VIS_PRIVATE, VIS_DIM };

struct VariableDefinition : public ASTNode {
    String name;
    String type;
    Visibility visibility;
    // Arrays?
    Vector<int> array_sizes; // if array
};

struct EventDefinition : public ASTNode {
    String name;
    Vector<String> arguments;
};

struct RaiseEventStatement : public Statement {
    String expression_name;
    Vector<ExpressionNode*> arguments;
    RaiseEventStatement() : Statement(STMT_RAISE_EVENT) {}
    ~RaiseEventStatement() {
         for(int i=0; i<arguments.size(); i++) if(arguments[i]) delete arguments[i];
    }
};

struct KillStatement : public Statement {
    ExpressionNode* path;
    KillStatement() : Statement(STMT_KILL) { path = nullptr; }
    virtual ~KillStatement() {
        if (path) delete path;
    }
};

struct NameStatement : public Statement {
    ExpressionNode* old_path;
    ExpressionNode* new_path;
    NameStatement() : Statement(STMT_NAME) { old_path=nullptr; new_path=nullptr; }
    virtual ~NameStatement() {
        if(old_path) delete old_path;
        if(new_path) delete new_path;
    }
};

struct TryStatement : public Statement {
    Vector<Statement*> try_block;
    Vector<Statement*> catch_block;
    Vector<Statement*> finally_block;
    String catch_var_name;
    
    TryStatement() : Statement(STMT_TRY) {}
    ~TryStatement() {
        for(int i=0; i<try_block.size(); i++) if(try_block[i]) delete try_block[i];
        for(int i=0; i<catch_block.size(); i++) if(catch_block[i]) delete catch_block[i];
        for(int i=0; i<finally_block.size(); i++) if(finally_block[i]) delete finally_block[i];
    }
};

struct RaiseStatement : public Statement {
    ExpressionNode* code;
    ExpressionNode* msg;
    // Backwards-compatible aliases used in other code: `error_code` and `message`.
    ExpressionNode*& error_code;
    ExpressionNode*& message;
    RaiseStatement() : Statement(STMT_RAISE), error_code(code), message(msg) { code=nullptr; msg=nullptr; } 
    virtual ~RaiseStatement() {
        if(code) delete code;
        if(msg) delete msg;
    }
};

struct PassStatement : public Statement { 
    PassStatement() : Statement(STMT_PASS) {} 
};

struct WheneverSectionStatement : public Statement {
    String section_name;
    String variable_name;
    String comparison_operator;  // "Changes", "Becomes", "Exceeds", "Below", "Between", "Contains"
    ExpressionNode* comparison_value;
    ExpressionNode* comparison_value2;  // For "Between" operator
    ExpressionNode* condition_expression;  // For complex conditions like (health < 10 And stamina < 5)
    Vector<String> callback_procedures;  // Support multiple callbacks
    bool is_local_scope;  // True if declared with "Local" keyword
    
    WheneverSectionStatement() : Statement(STMT_WHENEVER_SECTION), is_local_scope(false) {
        comparison_value = nullptr;
        comparison_value2 = nullptr;
        condition_expression = nullptr;
    }
    
    virtual ~WheneverSectionStatement() {
        if(comparison_value) delete comparison_value;
        if(comparison_value2) delete comparison_value2;
        if(condition_expression) delete condition_expression;
    }
};

struct SuspendWheneverStatement : public Statement {
    String section_name;
    
    SuspendWheneverStatement() : Statement(STMT_SUSPEND_WHENEVER) {}
};

struct ResumeWheneverStatement : public Statement {
    String section_name;
    
    ResumeWheneverStatement() : Statement(STMT_RESUME_WHENEVER) {}
};

struct ModuleNode {
    bool option_explicit;
    bool option_compare_text;
    String inherits_path; // For inheritance
    Vector<EventDefinition*> events;
    Vector<SubDefinition*> subs;
    Vector<StructDefinition*> structs;
    Vector<EnumDefinition*> enums;
    Vector<VariableDefinition*> variables; // Module level variables
    Vector<ConstStatement*> constants; // Module level constants
    Vector<Statement*> global_statements; // For Data and Labels at module level
    
    ModuleNode() { option_explicit = false; option_compare_text = false; }

    ~ModuleNode() {
        for(int i=0; i<events.size(); i++) if(events[i]) delete events[i];
        for(int i=0; i<subs.size(); i++) if(subs[i]) delete subs[i];
        for(int i=0; i<structs.size(); i++) if(structs[i]) delete structs[i];
        for(int i=0; i<enums.size(); i++) if(enums[i]) delete enums[i];
        for(int i=0; i<variables.size(); i++) if(variables[i]) delete variables[i];
        for(int i=0; i<constants.size(); i++) if(constants[i]) delete constants[i];
        for(int i=0; i<global_statements.size(); i++) if(global_statements[i]) delete global_statements[i];
    }
};

#endif // VISUAL_GASIC_AST_H
