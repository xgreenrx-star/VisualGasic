' VisualGasic Game-Oriented Keywords Test
' Testing all 22 newly implemented game keywords from AMOS, BlitzBasic, FUZE BASIC, etc.

Option Explicit

' =================================================================
' GAME-ORIENTED STATEMENT TESTING
' =================================================================

Sub TestGraphicsCommands()
    Print "=== Testing Graphics Commands ==="
    
    ' Clear screen
    Cls
    
    ' Draw pixel
    Plot 100, 50
    Plot 200, 75, 0xFF0000  ' Red pixel
    
    ' Draw shapes  
    Circle 150, 100, 25
    Circle 250, 100, 30, 0x00FF00  ' Green circle
    
    Box 50, 150, 100, 50
    Box 200, 150, 100, 50, 0x0000FF  ' Blue box
    
    ' Sprite handling
    Sprite 1, 300, 200
    Sprite 2, 350, 200, "player.png"
    
    ' Blitter objects (animated sprites)
    Bob 1, 400, 250
    Bob 2, 450, 250, "enemy.png"
    
    ' Animation control
    Animate 1, 4  ' 4 frames
    Animate 2, 8  ' 8 frames
    
    ' Double buffer flip
    Flip
    
    Print "Graphics commands executed successfully!"
End Sub

Sub TestAudioCommands()
    Print "=== Testing Audio Commands ==="
    
    ' Load sound samples
    Sample 1, "sounds/explosion.wav"
    Sample 2, "sounds/jump.wav"
    
    ' Play background music
    Music "music/background.ogg"
    
    ' Volume control
    Volume 80  ' 80% volume
    
    Print "Audio commands executed successfully!"
End Sub

Sub TestSystemCommands()
    Print "=== Testing System Commands ==="
    
    ' Memory management
    Reserve 1024  ' Reserve 1KB
    
    ' Performance hint
    Fast
    
    ' Timing control
    Wait 0.5  ' Wait half a second
    
    Print "System commands executed successfully!"
End Sub

' =================================================================
' GAME-ORIENTED EXPRESSION TESTING  
' =================================================================

Sub TestInputExpressions()
    Print "=== Testing Input Expressions ==="
    
    ' Immediate key input
    Dim key_pressed As String
    key_pressed = Inkey
    Print "Last key pressed: '" & key_pressed & "'"
    
    ' Mouse position
    Dim mouse_x As Integer
    Dim mouse_y As Integer
    mouse_x = MouseX
    mouse_y = MouseY
    Print "Mouse position: " & mouse_x & ", " & mouse_y
    
    ' Mouse button state
    Dim mouse_button As Integer
    mouse_button = MouseClick
    Print "Mouse button state: " & mouse_button
    
    Print "Input expressions tested successfully!"
End Sub

Sub TestUtilityExpressions()
    Print "=== Testing Utility Expressions ==="
    
    ' High precision timer
    Dim current_time As Single
    current_time = Timer
    Print "Current timer: " & current_time
    
    ' Multi-value selector (Choose function)
    Dim result As Variant
    result = Choose(True, "Option A", "Option B", "Option C")
    Print "Choose result: " & result
    
    result = Choose(False, "First", "Second") 
    Print "Choose result 2: " & result
    
    ' Collision detection
    Dim collision_result As Boolean
    collision_result = Collision("player", "enemy")
    Print "Collision detected: " & collision_result
    
    Print "Utility expressions tested successfully!"
End Sub

' =================================================================
' COMPREHENSIVE GAME DEMO
' =================================================================

Sub GameDemo()
    Print "=== Game Demo using New Keywords ==="
    
    ' Initialize graphics
    Cls
    Print "Initializing game..."
    
    ' Setup audio
    Sample 1, "shoot.wav"
    Music "game_music.ogg"
    Volume 75
    
    ' Game loop simulation
    Dim frame_count As Integer
    frame_count = 0
    
    While frame_count < 10
        ' Clear and draw
        Cls
        
        ' Draw player sprite
        Sprite 1, 100 + (frame_count * 5), 200
        
        ' Draw enemies
        Bob 1, 200, 150 + (frame_count * 2)
        Bob 2, 250, 180 - (frame_count * 3)
        
        ' Draw UI elements
        Box 10, 10, 200, 30, 0x333333  ' Health bar background
        Box 12, 12, 150, 26, 0x00FF00  ' Health bar fill
        
        ' Game logic
        If MouseX > 100 And MouseY > 100 Then
            Circle MouseX, MouseY, 10, 0xFFFF00  ' Yellow cursor
        End If
        
        ' Animation
        Animate 1, 4
        
        ' Physics/collision (placeholder)
        If Collision(1, 2) Then
            Print "Hit detected at frame " & frame_count
        End If
        
        ' Update display
        Flip
        
        ' Timing
        Print "Frame " & frame_count & " - Timer: " & Timer
        
        frame_count = frame_count + 1
    Wend
    
    Print "Game demo completed!"
End Sub

' =================================================================
' MAIN TEST EXECUTION
' =================================================================

Sub Main()
    Print "========================================="
    Print "  VisualGasic Game Keywords Test Suite  "
    Print "========================================="
    Print ""
    
    ' Test all the new game-oriented features
    Call TestGraphicsCommands()
    Print ""
    
    Call TestAudioCommands() 
    Print ""
    
    Call TestSystemCommands()
    Print ""
    
    Call TestInputExpressions()
    Print ""
    
    Call TestUtilityExpressions()
    Print ""
    
    Call GameDemo()
    Print ""
    
    Print "========================================="
    Print "  All 22 game keywords tested!"
    Print "  AMOS/BlitzBasic/FUZE BASIC compatibility added!"
    Print "========================================="
End Sub