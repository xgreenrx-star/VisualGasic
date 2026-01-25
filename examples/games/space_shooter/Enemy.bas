' Enemy.bas - Enemy AI and behavior for Space Shooter
Extends CharacterBody2D

Option Explicit On
Option Strict On

Public Class Enemy
    Inherits CharacterBody2D
    
    ' Enemy properties
    Public Property Health As Integer = 30
    Public Property MaxHealth As Integer = 30
    Public Property Speed As Single = 150.0
    Public Property CollisionDamage As Integer = 25
    Public Property ScoreValue As Integer = 100
    Public Property EnemyType As String = "basic"
    
    ' AI properties
    Private player As Player
    Private fireRate As Single = 1.5
    Private lastFireTime As Single = 0.0
    Private bulletSpeed As Single = 300.0
    Private movementPattern As String = "straight"
    Private moveTimer As Single = 0.0
    
    ' Movement variables
    Private startPosition As Vector2
    Private amplitude As Single = 100.0
    Private frequency As Single = 2.0
    Private screenSize As Vector2
    
    ' Events
    Public Event EnemyDestroyed(enemy As Enemy)
    Public Event EnemyHitPlayer(damage As Integer)
    
    Public Overrides Sub _Ready()
        screenSize = GetViewportRect().Size
        startPosition = Position
        
        ' Find player in scene
        player = GetNode("../Player")
        
        ' Set up collision
        SetCollisionLayerBit(2, True)  ' Enemy layer
        SetCollisionMaskBit(1, True)   ' Player layer
        
        ' Configure based on enemy type
        ConfigureEnemyType()
        
        Console.WriteLine($"Enemy spawned: {EnemyType}")
    End Sub
    
    Private Sub ConfigureEnemyType()
        Select Case EnemyType.ToLower()
            Case "basic"
                Health = 30
                Speed = 150.0
                ScoreValue = 100
                CollisionDamage = 25
                fireRate = 2.0
                movementPattern = "straight"
                
            Case "fast"
                Health = 15
                Speed = 250.0
                ScoreValue = 150
                CollisionDamage = 20
                fireRate = 1.0
                movementPattern = "zigzag"
                
            Case "heavy"
                Health = 80
                Speed = 100.0
                ScoreValue = 300
                CollisionDamage = 40
                fireRate = 3.0
                movementPattern = "straight"
                
            Case "fighter"
                Health = 40
                Speed = 200.0
                ScoreValue = 200
                CollisionDamage = 30
                fireRate = 0.8
                movementPattern = "follow_player"
                
            Case "boss"
                Health = 200
                Speed = 80.0
                ScoreValue = 1000
                CollisionDamage = 50
                fireRate = 0.5
                movementPattern = "boss_pattern"
                amplitude = 200.0
        End Select
        
        MaxHealth = Health
    End Sub
    
    Public Overrides Sub _Process(delta As Single)
        UpdateMovement(delta)
        UpdateShooting(delta)
        CheckBounds()
    End Sub
    
    Private Sub UpdateMovement(delta As Single)
        moveTimer += delta
        Dim velocity As Vector2 = Vector2.Zero
        
        Select Case movementPattern
            Case "straight"
                velocity = Vector2(0, Speed)
                
            Case "zigzag"
                velocity = Vector2(
                    Math.Sin(moveTimer * frequency) * amplitude * 0.01,
                    Speed
                )
                
            Case "sine_wave"
                velocity = Vector2(
                    Math.Sin(moveTimer * frequency) * 50,
                    Speed
                )
                
            Case "follow_player"
                If player IsNot Nothing Then
                    Dim direction As Vector2 = (player.Position - Position).Normalized()
                    velocity = direction * Speed * 0.7  ' Slower following
                    velocity.Y = Math.Max(velocity.Y, Speed * 0.3)  ' Always move down
                End If
                
            Case "circle"
                Dim circleRadius As Single = amplitude
                velocity = Vector2(
                    Math.Cos(moveTimer * frequency) * circleRadius * 0.01,
                    Math.Sin(moveTimer * frequency) * circleRadius * 0.01 + Speed * 0.5
                )
                
            Case "boss_pattern"
                ' Complex boss movement
                If moveTimer < 3.0 Then
                    ' Move side to side
                    velocity = Vector2(Math.Sin(moveTimer * 2) * 100, 0)
                ElseIf moveTimer < 6.0 Then
                    ' Move down
                    velocity = Vector2(0, Speed)
                Else
                    ' Reset timer for loop
                    moveTimer = 0.0
                End If
        End Select
        
        SetVelocity(velocity)
        MoveAndSlide()
    End Sub
    
    Private Sub UpdateShooting(delta As Single)
        If player Is Nothing Then Return
        
        Dim currentTime As Single = Time.GetUnixTimeFromSystem()
        If currentTime - lastFireTime < fireRate Then Return
        
        lastFireTime = currentTime
        
        Select Case EnemyType.ToLower()
            Case "basic", "heavy"
                FireStraight()
            Case "fast"
                FireAtPlayer()
            Case "fighter"
                FireBurst()
            Case "boss"
                FireBossPattern()
        End Select
    End Sub
    
    Private Sub FireStraight()
        CreateEnemyBullet(Position + Vector2(0, 20), Vector2(0, 1))
    End Sub
    
    Private Sub FireAtPlayer()
        If player IsNot Nothing Then
            Dim direction As Vector2 = (player.Position - Position).Normalized()
            CreateEnemyBullet(Position + Vector2(0, 20), direction)
        End If
    End Sub
    
    Private Sub FireBurst()
        For i As Integer = -1 To 1
            Dim angle As Single = i * 0.4
            Dim direction As Vector2 = Vector2(Math.Sin(angle), Math.Cos(angle))
            CreateEnemyBullet(Position + Vector2(i * 10, 20), direction)
        Next
    End Sub
    
    Private Sub FireBossPattern()
        ' Boss fires in multiple directions
        For i As Integer = 0 To 7
            Dim angle As Single = (i * Math.PI * 2) / 8
            Dim direction As Vector2 = Vector2(Math.Cos(angle), Math.Sin(angle))
            CreateEnemyBullet(Position + direction * 30, direction)
        Next
    End Sub
    
    Private Sub CreateEnemyBullet(startPos As Vector2, direction As Vector2)
        Dim bullet As Bullet = New Bullet()
        bullet.Position = startPos
        bullet.Direction = direction
        bullet.Speed = bulletSpeed
        bullet.IsPlayerBullet = False
        bullet.Damage = 15
        
        ' Add to scene
        GetParent().AddChild(bullet)
    End Sub
    
    Public Sub TakeDamage(damage As Integer)
        Health = Math.Max(0, Health - damage)
        
        ' Visual damage feedback
        ShowDamageEffect()
        
        If Health <= 0 Then
            Die()
        End If
        
        Console.WriteLine($"Enemy hit! Health: {Health}/{MaxHealth}")
    End Sub
    
    Private Sub ShowDamageEffect()
        ' Flash red when hit
        Modulate = Color.Red
        Dim tween As Tween = CreateTween()
        tween.TweenProperty(Me, "modulate", Color.White, 0.2)
    End Sub
    
    Private Sub Die()
        ' Create explosion effect
        CreateExplosion()
        
        ' Drop power-up chance
        If Randf() < 0.3 Then  ' 30% chance
            DropPowerUp()
        End If
        
        ' Notify game manager
        RaiseEvent EnemyDestroyed(Me)
        
        Console.WriteLine($"Enemy destroyed! Score: {ScoreValue}")
        
        ' Remove from scene
        QueueFree()
    End Sub
    
    Private Sub CreateExplosion()
        ' Create simple particle explosion
        Dim explosion As CPUParticles2D = New CPUParticles2D()
        explosion.Position = Position
        explosion.Emitting = True
        explosion.Amount = 50
        explosion.Lifetime = 1.0
        explosion.SpeedScale = 2.0
        
        ' Configure explosion properties
        explosion.EmissionShape = CPUParticles2D.EmissionShapeEnum.Sphere
        explosion.Direction = Vector2(0, -1)
        explosion.InitialVelocityMin = 50.0
        explosion.InitialVelocityMax = 150.0
        explosion.AngularVelocityMin = -180.0
        explosion.AngularVelocityMax = 180.0
        explosion.ScaleAmountMin = 0.5
        explosion.ScaleAmountMax = 1.5
        
        GetParent().AddChild(explosion)
        
        ' Remove explosion after animation
        Dim timer As Timer = New Timer()
        timer.WaitTime = 2.0
        timer.OneShot = True
        timer.Connect("timeout", Sub() explosion.QueueFree())
        AddChild(timer)
        timer.Start()
    End Sub
    
    Private Sub DropPowerUp()
        Dim powerUp As PowerUp = New PowerUp()
        powerUp.Position = Position
        
        ' Random power-up type
        Dim powerTypes() As String = {"health", "weapon", "speed", "shield"}
        powerUp.PowerUpType = powerTypes(Randi() Mod powerTypes.Length)
        
        GetParent().AddChild(powerUp)
    End Sub
    
    Private Sub CheckBounds()
        ' Remove enemy if it goes off screen
        If Position.Y > screenSize.Y + 50 Or 
           Position.X < -50 Or Position.X > screenSize.X + 50 Then
            QueueFree()
        End If
    End Sub
    
    ' Collision detection
    Public Sub OnCollisionEntered(body As Node)
        If TypeOf body Is Player Then
            Dim playerRef As Player = CType(body, Player)
            playerRef.TakeDamage(CollisionDamage)
            RaiseEvent EnemyHitPlayer(CollisionDamage)
            
            ' Enemy takes damage from collision too
            TakeDamage(25)
        ElseIf TypeOf body Is Bullet Then
            Dim bullet As Bullet = CType(body, Bullet)
            If bullet.IsPlayerBullet Then
                TakeDamage(bullet.Damage)
                bullet.Destroy()
            End If
        End If
    End Sub
    
    ' Factory method for creating different enemy types
    Public Shared Function CreateEnemy(enemyType As String, spawnPosition As Vector2) As Enemy
        Dim enemy As New Enemy()
        enemy.EnemyType = enemyType
        enemy.Position = spawnPosition
        Return enemy
    End Function
End Class