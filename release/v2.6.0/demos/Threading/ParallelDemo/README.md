# Parallel Processing Demo

A comprehensive demonstration of VisualGasic's multitasking and threading capabilities.

## Features Demonstrated

### Parallel For Loops
```vb
' Automatically distributes work across CPU cores
Parallel For i As Integer = 0 To MAX_PARTICLES - 1
    UpdateSingleParticle i, delta
Next

' With thread-safe operations
Parallel For batch As Integer = 0 To numBatches - 1
    ' Do parallel work...
    
    ' Thread-safe increment
    Lock
        completedTasks = completedTasks + 1
    Unlock
Next
```

### Task.Run for Async Operations
```vb
' Fire-and-forget async task
Task.Run Sub()
    Dim i As Integer
    For i = 1 To 5
        Print "Async work step " & Str(i)
        Sleep 500  ' Simulate work
    Next
    Print "Async task completed!"
End Sub

Print "Main thread continues immediately..."
```

### Await for Task Results
```vb
' Wait for async task to complete and get result
Dim result As Integer = Await Task.Run(Function()
    Dim sum As Integer = 0
    Dim i As Integer
    For i = 1 To 1000000
        sum = sum + i
    Next
    Return sum
End Function)

Print "Awaited result: " & Str(result)
```

### Lock/Unlock for Thread Safety
```vb
Parallel For i As Integer = 0 To COUNT - 1
    DoWork i
    
    ' Thread-safe section
    Lock
        sharedCounter = sharedCounter + 1
        completedTasks = completedTasks + 1
    Unlock
Next
```

### Whenever for Task Monitoring
```vb
Whenever Section TaskMonitor
    Whenever completedTasks Changes
        Dim pct As Integer = Int(completedTasks / totalTasks * 100)
        Print "Task progress: " & Str(pct) & "%"
    End Whenever
    
    Whenever activeTasks Becomes 0
        Print "✓ All tasks completed!"
    End Whenever
End Whenever Section
```

## Demos Included

### 1. Particle Physics (Press 1)
- 500 particles with physics simulation
- Compare Serial vs Parallel update (hold SPACE)
- Visual demonstration of parallel processing

### 2. Work Load Comparison (Press 2)
- 100 CPU-intensive tasks
- Run Serial first, then Parallel
- See real speedup numbers

### 3. Prime Number Calculation (Press 3)
- Find all primes up to 10,000
- Batch processing with parallelization
- Compare algorithm performance

## Controls

| Key | Action |
|-----|--------|
| 1 | Particle Physics Demo |
| 2 | Work Load Comparison |
| 3 | Prime Calculation |
| Enter | Run Test (Serial then Parallel) |
| Space | Hold for Parallel (Particle demo) |
| A | Run Async Task |
| W | Run Awaited Task |
| R | Reset Particles |

## Performance Tips

1. **Use Parallel For** for independent iterations
2. **Batch small tasks** to reduce threading overhead
3. **Lock shared resources** to prevent race conditions
4. **Use Await** when you need the result before continuing

## How to Run

1. Open this folder in Godot 4.5+
2. Make sure the VisualGasic addon is enabled
3. Run the project (F5)
4. Try each demo and compare Serial vs Parallel!
