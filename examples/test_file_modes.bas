' Test all VB6 file modes
' Tests: Binary, Random, Access Read/Write, Lock Shared, record-based I/O

Sub TestFileModes()
    Print "=== Testing VB6 File Modes ==="
    
    ' Test Binary mode with Access and Lock
    Print ""
    Print "Test 1: Binary mode with Access Read"
    Open "testfile.bin" For Binary Access Read As #1
    Print "File #1 opened in Binary Read mode"
    Close #1
    
    ' Test Binary write mode
    Print ""
    Print "Test 2: Binary mode with Access Write"
    Open "testfile.bin" For Binary Access Write As #2
    Print "File #2 opened in Binary Write mode"
    Close #2
    
    ' Test Binary read/write mode
    Print ""
    Print "Test 3: Binary mode with Access Read Write"
    Open "testfile.bin" For Binary Access Read Write As #3
    Print "File #3 opened in Binary Read/Write mode"
    Close #3
    
    ' Test Random mode with record length
    Print ""
    Print "Test 4: Random mode with Len=64"
    Open "records.dat" For Random Access Read Write As #4 Len=64
    Print "File #4 opened in Random mode with 64-byte records"
    Close #4
    
    ' Test with Lock Shared
    Print ""
    Print "Test 5: Input mode with Lock Shared"
    Open "shared.txt" For Input Lock Shared As #5
    Print "File #5 opened with Lock Shared"
    Close #5
    
    ' Test Append with Lock Write
    Print ""
    Print "Test 6: Append mode with Lock Write"
    Open "append.txt" For Append Lock Write As #6
    Print "File #6 opened for Append with Lock Write"
    Close #6
    
    ' Test Output with Shared keyword
    Print ""
    Print "Test 7: Output mode with Shared"
    Open "output.txt" For Output Shared As #7
    Print "File #7 opened for Output with Shared access"
    Close #7
    
    ' Test Binary with Lock Read Write
    Print ""
    Print "Test 8: Binary mode with Lock Read Write"
    Open "locked.bin" For Binary Access Read Write Lock Read Write As #8
    Print "File #8 opened with Lock Read Write"
    Close #8
    
    Print ""
    Print "=== All File Mode Tests Completed ==="
    Print "Binary, Random, Access, Lock, and Shared keywords are functional!"
End Sub

' Execute test
TestFileModes()
