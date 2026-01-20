Attribute VB_Name = "Pong"

Dim ball_node
Dim ball_pos_x As Single
Dim ball_pos_y As Single
Dim ball_vel_x As Single
Dim ball_vel_y As Single

Dim p1_node
Dim p2_node
Dim p1_pos_y As Single
Dim p2_pos_y As Single

Dim speed As Single
Dim paddle_speed As Single

Sub _Ready()
    Print "Pong is starting..."
    
    ' Nodes
    Set ball_node = get_node("Ball")
    Set p1_node = get_node("Paddle1")
    Set p2_node = get_node("Paddle2")
    
    ' Init
    ball_pos_x = 400
    ball_pos_y = 300
    ball_vel_x = 200
    ball_vel_y = 150
    speed = 200.0
    
    p1_pos_y = 250
    p2_pos_y = 250
    paddle_speed = 300.0
    
    Print "Pong Initialized."
End Sub

Sub _Process(delta)
    Print "Processing... delta: " & Str(delta)
    ' Move Ball
    ball_pos_x = ball_pos_x + ball_vel_x * delta
    ball_pos_y = ball_pos_y + ball_vel_y * delta
    
    ' Bounce Walls
    If ball_pos_y < 0 Then
        ball_pos_y = 0
        ball_vel_y = -ball_vel_y
    End If
    If ball_pos_y > 600 Then
        ball_pos_y = 600
        ball_vel_y = -ball_vel_y
    End If
    
    ' Bounce X (Score logic simplified)
    If ball_pos_x < 0 Then
        ball_pos_x = 400
        ball_vel_x = Abs(ball_vel_x) ' Serve to right
        Print "Score for P2!"
    End If
    
    If ball_pos_x > 800 Then
        ball_pos_x = 400
        ball_vel_x = -Abs(ball_vel_x) ' Serve to left
        Print "Score for P1!"
    End If
    
    ' Paddle 1 AI (Follow Ball)
    If ball_pos_y > p1_pos_y + 50 Then
        p1_pos_y = p1_pos_y + paddle_speed * delta
    End If
    If ball_pos_y < p1_pos_y + 50 Then
        p1_pos_y = p1_pos_y - paddle_speed * delta
    End If
    
    ' Paddle 2 (Simple AI for demo or Input if I could bind actions)
    ' Let's just make it move opposite
    If ball_pos_y > p2_pos_y + 50 Then
        p2_pos_y = p2_pos_y + paddle_speed * delta * 0.8
    End If
    If ball_pos_y < p2_pos_y + 50 Then
        p2_pos_y = p2_pos_y - paddle_speed * delta * 0.8
    End If

    ' Update Visuals
    ' Vector2 is now supported
    If Not ball_node Is Nothing Then
        ball_node.set_position Vector2(ball_pos_x, ball_pos_y)
    End If
    
    If Not p1_node Is Nothing Then
        p1_node.set_position Vector2(50, p1_pos_y)
    End If
    
    If Not p2_node Is Nothing Then
        p2_node.set_position Vector2(750, p2_pos_y)
    End If

End Sub
