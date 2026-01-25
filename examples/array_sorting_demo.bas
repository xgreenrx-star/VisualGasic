' Array Sorting Demo for VisualGasic
' Demonstrates all array manipulation functions

Sub Main()
    Print "VisualGasic Array Sorting Demo"
    Print "==================================="
    Print
    
    ' Test numeric array sorting
    Dim numbers
    numbers = [42, 7, 23, 1, 89, 12, 56]
    Print "Original numbers:", Join(numbers, ", ")
    
    Dim sorted_numbers
    sorted_numbers = Sort(numbers)
    Print "Sorted numbers:  ", Join(sorted_numbers, ", ")
    
    Dim reversed_numbers  
    reversed_numbers = Reverse(numbers)
    Print "Reversed numbers:", Join(reversed_numbers, ", ")
    Print
    
    ' Test string array sorting
    Dim fruits
    fruits = ["banana", "apple", "orange", "grape", "kiwi"]
    Print "Original fruits:", Join(fruits, ", ")
    
    Dim sorted_fruits
    sorted_fruits = Sort(fruits)
    Print "Sorted fruits:  ", Join(sorted_fruits, ", ")
    Print
    
    ' Test mixed type array
    Dim mixed
    mixed = [3, "apple", 1, "zebra", 7, "banana"]
    Print "Mixed array:    ", Join(mixed, ", ")
    
    Dim sorted_mixed
    sorted_mixed = Sort(mixed)
    Print "Sorted mixed:   ", Join(sorted_mixed, ", ")
    Print
    
    ' Test search functions
    Dim search_array
    search_array = [10, 20, 30, 40, 50]
    Print "Search array:   ", Join(search_array, ", ")
    Print "IndexOf(30):    ", IndexOf(search_array, 30)
    Print "IndexOf(99):    ", IndexOf(search_array, 99)
    Print "Contains(40):   ", Contains(search_array, 40)
    Print "Contains(15):   ", Contains(search_array, 15)
    Print
    
    ' Test unique function
    Dim duplicates
    duplicates = [1, 2, 2, 3, 3, 3, 4, 4, 5]
    Print "With duplicates:", Join(duplicates, ", ")
    
    Dim unique_values
    unique_values = Unique(duplicates)
    Print "Unique values:  ", Join(unique_values, ", ")
    Print
    
    ' Test flatten function
    Dim nested
    nested = [1, [2, 3], 4, [5, [6, 7]], 8]
    Print "Nested array:   ", ToString(nested)
    
    Dim flattened
    flattened = Flatten(nested)
    Print "Flattened:      ", Join(flattened, ", ")
    Print
    
    Print "Array sorting demo completed!"
End Sub

' Helper function to convert array to string representation
Function ToString(arr As Variant) As String
    If TypeOf arr Is Array Then
        Dim result As String = "["
        Dim array_data As Array = arr
        For i As Integer = 0 To array_data.Length - 1
            If i > 0 Then result = result & ", "
            result = result & ToString(array_data(i))
        Next
        result = result & "]"
        Return result
    Else
        Return CStr(arr)
    End If
End Function

' Helper function to join array elements
Function Join(arr As Variant, delimiter As String) As String
    If Not (TypeOf arr Is Array) Then Return CStr(arr)
    
    Dim array_data As Array = arr
    Dim result As String = ""
    
    For i As Integer = 0 To array_data.Length - 1
        If i > 0 Then result = result & delimiter
        result = result & CStr(array_data(i))
    Next
    
    Return result
End Function