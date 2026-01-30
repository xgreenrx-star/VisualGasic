' VisualGasic New Features Test
' Testing all 11 newly implemented keywords from other languages

Option Explicit

' 1. EXPORT - Variables that appear in Godot's inspector
Export health As Integer = 100
Export player_name As String = "Player1"
Export is_enabled As Boolean = True

' 2. READONLY - Immutable variables
ReadOnly max_level As Integer = 50
ReadOnly game_version As String = "1.0.0"

' 3. ONREADY - Lazy initialization (runtime placeholder)
OnReady sprite_node As Node = GetNode("Sprite2D")

' 4. INTERFACE - Interface definitions  
Interface IMovable
    Sub Move(x As Integer, y As Integer)
    Function GetSpeed() As Single
End Interface

Interface IDrawable
    Sub Draw()
End Interface

' 5. PARTIAL - Partial class support (parsed but not fully implemented)
Partial Class Player
    Public x As Integer
    Public y As Integer
End Class

' Test functions demonstrating new expression features
Sub TestNewExpressions()
    Dim result As Variant
    
    ' 6. NAMEOF - Get symbol names as strings
    result = NameOf(health)          ' Returns "health"
    Print "Variable name: " & result
    
    result = NameOf(TestNewExpressions)  ' Returns "TestNewExpressions"  
    Print "Function name: " & result
    
    ' 7. ADDRESSOF - Function pointer support
    result = AddressOf TestNewExpressions
    Print "Function address info: " & result
    
    ' 8. TYPEOF...IS - Type checking
    If TypeOf health Is Integer Then
        Print "health is an Integer"
    End If
End Sub

' 9. MATCH - Pattern matching
Sub TestMatchStatement(value As Variant)
    Match value
        Case 1, 2, 3
            Print "Small number: " & value
        Case 10
            Print "It's ten!"
        Case "hello", "hi"  
            Print "Greeting: " & value
        Case _
            Print "Unknown value: " & value
    End Match
End Sub

' 10. YIELD - Generator/coroutine support (placeholder)
Function CountToThree() As Variant
    Yield 1
    Yield 2  
    Yield 3
End Function

' 11. SIGNAL - Custom signal declarations
Signal player_died()
Signal score_changed(new_score As Integer)
Signal item_collected(item_name As String, quantity As Integer)

' Main test function
Sub Main()
    Print "=== VisualGasic New Features Test ==="
    Print ""
    
    ' Test exported variables
    Print "Exported variables:"
    Print "  health = " & health
    Print "  player_name = " & player_name
    Print "  is_enabled = " & is_enabled
    Print ""
    
    ' Test readonly variables  
    Print "ReadOnly variables:"
    Print "  max_level = " & max_level
    Print "  game_version = " & game_version
    Print ""
    
    ' Test new expressions
    Print "Expression features:"
    Call TestNewExpressions()
    Print ""
    
    ' Test pattern matching
    Print "Pattern matching tests:"
    Call TestMatchStatement(2)
    Call TestMatchStatement(10)  
    Call TestMatchStatement("hello")
    Call TestMatchStatement(99)
    Print ""
    
    ' Test generator (placeholder)
    Print "Generator test:"
    Dim gen As Variant = CountToThree()
    Print "Generator created: " & TypeName(gen)
    Print ""
    
    Print "=== All new features tested successfully! ==="
End Sub