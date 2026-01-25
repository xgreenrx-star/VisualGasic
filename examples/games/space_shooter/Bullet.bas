' Bullet.bas - Projectile system for Space Shooter
Extends CharacterBody2D

Option Explicit On
Option Strict On

Public Class Bullet
    Inherits CharacterBody2D
    
    ' Bullet properties
    Public Property Speed As Single = 400.0
    Public Property Direction As Vector2 = Vector2(0, -1)
    Public Property Damage As Integer = 10
    Public Property IsPlayerBullet As Boolean = True
    Public Property Lifetime As Single = 5.0  ' Seconds before auto-destroy
    Public Property BulletType As String = "normal"
    
    ' Visual properties
    Public Property BulletColor As Color = Color.Yellow
    Public Property TrailEnabled As Boolean = False
    
    ' Internal state
    Private timeAlive As Single = 0.0
    Private hasHit As Boolean = False
    Private screenSize As Vector2
    
    ' Trail effect
    Private trail As Line2D
    Private trailPoints As List(Of Vector2)
    Private maxTrailLength As Integer = 10
    
    Public Overrides Sub _Ready()
        screenSize = GetViewportRect().Size
        
        ' Set up collision
        If IsPlayerBullet Then
            SetCollisionLayerBit(3, True)  ' Player bullet layer
            SetCollisionMaskBit(2, True)   ' Enemy layer
            BulletColor = Color.Cyan
        Else
            SetCollisionLayerBit(4, True)  ' Enemy bullet layer  
            SetCollisionMaskBit(1, True)   ' Player layer
            BulletColor = Color.Red
        End If
        
        ' Configure based on bullet type
        ConfigureBulletType()
        
        ' Set up visual appearance
        SetupVisuals()
        
        ' Set up trail effect if enabled
        If TrailEnabled Then
            SetupTrail()
        End If
    End Sub
    
    Private Sub ConfigureBulletType()
        Select Case BulletType.ToLower()
            Case "normal"
                Speed = 400.0
                Damage = 10
                BulletColor = If(IsPlayerBullet, Color.Cyan, Color.Red)
                
            Case "fast"
                Speed = 600.0
                Damage = 8
                BulletColor = If(IsPlayerBullet, Color.White, Color.Orange)
                
            Case "heavy"
                Speed = 250.0
                Damage = 25
                BulletColor = If(IsPlayerBullet, Color.Blue, Color.Purple)
                TrailEnabled = True
                
            Case "explosive"
                Speed = 300.0
                Damage = 20
                BulletColor = If(IsPlayerBullet, Color.Yellow, Color.Magenta)
                TrailEnabled = True
                
            Case "laser"
                Speed = 800.0
                Damage = 15
                BulletColor = If(IsPlayerBullet, Color.Green, Color.Pink)
                Lifetime = 2.0  ' Shorter lifetime for rapid laser
                
            Case "plasma"
                Speed = 350.0
                Damage = 30
                BulletColor = If(IsPlayerBullet, Color.Violet, Color.DarkRed)
                TrailEnabled = True
        End Select
    End Sub
    
    Private Sub SetupVisuals()
        ' Create visual representation
        Dim sprite As ColorRect = New ColorRect()
        sprite.Size = GetBulletSize()
        sprite.Color = BulletColor
        sprite.Position = -sprite.Size / 2  ' Center the sprite
        AddChild(sprite)
        
        ' Add glow effect for some bullet types
        If BulletType = "laser" Or BulletType = "plasma" Then
            AddGlowEffect(sprite)
        End If
    End Sub
    
    Private Function GetBulletSize() As Vector2
        Select Case BulletType.ToLower()
            Case "normal", "fast"
                Return Vector2(4, 8)
            Case "heavy", "explosive"
                Return Vector2(6, 12)
            Case "laser"
                Return Vector2(2, 16)
            Case "plasma"
                Return Vector2(8, 8)
            Case Else
                Return Vector2(4, 8)
        End Select
    End Function
    
    Private Sub AddGlowEffect(sprite As ColorRect)
        ' Add a larger, semi-transparent background for glow
        Dim glow As ColorRect = New ColorRect()
        glow.Size = sprite.Size * 2
        glow.Color = Color(BulletColor.R, BulletColor.G, BulletColor.B, 0.3)
        glow.Position = -glow.Size / 2
        AddChild(glow)
        MoveChild(glow, 0)  ' Put glow behind main sprite
    End Sub
    
    Private Sub SetupTrail()
        trail = New Line2D()
        trail.DefaultColor = Color(BulletColor.R, BulletColor.G, BulletColor.B, 0.7)
        trail.Width = 3.0
        trail.Antialiased = True
        AddChild(trail)
        
        trailPoints = New List(Of Vector2)()
    End Sub
    
    Public Overrides Sub _PhysicsProcess(delta As Single)
        If hasHit Then Return
        
        timeAlive += delta
        
        ' Check lifetime
        If timeAlive >= Lifetime Then
            Destroy()
            Return
        End If
        
        ' Move bullet
        Dim velocity As Vector2 = Direction.Normalized() * Speed
        SetVelocity(velocity)
        MoveAndSlide()
        
        ' Update trail
        If TrailEnabled And trail IsNot Nothing Then
            UpdateTrail()
        End If
        
        ' Check bounds
        If IsOutOfBounds() Then
            Destroy()
        End If
        
        ' Special behavior based on bullet type
        UpdateSpecialBehavior(delta)
    End Sub
    
    Private Sub UpdateTrail()
        If trailPoints Is Nothing Then Return
        
        trailPoints.Add(GlobalPosition)
        
        ' Limit trail length
        If trailPoints.Count > maxTrailLength Then
            trailPoints.RemoveAt(0)
        End If
        
        ' Update line points
        trail.ClearPoints()
        For Each point In trailPoints
            trail.AddPoint(ToLocal(point))
        Next
    End Sub
    
    Private Function IsOutOfBounds() As Boolean
        Dim margin As Single = 50.0
        Return Position.X < -margin Or Position.X > screenSize.X + margin Or
               Position.Y < -margin Or Position.Y > screenSize.Y + margin
    End Function
    
    Private Sub UpdateSpecialBehavior(delta As Single)
        Select Case BulletType.ToLower()
            Case "explosive"
                ' Pulse effect for explosive bullets
                Dim pulse As Single = 1.0 + Math.Sin(timeAlive * 10) * 0.2
                Scale = Vector2(pulse, pulse)
                
            Case "laser"
                ' Slight random wobble for laser
                Dim wobble As Single = Math.Sin(timeAlive * 50) * 0.02
                Position += Vector2(wobble, 0)
                
            Case "plasma"
                ' Rotate plasma bullets
                Rotation += delta * 5.0
        End Select
    End Sub
    
    Public Sub OnHit(target As Node)
        If hasHit Then Return
        hasHit = True
        
        Select Case BulletType.ToLower()
            Case "explosive"
                CreateExplosion()
            Case "plasma"
                CreatePlasmaEffect()
            Case Else
                CreateHitEffect()
        End Select
        
        Destroy()
    End Sub
    
    Private Sub CreateHitEffect()
        ' Simple hit spark
        Dim particles As CPUParticles2D = New CPUParticles2D()
        particles.GlobalPosition = GlobalPosition
        particles.Emitting = True
        particles.Amount = 10
        particles.Lifetime = 0.3
        particles.OneShot = True
        
        particles.Direction = -Direction
        particles.InitialVelocityMin = 50.0
        particles.InitialVelocityMax = 100.0
        particles.ScaleAmountMin = 0.5
        particles.ScaleAmountMax = 1.0
        
        GetParent().AddChild(particles)
        
        ' Clean up particles
        Dim timer As Timer = New Timer()
        timer.WaitTime = 1.0
        timer.OneShot = True
        timer.Connect("timeout", Sub() particles.QueueFree())
        particles.AddChild(timer)
        timer.Start()
    End Sub
    
    Private Sub CreateExplosion()
        ' Larger explosion effect
        Dim explosion As CPUParticles2D = New CPUParticles2D()
        explosion.GlobalPosition = GlobalPosition
        explosion.Emitting = True
        explosion.Amount = 25
        explosion.Lifetime = 0.5
        explosion.OneShot = True
        
        explosion.EmissionShape = CPUParticles2D.EmissionShapeEnum.Sphere
        explosion.InitialVelocityMin = 75.0
        explosion.InitialVelocityMax = 150.0
        explosion.ScaleAmountMin = 0.8
        explosion.ScaleAmountMax = 1.5
        
        GetParent().AddChild(explosion)
        
        ' Explosion damage to nearby enemies
        DealAreaDamage(50.0, Damage * 0.5)
        
        ' Clean up
        Dim timer As Timer = New Timer()
        timer.WaitTime = 1.0
        timer.OneShot = True
        timer.Connect("timeout", Sub() explosion.QueueFree())
        explosion.AddChild(timer)
        timer.Start()
    End Sub
    
    Private Sub CreatePlasmaEffect()
        ' Electric arc effect
        Dim plasma As CPUParticles2D = New CPUParticles2D()
        plasma.GlobalPosition = GlobalPosition
        plasma.Emitting = True
        plasma.Amount = 15
        plasma.Lifetime = 0.4
        plasma.OneShot = True
        
        plasma.Direction = Vector2(0, 0)  ' Radial
        plasma.InitialVelocityMin = 30.0
        plasma.InitialVelocityMax = 80.0
        plasma.ScaleAmountMin = 0.3
        plasma.ScaleAmountMax = 0.8
        
        GetParent().AddChild(plasma)
        
        ' Clean up
        Dim timer As Timer = New Timer()
        timer.WaitTime = 1.0
        timer.OneShot = True
        timer.Connect("timeout", Sub() plasma.QueueFree())
        plasma.AddChild(timer)
        timer.Start()
    End Sub
    
    Private Sub DealAreaDamage(radius As Single, damage As Integer)
        ' Get all bodies in explosion radius
        Dim space As PhysicsDirectSpaceState2D = GetWorld2D().DirectSpaceState
        Dim query As PhysicsPointQueryParameters2D = New PhysicsPointQueryParameters2D()
        query.Position = GlobalPosition
        query.CollisionMask = If(IsPlayerBullet, 2, 1)  ' Enemy or player layer
        
        ' This is a simplified area damage - in a real game you'd use Area2D
        Console.WriteLine($"Explosion at {GlobalPosition} with radius {radius}")
    End Sub
    
    Public Sub Destroy()
        If Not hasHit Then
            hasHit = True
        End If
        QueueFree()
    End Sub
    
    ' Collision detection
    Public Sub OnCollisionEntered(body As Node)
        If hasHit Then Return
        
        If IsPlayerBullet And TypeOf body Is Enemy Then
            Dim enemy As Enemy = CType(body, Enemy)
            enemy.TakeDamage(Damage)
            OnHit(body)
        ElseIf Not IsPlayerBullet And TypeOf body Is Player Then
            Dim player As Player = CType(body, Player)
            player.TakeDamage(Damage)
            OnHit(body)
        End If
    End Sub
    
    ' Factory methods for creating different bullet types
    Public Shared Function CreatePlayerBullet(position As Vector2, direction As Vector2, Optional bulletType As String = "normal") As Bullet
        Dim bullet As New Bullet()
        bullet.Position = position
        bullet.Direction = direction
        bullet.IsPlayerBullet = True
        bullet.BulletType = bulletType
        Return bullet
    End Function
    
    Public Shared Function CreateEnemyBullet(position As Vector2, direction As Vector2, Optional bulletType As String = "normal") As Bullet
        Dim bullet As New Bullet()
        bullet.Position = position
        bullet.Direction = direction
        bullet.IsPlayerBullet = False
        bullet.BulletType = bulletType
        Return bullet
    End Function
End Class