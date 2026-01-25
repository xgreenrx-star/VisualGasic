#ifndef VISUAL_GASIC_ERROR_REPORTER_H
#define VISUAL_GASIC_ERROR_REPORTER_H

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/templates/vector.hpp>
#include <godot_cpp/variant/string.hpp>

using namespace godot;

class VisualGasicErrorReporter {
public:
    enum ErrorSeverity {
        SEVERITY_INFO,
        SEVERITY_WARNING,
        SEVERITY_ERROR
    };

    struct CompileError {
        ErrorSeverity severity;
        String message;
        String filename;
        int line;
        int column;
        String code_context; // Line of code where error occurred
        
        CompileError() : severity(SEVERITY_ERROR), line(0), column(0) {}
        
        CompileError(ErrorSeverity p_severity, const String& p_message, 
                     const String& p_filename, int p_line, int p_column,
                     const String& p_context = "")
            : severity(p_severity), message(p_message), filename(p_filename),
              line(p_line), column(p_column), code_context(p_context) {}
    };

private:
    Vector<CompileError> errors;
    Vector<CompileError> warnings;
    bool stop_on_error;

public:
    VisualGasicErrorReporter() : stop_on_error(true) {}

    void clear() {
        errors.clear();
        warnings.clear();
    }

    void add_error(const String& message, const String& filename, int line, int column, const String& context = "") {
        errors.push_back(CompileError(SEVERITY_ERROR, message, filename, line, column, context));
    }

    void add_warning(const String& message, const String& filename, int line, int column, const String& context = "") {
        warnings.push_back(CompileError(SEVERITY_WARNING, message, filename, line, column, context));
    }

    void add_info(const String& message, const String& filename, int line, int column, const String& context = "") {
        warnings.push_back(CompileError(SEVERITY_INFO, message, filename, line, column, context));
    }

    bool has_errors() const { return errors.size() > 0; }
    bool has_warnings() const { return warnings.size() > 0; }
    
    int error_count() const { return errors.size(); }
    int warning_count() const { return warnings.size(); }
    
    Vector<CompileError> get_errors() const { return errors; }
    Vector<CompileError> get_warnings() const { return warnings; }

    String format_error(const CompileError& err) const {
        String result = "";
        
        // Format: "filename:line:column: [ERROR/WARNING] message"
        result += err.filename;
        result += ":";
        result += String::num(err.line);
        result += ":";
        result += String::num(err.column);
        result += ": ";
        
        switch(err.severity) {
            case SEVERITY_ERROR:
                result += "[ERROR] ";
                break;
            case SEVERITY_WARNING:
                result += "[WARNING] ";
                break;
            case SEVERITY_INFO:
                result += "[INFO] ";
                break;
        }
        
        result += err.message;
        
        if (!err.code_context.is_empty()) {
            result += "\n    ";
            result += err.code_context;
        }
        
        return result;
    }

    String format_all_errors() const {
        String result = "";
        
        for (const CompileError& err : errors) {
            result += format_error(err);
            result += "\n";
        }
        
        for (const CompileError& warn : warnings) {
            result += format_error(warn);
            result += "\n";
        }
        
        return result;
    }

    void print_errors() const {
        for (const CompileError& err : errors) {
            UtilityFunctions::printerr(format_error(err));
        }
        
        for (const CompileError& warn : warnings) {
            UtilityFunctions::print(format_error(warn));
        }
    }
};

#endif // VISUAL_GASIC_ERROR_REPORTER_H
