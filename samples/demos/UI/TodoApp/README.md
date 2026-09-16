# Todo App - UI Demo

A full-featured todo application demonstrating VisualGasic's file I/O and Lambda expressions.

## Features Demonstrated

### File I/O Operations
```vb
' Save todos to file
Sub SaveTodos()
    Dim fileNum As Integer = FreeFile()
    Open SAVE_FILE For Output As #fileNum
    
    Print #fileNum, todoCount
    
    Dim i As Integer
    For i = 0 To todoCount - 1
        Print #fileNum, todos(i).Text
        Print #fileNum, todos(i).Completed
        Print #fileNum, todos(i).Priority
    Next
    
    Close #fileNum
End Sub

' Load todos from file
Sub LoadTodos()
    Dim fileNum As Integer = FreeFile()
    Open SAVE_FILE For Input As #fileNum
    
    Input #fileNum, todoCount
    
    For i = 0 To todoCount - 1
        Input #fileNum, todos(i).Text
        Input #fileNum, todos(i).Completed
        Input #fileNum, todos(i).Priority
    Next
    
    Close #fileNum
End Sub
```

### Lambda Expressions for Filtering
```vb
' Filter using Lambda
Select Case filterMode
    Case 1  ' Active only
        include = Lambda(t) Not t.Completed
        include = include(todos(i))
    Case 2  ' Completed only
        include = Lambda(t) t.Completed
        include = include(todos(i))
End Select
```

### Whenever Reactive System
```vb
Whenever Section TaskStatistics
    Whenever completedTasks Changes
        pendingTasks = totalTasks - completedTasks
        Print "Tasks remaining: " & Str(pendingTasks)
    End Whenever
    
    ' Celebration when all done!
    Whenever pendingTasks Becomes 0
        If totalTasks > 0 Then
            Print "🎉 ALL TASKS COMPLETED! 🎉"
        End If
    End Whenever
    
    ' Warning when too many tasks
    Whenever pendingTasks Exceeds 10
        Print "⚠️ You have too many pending tasks!"
    End Whenever
End Whenever Section
```

### Custom Types
```vb
Type TodoItem
    Text As String
    Completed As Boolean
    Priority As Integer
    CreatedAt As String
End Type

Dim todos(MAX_TODOS) As TodoItem
```

### DATA for Sample Data
```vb
SampleTodos:
Data "Learn VisualGasic basics", 1, 1
Data "Build first game prototype", 1, 0
Data "Read documentation", 2, 0
Data "END", 0, 0

' Load with Restore/Read
Restore SampleTodos
Read text, priority, completed
```

## Features

- ✅ Add new tasks
- ✅ Toggle completion
- ✅ Delete tasks
- ✅ Priority levels (High/Medium/Low)
- ✅ Filter views (All/Active/Completed)
- ✅ Clear completed tasks
- ✅ Persistent storage (saves automatically)
- ✅ Progress tracking
- ✅ Reactive statistics

## Controls

| Key | Action |
|-----|--------|
| Type | Enter new task text |
| Enter | Add task / Toggle selected |
| ↑/↓ | Navigate tasks |
| P | Cycle priority |
| 1 | Show all tasks |
| 2 | Show active only |
| 3 | Show completed only |
| Ctrl+C | Clear completed |
| Shift+Del | Delete selected |

## How to Run

1. Open this folder in Godot 4.6.1+
2. Make sure the VisualGasic addon is enabled
3. Run the project (F5)
4. Start managing your tasks!
