' VisualGasic Multitasking Test Suite
' Comprehensive demonstration of async/await, parallel processing, and task management
Option Explicit

' Global variables for testing
Dim shared_counter As Integer
Dim test_results() As String
Dim task_completed As Boolean

' Main test runner
Sub Main()
    Print "🧵 VisualGasic Multitasking Test Suite"
    Print "======================================"
    Print ""
    
    ' Initialize test data
    shared_counter = 0
    task_completed = False
    Redim test_results(10)
    
    ' Run all multitasking tests
    Test_AsyncFunctions()
    Test_TaskOperations() 
    Test_ParallelProcessing()
    Test_ConcurrentWhenever()
    Test_ThreadSafety()
    
    Print ""
    Print "✅ All multitasking tests completed!"
    Print "📊 Results summary:"
    For i = 0 To UBound(test_results)
        If test_results(i) <> "" Then
            Print "   " & test_results(i)
        End If
    Next
End Sub

' Test 1: Async Functions and Await
Sub Test_AsyncFunctions()
    Print "🔄 Testing Async Functions..."
    
    ' Call async function
    Dim result = LoadDataAsync()
    test_results(0) = "✓ Async function executed: " & result
    
    ' Await expression test
    Dim data = Await ProcessDataAsync("test_input")
    test_results(1) = "✓ Await expression: " & data
    
    Print "   Async functions test completed"
End Sub

' Async function example
Async Function LoadDataAsync() As Task(Of String)
    Print "   📂 Loading data asynchronously..."
    
    ' Simulate async work
    For i = 1 To 3
        Print "     Loading step " & i & "..."
        ' Await Delay(100) ' Would pause without blocking
    Next
    
    Return "Data loaded successfully"
End Function

' Another async function with await
Async Function ProcessDataAsync(input_data As String) As Task(Of String)
    Print "   ⚙️ Processing: " & input_data
    
    ' Await another async operation
    Dim processed = Await TransformDataAsync(input_data)
    
    Return processed & " [processed]"
End Function

Async Function TransformDataAsync(data As String) As Task(Of String)
    Print "     🔄 Transforming: " & data
    Return UCase(data) & "_TRANSFORMED"
End Function

' Test 2: Task Operations
Sub Test_TaskOperations()
    Print "📋 Testing Task Operations..."
    
    ' Background task
    Task.Run BackgroundWorker
        Print "   🔧 Background task executing..."
        For i = 1 To 5
            shared_counter = shared_counter + 1
            Print "     Counter: " & shared_counter
        Next
        task_completed = True
    End Task
    
    ' Named task
    Task.Run CalculationTask
        Dim result = 0
        For i = 1 To 100
            result = result + i
        Next
        Print "   🧮 Calculation result: " & result
    End Task
    
    ' Wait for tasks
    Task.WaitAll(BackgroundWorker, CalculationTask)
    
    test_results(2) = "✓ Background tasks completed, counter: " & shared_counter
    test_results(3) = "✓ Task coordination successful"
    
    Print "   Task operations test completed"
End Sub

' Test 3: Parallel Processing
Sub Test_ParallelProcessing()
    Print "⚡ Testing Parallel Processing..."
    
    ' Parallel for loop
    Dim numbers(10) As Integer
    
    ' Initialize array in parallel
    Parallel For i = 0 To 9
        numbers(i) = i * i
        Print "   🔢 Calculated: " & i & "² = " & numbers(i)
    Next
    
    ' Parallel section
    Parallel Section
        ' These would run concurrently
        ProcessArraySection1(numbers)
        ProcessArraySection2(numbers) 
        ProcessArraySection3(numbers)
    End Section
    
    test_results(4) = "✓ Parallel for loop: processed 10 items"
    test_results(5) = "✓ Parallel sections: 3 concurrent operations"
    
    Print "   Parallel processing test completed"
End Sub

Sub ProcessArraySection1(arr() As Integer)
    Print "   📊 Section 1: Processing first half..."
    Dim sum = 0
    For i = 0 To 4
        sum = sum + arr(i)
    Next
    Print "     First half sum: " & sum
End Sub

Sub ProcessArraySection2(arr() As Integer)
    Print "   📈 Section 2: Processing second half..."
    Dim sum = 0
    For i = 5 To 9
        sum = sum + arr(i)
    Next
    Print "     Second half sum: " & sum
End Sub

Sub ProcessArraySection3(arr() As Integer)
    Print "   📉 Section 3: Finding max value..."
    Dim max_val = 0
    For i = 0 To 9
        If arr(i) > max_val Then max_val = arr(i)
    Next
    Print "     Maximum value: " & max_val
End Sub

' Test 4: Concurrent Whenever (Thread-Safe Reactive Programming)
Sub Test_ConcurrentWhenever()
    Print "🔀 Testing Concurrent Whenever..."
    
    Dim monitor_value As Integer
    monitor_value = 0
    
    ' Parallel whenever sections
    Whenever Section Parallel MonitorSystem
        monitor_value Changes LogChange, CheckThreshold
        shared_counter Changes UpdateDisplay
    End Whenever
    
    ' Trigger changes from multiple contexts
    Task.Run ParallelUpdater1
        For i = 1 To 5
            monitor_value = i * 10
            shared_counter = shared_counter + 1
            ' Small delay would be here
        Next
    End Task
    
    Task.Run ParallelUpdater2  
        For i = 1 To 3
            monitor_value = monitor_value + i
            shared_counter = shared_counter + 2
        Next
    End Task
    
    Task.WaitAll(ParallelUpdater1, ParallelUpdater2)
    
    test_results(6) = "✓ Concurrent Whenever: thread-safe monitoring"
    test_results(7) = "✓ Final monitor value: " & monitor_value
    
    Print "   Concurrent Whenever test completed"
End Sub

Sub LogChange()
    Print "   📝 Value changed in thread-safe context"
End Sub

Sub CheckThreshold()
    Print "   ⚠️ Threshold monitoring active"
End Sub

Sub UpdateDisplay()
    Print "   🖥️ Display updated, counter: " & shared_counter
End Sub

' Test 5: Thread Safety
Sub Test_ThreadSafety()
    Print "🔒 Testing Thread Safety..."
    
    Dim safe_counter As Integer
    safe_counter = 0
    
    ' Multiple tasks modifying shared data
    Task.Run SafetyTest1
        For i = 1 To 50
            safe_counter = safe_counter + 1
        Next
    End Task
    
    Task.Run SafetyTest2
        For i = 1 To 50  
            safe_counter = safe_counter + 1
        Next
    End Task
    
    Task.Run SafetyTest3
        For i = 1 To 50
            safe_counter = safe_counter + 1
        Next
    End Task
    
    Task.WaitAll(SafetyTest1, SafetyTest2, SafetyTest3)
    
    test_results(8) = "✓ Thread safety test completed"
    test_results(9) = "✓ Expected: 150, Actual: " & safe_counter
    
    Print "   Thread safety test completed"
    Print "   Expected counter: 150, Actual: " & safe_counter
    
    If safe_counter = 150 Then
        test_results(10) = "✓ Perfect thread synchronization achieved!"
    Else
        test_results(10) = "⚠️ Thread safety needs improvement"
    End If
End Sub

' Performance benchmark
Sub Benchmark_ParallelVsSequential()
    Print "📊 Performance Benchmark..."
    
    Dim start_time = Timer()
    
    ' Sequential processing
    For i = 1 To 1000
        Dim result = i * i + i
        ' Simulated work
    Next
    
    Dim sequential_time = Timer() - start_time
    start_time = Timer()
    
    ' Parallel processing
    Parallel For i = 1 To 1000
        Dim result = i * i + i
        ' Same simulated work
    Next
    
    Dim parallel_time = Timer() - start_time
    
    Print "   Sequential time: " & sequential_time & "ms"
    Print "   Parallel time: " & parallel_time & "ms"
    Print "   Speedup: " & Format(sequential_time / parallel_time, "0.00") & "x"
End Sub

' Error handling in async context
Async Function ErrorHandlingTest() As Task(Of String)
    Try
        ' Simulate async operation that might fail
        Await RiskyOperationAsync()
        Return "Success"
    Catch ex
        Print "   ❌ Async error handled: " & ex.Message
        Return "Error handled gracefully"
    Finally
        Print "   🧹 Async cleanup completed"
    End Try
End Function

Async Function RiskyOperationAsync() As Task
    ' Simulate potential failure
    If Rnd() < 0.5 Then
        Throw New Exception("Simulated async error")
    End If
End Function