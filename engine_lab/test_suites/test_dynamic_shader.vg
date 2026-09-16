Sub Main()
    Print "Testing Dynamic Shader Generation..."
    

    Set spr = LoadSprite("res://icon.svg")
    If TypeName(spr) = "Sprite2D" Then
        AddChild spr
        spr.position = Vector2(300, 300)
    Else
        Print "Sprite load failed, shader test might be invisible"
    End If
    
    ' Build Shader Code in BASIC

    code = "shader_type canvas_item;" & Chr(10)
    code = code & "void fragment() {" & Chr(10)
    code = code & "  COLOR = texture(TEXTURE, UV);" & Chr(10)
    ' Invert Colors
    code = code & "  COLOR.rgb = vec3(1.0) - COLOR.rgb;" & Chr(10)
    code = code & "}"
    
    Print "Compiling Shader..."

    Set sh = CompileShader(code)
    
    If Not sh Is Nothing Then
        Print "Shader Compiled!"
        If Not spr Is Nothing Then
             SetShader spr, sh
             Print "Applied Invert Shader"
        End If
    Else
        Print "Compile Failed (returned Nothing)"
    End If
End Sub
