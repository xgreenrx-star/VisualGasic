#include "visual_gasic_snippets.h"
#include <godot_cpp/variant/utility_functions.hpp>

Array* SnippetHelper::snippets = nullptr;
Dictionary* SnippetHelper::parameter_hints = nullptr;
bool SnippetHelper::initialized = false;

void SnippetHelper::initialize_snippets() {
    if (initialized) return;
    
    // Lazy initialize
    if (!snippets) {
        snippets = memnew(Array);
    }
    if (!parameter_hints) {
        parameter_hints = memnew(Dictionary);
    }
    
    snippets->clear();
    
    // For loop with index
    Dictionary fori;
    fori["trigger"] = "fori";
    fori["description"] = "For loop with index";
    fori["insert_text"] = "For i = 1 To 10\n\t\nNext i";
    snippets->push_back(fori);
    
    // For loop reverse
    Dictionary forr;
    forr["trigger"] = "forr";
    forr["description"] = "For loop reverse";
    forr["insert_text"] = "For i = 10 To 1 Step -1\n\t\nNext i";
    snippets->push_back(forr);
    
    // For Each loop
    Dictionary fore;
    fore["trigger"] = "fore";
    fore["description"] = "For Each loop";
    fore["insert_text"] = "For Each item In collection\n\t\nNext item";
    snippets->push_back(fore);
    
    // While loop
    Dictionary whil;
    whil["trigger"] = "whil";
    whil["description"] = "While loop";
    whil["insert_text"] = "While condition\n\t\nWend";
    snippets->push_back(whil);
    
    // Do While loop
    Dictionary dow;
    dow["trigger"] = "dow";
    dow["description"] = "Do While loop";
    dow["insert_text"] = "Do While condition\n\t\nLoop";
    snippets->push_back(dow);
    
    // Do Until loop
    Dictionary dou;
    dou["trigger"] = "dou";
    dou["description"] = "Do Until loop";
    dou["insert_text"] = "Do Until condition\n\t\nLoop";
    snippets->push_back(dou);
    
    // If Then Else
    Dictionary ife;
    ife["trigger"] = "ife";
    ife["description"] = "If Then Else";
    ife["insert_text"] = "If condition Then\n\t\nElse\n\t\nEnd If";
    snippets->push_back(ife);
    
    // If Then
    Dictionary ift;
    ift["trigger"] = "ift";
    ift["description"] = "If Then";
    ift["insert_text"] = "If condition Then\n\t\nEnd If";
    snippets->push_back(ift);
    
    // Select Case
    Dictionary selc;
    selc["trigger"] = "selc";
    selc["description"] = "Select Case";
    selc["insert_text"] = "Select Case variable\n\tCase value1\n\t\t\n\tCase value2\n\t\t\n\tCase Else\n\t\t\nEnd Select";
    snippets->push_back(selc);
    
    // Try Catch
    Dictionary tryc;
    tryc["trigger"] = "tryc";
    tryc["description"] = "Try Catch";
    tryc["insert_text"] = "Try\n\t\nCatch ex As Exception\n\tPrint ex.Message\nEnd Try";
    snippets->push_back(tryc);
    
    // Try Catch Finally
    Dictionary trycf;
    trycf["trigger"] = "trycf";
    trycf["description"] = "Try Catch Finally";
    trycf["insert_text"] = "Try\n\t\nCatch ex As Exception\n\tPrint ex.Message\nFinally\n\t\nEnd Try";
    snippets->push_back(trycf);
    
    // Sub procedure
    Dictionary sub;
    sub["trigger"] = "sub";
    sub["description"] = "Sub procedure";
    sub["insert_text"] = "Sub ProcedureName()\n\t\nEnd Sub";
    snippets->push_back(sub);
    
    // Function
    Dictionary func;
    func["trigger"] = "func";
    func["description"] = "Function";
    func["insert_text"] = "Function FunctionName() As Variant\n\t\n\tReturn Nothing\nEnd Function";
    snippets->push_back(func);
    
    // Property Get
    Dictionary propg;
    propg["trigger"] = "propg";
    propg["description"] = "Property Get";
    propg["insert_text"] = "Property Get PropertyName() As Variant\n\tReturn _value\nEnd Property";
    snippets->push_back(propg);
    
    // Property Set
    Dictionary props;
    props["trigger"] = "props";
    props["description"] = "Property Set";
    props["insert_text"] = "Property Set PropertyName(value As Variant)\n\t_value = value\nEnd Property";
    snippets->push_back(props);
    
    // Class
    Dictionary cls;
    cls["trigger"] = "cls";
    cls["description"] = "Class definition";
    cls["insert_text"] = "Class ClassName\n\tPrivate _value As Variant\n\t\n\tSub New()\n\t\t\n\tEnd Sub\nEnd Class";
    snippets->push_back(cls);
    
    // With block
    Dictionary wit;
    wit["trigger"] = "wit";
    wit["description"] = "With block";
    wit["insert_text"] = "With object\n\t.Property = value\nEnd With";
    snippets->push_back(wit);
    
    // Main function
    Dictionary main;
    main["trigger"] = "main";
    main["description"] = "Main entry point";
    main["insert_text"] = "Sub Main()\n\t\nEnd Sub";
    snippets->push_back(main);
    
    initialized = true;
}

void SnippetHelper::initialize_parameter_hints() {
    parameter_hints->clear();
    
    // Common VisualGasic functions
    (*parameter_hints)["CreateActor2D"] = "CreateActor2D(name As String, x As Double, y As Double) As Node2D";
    (*parameter_hints)["LoadForm"] = "LoadForm(formName As String) As Form";
    (*parameter_hints)["MsgBox"] = "MsgBox(message As String, buttons As Integer, title As String) As Integer";
    (*parameter_hints)["Print"] = "Print(value As Variant)";
    (*parameter_hints)["Input"] = "Input(prompt As String) As String";
    (*parameter_hints)["Format"] = "Format(value As Variant, formatString As String) As String";
    (*parameter_hints)["RandRange"] = "RandRange(min As Double, max As Double) As Double";
    (*parameter_hints)["Lerp"] = "Lerp(from As Double, to As Double, weight As Double) As Double";
    (*parameter_hints)["Clamp"] = "Clamp(value As Double, min As Double, max As Double) As Double";
    (*parameter_hints)["DrawText"] = "DrawText(text As String, x As Double, y As Double, color As Color)";
    (*parameter_hints)["DrawString"] = "DrawString(text As String, x As Double, y As Double, color As Color, [fontSize As Integer])";
    (*parameter_hints)["DrawLine"] = "DrawLine(x1 As Double, y1 As Double, x2 As Double, y2 As Double, color As Color, [width As Double])";
    (*parameter_hints)["DrawRect"] = "DrawRect(x As Double, y As Double, width As Double, height As Double, color As Color, [filled As Boolean])";
    (*parameter_hints)["DrawCircle"] = "DrawCircle(x As Double, y As Double, radius As Double, color As Color)";
    (*parameter_hints)["DrawPixel"] = "DrawPixel(x As Double, y As Double, color As Color)";
    (*parameter_hints)["PSet"] = "PSet(x As Double, y As Double, color As Color)";
    (*parameter_hints)["DrawTexture"] = "DrawTexture(texture As Texture2D, x As Double, y As Double, [modulate As Color])";
    (*parameter_hints)["DrawTextureRect"] = "DrawTextureRect(texture As Texture2D, x As Double, y As Double, w As Double, h As Double, [tile As Boolean], [modulate As Color])";
    (*parameter_hints)["DrawArc"] = "DrawArc(x As Double, y As Double, radius As Double, startAngle As Double, endAngle As Double, [pointCount As Integer], [color As Color], [width As Double])";
    (*parameter_hints)["DrawPolygon"] = "DrawPolygon(points As Array, color As Color)";
    (*parameter_hints)["DrawPolyline"] = "DrawPolyline(points As Array, color As Color, [width As Double])";
    (*parameter_hints)["SetDrawTransform"] = "SetDrawTransform(x As Double, y As Double, [rotation As Double], [scaleX As Double], [scaleY As Double])";
    (*parameter_hints)["ResetDrawTransform"] = "ResetDrawTransform()";
    (*parameter_hints)["QueueRedraw"] = "QueueRedraw()";
    (*parameter_hints)["CLS"] = "CLS()";
    (*parameter_hints)["CreateImage"] = "CreateImage(width As Integer, height As Integer, [fillColor As Color]) As Image";
    (*parameter_hints)["CreateTexture"] = "CreateTexture(width As Integer, height As Integer, [fillColor As Color]) As ImageTexture";
    (*parameter_hints)["ImageToTexture"] = "ImageToTexture(image As Image) As ImageTexture";
    (*parameter_hints)["SetImagePixel"] = "SetImagePixel(image As Image, x As Integer, y As Integer, color As Color)";
    (*parameter_hints)["GetImagePixel"] = "GetImagePixel(image As Image, x As Integer, y As Integer) As Color";
    (*parameter_hints)["FillImage"] = "FillImage(image As Image, color As Color)";
    (*parameter_hints)["FillImageRect"] = "FillImageRect(image As Image, x As Integer, y As Integer, w As Integer, h As Integer, color As Color)";
    (*parameter_hints)["BlitImage"] = "BlitImage(destImage As Image, srcImage As Image, srcRect As Rect2i, destPos As Vector2i)";
    (*parameter_hints)["DrawImageLine"] = "DrawImageLine(image As Image, x1 As Integer, y1 As Integer, x2 As Integer, y2 As Integer, color As Color, [width As Integer])";
    (*parameter_hints)["Line"] = "Line(image As Image, x1 As Integer, y1 As Integer, x2 As Integer, y2 As Integer, color As Color, [width As Integer])  ' Alias for DrawImageLine";
    (*parameter_hints)["DrawImageRect"] = "DrawImageRect(image As Image, x1 As Integer, y1 As Integer, x2 As Integer, y2 As Integer, color As Color)";
    (*parameter_hints)["DrawImageEllipse"] = "DrawImageEllipse(image As Image, cx As Integer, cy As Integer, rx As Integer, ry As Integer, color As Color)";
    (*parameter_hints)["DrawImageCircle"] = "DrawImageCircle(image As Image, cx As Integer, cy As Integer, radius As Integer, color As Color)";
    (*parameter_hints)["FloodFillImage"] = "FloodFillImage(image As Image, x As Integer, y As Integer, color As Color)";
    (*parameter_hints)["DrawImageText"] = "DrawImageText(image As Image, x As Integer, y As Integer, text As String, color As Color[, scale As Integer])";
    (*parameter_hints)["UpdateTexture"] = "UpdateTexture(texture As ImageTexture, image As Image)";
    (*parameter_hints)["ImageWidth"] = "ImageWidth(image As Image) As Integer";
    (*parameter_hints)["ImageHeight"] = "ImageHeight(image As Image) As Integer";
    (*parameter_hints)["TextureWidth"] = "TextureWidth(texture As Texture2D) As Integer";
    (*parameter_hints)["TextureHeight"] = "TextureHeight(texture As Texture2D) As Integer";
    (*parameter_hints)["LoadImage"] = "LoadImage(path As String) As Image";
    (*parameter_hints)["SaveImage"] = "SaveImage(image As Image, path As String) As Boolean";
    (*parameter_hints)["GetTextureImage"] = "GetTextureImage(texture As Texture2D) As Image";
    // VB6-style aliases and new functions (v4.2.0)
    (*parameter_hints)["Circle"] = "Circle(image As Image, cx As Integer, cy As Integer, radius As Integer, color As Color)  ' Alias for DrawImageCircle";
    (*parameter_hints)["Point"] = "Point(image As Image, x As Integer, y As Integer) As Color  ' Alias for GetImagePixel";
    (*parameter_hints)["SavePicture"] = "SavePicture(image As Image, path As String) As Boolean  ' Alias for SaveImage";
    (*parameter_hints)["Error"] = "Error(errorNumber As Integer[, description As String])  ' Raises runtime error";
    (*parameter_hints)["Error$"] = "Error$(errorNumber As Integer) As String  ' Returns error description";
    (*parameter_hints)["ErrorDesc"] = "ErrorDesc([errorNumber As Integer]) As String  ' Returns error description";
    (*parameter_hints)["Reset"] = "Reset()  ' Closes all open files";
    (*parameter_hints)["IsMissing"] = "IsMissing(argName As Variant) As Boolean  ' True if Optional argument was not supplied";
    (*parameter_hints)["Erl"] = "Erl() As Long  ' Returns line number of last error";
    (*parameter_hints)["LSet"] = "LSet(string As String, length As Integer) As String  ' Left-align in fixed-width field";
    (*parameter_hints)["RSet"] = "RSet(string As String, length As Integer) As String  ' Right-align in fixed-width field";
    (*parameter_hints)["ChrW"] = "ChrW(charCode As Long) As String  ' Unicode character from code point";
    (*parameter_hints)["AscW"] = "AscW(string As String) As Long  ' Unicode code point of first character";
    (*parameter_hints)["DateValue"] = "DateValue(dateString As String) As String  ' Extracts date portion from date/time string";
    (*parameter_hints)["TimeValue"] = "TimeValue(timeString As String) As String  ' Extracts time portion from date/time string";
    (*parameter_hints)["StrConv"] = "StrConv(string As String, conversion As Integer) As String  ' 1=Upper, 2=Lower, 3=Proper";
    (*parameter_hints)["FormatNumber"] = "FormatNumber(expression As Double[, numDigits As Integer][, leadingDigit][, parens][, groupDigits]) As String";
    (*parameter_hints)["FormatCurrency"] = "FormatCurrency(expression As Double[, numDigits As Integer][, leadingDigit][, parens][, groupDigits]) As String";
    (*parameter_hints)["FormatPercent"] = "FormatPercent(expression As Double[, numDigits As Integer][, leadingDigit][, parens][, groupDigits]) As String";
    (*parameter_hints)["FileDateTime"] = "FileDateTime(pathname As String) As String  ' Returns file last-modified date/time";
    (*parameter_hints)["TextWidth"] = "TextWidth(text As String[, fontSize As Integer]) As Long  ' Returns text width in pixels";
    (*parameter_hints)["TextHeight"] = "TextHeight(text As String[, fontSize As Integer]) As Long  ' Returns text height in pixels";
    (*parameter_hints)["Input$"] = "Input$(n As Integer, fileNumber As Integer) As String  ' Reads n characters from file";
    (*parameter_hints)["InputStr"] = "InputStr(n As Integer, fileNumber As Integer) As String  ' Alias for Input$";
    (*parameter_hints)["CallByName"] = "CallByName(object As Variant, procName As String, callType As Integer[, args...]) As Variant  ' 1=Method, 2=Get, 4=Let";
    (*parameter_hints)["RGB"] = "RGB(red As Integer, green As Integer, blue As Integer) As Color";
    (*parameter_hints)["PlaySound"] = "PlaySound(soundPath As String, volume As Double)";
    (*parameter_hints)["SetTitle"] = "SetTitle(title As String)";
    (*parameter_hints)["ChangeScene"] = "ChangeScene(scenePath As String)";
    (*parameter_hints)["Sleep"] = "Sleep(milliseconds As Integer)";
    (*parameter_hints)["Shell"] = "Shell(command As String) As Integer";
    (*parameter_hints)["SaveSetting"] = "SaveSetting(key As String, value As Variant)";
    (*parameter_hints)["GetSetting"] = "GetSetting(key As String, defaultValue As Variant) As Variant";
    (*parameter_hints)["LoadPicture"] = "LoadPicture(path As String) As Texture2D";
}

Array SnippetHelper::get_all_snippets() {
    initialize_snippets();
    return *snippets;
}

Dictionary SnippetHelper::get_snippet(const String& trigger) {
    initialize_snippets();
    
    for (int i = 0; i < snippets->size(); i++) {
        Dictionary snip = (*snippets)[i];
        if (snip["trigger"] == trigger) {
            return snip;
        }
    }
    
    return Dictionary();
}

String SnippetHelper::detect_incomplete_statement(const String& line) {
    String trimmed = line.strip_edges().to_lower();
    
    // If statement without Then
    if (trimmed.begins_with("if ") && !trimmed.contains(" then")) {
        return "then";
    }
    
    // For statement without To
    if (trimmed.begins_with("for ") && !trimmed.contains(" to ")) {
        return "to";
    }
    
    // While statement (complete as-is, but could add Do)
    if (trimmed.begins_with("while ") && trimmed.length() > 6) {
        return ""; // While is complete
    }
    
    // Dim without As
    if (trimmed.begins_with("dim ") && !trimmed.contains(" as ")) {
        return "as";
    }
    
    return "";
}

String SnippetHelper::get_statement_completion(const String& line) {
    String trimmed = line.strip_edges();
    String lower = trimmed.to_lower();
    
    // If without Then
    if (lower.begins_with("if ") && !lower.contains(" then")) {
        return trimmed + " Then";
    }
    
    // For without To
    if (lower.begins_with("for ") && !lower.contains(" to ")) {
        // Extract variable name
        int space_pos = lower.find(" ", 4);
        if (space_pos > 4) {
            String var_part = lower.substr(4, space_pos - 4).strip_edges();
            if (var_part.contains("=")) {
                // Already has =, just needs To
                return trimmed + " To 10";
            } else {
                // Needs = and To
                return trimmed + " = 1 To 10";
            }
        }
        return trimmed + " = 1 To 10";
    }
    
    // Dim without As
    if (lower.begins_with("dim ") && !lower.contains(" as ")) {
        return trimmed + " As Variant";
    }
    
    // Function without As
    if (lower.begins_with("function ") && lower.contains("(") && lower.contains(")") && !lower.contains(" as ")) {
        return trimmed + " As Variant";
    }
    
    // Sub without parentheses
    if (lower.begins_with("sub ") && !lower.contains("(")) {
        return trimmed + "()";
    }
    
    // Function without parentheses
    if (lower.begins_with("function ") && !lower.contains("(")) {
        return trimmed + "() As Variant";
    }
    
    return "";
}

String SnippetHelper::detect_brace_keyword_completion(const String& line) {
    // Remove the trailing {
    String without_brace = line;
    if (without_brace.ends_with("{")) {
        without_brace = without_brace.substr(0, without_brace.length() - 1).strip_edges();
    }
    
    String lower = without_brace.to_lower();
    
    // If statement: "If x > 10 {" → "If x > 10 Then"
    if (lower.begins_with("if ") && !lower.contains(" then")) {
        return without_brace + " Then";
    }
    
    // For statement: "For i = 1 {" → "For i = 1 To 10"
    if (lower.begins_with("for ") && !lower.contains(" to ")) {
        if (lower.contains("=")) {
            return without_brace + " To 10";
        } else {
            return without_brace + " = 1 To 10";
        }
    }
    
    // While statement: "While x < 100 {" → just remove brace
    if (lower.begins_with("while ")) {
        return without_brace;
    }
    
    // Do statement: "Do {" → just remove brace
    if (lower == "do") {
        return without_brace;
    }
    
    // Select Case: "Select Case x {" → just remove brace
    if (lower.begins_with("select ")) {
        return without_brace;
    }
    
    // With: "With obj {" → just remove brace  
    if (lower.begins_with("with ")) {
        return without_brace;
    }
    
    return "";
}

Dictionary SnippetHelper::get_parameter_hint(const String& function_name) {
    initialize_parameter_hints();
    
    Dictionary result;
    if (parameter_hints->has(function_name)) {
        result["signature"] = (*parameter_hints)[function_name];
        result["found"] = true;
    } else {
        result["found"] = false;
    }
    
    return result;
}

String SnippetHelper::generate_paired_structure(const String& opening_line) {
    String trimmed = opening_line.strip_edges();
    String lower = trimmed.to_lower();
    
    // For loop
    if (lower.begins_with("for ")) {
        // Extract variable name
        String var_name = "";
        int for_pos = 4;
        int eq_pos = lower.find("=", for_pos);
        if (eq_pos > for_pos) {
            var_name = trimmed.substr(for_pos, eq_pos - for_pos).strip_edges();
        }
        
        if (!var_name.is_empty()) {
            return trimmed + "\n\t\nNext " + var_name;
        } else {
            return trimmed + "\n\t\nNext";
        }
    }
    
    // While loop
    if (lower.begins_with("while ")) {
        return trimmed + "\n\t\nWend";
    }
    
    // Do loop
    if (lower == "do" || lower.begins_with("do ")) {
        return trimmed + "\n\t\nLoop";
    }
    
    // If statement
    if (lower.begins_with("if ") && lower.contains(" then")) {
        return trimmed + "\n\t\nEnd If";
    }
    
    // Select Case
    if (lower.begins_with("select ")) {
        return trimmed + "\n\tCase value\n\t\t\nEnd Select";
    }
    
    // With block
    if (lower.begins_with("with ")) {
        return trimmed + "\n\t\nEnd With";
    }
    
    // Sub
    if (lower.begins_with("sub ")) {
        return trimmed + "\n\t\nEnd Sub";
    }
    
    // Function
    if (lower.begins_with("function ")) {
        return trimmed + "\n\t\nEnd Function";
    }
    
    // Try
    if (lower == "try") {
        return trimmed + "\n\t\nCatch ex As Exception\n\tPrint ex.Message\nEnd Try";
    }
    
    // Class
    if (lower.begins_with("class ")) {
        return trimmed + "\n\t\nEnd Class";
    }
    
    // Property
    if (lower.begins_with("property ")) {
        return trimmed + "\n\t\nEnd Property";
    }
    
    return "";
}

bool SnippetHelper::should_generate_pair(const String& line) {
    String lower = line.strip_edges().to_lower();
    
    return lower.begins_with("for ") ||
           lower.begins_with("while ") ||
           lower == "do" ||
           lower.begins_with("do ") ||
           (lower.begins_with("if ") && lower.contains(" then")) ||
           lower.begins_with("select ") ||
           lower.begins_with("with ") ||
           lower.begins_with("sub ") ||
           lower.begins_with("function ") ||
           lower == "try" ||
           lower.begins_with("class ") ||
           lower.begins_with("property ");
}

String SnippetHelper::extract_function_name(const String& line) {
    String trimmed = line.strip_edges();
    
    // Find the last word before (
    int paren_pos = trimmed.rfind("(");
    if (paren_pos == -1) return "";
    
    String before_paren = trimmed.substr(0, paren_pos).strip_edges();
    
    // Get the last word
    int space_pos = before_paren.rfind(" ");
    if (space_pos != -1) {
        return before_paren.substr(space_pos + 1).strip_edges();
    }
    
    return before_paren;
}
