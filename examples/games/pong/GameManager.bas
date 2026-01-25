' GameManager.bas - Score tracking and game states for Pong
Extends Control

Option Explicit On
Option Strict On

Public Class GameManager
    Inherits Control
    
    ' Game state
    Private playerScore As Integer = 0
    Private aiScore As Integer = 0
    Private maxScore As Integer = 5
    Private gameRunning As Boolean = True
    Private gamePaused As Boolean = False
    
    ' UI elements (assigned in Godot editor or created in code)
    Private scoreLabel As Label
    Private gameOverLabel As Label
    Private instructionsLabel As Label
    
    ' Game objects
    Private ball As Ball
    Private playerPaddle As Paddle  
    Private aiPaddle As Paddle
    
    ' Events
    Public Event GameOver(winner As String)
    Public Event ScoreChanged(playerScore As Integer, aiScore As Integer)
    
    Public Overrides Sub _Ready()
        InitializeUI()
        InitializeGame()
        SetupInput()
    End Sub
    
    Private Sub InitializeUI()
        ' Create UI elements if they don't exist
        If scoreLabel Is Nothing Then
            scoreLabel = New Label()
            scoreLabel.Position = Vector2(20, 20)
            scoreLabel.AddThemeStyleboxOverride("normal", Nothing) ' Transparent background
            AddChild(scoreLabel)
        End If
        
        If gameOverLabel Is Nothing Then
            gameOverLabel = New Label()
            gameOverLabel.Position = Vector2(400, 300)
            gameOverLabel.Visible = False
            AddChild(gameOverLabel)
        End If
        
        If instructionsLabel Is Nothing Then
            instructionsLabel = New Label()
            instructionsLabel.Text = "Player: W/S or Arrow Keys | Press SPACE to pause | First to " & maxScore.ToString() & " wins!"
            instructionsLabel.Position = Vector2(20, GetViewportRect().Size.Y - 40)
            AddChild(instructionsLabel)
        End If
        
        UpdateScoreDisplay()
    End Sub
    
    Private Sub InitializeGame()
        ' Create game objects
        CreateBall()
        CreatePaddles()
        
        ' Connect signals
        If ball IsNot Nothing Then
            AddressOf ball.GoalScored += OnGoalScored
        End If
    End Sub
    
    Private Sub CreateBall()
        ball = New Ball()
        ball.Position = GetViewportRect().Size / 2
        ball.Name = "Ball"
        AddChild(ball)
    End Sub
    
    Private Sub CreatePaddles()
        ' Create player paddle (left side)
        playerPaddle = New Paddle()
        playerPaddle.Position = Vector2(50, GetViewportRect().Size.Y / 2)
        playerPaddle.IsPlayer = True
        playerPaddle.Name = "PlayerPaddle"
        AddChild(playerPaddle)
        
        ' Create AI paddle (right side)  
        aiPaddle = New Paddle()
        aiPaddle.Position = Vector2(GetViewportRect().Size.X - 50, GetViewportRect().Size.Y / 2)
        aiPaddle.IsPlayer = False
        aiPaddle.Name = "AIPaddle"
        aiPaddle.SetAIDifficulty("medium")  ' Set difficulty
        AddChild(aiPaddle)
    End Sub
    
    Private Sub SetupInput()
        ' Define input actions (these should be set in Godot's Input Map)
        ' move_up: W key or Up Arrow
        ' move_down: S key or Down Arrow  
        ' pause_game: Space key
        ' restart_game: R key
    End Sub
    
    Public Overrides Sub _Process(delta As Single)
        HandleInput()
        
        If Not gameRunning Or gamePaused Then Return
        
        ' Update AI paddle (alternative to built-in AI)
        If aiPaddle IsNot Nothing And ball IsNot Nothing Then
            aiPaddle.FollowBall(ball.Position.Y)
        End If
        
        ' Check win condition
        If playerScore >= maxScore Or aiScore >= maxScore Then
            EndGame()
        End If
    End Sub
    
    Private Sub HandleInput()
        ' Handle pause
        If Input.IsActionJustPressed("pause_game") Or Input.IsKeyPressed(Key.Space) Then
            TogglePause()
        End If
        
        ' Handle restart
        If Input.IsActionJustPressed("restart_game") Or Input.IsKeyPressed(Key.R) Then
            RestartGame()
        End If
        
        ' Handle quit
        If Input.IsActionJustPressed("ui_cancel") Or Input.IsKeyPressed(Key.Escape) Then
            QuitGame()
        End If
    End Sub
    
    Private Sub OnGoalScored(goalSide As String)
        If Not gameRunning Then Return
        
        ' Update score
        If goalSide = "left" Then
            aiScore += 1
            Console.WriteLine("AI Scores! AI: " & aiScore.ToString() & " Player: " & playerScore.ToString())
        Else
            playerScore += 1
            Console.WriteLine("Player Scores! Player: " & playerScore.ToString() & " AI: " & aiScore.ToString())
        End If
        
        UpdateScoreDisplay()
        RaiseEvent ScoreChanged(playerScore, aiScore)
        
        ' Pause briefly before resetting ball
        gamePaused = True
        Dim timer As Timer = New Timer()
        timer.WaitTime = 1.0
        timer.OneShot = True
        timer.Connect("timeout", AddressOf OnResetDelay)
        AddChild(timer)
        timer.Start()
    End Sub
    
    Private Sub OnResetDelay()
        gamePaused = False
        If ball IsNot Nothing Then
            ball.ResetBall()
        End If
    End Sub
    
    Private Sub UpdateScoreDisplay()
        If scoreLabel IsNot Nothing Then
            scoreLabel.Text = $"Player: {playerScore}  |  AI: {aiScore}"
        End If
    End Sub
    
    Private Sub EndGame()
        gameRunning = False
        
        Dim winner As String
        If playerScore >= maxScore Then
            winner = "Player"
            If gameOverLabel IsNot Nothing Then
                gameOverLabel.Text = "🎉 PLAYER WINS! 🎉" & vbCrLf & "Press R to restart or ESC to quit"
            End If
        Else
            winner = "AI"
            If gameOverLabel IsNot Nothing Then
                gameOverLabel.Text = "💻 AI WINS! 💻" & vbCrLf & "Press R to restart or ESC to quit"
            End If
        End If
        
        If gameOverLabel IsNot Nothing Then
            gameOverLabel.Visible = True
            ' Center the label
            Dim labelSize As Vector2 = gameOverLabel.GetThemeFont("font").GetStringSize(gameOverLabel.Text)
            gameOverLabel.Position = (GetViewportRect().Size - labelSize) / 2
        End If
        
        RaiseEvent GameOver(winner)
        Console.WriteLine($"Game Over! {winner} wins!")
    End Sub
    
    Private Sub TogglePause()
        gamePaused = Not gamePaused
        
        If instructionsLabel IsNot Nothing Then
            If gamePaused Then
                instructionsLabel.Text = "PAUSED - Press SPACE to resume"
            Else
                instructionsLabel.Text = "Player: W/S or Arrow Keys | Press SPACE to pause | First to " & maxScore.ToString() & " wins!"
            End If
        End If
        
        Console.WriteLine(If(gamePaused, "Game Paused", "Game Resumed"))
    End Sub
    
    Public Sub RestartGame()
        ' Reset scores
        playerScore = 0
        aiScore = 0
        gameRunning = True
        gamePaused = False
        
        ' Hide game over screen
        If gameOverLabel IsNot Nothing Then
            gameOverLabel.Visible = False
        End If
        
        ' Reset ball
        If ball IsNot Nothing Then
            ball.ResetBall()
        End If
        
        UpdateScoreDisplay()
        Console.WriteLine("Game Restarted!")
    End Sub
    
    Private Sub QuitGame()
        Console.WriteLine("Thanks for playing!")
        GetTree().Quit()
    End Sub
    
    ' Public methods for external control
    Public Sub SetMaxScore(score As Integer)
        maxScore = Math.Max(1, score)
        UpdateScoreDisplay()
    End Sub
    
    Public Sub SetAIDifficulty(difficulty As String)
        If aiPaddle IsNot Nothing Then
            aiPaddle.SetAIDifficulty(difficulty)
        End If
    End Sub
    
    Public Function GetCurrentScore() As (playerScore As Integer, aiScore As Integer)
        Return (playerScore, aiScore)
    End Function
    
    Public Function IsGameRunning() As Boolean
        Return gameRunning And Not gamePaused
    End Function
End Class