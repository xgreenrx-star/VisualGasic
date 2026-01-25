' Paddle.bas - Player paddle class for Pong game
Extends CharacterBody2D

Option Explicit On
Option Strict On

Public Class Paddle
    Inherits CharacterBody2D
    
    ' Paddle properties
    Public Property Speed As Single = 400.0
    Public Property IsPlayer As Boolean = True
    Public Property PaddleHeight As Single = 80.0
    
    ' Screen bounds
    Private screenSize As Vector2
    Private paddleBounds As Rect2
    
    ' AI properties (for computer paddle)
    Private followSpeed As Single = 200.0
    Private ballTarget As Ball
    Private aiReactionDelay As Single = 0.1
    Private aiTimer As Single = 0.0
    
    Public Overrides Sub _Ready()
        ' Get screen size and set bounds
        screenSize = GetViewportRect().Size
        UpdateBounds()
        
        ' Set up collision
        SetCollisionLayerBit(1, True)  ' Paddle layer
        SetCollisionMaskBit(2, True)   ' Ball layer
    End Sub
    
    Private Sub UpdateBounds()
        ' Keep paddle within screen bounds
        Dim halfHeight As Single = PaddleHeight / 2
        paddleBounds = New Rect2(
            Position.X, 
            halfHeight, 
            0, 
            screenSize.Y - PaddleHeight
        )
    End Sub
    
    Public Overrides Sub _PhysicsProcess(delta As Single)
        Dim velocity As Vector2 = Vector2.Zero
        
        If IsPlayer Then
            HandlePlayerInput(velocity)
        Else
            HandleAIMovement(delta, velocity)
        End If
        
        ' Apply movement with collision
        SetVelocity(velocity)
        MoveAndSlide()
        
        ' Keep paddle in bounds
        ClampToBounds()
    End Sub
    
    Private Sub HandlePlayerInput(ByRef velocity As Vector2)
        ' Handle keyboard input for player
        If Input.IsActionPressed("ui_up") Or Input.IsActionPressed("move_up") Then
            velocity.Y = -Speed
        ElseIf Input.IsActionPressed("ui_down") Or Input.IsActionPressed("move_down") Then
            velocity.Y = Speed
        End If
        
        ' Alternative keys (W/S)
        If Input.IsKeyPressed(Key.W) Then
            velocity.Y = -Speed
        ElseIf Input.IsKeyPressed(Key.S) Then
            velocity.Y = Speed
        End If
    End Sub
    
    Private Sub HandleAIMovement(delta As Single, ByRef velocity As Vector2)
        If ballTarget Is Nothing Then
            ' Try to find the ball in the scene
            ballTarget = GetNode("../Ball") ' Adjust path as needed
            If ballTarget Is Nothing Then Return
        End If
        
        ' Add reaction delay for more realistic AI
        aiTimer += delta
        If aiTimer < aiReactionDelay Then Return
        
        ' Get ball position
        Dim ballY As Single = ballTarget.Position.Y
        Dim paddleY As Single = Position.Y
        Dim difference As Single = ballY - paddleY
        
        ' Dead zone - don't move if ball is close enough
        Dim deadZone As Single = 20.0
        If Math.Abs(difference) < deadZone Then
            Return
        End If
        
        ' Move towards ball, but limit speed for difficulty
        Dim aiSpeed As Single = followSpeed
        
        ' Make AI harder when ball is moving towards it
        If ballTarget.GetLinearVelocity().X > 0 And Position.X > screenSize.X / 2 Then
            aiSpeed = followSpeed * 1.3  ' AI paddle on right, ball coming toward it
        ElseIf ballTarget.GetLinearVelocity().X < 0 And Position.X < screenSize.X / 2 Then
            aiSpeed = followSpeed * 1.3  ' AI paddle on left, ball coming toward it
        Else
            aiSpeed = followSpeed * 0.8  ' Ball moving away, slower reaction
        End If
        
        If difference > 0 Then
            velocity.Y = aiSpeed
        Else
            velocity.Y = -aiSpeed
        End If
    End Sub
    
    Private Sub ClampToBounds()
        ' Keep paddle within screen boundaries
        Dim halfHeight As Single = PaddleHeight / 2
        Dim newY As Single = Math.Max(halfHeight, Position.Y)
        newY = Math.Min(screenSize.Y - halfHeight, newY)
        Position = New Vector2(Position.X, newY)
    End Sub
    
    Public Sub FollowBall(ballY As Single)
        ' Alternative method for AI control (called from game manager)
        Dim difference As Single = ballY - Position.Y
        Dim moveSpeed As Single = followSpeed
        
        If Math.Abs(difference) > 10 Then
            If difference > 0 Then
                Position = New Vector2(Position.X, Position.Y + moveSpeed * GetPhysicsProcessDeltaTime())
            Else
                Position = New Vector2(Position.X, Position.Y - moveSpeed * GetPhysicsProcessDeltaTime())
            End If
        End If
        
        ClampToBounds()
    End Sub
    
    Public Function GetBounds() As Rect2
        ' Return paddle collision bounds
        Return New Rect2(
            Position.X - 10, 
            Position.Y - PaddleHeight / 2, 
            20, 
            PaddleHeight
        )
    End Function
    
    Public Sub SetAIDifficulty(difficulty As String)
        ' Adjust AI difficulty
        Select Case difficulty.ToLower()
            Case "easy"
                followSpeed = 150.0
                aiReactionDelay = 0.2
            Case "medium"
                followSpeed = 200.0
                aiReactionDelay = 0.1
            Case "hard"
                followSpeed = 280.0
                aiReactionDelay = 0.05
            Case "expert"
                followSpeed = 350.0
                aiReactionDelay = 0.02
        End Select
    End Sub
End Class