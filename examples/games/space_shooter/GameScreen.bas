' GameScreen.bas - Main game scene for Space Shooter
Extends Control

Option Explicit On
Option Strict On

Public Class GameScreen
    Inherits Control
    
    ' Game objects
    Private player As Player
    Private enemies As List(Of Enemy)
    Private bullets As List(Of Bullet)
    Private powerUps As List(Of PowerUp)
    
    ' Game state
    Private gameRunning As Boolean = True
    Private gamePaused As Boolean = False
    Private currentWave As Integer = 1
    Private enemiesInWave As Integer = 5
    Private enemiesSpawned As Integer = 0
    Private enemiesKilled As Integer = 0
    
    ' Spawning
    Private enemySpawnTimer As Timer
    Private waveSpawnDelay As Single = 2.0
    Private enemySpawnRate As Single = 1.5  ' Seconds between spawns
    
    ' UI Manager
    Private uiManager As UIManager
    
    ' Background scrolling
    Private backgroundSpeed As Single = 50.0
    Private background1 As TextureRect
    Private background2 As TextureRect
    
    ' Events
    Public Event GameOver(finalScore As Integer)
    Public Event WaveCompleted(waveNumber As Integer)
    Public Event PlayerScoreChanged(newScore As Integer)
    
    Public Overrides Sub _Ready()
        Console.WriteLine("Space Shooter: Game Starting!")
        
        InitializeGame()
        SetupUI()
        SetupBackground()
        StartWave()
    End Sub
    
    Private Sub InitializeGame()
        ' Initialize collections
        enemies = New List(Of Enemy)()
        bullets = New List(Of Bullet)()
        powerUps = New List(Of PowerUp)()
        
        ' Create player
        CreatePlayer()
        
        ' Set up enemy spawning
        SetupEnemySpawning()
        
        Console.WriteLine("Game initialized successfully!")
    End Sub
    
    Private Sub CreatePlayer()
        player = New Player()
        player.Position = Vector2(GetViewportRect().Size.X / 2, GetViewportRect().Size.Y - 100)
        AddChild(player)
        
        ' Connect player events
        AddressOf player.PlayerDied += OnPlayerDied
        AddressOf player.PlayerHit += OnPlayerHit
        AddressOf player.WeaponUpgraded += OnWeaponUpgraded
        AddressOf player.ScoreChanged += OnPlayerScoreChanged
        
        Console.WriteLine("Player created and ready!")
    End Sub
    
    Private Sub SetupEnemySpawning()
        enemySpawnTimer = New Timer()
        enemySpawnTimer.WaitTime = enemySpawnRate
        enemySpawnTimer.Autostart = True
        enemySpawnTimer.Connect("timeout", AddressOf SpawnEnemy)
        AddChild(enemySpawnTimer)
    End Sub
    
    Private Sub SetupUI()
        uiManager = New UIManager()
        AddChild(uiManager)
        
        ' Connect UI events
        AddressOf uiManager.GamePaused += OnGamePaused
        AddressOf uiManager.GameResumed += OnGameResumed
        AddressOf uiManager.RestartRequested += OnRestartRequested
        
        ' Initialize UI with player data
        If player IsNot Nothing Then
            uiManager.UpdateHealth(player.GetHealthPercent())
            uiManager.UpdateScore(player.GetScore())
            uiManager.UpdateLives(player.Lives)
            uiManager.UpdateWave(currentWave)
        End If
    End Sub
    
    Private Sub SetupBackground()
        ' Create scrolling space background
        background1 = CreateBackgroundLayer(0)
        background2 = CreateBackgroundLayer(-GetViewportRect().Size.Y)
        
        AddChild(background1)
        AddChild(background2)
        
        ' Move backgrounds behind other elements
        MoveChild(background1, 0)
        MoveChild(background2, 1)
    End Sub
    
    Private Function CreateBackgroundLayer(yOffset As Single) As TextureRect
        Dim bg As New TextureRect()
        bg.Size = GetViewportRect().Size
        bg.Position = Vector2(0, yOffset)
        
        ' Create a simple starfield effect using ColorRect
        Dim starField As ColorRect = New ColorRect()
        starField.Size = bg.Size
        starField.Color = Color.Black
        bg.AddChild(starField)
        
        ' Add some "stars" (small white rectangles)
        For i As Integer = 0 To 50
            Dim star As ColorRect = New ColorRect()
            star.Size = Vector2(2, 2)
            star.Position = Vector2(Randf() * bg.Size.X, Randf() * bg.Size.Y)
            star.Color = Color(1, 1, 1, Randf() * 0.8 + 0.2)  ' Random brightness
            starField.AddChild(star)
        Next
        
        Return bg
    End Sub
    
    Public Overrides Sub _Process(delta As Single)
        If Not gameRunning Then Return
        
        If gamePaused Then
            HandlePauseInput()
            Return
        End If
        
        HandleInput()
        UpdateBackground(delta)
        UpdateGameLogic(delta)
        CleanupObjects()
        CheckWaveProgress()
    End Sub
    
    Private Sub HandleInput()
        ' Pause game
        If Input.IsActionJustPressed("pause_game") Or Input.IsKeyPressed(Key.Escape) Then
            TogglePause()
        End If
    End Sub
    
    Private Sub HandlePauseInput()
        If Input.IsActionJustPressed("pause_game") Or Input.IsKeyPressed(Key.Escape) Then
            TogglePause()
        End If
    End Sub
    
    Private Sub UpdateBackground(delta As Single)
        ' Scroll backgrounds downward
        background1.Position += Vector2(0, backgroundSpeed * delta)
        background2.Position += Vector2(0, backgroundSpeed * delta)
        
        ' Reset positions when off screen
        Dim screenHeight As Single = GetViewportRect().Size.Y
        If background1.Position.Y >= screenHeight Then
            background1.Position = Vector2(0, background2.Position.Y - screenHeight)
        End If
        If background2.Position.Y >= screenHeight Then
            background2.Position = Vector2(0, background1.Position.Y - screenHeight)
        End If
    End Sub
    
    Private Sub UpdateGameLogic(delta As Single)
        ' Update UI
        If player IsNot Nothing And uiManager IsNot Nothing Then
            uiManager.UpdateHealth(player.GetHealthPercent())
            uiManager.UpdateScore(player.GetScore())
            uiManager.UpdateLives(player.Lives)
        End If
    End Sub
    
    Private Sub CleanupObjects()
        ' Clean up destroyed enemies
        For i As Integer = enemies.Count - 1 To 0 Step -1
            If enemies(i) Is Nothing Or Not IsInstanceValid(enemies(i)) Then
                enemies.RemoveAt(i)
            End If
        Next
        
        ' Clean up destroyed bullets
        For i As Integer = bullets.Count - 1 To 0 Step -1
            If bullets(i) Is Nothing Or Not IsInstanceValid(bullets(i)) Then
                bullets.RemoveAt(i)
            End If
        Next
        
        ' Clean up collected power-ups
        For i As Integer = powerUps.Count - 1 To 0 Step -1
            If powerUps(i) Is Nothing Or Not IsInstanceValid(powerUps(i)) Then
                powerUps.RemoveAt(i)
            End If
        Next
    End Sub
    
    Private Sub SpawnEnemy()
        If Not gameRunning Or gamePaused Then Return
        If enemiesSpawned >= enemiesInWave Then Return
        
        ' Random spawn position across top of screen
        Dim spawnX As Single = Randf() * GetViewportRect().Size.X
        Dim spawnPos As Vector2 = Vector2(spawnX, -50)
        
        ' Choose enemy type based on wave
        Dim enemyType As String = ChooseEnemyType()
        
        ' Create and configure enemy
        Dim enemy As Enemy = Enemy.CreateEnemy(enemyType, spawnPos)
        AddChild(enemy)
        enemies.Add(enemy)
        
        ' Connect enemy events
        AddressOf enemy.EnemyDestroyed += OnEnemyDestroyed
        AddressOf enemy.EnemyHitPlayer += OnEnemyHitPlayer
        
        enemiesSpawned += 1
        Console.WriteLine($"Enemy spawned: {enemyType} ({enemiesSpawned}/{enemiesInWave})")
    End Sub
    
    Private Function ChooseEnemyType() As String
        ' Enemy types get more difficult with higher waves
        Select Case currentWave
            Case 1 To 2
                Return "basic"
            Case 3 To 4
                Dim types() As String = {"basic", "fast"}
                Return types(Randi() Mod types.Length)
            Case 5 To 7
                Dim types() As String = {"basic", "fast", "heavy"}
                Return types(Randi() Mod types.Length)
            Case 8 To 10
                Dim types() As String = {"basic", "fast", "heavy", "fighter"}
                Return types(Randi() Mod types.Length)
            Case Else
                ' Boss waves every 10 levels
                If currentWave Mod 10 = 0 Then
                    Return "boss"
                Else
                    Dim types() As String = {"fast", "heavy", "fighter"}
                    Return types(Randi() Mod types.Length)
                End If
        End Select
    End Function
    
    Private Sub CheckWaveProgress()
        If enemiesKilled >= enemiesInWave Then
            CompleteWave()
        End If
    End Sub
    
    Private Sub StartWave()
        Console.WriteLine($"Starting Wave {currentWave}")
        
        ' Reset counters
        enemiesSpawned = 0
        enemiesKilled = 0
        
        ' Calculate enemies for this wave
        enemiesInWave = 5 + currentWave * 2
        
        ' Adjust spawn rate (faster spawning in later waves)
        enemySpawnRate = Math.Max(0.3, 1.5 - currentWave * 0.1)
        enemySpawnTimer.WaitTime = enemySpawnRate
        
        ' Update UI
        If uiManager IsNot Nothing Then
            uiManager.UpdateWave(currentWave)
            uiManager.ShowWaveStart(currentWave)
        End If
    End Sub
    
    Private Sub CompleteWave()
        Console.WriteLine($"Wave {currentWave} completed!")
        RaiseEvent WaveCompleted(currentWave)
        
        ' Bonus score for completing wave
        If player IsNot Nothing Then
            player.AddScore(currentWave * 100)
        End If
        
        ' Move to next wave
        currentWave += 1
        
        ' Brief pause between waves
        enemySpawnTimer.Stop()
        Dim waveTimer As Timer = New Timer()
        waveTimer.WaitTime = waveSpawnDelay
        waveTimer.OneShot = True
        waveTimer.Connect("timeout", Sub()
            enemySpawnTimer.Start()
            StartWave()
            waveTimer.QueueFree()
        End Sub)
        AddChild(waveTimer)
        waveTimer.Start()
    End Sub
    
    Private Sub TogglePause()
        gamePaused = Not gamePaused
        
        If gamePaused Then
            enemySpawnTimer.Paused = True
            RaiseEvent uiManager.GamePaused() If uiManager IsNot Nothing
            Console.WriteLine("Game Paused")
        Else
            enemySpawnTimer.Paused = False
            RaiseEvent uiManager.GameResumed() If uiManager IsNot Nothing
            Console.WriteLine("Game Resumed")
        End If
    End Sub
    
    ' Event handlers
    Private Sub OnPlayerDied()
        Console.WriteLine("Player has died!")
        EndGame()
    End Sub
    
    Private Sub OnPlayerHit(damage As Integer)
        Console.WriteLine($"Player took {damage} damage!")
        
        ' Screen shake effect could be added here
        CreateScreenShake(0.5, 10.0)
    End Sub
    
    Private Sub OnWeaponUpgraded(newLevel As Integer)
        Console.WriteLine($"Weapon upgraded to level {newLevel}!")
        If uiManager IsNot Nothing Then
            uiManager.ShowWeaponUpgrade(newLevel)
        End If
    End Sub
    
    Private Sub OnPlayerScoreChanged(newScore As Integer)
        RaiseEvent PlayerScoreChanged(newScore)
    End Sub
    
    Private Sub OnEnemyDestroyed(enemy As Enemy)
        enemiesKilled += 1
        Console.WriteLine($"Enemy destroyed! ({enemiesKilled}/{enemiesInWave})")
        
        ' Add score
        If player IsNot Nothing Then
            player.AddScore(enemy.ScoreValue)
        End If
        
        ' Remove from list
        If enemies.Contains(enemy) Then
            enemies.Remove(enemy)
        End If
    End Sub
    
    Private Sub OnEnemyHitPlayer(damage As Integer)
        Console.WriteLine($"Enemy hit player for {damage} damage!")
    End Sub
    
    Private Sub OnGamePaused()
        gamePaused = True
    End Sub
    
    Private Sub OnGameResumed()
        gamePaused = False
    End Sub
    
    Private Sub OnRestartRequested()
        RestartGame()
    End Sub
    
    Private Sub CreateScreenShake(duration As Single, intensity As Single)
        ' Simple screen shake effect
        Dim originalPosition As Vector2 = Position
        Dim tween As Tween = CreateTween()
        
        For i As Integer = 0 To CInt(duration * 10)
            Dim offset As Vector2 = Vector2(
                (Randf() - 0.5) * intensity,
                (Randf() - 0.5) * intensity
            )
            tween.TweenProperty(Me, "position", originalPosition + offset, 0.05)
        Next
        
        tween.TweenProperty(Me, "position", originalPosition, 0.1)
    End Sub
    
    Private Sub EndGame()
        gameRunning = False
        enemySpawnTimer.Stop()
        
        Dim finalScore As Integer = If(player IsNot Nothing, player.GetScore(), 0)
        Console.WriteLine($"Game Over! Final Score: {finalScore}")
        
        If uiManager IsNot Nothing Then
            uiManager.ShowGameOver(finalScore)
        End If
        
        RaiseEvent GameOver(finalScore)
    End Sub
    
    Public Sub RestartGame()
        Console.WriteLine("Restarting game...")
        
        ' Reset game state
        gameRunning = True
        gamePaused = False
        currentWave = 1
        enemiesSpawned = 0
        enemiesKilled = 0
        
        ' Clear all game objects
        For Each enemy In enemies
            If IsInstanceValid(enemy) Then enemy.QueueFree()
        Next
        enemies.Clear()
        
        For Each bullet In bullets
            If IsInstanceValid(bullet) Then bullet.QueueFree()
        Next
        bullets.Clear()
        
        For Each powerUp In powerUps
            If IsInstanceValid(powerUp) Then powerUp.QueueFree()
        Next
        powerUps.Clear()
        
        ' Reset player
        If player IsNot Nothing Then
            player.Health = player.MaxHealth
            player.Lives = 3
            player.Position = Vector2(GetViewportRect().Size.X / 2, GetViewportRect().Size.Y - 100)
        End If
        
        ' Restart wave
        StartWave()
        enemySpawnTimer.Start()
        
        Console.WriteLine("Game restarted successfully!")
    End Sub
    
    ' Public accessors
    Public Function GetCurrentWave() As Integer
        Return currentWave
    End Function
    
    Public Function GetEnemyCount() As Integer
        Return enemies.Count
    End Function
    
    Public Function IsGameRunning() As Boolean
        Return gameRunning
    End Function
    
    Public Function IsGamePaused() As Boolean
        Return gamePaused
    End Function
End Class