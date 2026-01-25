' Test new VB6 keywords

Sub _ready()
    Print "Testing VB6 Keywords Implementation"
    
    ' Test Mod operator
    Dim result As Integer
    result = 17 Mod 5
    Print "17 Mod 5 = "; result  ' Should be 2
    
    ' Test Erase
    Dim arr(5) As Integer
    arr(0) = 10
    arr(1) = 20
    Print "Before Erase: arr(0) = "; arr(0)
    Erase arr
    Print "After Erase: array cleared"
    
    ' Test Like operator
    Dim text As String
    text = "Hello"
    If text Like "H*" Then
        Print "Text matches pattern H*"
    End If
    
    ' Test Null and Empty
    Dim v As Variant
    v = Null
    If IsNull(v) Then
        Print "v is Null"
    End If
    
    v = Empty
    If IsEmpty(v) Then
        Print "v is Empty"
    End If
    
    ' Test Xor operator
    Dim a As Boolean
    Dim b As Boolean
    a = True
    b = False
    If a Xor b Then
        Print "True Xor False = True"
    End If
    
    ' Test Imp operator
    If True Imp True Then
        Print "True Imp True = True"
    End If
    
    ' Test Eqv operator
    If True Eqv True Then
        Print "True Eqv True = True"
    End If
    
    ' Test Stop (breakpoint)
    Print "About to hit Stop statement..."
    Stop
    Print "Continued after Stop"
    
    ' Test TypeOf...Is
    Dim node As Object
    Set node = Me
    If TypeOf node Is Node Then
        Print "node is a Node type"
    End If
    
    Print "All tests completed!"
End Sub
