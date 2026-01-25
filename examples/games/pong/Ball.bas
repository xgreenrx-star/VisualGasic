' Ball.bas - Ball physics and collision for Pong game
Extends RigidBody2D

Option Explicit On
Option Strict On

Public Class Ball
    Inherits RigidBody2D
    
    ' Ball properties
    Public Property Speed As Single = 300.0
    Public Property Direction As Vector2 = Vector2(1, 0)
    Public Property MaxSpeed As Single = 600.0
    Public Property SpeedIncrease As Single = 20.0
    
    ' Screen bounds
    Private screenSize As Vector2
    
    ' Events
    Public Event GoalScored(goalSide As String)
    
    Public Overrides Sub _Ready()
        ' Get screen size
        screenSize = GetViewportRect().Size
        
        ' Set up physics
        SetGravityScale(0)  ' No gravity for top-down game
        SetLockRotation(True)  ' Keep ball from rotating
        
        ' Start moving
        ResetBall()
    End Sub
    
    Public Overrides Sub _PhysicsProcess(delta As Single)
        ' Check for goals (ball goes off screen)
        If Position.X < -50 Then
            ' Goal on left side (AI scored)
            RaiseEvent GoalScored("left")
        ElseIf Position.X > screenSize.X + 50 Then
            ' Goal on right side (Player scored)
            RaiseEvent GoalScored("right")
        End If
        
        ' Keep ball moving at consistent speed
        Dim velocity As Vector2 = GetLinearVelocity()
        If velocity.Length() > 0 Then
            velocity = velocity.Normalized() * Speed
            SetLinearVelocity(velocity)
        End If
        
        ' Prevent ball from getting stuck horizontally
        If Math.Abs(velocity.Y) < 50 Then
            velocity.Y = If(velocity.Y >= 0, 50, -50)
            SetLinearVelocity(velocity)
        End If
    End Sub
    
    Public Sub ResetBall()
        ' Reset position to center
        Position = screenSize / 2
        
        ' Random direction (left or right)
        Dim randomDirection As Integer = If(Randf() < 0.5, -1, 1)
        Dim randomAngle As Single = (Randf() - 0.5) * 0.8  ' Random angle up to ~25 degrees
        
        Direction = Vector2(randomDirection, randomAngle).Normalized()
        SetLinearVelocity(Direction * Speed)
    End Sub
    
    Public Sub OnPaddleHit(paddle As Paddle)
        ' Increase speed slightly
        Speed = Math.Min(Speed + SpeedIncrease, MaxSpeed)
        
        ' Add some randomness based on where ball hits paddle
        Dim velocity As Vector2 = GetLinearVelocity()
        Dim paddleCenter As Single = paddle.Position.Y
        Dim hitOffset As Single = Position.Y - paddleCenter
        
        ' Normalize hit offset (-1 to 1)
        hitOffset = hitOffset / (paddle.GetBounds().Size.Y / 2)
        hitOffset = Math.Max(-1, Math.Min(1, hitOffset))
        
        ' Apply new direction
        Dim newDirection As Vector2
        If velocity.X > 0 Then
            ' Ball was moving right, now goes left
            newDirection = Vector2(-1, hitOffset * 0.7).Normalized()
        Else
            ' Ball was moving left, now goes right  
            newDirection = Vector2(1, hitOffset * 0.7).Normalized()
        End If
        
        SetLinearVelocity(newDirection * Speed)
    End Sub
    
    Public Sub OnWallHit()
        ' Reverse Y direction when hitting top/bottom walls
        Dim velocity As Vector2 = GetLinearVelocity()
        velocity.Y = -velocity.Y
        SetLinearVelocity(velocity)
    End Sub
    
    ' Collision detection
    Public Sub OnCollisionEntered(body As Node)
        If TypeOf body Is Paddle Then
            OnPaddleHit(CType(body, Paddle))
        ElseIf body.Name = "TopWall" Or body.Name = "BottomWall" Then
            OnWallHit()
        End If
    End Sub
End Class