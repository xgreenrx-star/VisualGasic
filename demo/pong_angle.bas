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
	If Rnd() > 0.5 Then BallVelX = -BallVelX
	
	' Randomize Y start (Ensure non-zero)
	BallVelY = (Rnd() * 200) + 100
	If Rnd() > 0.5 Then BallVelY = -BallVelY
	
	Print "Reset Ball: Vx=" + Str(BallVelX) + " Vy=" + Str(BallVelY)
End Sub

Sub _Process(delta)
	' Move Ball using Top/Left aliases for safety
	Ball.Left = Ball.Left + (BallVelX * delta)
	
	Dim oldTop = Ball.Top
	Ball.Top = Ball.Top + (BallVelY * delta)
	
	If Ball.Top > 620.0 Then
		 Print "DEBUG Frame: Old=" + Str(oldTop) + " New=" + Str(Ball.Top) + " d=" + Str(delta) + " Vy=" + Str(BallVelY)
	End If
	
	' Simple AI for Paddle 2 (Right)
	Dim P2Vy = 0
	If Ball.Top > Paddle2.Position.y + 50 Then
		P2Vy = 200
		Paddle2.Position.y = Paddle2.Position.y + (P2Vy * delta)
	Else
		P2Vy = -200
		Paddle2.Position.y = Paddle2.Position.y + (P2Vy * delta)
	End If
	
	' Player Input for Paddle 1
	Dim P1Vy = 0
	If IsKeyDown("S") Then
		P1Vy = 300
	End If
	If IsKeyDown("W") Then
		P1Vy = -300
	End If
	Paddle1.Position.y = Paddle1.Position.y + (P1Vy * delta)
	
	' Screen Collision (Top/Bottom)
	If Ball.Top < 0.0 Then
		Ball.Top = 0.0
		BallVelY = Abs(BallVelY) ' Force Down
		Print "Hit Top! Vy now: " + Str(BallVelY)
	End If
	If Ball.Top > 628.0 Then ' 648 - 20
		Print "TRAP ENTRY: Top=" + Str(Ball.Top)
		Ball.Top = 628.0
		BallVelY = -Abs(BallVelY) ' Force Up
		Print "Hit Bottom! Top=" + Str(Ball.Top) + " Vy=" + Str(BallVelY)
	End If
	
	' Paddle Collision (Simple AABB)
	Dim bRect = Ball.GetRect()
	bRect.Position = Ball.Position ' Position should still update correctly from Top/Left logic
	
	Dim p1Rect = Paddle1.GetRect()
	p1Rect.Position = Paddle1.Position
	
	Dim p2Rect = Paddle2.GetRect()
	p2Rect.Position = Paddle2.Position
	
	If bRect.Intersects(p1Rect) Then
		BallVelX = Abs(BallVelX) * 1.1 ' Speed up and bounce right
		BallVelY = BallVelY + (P1Vy * 0.5) ' Transfer paddle velocity
		' Add relative intersect logic for gameplay feel
		Dim diff1 = (Ball.Top + 10) - (Paddle1.Position.y + 50)
		BallVelY = BallVelY + (diff1 * 2.0)
	End If
	
	If bRect.Intersects(p2Rect) Then
		BallVelX = -Abs(BallVelX) * 1.1 ' Speed up and bounce left
		BallVelY = BallVelY + (P2Vy * 0.5) ' Transfer paddle velocity
		' Add relative intersect logic
		Dim diff2 = (Ball.Top + 10) - (Paddle2.Position.y + 50)
		BallVelY = BallVelY + (diff2 * 2.0)
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
