Sub _Ready()
    Print "Testing String Library"

    ' Basic String Concat
    Dim s As String
    s = "Hello" & " " & "World"
    Print "Concat: " & s

    ' Len
    Print "Len: " & Len(s)

    ' Left / Right / Mid
    Print "Left: " & Left(s, 5)
    Print "Right: " & Right(s, 5)
    Print "Mid: " & Mid(s, 7, 5)

    ' UCase / LCase
    Print "UCase: " & UCase(s)
    Print "LCase: " & LCase(s)

    ' InStr
    Print "InStr (World): " & InStr(s, "World")
    Print "InStr (NotFound): " & InStr(s, "Universe")

    ' Replace
    Print "Replace: " & Replace(s, "World", "Visual Gasic")

    ' Trim / LTrim / RTrim
    Dim t As String
    t = "   TrimMe   "
    Print "Trim: '" & Trim(t) & "'"
    
    ' StrReverse (Bonus)
    Print "StrReverse: " & StrReverse(s)


    Set tree = GetTree()
    Print "Tree: " & tree

    ' Quit Check
    GetTree().Quit()
End Sub
