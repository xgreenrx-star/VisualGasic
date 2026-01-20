extends SceneTree

func _init():
    print("Testing Auto-Indentation...")
    
    # We need to get the Language singleton.
    # Usually available via Engine or by instancing if exposed.
    # VisualGasicLanguage is a ScriptLanguageExtension.
    # We can try to instantiate it (it has a constructor) but it might be singleton.
    
    var lang = VisualGasicLanguage.new()
    
    var raw_code = "Sub Test\nPrint \"Hi\"\nIf 1=1 Then\nPrint \"True\"\nEnd If\nEnd Sub"
    print("Raw Code:\n" + raw_code)
    
    # Check if format_source_code is bound
    if lang.has_method("format_source_code"):
        var formatted = lang.format_source_code(raw_code)
        print("\nFormatted Code:\n" + formatted)
        
        if formatted.contains("\tPrint"):
            print("\nSUCCESS: Indentation applied.")
        else:
            print("\nFAILURE: No indentation found.")
    else:
        print("\nFAILURE: format_source_code method not found on VisualGasicLanguage.")
    
    quit()
