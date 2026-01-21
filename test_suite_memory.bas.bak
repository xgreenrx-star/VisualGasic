Sub Main()
    Print "Testing Low Level Features"
    
    ' Test 1: WeakRef
    Dim obj
    Set obj = New Dictionary
    Dim wr
    // This needs to be Set if WeakRef returns an Object
    Set wr = WeakRef(obj)
    
    Print "WeakRef Valid Before Set Nothing: " & (wr.get_ref() IsNot Nothing)
    
    // Set obj = Nothing ' We don't have Set Nothing syntax or garbage collection force yet
    // But we can overwrite obj
    Set obj = New Dictionary
    // In Godot, the previous dictionary might still exist if ref counted, but if we drop all refs it should free.
    // However, basic variables in VisualGasicInstance::variables hold strong refs.
    // So 'obj' holds a strong ref.
    
    ' Test 2: MemoryBlock (PackedByteArray)
    Dim mb
    mb = New MemoryBlock(16)
    Print "MemoryBlock Size: " & mb.size()
    
    mb.encode_u8(0, 255)
    Print "Byte 0: " & mb.decode_u8(0)
    
    Print "Test Complete"
End Sub
