Sub Main()
    Print "Testing System Commands..."
    
    ' 1. Test CreateText
    Dim lbl
    Set lbl = CreateText("Hello Visual Gasic!", 100, 100)
    
    If TypeName(lbl) = "Label" Then
        Print "CreateText: Success"
        ' Label is automatically added to scene by CreateText
        Print "Added Label to scene" 
    Else
        Print "CreateText: Failed, type is " & TypeName(lbl)
    End If
    
    ' 2. Test Input Axis (Headless defaults to 0 usually)
    Dim ax
    ax = GetAxis("ui_left", "ui_right")
    Print "Input Axis (ui_left/right): " & ax
    
    ' 3. Test Joy Axis
    Dim jax
    jax = GetJoyAxis(0, 0)
    Print "Joy 0 Axis 0: " & jax
    
    ' 4. Test CreateParticles2D
    Dim parts
    Set parts = CreateParticles2D("res://dummy_material.tres", 50, 50)
    If TypeName(parts) = "GPUParticles2D" Then
        Print "CreateParticles2D: Success (GPUParticles2D created)"
    Else
        Print "CreateParticles2D: Failed, Type is " & TypeName(parts)
    End If
    
    ' 5. Test CreateMultiMeshInstance3D
    Dim mm
    Set mm = CreateMultiMeshInstance3D("res://dummy_multimesh.tres", 0, 0, 0)
    If TypeName(mm) = "MultiMeshInstance3D" Then
        Print "CreateMultiMeshInstance3D: Success"
    Else
        Print "CreateMultiMeshInstance3D: Failed, Type is " & TypeName(mm)
    End If
    
    ' 6. Test CreateTextureRect
    Dim tr
    Set tr = CreateTextureRect("res://icon.svg", 10, 10)
    If TypeName(tr) = "TextureRect" Then
        Print "CreateTextureRect: Success"
    Else
        Print "CreateTextureRect: Failed, Type is " & TypeName(tr)
    End If
    
    ' 7. Test CreateSprite3D
    Dim s3d
    Set s3d = CreateSprite3D("res://icon.svg", 0, 0, 0)
    If TypeName(s3d) = "Sprite3D" Then
        Print "CreateSprite3D: Success"
    Else
        Print "CreateSprite3D: Failed, Type is " & TypeName(s3d)
    End If

    ' 8. Test CLS (Clear Screen / Dynamic Nodes)
    CLS
    ' After CLS, nodes should be queued for deletion. 
    ' We can't immediately check if they are gone in same frame easily in BASIC without Wait.
    ' But we can check that the command runs.
    Print "CLS Executed."
    
    ' 9. Test AI System (Chase)
    ' Create dummy enemy and player using Actors (Physics bodies)
    Dim enemy
    Dim player
    Set enemy = CreateActor2D("res://icon.svg", 100, 100)
    Set player = CreateActor2D("res://icon.svg", 400, 400)
    
    ' Setup positions
    AI_Chase(enemy, player, 100, 10) 
    ' Can't verify movement in single frame, but check for no crash
    Print "AI_Chase command issued."
    
    ' Test Wander (re-assign AI)
    AI_Wander(enemy, 50, 200)
    Print "AI_Wander command issued."
    
    AI_Stop(enemy)
    Print "AI_Stop command issued."

    Print "System Test Complete."
End Sub
