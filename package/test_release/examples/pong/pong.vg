' Pong Clone in Visual Gasic
' demonstrating dynamic node creation and basic physics loop

Global Ball
Global Paddle1
Global Paddle2
Global LabelScore1
Global LabelScore2

Global BallVelX
Global BallVelY
Global Score1
Global Score2

Sub _Ready()
    ' Setup Screen
    ' Assume 800x600 resolution or similar
    
    Score1 = 0
    Score2 = 0
    
    ' Create Visual Elements using standard Godot Nodes
    
    ' --- PADDLE 1 (Left) ---
    Set Paddle1 = CreateNode("ColorRect")
    AddChild(Paddle1)
    Paddle1.Color = Color(0.2, 0.8, 0.2)
    Paddle1.Size.x = 20
    Paddle1.Size.y = 100
    Paddle1.Position.x = 50
    Paddle1.Position.y = 250
    
    ' --- PADDLE 2 (Right) ---
    Set Paddle2 = CreateNode("ColorRect")
    AddChild(Paddle2)
    Paddle2.Color = Color(0.2, 0.2, 0.8)
    Paddle2.Size.x = 20
    Paddle2.Size.y = 100
    Paddle2.Position.x = 1080 ' Assuming 1152 width
    Paddle2.Position.y = 250
    
    ' --- BALL ---
    Set Ball = CreateNode("ColorRect")
    AddChild(Ball)
    Ball.Color = Color(1, 1, 1)
    Ball.Size.x = 20
    Ball.Size.y = 20
    Call ResetBall
    
    ' --- UI ---
    Set LabelScore1 = CreateLabel("0", 300, 50)
    LabelScore1.AddThemeFontSizeOverride("font_size", 40)
    
    Set LabelScore2 = CreateLabel("0", 800, 50)
    LabelScore2.AddThemeFontSizeOverride("font_size", 40)
    
    Print "Pong Ready!"
End Sub

Sub ResetBall()
    Ball.Position.x = 576 ' Center Width
    Ball.Position.y = 324 ' Center Height
    BallVelX = 300
    BallVelY = 300
    If Rnd() > 0.5 Then BallVelX = -BallVelX
    If Rnd() > 0.5 Then BallVelY = -BallVelY
End Sub

Sub _Process(delta)
    ' Move Ball
    Ball.Position.x = Ball.Position.x + (BallVelX * delta)
    Ball.Position.y = Ball.Position.y + (BallVelY * delta)
    
    ' Simple AI for Paddle 2 (Right)
    If Ball.Position.y > Paddle2.Position.y + 50 Then
        Paddle2.Position.y = Paddle2.Position.y + (200 * delta)
    Else
        Paddle2.Position.y = Paddle2.Position.y - (200 * delta)
    End If
    
    ' Player Input for Paddle 1
    If Input.IsActionPressed("ui_down") Then
        Paddle1.Position.y = Paddle1.Position.y + (300 * delta)
    End If
    If Input.IsActionPressed("ui_up") Then
        Paddle1.Position.y = Paddle1.Position.y - (300 * delta)
    End If
    
    ' Screen Collision (Top/Bottom)
    If Ball.Position.y < 0 Then
        Ball.Position.y = 0
        BallVelY = -BallVelY
    End If
    If Ball.Position.y > 628 Then ' 648 - 20
        Ball.Position.y = 628
        BallVelY = -BallVelY
    End If
    
    ' Paddle Collision (Simple AABB)
    Dim t As Object
    bRect.Position = Ball.Position
    
    Dim ct As Object
    p1Rect.Position = Paddle1.Position
    
    Dim ct As Object
    p2Rect.Position = Paddle2.Position
    
    If bRect.Intersects(p1Rect) Then
        BallVelX = Abs(BallVelX) * 1.1 ' Speed up and bounce right
    End If
    
    If bRect.Intersects(p2Rect) Then
        BallVelX = -Abs(BallVelX) * 1.1 ' Speed up and bounce left
    End If
    
    ' Scoring
    If Ball.Position.x < 0 Then
        Score2 = Score2 + 1
        LabelScore2.Text = Str(Score2)
        Call ResetBall
    End If
    
    If Ball.Position.x > 1152 Then
        Score1 = Score1 + 1
        LabelScore1.Text = Str(Score1)
        Call ResetBall
    End If
End Sub

Function Abs(val)
    If val < 0 Then Return -val
    Return val
End Function
