# VisualGasic Example Projects
*Complete, working examples to learn from and build upon*

## 🎮 Game Projects

### 1. Pong Game (Beginner)
*Classic Pong implementation with modern VisualGasic features*

**Files**: `examples/games/pong/`
- `PongGame.vg` - Main game logic
- `Paddle.vg` - Player paddle class
- `Ball.vg` - Ball physics and collision
- `GameManager.vg` - Score tracking and game states
- `project.godot` - Godot project configuration

**Key Learning Topics**:
- Basic game loop
- Input handling
- Collision detection
- Score management
- Simple AI for computer player

**Complete Source Code:**

**Main Game (PongGame.vg):**
```vb
' PongGame.vg - Main game scene
Extends Control

Option Explicit On
Option Strict On

Public Class PongGame
    Inherits Control
    
    ' Use GameManager to handle all game logic
    Private gameManager As GameManager
    
    Public Overrides Sub _Ready()
        ' Create and initialize game manager
        gameManager = New GameManager()
        AddChild(gameManager)
        
        Console.WriteLine("Pong Game Started!")
        Console.WriteLine("Controls: W/S or Arrow Keys to move paddle")
        Console.WriteLine("Space to pause, R to restart, ESC to quit")
    End Sub
End Class
```

**Ball Class (Ball.vg):**
```vb
' Ball.vg - Ball physics and collision
Extends RigidBody2D

Public Class Ball
    Inherits RigidBody2D
    
    Public Property Speed As Single = 300.0
    Public Property Direction As Vector2 = Vector2(1, 0)
    Public Event GoalScored(goalSide As String)
    
    Public Overrides Sub _PhysicsProcess(delta As Single)
        ' Check for goals (ball goes off screen)
        If Position.X < -50 Then
            RaiseEvent GoalScored("left")
        ElseIf Position.X > GetViewportRect().Size.X + 50 Then
            RaiseEvent GoalScored("right")
        End If
        
        ' Keep consistent speed
        Dim velocity As Vector2 = GetLinearVelocity()
        If velocity.Length() > 0 Then
            SetLinearVelocity(velocity.Normalized() * Speed)
        End If
    End Sub
    
    Public Sub ResetBall()
        Position = GetViewportRect().Size / 2
        Dim randomDir As Integer = If(Randf() < 0.5, -1, 1)
        SetLinearVelocity(Vector2(randomDir, Randf() - 0.5) * Speed)
    End Sub
End Class
```

**Paddle Class (Paddle.vg):**
```vb
' Paddle.vg - Player and AI paddle
Extends CharacterBody2D

Public Class Paddle
    Inherits CharacterBody2D
    
    Public Property Speed As Single = 400.0
    Public Property IsPlayer As Boolean = True
    Private followSpeed As Single = 200.0
    
    Public Overrides Sub _PhysicsProcess(delta As Single)
        Dim velocity As Vector2 = Vector2.Zero
        
        If IsPlayer Then
            ' Player controls
            If Input.IsKeyPressed(Key.W) Or Input.IsActionPressed("ui_up") Then
                velocity.Y = -Speed
            ElseIf Input.IsKeyPressed(Key.S) Or Input.IsActionPressed("ui_down") Then
                velocity.Y = Speed
            End If
        End If
        
        SetVelocity(velocity)
        MoveAndSlide()
        ClampToBounds()
    End Sub
    
    Public Sub FollowBall(ballY As Single)
        ' AI movement
        Dim difference As Single = ballY - Position.Y
        If Math.Abs(difference) > 10 Then
            Dim moveAmount As Single = followSpeed * GetPhysicsProcessDeltaTime()
            Position = New Vector2(Position.X, Position.Y + Math.Sign(difference) * moveAmount)
            ClampToBounds()
        End If
    End Sub
    
    Private Sub ClampToBounds()
        Dim screenHeight As Single = GetViewportRect().Size.Y
        Position = New Vector2(Position.X, Math.Max(40, Math.Min(screenHeight - 40, Position.Y)))
    End Sub
End Class
```

### 2. Space Shooter (Intermediate)
*Top-down space shooter with enemies, power-ups, and particle effects*

**Files**: `examples/games/space_shooter/`
- `Player.vg` - Player ship with weapons
- `Enemy.vg` - Enemy AI and behavior
- `Bullet.vg` - Projectile system
- `PowerUp.vg` - Collectible upgrades
- `GameScreen.vg` - Main game scene
- `UIManager.vg` - HUD and menus

**Key Learning Topics**:
- Object pooling for bullets
- Enemy AI patterns
- Particle systems
- Power-up system
- Background scrolling
- Game state management

### 3. Platformer Adventure (Advanced)
*2D platformer with multiple levels, collectibles, and animated characters*

**Files**: `examples/games/platformer/`
- `Player.vg` - Character controller with animations
- `Level.vg` - Level management and transitions
- `Enemy.vg` - Various enemy types
- `Collectible.vg` - Items and power-ups
- `Platform.vg` - Moving and interactive platforms
- `GameData.vg` - Save/load system

**Key Learning Topics**:
- Character state machines
- Level design and tilemaps
- Animation systems
- Save/load functionality
- Camera following
- Physics and collision layers

## 💼 Business Applications

### 4. Inventory Manager (Beginner-Intermediate)
*Complete inventory management system with database integration*

**Files**: `examples/business/inventory_manager/`
- `MainWindow.vg` - Main application window
- `Product.vg` - Product data class
- `Database.vg` - SQLite database operations
- `Reports.vg` - Inventory reports
- `ImportExport.vg` - CSV import/export

**Key Learning Topics**:
- Database design and operations
- Data binding to UI controls
- Report generation
- File operations
- Input validation
- CRUD operations

**Code Preview**:
```vb
' Product.vg - Product data model
Option Explicit On
Option Strict On

Public Class Product
    Public Property ID As Integer
    Public Property Name As String
    Public Property SKU As String
    Public Property Category As String
    Public Property Quantity As Integer
    Public Property UnitPrice As Decimal
    Public Property ReorderLevel As Integer
    Public Property Supplier As String
    Public Property DateAdded As DateTime
    
    Public Sub New()
        DateAdded = DateTime.Now
    End Sub
    
    Public Sub New(name As String, sku As String, category As String, 
                   quantity As Integer, unitPrice As Decimal)
        Me.Name = name
        Me.SKU = sku
        Me.Category = category
        Me.Quantity = quantity
        Me.UnitPrice = unitPrice
        Me.DateAdded = DateTime.Now
    End Sub
    
    Public ReadOnly Property TotalValue As Decimal
        Get
            Return Quantity * UnitPrice
        End Get
    End Property
    
    Public ReadOnly Property IsLowStock As Boolean
        Get
            Return Quantity <= ReorderLevel
        End Get
    End Property
    
    Public Function ToCSVString() As String
        Return $"{ID},{Name},{SKU},{Category},{Quantity},{UnitPrice},{ReorderLevel},{Supplier},{DateAdded:yyyy-MM-dd}"
    End Function
    
    Public Shared Function FromCSVString(csvLine As String) As Product
        Dim parts() As String = csvLine.Split(","c)
        If parts.Length <> 9 Then
            Throw New ArgumentException("Invalid CSV format")
        End If
        
        Dim product As New Product()
        product.ID = Integer.Parse(parts(0))
        product.Name = parts(1)
        product.SKU = parts(2)
        product.Category = parts(3)
        product.Quantity = Integer.Parse(parts(4))
        product.UnitPrice = Decimal.Parse(parts(5))
        product.ReorderLevel = Integer.Parse(parts(6))
        product.Supplier = parts(7)
        product.DateAdded = DateTime.Parse(parts(8))
        
        Return product
    End Function
End Class
```

### 5. Personal Finance Tracker (Intermediate)
*Track income, expenses, budgets, and generate financial reports*

**Files**: `examples/business/finance_tracker/`
- `Transaction.vg` - Financial transaction model
- `Category.vg` - Expense/income categories
- `Budget.vg` - Budget planning and tracking
- `Report.vg` - Financial reports and charts
- `BankImport.vg` - Import from bank statements

### 6. Student Management System (Advanced)
*Complete school management with students, courses, grades, and reporting*

**Files**: `examples/business/student_management/`
- `Student.vg` - Student information
- `Course.vg` - Course management
- `Grade.vg` - Grading system
- `Teacher.vg` - Teacher profiles
- `Schedule.vg` - Class scheduling
- `ReportCard.vg` - Report generation

## 🧮 Utility Applications

### 7. Advanced Calculator (Beginner)
*Scientific calculator with history and programmable functions*

**Files**: `examples/utilities/calculator/`
- `Calculator.vg` - Main calculator logic
- `MathEngine.vg` - Mathematical operations
- `History.vg` - Calculation history
- `Functions.vg` - Custom functions

**Code Preview**:
```vb
' Calculator.vg - Main calculator class
Option Explicit On
Option Strict On

Imports System.Math

Public Class Calculator
    Private currentValue As Double = 0
    Private previousValue As Double = 0
    Private operation As String = ""
    Private history As New List(Of String)
    Private memoryValue As Double = 0
    
    Public Sub Clear()
        currentValue = 0
        previousValue = 0
        operation = ""
    End Sub
    
    Public Sub EnterNumber(number As Double)
        currentValue = number
        UpdateDisplay()
    End Sub
    
    Public Sub SetOperation(op As String)
        If operation <> "" Then
            Calculate()
        End If
        previousValue = currentValue
        operation = op
        currentValue = 0
    End Sub
    
    Public Function Calculate() As Double
        Dim result As Double = 0
        
        Select Case operation
            Case "+"
                result = previousValue + currentValue
            Case "-"
                result = previousValue - currentValue
            Case "*"
                result = previousValue * currentValue
            Case "/"
                If currentValue = 0 Then
                    Throw New DivideByZeroException("Cannot divide by zero")
                End If
                result = previousValue / currentValue
            Case "^"
                result = Pow(previousValue, currentValue)
            Case "mod"
                result = previousValue Mod currentValue
            Case Else
                result = currentValue
        End Select
        
        ' Add to history
        If operation <> "" Then
            history.Add($"{previousValue} {operation} {currentValue} = {result}")
        End If
        
        currentValue = result
        operation = ""
        UpdateDisplay()
        Return result
    End Function
    
    ' Scientific functions
    Public Function Sin(angle As Double) As Double
        Return Math.Sin(angle * Math.PI / 180) ' Convert degrees to radians
    End Function
    
    Public Function Cos(angle As Double) As Double
        Return Math.Cos(angle * Math.PI / 180)
    End Function
    
    Public Function Tan(angle As Double) As Double
        Return Math.Tan(angle * Math.PI / 180)
    End Function
    
    Public Function Log(value As Double) As Double
        If value <= 0 Then
            Throw New ArgumentException("Logarithm of non-positive number")
        End If
        Return Math.Log10(value)
    End Function
    
    Public Function Ln(value As Double) As Double
        If value <= 0 Then
            Throw New ArgumentException("Natural logarithm of non-positive number")
        End If
        Return Math.Log(value)
    End Function
    
    Public Function Sqrt(value As Double) As Double
        If value < 0 Then
            Throw New ArgumentException("Square root of negative number")
        End If
        Return Math.Sqrt(value)
    End Function
    
    ' Memory functions
    Public Sub MemoryStore()
        memoryValue = currentValue
    End Sub
    
    Public Sub MemoryRecall()
        currentValue = memoryValue
        UpdateDisplay()
    End Sub
    
    Public Sub MemoryAdd()
        memoryValue += currentValue
    End Sub
    
    Public Sub MemorySubtract()
        memoryValue -= currentValue
    End Sub
    
    Public Sub MemoryClear()
        memoryValue = 0
    End Sub
    
    Public Function GetHistory() As List(Of String)
        Return New List(Of String)(history)
    End Function
    
    Private Sub UpdateDisplay()
        ' This would update the UI display
        ' Implementation depends on UI framework
    End Sub
End Class
```

### 8. File Organizer (Intermediate)
*Automatically organize files based on type, date, or custom rules*

**Files**: `examples/utilities/file_organizer/`
- `FileManager.vg` - File operations
- `Rules.vg` - Organization rules
- `Monitor.vg` - Folder monitoring
- `Settings.vg` - Application settings

### 9. Password Manager (Advanced)
*Secure password storage with encryption and auto-generation*

**Files**: `examples/utilities/password_manager/`
- `PasswordVault.vg` - Encrypted storage
- `PasswordGenerator.vg` - Secure generation
- `Encryption.vg` - AES encryption
- `SecureForm.vg` - Secure UI components

## 🌐 Web and Network Applications

### 10. Weather App (Intermediate)
*Get weather data from APIs with forecasts and location services*

**Files**: `examples/web/weather_app/`
- `WeatherAPI.vg` - API integration
- `Location.vg` - GPS and location services  
- `Forecast.vg` - Weather data models
- `UI.vg` - Weather display interface

### 11. Chat Client (Advanced)
*Real-time chat application with networking*

**Files**: `examples/web/chat_client/`
- `ChatClient.vg` - Network client
- `MessageHandler.vg` - Message processing
- `UI.vg` - Chat interface
- `Protocol.vg` - Communication protocol

### 12. RSS Reader (Intermediate)
*Subscribe to RSS feeds and display articles*

**Files**: `examples/web/rss_reader/`
- `FeedParser.vg` - RSS/XML parsing
- `Article.vg` - Article data model
- `Subscription.vg` - Feed management
- `UI.vg` - Article display

## 🎨 Creative and Multimedia

### 13. Image Viewer (Beginner-Intermediate)
*View and organize images with basic editing tools*

**Files**: `examples/multimedia/image_viewer/`
- `ImageManager.vg` - Image loading and display
- `Thumbnail.vg` - Thumbnail generation
- `BasicEdit.vg` - Resize, rotate, crop
- `Gallery.vg` - Image gallery view

### 14. Music Player (Intermediate)
*Play music files with playlists and controls*

**Files**: `examples/multimedia/music_player/`
- `AudioPlayer.vg` - Audio playback
- `Playlist.vg` - Playlist management
- `Metadata.vg` - ID3 tag reading
- `Visualizer.vg` - Audio visualization

### 15. Drawing Application (Advanced)
*Create digital artwork with brushes, layers, and effects*

**Files**: `examples/multimedia/drawing_app/`
- `Canvas.vg` - Drawing surface
- `Brush.vg` - Drawing tools
- `Layer.vg` - Layer management
- `Effects.vg` - Image effects

## 📊 Data Analysis and Visualization

### 16. CSV Data Analyzer (Intermediate)
*Import, analyze, and visualize CSV data*

**Files**: `examples/data/csv_analyzer/`
- `CSVImporter.vg` - File parsing
- `DataAnalysis.vg` - Statistical analysis
- `Charts.vg` - Data visualization
- `Export.vg` - Report generation

**Code Preview**:
```vb
' DataAnalysis.vg - Statistical analysis functions
Option Explicit On
Option Strict On

Imports System.Linq

Public Class DataAnalysis
    Public Shared Function CalculateMean(values As List(Of Double)) As Double
        If values.Count = 0 Then Return 0
        Return values.Sum() / values.Count
    End Function
    
    Public Shared Function CalculateMedian(values As List(Of Double)) As Double
        If values.Count = 0 Then Return 0
        
        Dim sorted = values.OrderBy(Function(x) x).ToList()
        Dim mid As Integer = sorted.Count / 2
        
        If sorted.Count Mod 2 = 0 Then
            Return (sorted(mid - 1) + sorted(mid)) / 2
        Else
            Return sorted(mid)
        End If
    End Function
    
    Public Shared Function CalculateStandardDeviation(values As List(Of Double)) As Double
        If values.Count <= 1 Then Return 0
        
        Dim mean As Double = CalculateMean(values)
        Dim sumSquaredDifferences As Double = 0
        
        For Each value In values
            sumSquaredDifferences += Math.Pow(value - mean, 2)
        Next
        
        Return Math.Sqrt(sumSquaredDifferences / (values.Count - 1))
    End Function
    
    Public Shared Function FindCorrelation(x As List(Of Double), y As List(Of Double)) As Double
        If x.Count <> y.Count Or x.Count = 0 Then
            Throw New ArgumentException("Lists must have the same non-zero length")
        End If
        
        Dim meanX As Double = CalculateMean(x)
        Dim meanY As Double = CalculateMean(y)
        
        Dim numerator As Double = 0
        Dim sumSquaredX As Double = 0
        Dim sumSquaredY As Double = 0
        
        For i As Integer = 0 To x.Count - 1
            Dim diffX As Double = x(i) - meanX
            Dim diffY As Double = y(i) - meanY
            
            numerator += diffX * diffY
            sumSquaredX += diffX * diffX
            sumSquaredY += diffY * diffY
        Next
        
        Dim denominator As Double = Math.Sqrt(sumSquaredX * sumSquaredY)
        If denominator = 0 Then Return 0
        
        Return numerator / denominator
    End Function
End Class
```

### 17. Database Reporter (Advanced)
*Connect to databases and generate custom reports*

**Files**: `examples/data/database_reporter/`
- `DatabaseConnection.vg` - Multi-database support
- `QueryBuilder.vg` - Dynamic SQL generation
- `ReportEngine.vg` - Report formatting
- `Scheduler.vg` - Automated reports

## 🎓 Educational Projects

### 18. Math Tutor (Beginner-Intermediate)
*Interactive math problems for different skill levels*

**Files**: `examples/educational/math_tutor/`
- `ProblemGenerator.vg` - Math problem creation
- `ProgressTracker.vg` - Student progress
- `Difficulty.vg` - Adaptive difficulty
- `Rewards.vg` - Achievement system

### 19. Typing Tutor (Intermediate)
*Learn touch typing with lessons and games*

**Files**: `examples/educational/typing_tutor/`
- `Lesson.vg` - Typing lessons
- `WordGame.vg` - Typing games
- `Statistics.vg` - WPM and accuracy
- `Keyboard.vg` - Virtual keyboard

### 20. Language Learning Flashcards (Advanced)
*Spaced repetition flashcard system*

**Files**: `examples/educational/flashcards/`
- `Card.vg` - Flashcard model
- `SpacedRepetition.vg` - Learning algorithm
- `Deck.vg` - Card organization
- `Progress.vg` - Learning analytics

## 🔧 System Utilities

### 21. System Monitor (Advanced)
*Monitor CPU, memory, disk, and network usage*

**Files**: `examples/system/monitor/`
- `SystemInfo.vg` - Hardware information
- `Performance.vg` - Performance metrics
- `Alerts.vg` - System alerts
- `Logging.vg` - Performance logging

### 22. Backup Manager (Intermediate-Advanced)
*Automated file backup with scheduling*

**Files**: `examples/system/backup_manager/`
- `BackupEngine.vg` - Backup operations
- `Schedule.vg` - Backup scheduling
- `Compression.vg` - File compression
- `Encryption.vg` - Backup encryption

## 📱 Cross-Platform Applications

### 23. Note Taking App (Intermediate)
*Rich text notes with synchronization*

**Files**: `examples/cross_platform/notes/`
- `Note.vg` - Note data model
- `RichTextEditor.vg` - Text editing
- `Sync.vg` - Cloud synchronization
- `Search.vg` - Full-text search

### 24. Todo Manager (Beginner-Intermediate)
*Task management with categories and reminders*

**Files**: `examples/cross_platform/todo/`
- `Task.vg` - Task model
- `Category.vg` - Task categories
- `Reminder.vg` - Notification system
- `Export.vg` - Data export

## 🎯 Getting Started with Examples

### How to Use These Examples

1. **Choose Your Level**: Start with beginner projects if you're new to programming
2. **Download the Code**: Each example includes complete, runnable source code  
3. **Follow the Tutorial**: Each project has step-by-step instructions
4. **Modify and Experiment**: Change the code to see how it affects the program
5. **Build Your Own**: Use the examples as starting points for your own projects

### Running the Examples

```bash
# Clone the repository
git clone https://github.com/yourusername/visualgasic-examples.git
cd visualgasic-examples

# Navigate to any example
cd examples/games/pong

# Open in VisualGasic IDE
visualgasic PongGame.vgproj
```

### Example Project Structure
```
example_project/
├── src/                    # Source code files
│   ├── Main.vg           # Main application file
│   ├── Classes/           # Class definitions
│   └── Forms/             # UI forms (if applicable)
├── assets/                # Images, sounds, data files
├── docs/                  # Documentation and tutorials
│   ├── README.md          # Project overview
│   ├── TUTORIAL.md        # Step-by-step guide
│   └── API.md             # Code reference
├── tests/                 # Unit tests
├── project.vgproj         # VisualGasic project file
└── LICENSE                # Project license
```

### Contributing Examples

We welcome contributions! To submit your own example:

1. **Fork the Repository**: Create your own copy
2. **Create Your Example**: Follow our structure guidelines
3. **Write Documentation**: Include clear instructions and comments
4. **Test Thoroughly**: Ensure your code works correctly
5. **Submit a Pull Request**: Share your example with the community

### Example Categories by Skill Level

**🟢 Beginner (0-6 months experience)**
- Pong Game
- Advanced Calculator  
- Inventory Manager
- Image Viewer
- Todo Manager

**🟡 Intermediate (6+ months experience)**
- Space Shooter
- Personal Finance Tracker
- File Organizer
- Weather App
- CSV Data Analyzer

**🔴 Advanced (1+ years experience)**  
- Platformer Adventure
- Student Management System
- Password Manager
- Chat Client
- Drawing Application

### Learning Path Recommendations

1. **Start Here**: Hello World Calculator → Pong Game
2. **Build Skills**: Inventory Manager → Weather App  
3. **Add Complexity**: Space Shooter → Drawing Application
4. **Master Advanced**: Chat Client → System Monitor

### Support and Help

- **Documentation**: Each example includes comprehensive docs
- **Video Tutorials**: Watch step-by-step video guides  
- **Community Forum**: Get help from other developers
- **GitHub Issues**: Report bugs or request features

---

*Ready to start coding? Pick an example that interests you and begin your VisualGasic journey!*