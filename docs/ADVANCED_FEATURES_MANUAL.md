# VisualGasic Advanced Features Manual

## Table of Contents
1. [Advanced Type System](#advanced-type-system)
2. [Pattern Matching](#pattern-matching)
3. [GPU Computing](#gpu-computing)
4. [Interactive REPL](#interactive-repl)
5. [Advanced Debugging](#advanced-debugging)
6. [Package Management](#package-management)
7. [Entity Component System](#entity-component-system)
8. [Language Server Protocol](#language-server-protocol)
9. [Performance Snapshot](#performance-snapshot)

---

## Performance Snapshot

VisualGasic targets high performance in tight loops and engine interop while keeping Gasic-style ergonomics. Below is a snapshot from the built‑in benchmark suite (Godot 4.5.1 headless). All 11 benchmarks faster than GDScript. Full results and methodology are in [performance.md](manual/performance.md).

```mermaid
xychart-beta
    title "StringConcat (us)"
    x-axis ["Visual Gasic","C++","GDScript"]
    y-axis "Elapsed (us)" 0 --> 6000
    bar [85,688,5278]
```

```mermaid
xychart-beta
    title "ArrayDict (us)"
    x-axis ["Visual Gasic","C++","GDScript"]
    y-axis "Elapsed (us)" 0 --> 12000
    bar [10180,4086,10833]
```

```mermaid
xychart-beta
    title "FileIO (us)"
    x-axis ["Visual Gasic","C++","GDScript"]
    y-axis "Elapsed (us)" 0 --> 1200
    bar [635,410,1040]
```

## Advanced Type System

### Generics
VisualGasic supports full generic programming with type parameters and constraints:

```gasic
' Generic function with type parameter
Function Process(Of T)(data As T) As T
    Return data
End Function

' Generic with constraints
Function Sort(Of T Where T Implements IComparable)(arr As T()) As T()
    ' Sorting implementation using IComparable.CompareTo
    For i As Integer = 0 To arr.Length - 2
        For j As Integer = i + 1 To arr.Length - 1
            If arr(i).CompareTo(arr(j)) > 0 Then
                Dim temp As T = arr(i)
                arr(i) = arr(j)
                arr(j) = temp
            End If
        Next
    Next
    Return arr
End Function

' Generic class
Class DataContainer(Of T)
    Private items As T()
    
    Sub New(capacity As Integer)
        ReDim items(capacity - 1)
    End Sub
    
    Function Get(index As Integer) As T
        Return items(index)
    End Function
    
    Sub Set(index As Integer, value As T)
        items(index) = value
    End Sub
End Class

' Usage
Dim numbers As New DataContainer(Of Integer)(10)
numbers.Set(0, 42)
Dim value As Integer = numbers.Get(0)

Dim names As New DataContainer(Of String)(5)
names.Set(0, "Hello")
Dim name As String = names.Get(0)
```

### Optional Types
Handle null values safely with optional types:

```gasic
' Optional type declaration
Function GetUserInput() As String?
    ' May return Nothing
    If SomeCondition Then
        Return "User Input"
    Else
        Return Nothing
    End If
End Function

Dim name As String? = GetUserInput()

' Check if value exists
If name.HasValue Then
    Print "Hello, " & name.Value
Else
    Print "No name provided"
End If

' Null coalescing operator
Dim displayName As String = name ?? "Anonymous"

' Safe navigation
Dim length As Integer? = name?.Length
```

### Union Types
Store multiple possible types in a single variable:

```gasic
' Union type declaration
Dim result As Integer | String | Boolean

result = 42
result = "Hello World"
result = True

' Type checking
If result Is Integer Then
    Print "It's a number: " & CInt(result)
ElseIf result Is String Then
    Print "It's text: " & CStr(result)
ElseIf result Is Boolean Then
    Print "It's boolean: " & CBool(result)
End If

' Pattern matching with union types
Select Match result
    Case Is Integer i
        Print "Number: " & i
    Case Is String s
        Print "Text: " & s
    Case Is Boolean b
        Print "Boolean: " & b
End Select
```

### Type Inference
Let the compiler determine types automatically:

```gasic
' Type inference in variable declarations
Dim count = 42              ' Inferred as Integer
Dim message = "Hello"       ' Inferred as String
Dim isValid = True          ' Inferred as Boolean
Dim numbers = {1, 2, 3}     ' Inferred as Integer()

' Type inference in function returns
Function CreateList()
    Return New List(Of String)()  ' Return type inferred as List(Of String)
End Function

' Type inference with generics
Dim container = New DataContainer(Of Integer)(10)  ' Type inferred from constructor
```

---

## Pattern Matching

### Core Pattern Matching
Advanced pattern matching with Select Match statements:

```gasic
Function ProcessValue(value As Object) As String
    Select Match value
        Case 0
            Return "Zero"
        Case 1, 2, 3
            Return "Small number"
        Case Is String s When s.Length > 10
            Return "Long string: " & s
        Case Is Integer i When i > 100
            Return "Large number: " & i
        Case Is Array arr When arr.Length > 0
            Return "Non-empty array with " & arr.Length & " items"
        Case Nothing
            Return "Null value"
        Case Else
            Return "Unknown type: " & value.GetType().Name
    End Select
End Function
```

### Destructuring Patterns
Decompose complex data structures:

```gasic
' Tuple destructuring
Dim point As (Integer, Integer) = (10, 20)
Select Match point
    Case (0, 0)
        Print "Origin"
    Case (x, 0)
        Print "On X axis at " & x
    Case (0, y)
        Print "On Y axis at " & y
    Case (x, y) When x = y
        Print "Diagonal point at " & x
    Case (x, y)
        Print "Point at (" & x & ", " & y & ")"
End Select

' Array destructuring
Dim numbers() As Integer = {1, 2, 3, 4, 5}
Select Match numbers
    Case {}
        Print "Empty array"
    Case {first}
        Print "Single item: " & first
    Case {first, second}
        Print "Two items: " & first & ", " & second
    Case {first, ...rest}
        Print "First: " & first & ", Rest: " & rest.Length & " items"
End Select
```

### Guard Clauses
Add conditions to patterns:

```gasic
Function Classify(value As Object) As String
    Select Match value
        Case Is String s When s.StartsWith("http")
            Return "URL: " & s
        Case Is String s When s.Contains("@")
            Return "Email: " & s
        Case Is String s When s.All(Function(c) Char.IsDigit(c))
            Return "Numeric string: " & s
        Case Is Integer i When i >= 0 AndAlso i <= 100
            Return "Percentage: " & i & "%"
        Case Is Integer i When i < 0
            Return "Negative number: " & i
        Case Else
            Return "Unclassified"
    End Select
End Function
```

---

## GPU Computing

### SIMD Vector Operations
High-performance vector operations using GPU acceleration:

```gasic
' Import GPU module
Imports VisualGasic.GPU

Sub PerformVectorOperations()
    ' Create vectors
    Dim vectorA As Vector(Of Single) = {1.0, 2.0, 3.0, 4.0, 5.0}
    Dim vectorB As Vector(Of Single) = {2.0, 3.0, 4.0, 5.0, 6.0}
    
    ' GPU-accelerated operations
    Dim sum As Vector(Of Single) = GPU.SIMDAdd(vectorA, vectorB)
    Dim product As Vector(Of Single) = GPU.SIMDMultiply(vectorA, vectorB)
    Dim dotProduct As Single = GPU.SIMDDotProduct(vectorA, vectorB)
    
    Print "Vector A: " & String.Join(", ", vectorA)
    Print "Vector B: " & String.Join(", ", vectorB)
    Print "Sum: " & String.Join(", ", sum)
    Print "Product: " & String.Join(", ", product)
    Print "Dot Product: " & dotProduct
End Sub
```

### Parallel Processing
Distribute work across GPU cores:

```gasic
Sub ParallelProcessing()
    ' Large dataset
    Dim data(999999) As Single
    
    ' Initialize with parallel processing
    GPU.ParallelFor(data.Length, Sub(i As Integer)
        data(i) = Sin(i * 0.001) * Cos(i * 0.002)
    End Sub)
    
    ' Process in parallel
    GPU.ParallelFor(data.Length, Sub(i As Integer)
        data(i) = data(i) * data(i) + 1.0  ' Square and add 1
    End Sub)
    
    Print "Processed " & data.Length & " elements"
End Sub
```

### Map-Reduce Operations
Distributed processing with automatic GPU/CPU fallback:

```gasic
Function CalculateStatistics(numbers As Array) As Dictionary
    ' Sum using map-reduce
    Dim sumResult As Dictionary = GPU.ParallelMapReduce(numbers,
        Function(x) CDbl(x),           ' Map: convert to double
        Function(a, b) CDbl(a) + CDbl(b) ' Reduce: sum
    )
    
    ' Sum of squares for variance calculation
    Dim sumSquaresResult As Dictionary = GPU.ParallelMapReduce(numbers,
        Function(x) CDbl(x) * CDbl(x), ' Map: square each number
        Function(a, b) CDbl(a) + CDbl(b) ' Reduce: sum squares
    )
    
    Dim count As Integer = numbers.Length
    Dim sum As Double = sumResult("result")
    Dim sumSquares As Double = sumSquaresResult("result")
    Dim mean As Double = sum / count
    Dim variance As Double = (sumSquares / count) - (mean * mean)
    
    Dim stats As New Dictionary
    stats("count") = count
    stats("sum") = sum
    stats("mean") = mean
    stats("variance") = variance
    stats("std_dev") = Math.Sqrt(variance)
    
    Return stats
End Function
```

---

## Interactive REPL

### Starting the REPL
Interactive development environment for rapid prototyping:

```gasic
' Create and start REPL
Dim repl As New VisualGasicREPL()
repl.StartInteractiveSession()

' The REPL provides immediate feedback:
' > Dim x As Integer = 42
' ✓ x = 42 (Integer)
' 
' > x + 10
' 52
' 
' > Print "Hello " & "World"
' Output: Hello World
```

### REPL Commands
Built-in commands for enhanced development experience:

```
:help           - Show all available commands
:vars           - List all variables with types and values
:clear          - Clear the screen (terminal environments)
:history        - Show command history
:load myfile.bas - Load and execute a script file
:save session.bas - Save current session to file
:reset          - Reset REPL state (clear all variables)
:type expression - Show type information for expression
:quit           - Exit REPL
```

### Advanced REPL Features
```gasic
' Variable inspection
' > :vars
' Variables:
'   x = 42 (Integer)
'   name = "John" (String)
'   active = True (Boolean)

' Expression evaluation with type checking
' > x + "hello"
' Error: Cannot add Integer and String

' Auto-completion for variables and functions
' > x.[TAB]
' Suggestions: ToString(), GetType(), Equals()

' Multi-line input support
' > Function Calculate() As Integer
' ...     Return 42 + 8
' ... End Function
' ✓ Calculate defined

' Pattern matching in REPL
' > Select Match 42
' ...     Case Is Integer i When i > 40
' ...         Print "Large integer"
' ... End Select
' Output: Large integer
```

---

## Advanced Debugging

### Time-Travel Debugging
Record and replay execution with full state inspection:

```gasic
' Start debug session with time-travel enabled
Sub Main()
    Debugger.StartSession("time_travel_demo")
    Debugger.EnableTimeTravel(True)
    Debugger.EnableProfiling(True)
    Debugger.EnableMemoryTracking(True)
    
    ' Your program code here
    ProcessData()
    
    Debugger.EndSession()
End Sub

Function ProcessData() As Integer
    Dim result As Integer = 0
    For i As Integer = 1 To 10
        result += i * i
        ' Execution automatically recorded for time-travel
    Next
    Return result
End Function
```

### Breakpoint Management
Set sophisticated breakpoints with conditions:

```gasic
' Set core breakpoint
Debugger.SetBreakpoint("myfile.gasic", 42)

' Set conditional breakpoint
Debugger.SetBreakpoint("myfile.gasic", 25, "counter > 10 AndAlso name IsNot Nothing")

' Set breakpoint with action
Debugger.SetBreakpoint("myfile.gasic", 30, "", "log")  ' Log instead of breaking

' In debug session, you can:
' :step_back       - Go to previous execution frame
' :step_forward    - Go to next execution frame  
' :goto_frame 100  - Jump to specific execution frame
' :show_history    - Display execution timeline
' :break_at ProcessData - Set breakpoint at function entry
```

### Performance Profiling
Analyze performance with detailed timing and hotspot detection:

```gasic
Function SlowFunction() As Integer
    ' Function automatically timed when profiling enabled
    Dim result As Integer = 0
    For i As Integer = 1 To 1000000
        result += Math.Sin(i) * Math.Cos(i)
    Next
    Return result
End Function

Sub AnalyzePerformance()
    ' Get performance data
    Dim profile As Dictionary = Debugger.GetPerformanceProfile()
    Dim hotspots As Array = Debugger.GetFunctionHotspots(10)
    
    Print "Performance Analysis:"
    Print "Session Duration: " & profile("total_session_time") & "μs"
    Print "CPU Usage: " & profile("cpu_usage") & "%"
    
    Print "Top 10 Hotspots:"
    For Each hotspot As Dictionary In hotspots
        Print "  " & hotspot("function") & ": " & 
              hotspot("total_time_us") & "μs (" & 
              hotspot("percentage") & "% of total)"
    Next
End Sub
```

### Memory Analysis
Track memory usage and detect leaks:

```gasic
Sub AnalyzeMemory()
    ' Get memory usage information
    Dim usage As Dictionary = Debugger.GetMemoryUsage()
    Print "Memory Analysis:"
    Print "  Total Allocated: " & usage("total_allocated") & " bytes"
    Print "  Total Freed: " & usage("total_freed") & " bytes"  
    Print "  Current Usage: " & usage("current_usage") & " bytes"
    Print "  Active Allocations: " & usage("active_allocations")
    
    ' Check for memory leaks
    Dim leaks As Array = Debugger.GetMemoryLeaks()
    If leaks.Count > 0 Then
        Print "Memory Leaks Detected: " & leaks.Count
        For Each leak As Dictionary In leaks
            Print "  Address: " & leak("address") & 
                  ", Size: " & leak("size") & " bytes"
        Next
    Else
        Print "No memory leaks detected"
    End If
    
    ' Memory snapshots over time
    Dim snapshots As Array = Debugger.GetMemorySnapshots()
    Print "Memory usage over " & snapshots.Count & " snapshots:"
    For Each snapshot As Dictionary In snapshots
        Print "  " & snapshot("timestamp_us") & ": " & 
              snapshot("active_allocations") & " allocations"
    Next
End Sub
```

---

## Package Management

### Project Configuration
Define project dependencies and metadata in Package.gasic:

```gasic
' Package.gasic - Project configuration file
Package "MyGameProject"
    Version "1.0.0"
    Description "An awesome 2D platformer game"
    Author "Game Developer"
    License "MIT"
    Homepage "https://github.com/dev/mygame"
    Repository "https://github.com/dev/mygame.git"
    Keywords {"game", "2d", "platformer", "godot"}
    
    Dependencies
        "MathLibrary" -> "^2.1.0"
        "JsonParser" -> "~1.5.0"
        "GameFramework" -> ">=3.0.0"
    End Dependencies
    
    DevDependencies
        "TestFramework" -> "^3.0.0"
        "MockingLibrary" -> "^1.2.0"
    End DevDependencies
    
    Scripts
        Build -> "gasic build src/"
        Test -> "gasic test tests/"
        Deploy -> "gasic deploy --target production"
        Start -> "gasic run src/main.bas"
    End Scripts
    
    Files
        "src/"
        "assets/"
        "README.md"
        "LICENSE"
    End Files
End Package
```

### Installing and Managing Packages
```bash
# Install specific version
gasic pkg install MathLibrary@2.1.0

# Install with semantic version constraint  
gasic pkg install MathLibrary@^2.1.0   # Compatible with 2.x.x (>=2.1.0 <3.0.0)
gasic pkg install JsonParser@~1.5.0    # Compatible with 1.5.x (>=1.5.0 <1.6.0)

# Install development dependencies
gasic pkg install TestFramework@^3.0.0 --dev

# Update packages
gasic pkg update MathLibrary           # Update specific package
gasic pkg update                       # Update all packages
gasic pkg outdated                     # Show outdated packages

# Remove packages
gasic pkg uninstall MathLibrary

# Search for packages
gasic pkg search "math utilities"
gasic pkg info MathLibrary            # Show package information

# Working with registries
gasic pkg registry add mycompany https://packages.mycompany.com
gasic pkg registry set-default mycompany
gasic pkg login mycompany             # Authenticate for private registry
```

### Using Installed Packages
```gasic
' Import and use packages in your code
Imports MathLibrary
Imports JsonParser

Sub Main()
    ' Use MathLibrary functions
    Dim result As Double = Math.Lerp(0.0, 10.0, 0.5)  ' Linear interpolation
    Dim clamped As Double = Math.Clamp(result, 2.0, 8.0)
    
    ' Use JsonParser
    Dim jsonData As String = "{""name"": ""John"", ""age"": 30}"
    Dim parsed As Dictionary = JSON.Parse(jsonData)
    
    Print "Name: " & parsed("name")
    Print "Age: " & parsed("age")
    Print "Result: " & clamped
End Sub
```

### Publishing Packages
```bash
# Initialize new package
gasic pkg init MyAwesomeLibrary --template library

# Validate package before publishing
gasic pkg validate

# Build package
gasic pkg build

# Publish to registry
gasic pkg publish                    # Publish to default registry
gasic pkg publish --registry mycompany # Publish to specific registry

# Version management
gasic pkg version patch             # Increment patch version (1.0.0 -> 1.0.1)
gasic pkg version minor             # Increment minor version (1.0.0 -> 1.1.0) 
gasic pkg version major             # Increment major version (1.0.0 -> 2.0.0)
```

---

## Entity Component System

### Core ECS Usage
High-performance game development with ECS architecture:

```gasic
Imports VisualGasic.ECS

Sub Main()
    ' Create ECS world
    Dim world As New ECSWorld()
    world.Initialize()
    
    ' Add built-in systems
    world.AddSystem(New MovementSystem())
    world.AddSystem(New RenderSystem())
    
    ' Create game entities
    CreatePlayer(world)
    CreateEnemies(world, 10)
    
    ' Game loop
    While True
        world.Update(GetFrameDelta())
        
        ' Handle input, render, etc.
        If Input.IsActionPressed("ui_cancel") Then
            Exit While
        End If
    Wend
    
    world.Shutdown()
End Sub

Function CreatePlayer(world As ECSWorld) As EntityId
    Dim player As EntityId = world.CreateEntity()
    
    ' Add components
    world.AddComponent(player, New TransformComponent() With {
        .Position = Vector3(0, 0, 0),
        .Rotation = Vector3(0, 0, 0),
        .Scale = Vector3(1, 1, 1)
    })
    
    world.AddComponent(player, New VelocityComponent() With {
        .LinearVelocity = Vector3(0, 0, 0),
        .AngularVelocity = Vector3(0, 0, 0)
    })
    
    world.AddComponent(player, New RenderComponent() With {
        .MeshPath = "res://models/player.glb",
        .MaterialPath = "res://materials/player.material",
        .Visible = True,
        .RenderLayer = 1
    })
    
    Return player
End Function
```

### Custom Components
Create domain-specific components:

```gasic
' Health component for game entities
Class HealthComponent
    Inherits ECSComponent
    
    Public MaxHealth As Integer = 100
    Public CurrentHealth As Integer = 100
    Public IsAlive As Boolean = True
    Public DamageResistance As Single = 0.0
    
    Sub TakeDamage(amount As Integer)
        Dim actualDamage As Integer = Math.Max(1, amount * (1.0 - DamageResistance))
        CurrentHealth -= actualDamage
        
        If CurrentHealth <= 0 Then
            CurrentHealth = 0
            IsAlive = False
        End If
    End Sub
    
    Sub Heal(amount As Integer)
        CurrentHealth = Math.Min(MaxHealth, CurrentHealth + amount)
        IsAlive = True
    End Sub
    
    Function GetHealthPercentage() As Single
        Return CSng(CurrentHealth) / CSng(MaxHealth)
    End Function
End Class

' AI component for enemy behavior
Class AIComponent  
    Inherits ECSComponent
    
    Public AIType As String = "aggressive"  ' aggressive, defensive, patrol
    Public TargetEntity As EntityId = ECS.INVALID_ENTITY
    Public PatrolPoints As Vector3() = {}
    Public CurrentPatrolIndex As Integer = 0
    Public DetectionRange As Single = 50.0
    Public AttackRange As Single = 10.0
    Public AttackCooldown As Single = 1.0
    Public LastAttackTime As Single = 0.0
    
    Function CanAttack() As Boolean
        Return (Time.GetTicksMsec() / 1000.0) - LastAttackTime >= AttackCooldown
    End Function
End Class
```

### Custom Systems
Implement game logic with high-performance systems:

```gasic
' Health management system
Class HealthSystem
    Inherits ECSSystem
    
    Private world As ECSWorld
    
    Public Overrides Sub Initialize(ecsWorld As ECSWorld)
        world = ecsWorld
    End Sub
    
    Public Overrides Sub Update(deltaTime As Double)
        ' Query entities with Health component
        Dim entities = world.QueryEntities({"HealthComponent"})
        
        For Each entity As EntityId In entities
            Dim health = world.GetComponent(Of HealthComponent)(entity)
            
            If Not health.IsAlive Then
                ' Handle death - could add death effects, drop items, etc.
                OnEntityDeath(entity)
                world.DestroyEntity(entity)
            End If
        Next
    End Sub
    
    Private Sub OnEntityDeath(entity As EntityId)
        ' Add death particle effect
        If world.HasComponent(Of RenderComponent)(entity) Then
            Dim render = world.GetComponent(Of RenderComponent)(entity)
            ' Spawn death effect at entity position
            ' SpawnParticleEffect("death_explosion", render.WorldPosition)
        End If
    End Sub
    
    Public Overrides Function GetName() As String
        Return "HealthSystem"
    End Function
    
    Public Overrides Function GetPriority() As Integer
        Return 50  ' Execute after movement but before rendering
    End Function
End Class

' AI behavior system
Class AISystem
    Inherits ECSSystem
    
    Private world As ECSWorld
    
    Public Overrides Sub Update(deltaTime As Double)
        ' Query entities with AI and Transform components
        Dim aiEntities = world.QueryEntities({"AIComponent", "TransformComponent"})
        
        For Each entity As EntityId In aiEntities
            Dim ai = world.GetComponent(Of AIComponent)(entity)
            Dim transform = world.GetComponent(Of TransformComponent)(entity)
            
            ' Update AI behavior based on type
            Select Case ai.AIType
                Case "aggressive"
                    UpdateAggressiveAI(entity, ai, transform, deltaTime)
                Case "defensive"
                    UpdateDefensiveAI(entity, ai, transform, deltaTime)
                Case "patrol"
                    UpdatePatrolAI(entity, ai, transform, deltaTime)
            End Select
        Next
    End Sub
    
    Private Sub UpdateAggressiveAI(entity As EntityId, ai As AIComponent, 
                                 transform As TransformComponent, deltaTime As Double)
        ' Find nearest target within detection range
        Dim target = FindNearestTarget(transform.Position, ai.DetectionRange)
        
        If target <> ECS.INVALID_ENTITY Then
            ai.TargetEntity = target
            
            ' Move towards target
            Dim targetPos = world.GetComponent(Of TransformComponent)(target).Position
            Dim direction = (targetPos - transform.Position).Normalized()
            
            If world.HasComponent(Of VelocityComponent)(entity) Then
                Dim velocity = world.GetComponent(Of VelocityComponent)(entity)
                velocity.LinearVelocity = direction * 20.0  ' Speed
            End If
            
            ' Attack if in range
            If transform.Position.DistanceTo(targetPos) <= ai.AttackRange AndAlso ai.CanAttack() Then
                PerformAttack(entity, target)
                ai.LastAttackTime = Time.GetTicksMsec() / 1000.0
            End If
        End If
    End Sub
    
    Private Function FindNearestTarget(position As Vector3, range As Single) As EntityId
        ' Implementation would search for player or other target entities
        Return ECS.INVALID_ENTITY  ' Placeholder
    End Function
    
    Private Sub PerformAttack(attacker As EntityId, target As EntityId)
        ' Deal damage to target if it has health component
        If world.HasComponent(Of HealthComponent)(target) Then
            Dim health = world.GetComponent(Of HealthComponent)(target)
            health.TakeDamage(25)
        End If
    End Sub
End Class
```

### ECS Performance Features
Leverage high-performance ECS optimizations:

```gasic
Sub OptimizedECSUsage()
    Dim world As New ECSWorld()
    
    ' Create optimized queries for frequently accessed entity groups
    Dim movableEntities = world.CreateQuery() _
        .WithComponent("TransformComponent") _
        .WithComponent("VelocityComponent") _
        .WithoutComponent("StaticComponent")
    
    Dim renderableEntities = world.CreateQuery() _
        .WithComponent("TransformComponent") _
        .WithComponent("RenderComponent")
    
    ' Batch operations for better performance
    Dim entities = movableEntities.GetEntities()
    world.BatchOperation(entities, Sub(entity As EntityId)
        Dim transform = world.GetComponent(Of TransformComponent)(entity)
        Dim velocity = world.GetComponent(Of VelocityComponent)(entity)
        
        ' Update position based on velocity
        transform.Position += velocity.LinearVelocity * GetFrameDelta()
        transform.Rotation += velocity.AngularVelocity * GetFrameDelta()
    End Sub)
    
    ' Get performance statistics
    Dim stats = world.GetPerformanceStats()
    Print "ECS Performance:"
    Print "  Entities: " & stats("entity_count")
    Print "  Systems: " & stats("system_count")
    Print "  Update Time: " & stats("update_time_ms") & "ms"
    Print "  Memory Usage: " & stats("memory_usage_mb") & "MB"
End Sub
```

---

## Language Server Protocol

### IDE Integration Features
VisualGasic provides professional IDE integration through LSP:

**Intelligent Code Completion:**
- Context-aware suggestions
- Function signatures and parameter hints
- Import statement completion
- Generic type parameter completion

**Advanced Navigation:**
- Go to definition across files
- Find all references with preview
- Symbol outline and breadcrumbs
- Workspace-wide symbol search

**Real-time Diagnostics:**
- Syntax error highlighting
- Semantic error detection
- Type mismatch warnings
- Unused variable detection

**Code Quality Tools:**
- Hover documentation with type info
- Inline parameter hints
- Code formatting and organization
- Import statement optimization

### LSP Configuration
Configure the language server for optimal development experience:

```json
{
  "visualgasic.lsp": {
    "diagnostics": {
      "enabled": true,
      "reportUnusedVariables": true,
      "reportTypeErrors": true,
      "maxProblems": 100
    },
    "completion": {
      "enabled": true,
      "autoImport": true,
      "showSnippets": true,
      "caseSensitive": false
    },
    "hover": {
      "enabled": true,
      "showExamples": true,
      "showTypeInfo": true
    },
    "formatting": {
      "indentSize": 4,
      "insertSpaces": true,
      "organizeImports": true
    }
  }
}
```

This comprehensive advanced features manual demonstrates VisualGasic's evolution into a professional-grade programming language with cutting-edge capabilities while maintaining the accessibility and rapid development benefits of VisualGasic.

---

## User-Defined Types (Enhanced)

### Type...End Type with Fixed-Length Strings

VisualGasic supports VB6-compatible User-Defined Types with fixed-length string members:

```vb
Type Employee
    FirstName As String * 20    ' Fixed at 20 characters
    LastName As String * 25     ' Fixed at 25 characters
    EmployeeID As Long
    Salary As Double
    Active As Boolean
End Type

Sub Main()
    Dim emp As Employee
    emp.FirstName = "John"       ' Padded to "John                " (20 chars)
    emp.LastName = "Smith"
    emp.EmployeeID = 12345
    emp.Salary = 75000.50
    emp.Active = True
    
    Print emp.FirstName & "|" & emp.LastName
    Print "Salary: $" & FormatNumber(emp.Salary, 2)
End Sub
```

### Strict Member Type Checking

Struct members enforce their declared type on assignment. Values are coerced automatically where possible:

```vb
Type GameConfig
    MaxPlayers As Integer
    Difficulty As Double
    Title As String
    Fullscreen As Boolean
End Type

Dim cfg As GameConfig
cfg.MaxPlayers = 3.7       ' Coerced to 3 (Integer)
cfg.Difficulty = "1.5"     ' Coerced to 1.5 (Double)
cfg.Title = 42             ' Coerced to "42" (String)
cfg.Fullscreen = 1         ' Coerced to True (Boolean)
```

### IntelliSense for Struct Members

When you type a variable name followed by `.`, the editor shows autocomplete suggestions with member names and types for any variable declared as a User-Defined Type. This works for `Dim`, `Private`, `Public`, and `Static` declarations.

### Nested Types

Types can contain other Types as members:

```vb
Type Address
    Street As String * 40
    City As String * 20
    ZipCode As String * 10
End Type

Type Contact
    Name As String * 30
    HomeAddress As Address
    WorkAddress As Address
End Type

Dim c As Contact
c.Name = "Alice"
c.HomeAddress.Street = "123 Main St"
c.HomeAddress.City = "Springfield"
```

---

## Financial Functions

VisualGasic includes all 13 VB6 financial functions for desktop application development — loan calculators, accounting tools, investment analysis, and business applications.

### Loan & Payment Functions

#### Pmt — Periodic Payment
```vb
' Calculate monthly mortgage payment
Dim monthlyRate As Double = 0.065 / 12   ' 6.5% annual rate
Dim payment As Double = Pmt(monthlyRate, 360, -250000)
Print "Monthly Payment: $" & FormatNumber(payment, 2)
' Output: Monthly Payment: $1580.17
```

**Syntax**: `Pmt(rate, nper, pv[, fv][, type]) As Double`
- `rate` — Interest rate per period
- `nper` — Total number of payment periods
- `pv` — Present value (principal), negative = loan amount
- `fv` — Future value (default 0)
- `type` — 0 = payment at end (default), 1 = payment at beginning

#### FV — Future Value
```vb
' How much will $100/month grow to in 20 years at 8% annual?
Dim futureValue As Double = FV(0.08/12, 240, -100, 0, 0)
Print "Future Value: $" & FormatNumber(futureValue, 2)
```

**Syntax**: `FV(rate, nper, pmt[, pv][, type]) As Double`

#### PV — Present Value
```vb
' What lump sum equals $500/month for 10 years at 5%?
Dim presentValue As Double = PV(0.05/12, 120, -500)
Print "Present Value: $" & FormatNumber(presentValue, 2)
```

**Syntax**: `PV(rate, nper, pmt[, fv][, type]) As Double`

#### Rate — Interest Rate Per Period
```vb
' What rate makes $200/month pay off $20000 in 10 years?
Dim monthlyRate As Double = Rate(120, -200, 20000)
Print "Annual Rate: " & FormatPercent(monthlyRate * 12, 2)
```

**Syntax**: `Rate(nper, pmt, pv[, fv][, type][, guess]) As Double`

#### NPER — Number of Periods
```vb
' How many months to pay off $15000 at 4% with $350/month?
Dim months As Double = NPER(0.04/12, -350, 15000)
Print "Months: " & Int(months)
```

**Syntax**: `NPER(rate, pmt, pv[, fv][, type]) As Double`

#### IPmt / PPmt — Interest and Principal Portions
```vb
' Break down payment #1 of a mortgage
Dim r As Double = 0.06 / 12
Dim n As Integer = 360
Dim p As Double = -200000

Dim interest As Double = IPmt(r, 1, n, p)
Dim principal As Double = PPmt(r, 1, n, p)
Print "Interest: $" & FormatNumber(interest, 2)
Print "Principal: $" & FormatNumber(principal, 2)
```

**Syntax**: `IPmt(rate, per, nper, pv[, fv][, type]) As Double`
**Syntax**: `PPmt(rate, per, nper, pv[, fv][, type]) As Double`

### Investment Analysis Functions

#### NPV — Net Present Value
```vb
Dim cashFlows() As Double = {-100000, 25000, 35000, 40000, 30000}
Dim result As Double = NPV(0.10, cashFlows)
Print "NPV at 10%: $" & FormatNumber(result, 2)
```

**Syntax**: `NPV(rate, values()) As Double`

#### IRR — Internal Rate of Return
```vb
Dim flows() As Double = {-50000, 15000, 18000, 20000, 12000}
Dim irrResult As Double = IRR(flows)
Print "IRR: " & FormatPercent(irrResult, 2)
```

**Syntax**: `IRR(values()[, guess]) As Double`
Uses Newton-Raphson iteration; `guess` defaults to 0.1 (10%).

#### MIRR — Modified Internal Rate of Return
```vb
Dim flows() As Double = {-120000, 39000, 30000, 21000, 37000, 46000}
Dim mirrResult As Double = MIRR(flows, 0.10, 0.12)
Print "MIRR: " & FormatPercent(mirrResult, 2)
```

**Syntax**: `MIRR(values(), financeRate, reinvestRate) As Double`

### Depreciation Functions

#### SLN — Straight-Line Depreciation
```vb
Dim annualDep As Double = SLN(50000, 5000, 7)
Print "Annual Depreciation: $" & FormatNumber(annualDep, 2)
```

**Syntax**: `SLN(cost, salvage, life) As Double`

#### SYD — Sum-of-Years-Digits Depreciation
```vb
For yr = 1 To 5
    Print "Year " & yr & ": $" & FormatNumber(SYD(30000, 3000, 5, yr), 2)
Next yr
```

**Syntax**: `SYD(cost, salvage, life, period) As Double`

#### DDB — Double Declining Balance Depreciation
```vb
Print "Year 1 DDB: $" & FormatNumber(DDB(50000, 5000, 7, 1), 2)
Print "Year 1 DDB (1.5x): $" & FormatNumber(DDB(50000, 5000, 7, 1, 1.5), 2)
```

**Syntax**: `DDB(cost, salvage, life, period[, factor]) As Double`
Default `factor` is 2.0 (double declining). Use 1.5 for 150% declining balance.

---

---

---

---

## Alphabetical Index

*Quick-jump: [A](#index-a) · [B](#index-b) · [C](#index-c) · [D](#index-d) · [E](#index-e) · [F](#index-f) · [G](#index-g) · [I](#index-i) · [L](#index-l) · [M](#index-m) · [N](#index-n) · [O](#index-o) · [P](#index-p) · [R](#index-r) · [S](#index-s) · [T](#index-t) · [U](#index-u)*


### A {#index-a}

- **Advanced Debugging** — [Advanced Debugging](#advanced-debugging)
- **Advanced REPL Features** — [Advanced REPL Features](#advanced-repl-features)
- **Advanced Type System** — [Advanced Type System](#advanced-type-system)

### B {#index-b}

- **Breakpoint Management** — [Breakpoint Management](#breakpoint-management)

### C {#index-c}

- **Core ECS Usage** — [Core ECS Usage](#core-ecs-usage)
- **Core Pattern Matching** — [Core Pattern Matching](#core-pattern-matching)
- **Custom Components** — [Custom Components](#custom-components)
- **Custom Systems** — [Custom Systems](#custom-systems)

### D {#index-d}

- **DDB** — [DDB — Double Declining Balance Depreciation](#ddb-double-declining-balance-depreciation)
- **Depreciation Functions** — [Depreciation Functions](#depreciation-functions)
- **Destructuring Patterns** — [Destructuring Patterns](#destructuring-patterns)

### E {#index-e}

- **ECS Performance Features** — [ECS Performance Features](#ecs-performance-features)
- **Enhanced** — [User-Defined Types (Enhanced)](#user-defined-types-enhanced)
- **Entity Component System** — [Entity Component System](#entity-component-system)

### F {#index-f}

- **Financial Functions** — [Financial Functions](#financial-functions)
- **FV** — [FV — Future Value](#fv-future-value)

### G {#index-g}

- **Generics** — [Generics](#generics)
- **GPU Computing** — [GPU Computing](#gpu-computing)
- **Guard Clauses** — [Guard Clauses](#guard-clauses)

### I {#index-i}

- **IDE Integration Features** — [IDE Integration Features](#ide-integration-features)
- **Installing and Managing Packages** — [Installing and Managing Packages](#installing-and-managing-packages)
- **IntelliSense for Struct Members** — [IntelliSense for Struct Members](#intellisense-for-struct-members)
- **Interactive REPL** — [Interactive REPL](#interactive-repl)
- **Investment Analysis Functions** — [Investment Analysis Functions](#investment-analysis-functions)
- **IPmt** — [IPmt / PPmt — Interest and Principal Portions](#ipmt-ppmt-interest-and-principal-portions)
- **IRR** — [IRR — Internal Rate of Return](#irr-internal-rate-of-return)

### L {#index-l}

- **Language Server Protocol** — [Language Server Protocol](#language-server-protocol)
- **Loan & Payment Functions** — [Loan & Payment Functions](#loan-payment-functions)
- **LSP Configuration** — [LSP Configuration](#lsp-configuration)

### M {#index-m}

- **Map-Reduce Operations** — [Map-Reduce Operations](#map-reduce-operations)
- **Memory Analysis** — [Memory Analysis](#memory-analysis)
- **MIRR** — [MIRR — Modified Internal Rate of Return](#mirr-modified-internal-rate-of-return)

### N {#index-n}

- **Nested Types** — [Nested Types](#nested-types)
- **NPER** — [NPER — Number of Periods](#nper-number-of-periods)
- **NPV** — [NPV — Net Present Value](#npv-net-present-value)

### O {#index-o}

- **Optional Types** — [Optional Types](#optional-types)

### P {#index-p}

- **Package Management** — [Package Management](#package-management)
- **Parallel Processing** — [Parallel Processing](#parallel-processing)
- **Pattern Matching** — [Pattern Matching](#pattern-matching)
- **Performance Profiling** — [Performance Profiling](#performance-profiling)
- **Performance Snapshot** — [Performance Snapshot](#performance-snapshot)
- **Pmt** — [Pmt — Periodic Payment](#pmt-periodic-payment)
- **PPmt — Interest and Principal Portions** — [IPmt / PPmt — Interest and Principal Portions](#ipmt-ppmt-interest-and-principal-portions)
- **Project Configuration** — [Project Configuration](#project-configuration)
- **Publishing Packages** — [Publishing Packages](#publishing-packages)
- **PV** — [PV — Present Value](#pv-present-value)

### R {#index-r}

- **Rate** — [Rate — Interest Rate Per Period](#rate-interest-rate-per-period)
- **REPL Commands** — [REPL Commands](#repl-commands)

### S {#index-s}

- **SIMD Vector Operations** — [SIMD Vector Operations](#simd-vector-operations)
- **SLN** — [SLN — Straight-Line Depreciation](#sln-straight-line-depreciation)
- **Starting the REPL** — [Starting the REPL](#starting-the-repl)
- **Strict Member Type Checking** — [Strict Member Type Checking](#strict-member-type-checking)
- **SYD** — [SYD — Sum-of-Years-Digits Depreciation](#syd-sum-of-years-digits-depreciation)

### T {#index-t}

- **Time-Travel Debugging** — [Time-Travel Debugging](#time-travel-debugging)
- **Type Inference** — [Type Inference](#type-inference)
- **Type...End Type with Fixed-Length Strings** — [Type...End Type with Fixed-Length Strings](#typeend-type-with-fixed-length-strings)

### U {#index-u}

- **Union Types** — [Union Types](#union-types)
- **User-Defined Types** — [User-Defined Types (Enhanced)](#user-defined-types-enhanced)
- **Using Installed Packages** — [Using Installed Packages](#using-installed-packages)
