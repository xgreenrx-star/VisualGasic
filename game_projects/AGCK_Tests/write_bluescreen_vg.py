"""
Write BLUE SCREEN game VG files.
Run: python3 write_bluescreen_vg.py
"""
import os

BASE = os.path.dirname(os.path.abspath(__file__)) + "/build/BLUE_SCREEN"

# ─────────────────────────────────────────────────────────────────────────────
# Main.vg
# ─────────────────────────────────────────────────────────────────────────────

MAIN_VG = r"""' Main.vg — BLUE SCREEN Game Controller
' Survivors-style arena wave shooter. Era: 1999 / Y2K.
' Enemies spawn from screen edges; player auto-shoots toward nearest.
' Countdown: 3 minutes until Y2K midnight. Survive to see it.
Option Explicit

' ─── Score & Progression ───────────────────────────────────
Dim Score As Integer
Dim Wave As Integer
Dim PlayerHP As Integer
Dim PlayerMaxHP As Integer
Dim PlayerXP As Integer
Dim PlayerLevel As Integer

' ─── Wave System ────────────────────────────────────────────
Dim WaveTimer As Single
Dim WaveDuration As Single
Dim WaveCooldownTimer As Single
Dim WaveCooldown As Single
Dim IsWaveActive As Boolean
Dim EnemiesAlive As Integer
Dim TotalEnemiesThisWave As Integer
Dim SpawnIndex As Integer
Dim SpawnDelay As Single
Dim SpawnDelayTimer As Single

' ─── Auto-Shoot ─────────────────────────────────────────────
Dim ShootTimer As Single
Dim ShootInterval As Single
Dim BulletDamage As Integer

' ─── Y2K Countdown ──────────────────────────────────────────
Dim CountdownTimer As Single
Dim CountdownMax As Single
Dim IsMidnight As Boolean

' ─── Scene Paths ────────────────────────────────────────────
Dim HeroScene As String
Dim OverflowScene As String
Dim DateBugScene As String
Dim BulletScene As String
Dim XPOrbScene As String

' ─── Game State ─────────────────────────────────────────────
Dim IsGameOver As Boolean

' ════════════════════════════════════════════════════════════
Sub _Ready()
    Score = 0
    Wave = 0
    PlayerHP = 100
    PlayerMaxHP = 100
    PlayerXP = 0
    PlayerLevel = 1
    IsGameOver = False
    IsMidnight = False

    WaveDuration = 30.0
    WaveCooldown = 8.0
    WaveCooldownTimer = 3.0
    IsWaveActive = False
    EnemiesAlive = 0

    ShootInterval = 0.4
    ShootTimer = 0.0
    BulletDamage = 25

    CountdownTimer = 0.0
    CountdownMax = 180.0

    HeroScene = "res://build/BLUE_SCREEN/actors/Actor_Hero.tscn"
    OverflowScene = "res://build/BLUE_SCREEN/actors/Actor_Overflow.tscn"
    DateBugScene = "res://build/BLUE_SCREEN/actors/Actor_DateBug.tscn"
    BulletScene = "res://build/BLUE_SCREEN/actors/Actor_Bullet.tscn"
    XPOrbScene = "res://build/BLUE_SCREEN/actors/Actor_XPOrb.tscn"

    Connect(GetNode("GameOverOverlay/RestartBtn"), "pressed", "RestartBtn_Click")
    Connect(GetNode("VictoryOverlay/RestartBtn"), "pressed", "RestartBtn_Click")
    Connect(GetNode("MainMenuOverlay/PlayBtn"), "pressed", "PlayBtn_Click")
    Connect(GetNode("MainMenuOverlay/ExitBtn"), "pressed", "ExitBtn_Click")

    ' Spawn hero at arena center
    Dim hscn As PackedScene = Load(HeroScene)
    If hscn <> Nothing Then
        Dim hero As Node2D = hscn.Instantiate()
        hero.position = Vector2(320.0, 240.0)
        GetNode("LevelContainer").AddChild(hero)
    End If

    UpdateHUD()

    GetNode("MainMenuOverlay/Title").Text = "BLUE SCREEN" & vbCrLf & "Survive until midnight" & vbCrLf & vbCrLf & "Arrow keys to move"
    GetNode("MainMenuOverlay").Visible = True
    GetTree().Paused = True
End Sub

' ════════════════════════════════════════════════════════════
Sub _Process(delta As Single)
    If IsGameOver Then Exit Sub
    If GetTree().Paused Then Exit Sub

    ' ── Y2K Countdown ──
    CountdownTimer = CountdownTimer + delta
    If CountdownTimer >= CountdownMax And Not IsMidnight Then
        IsMidnight = True
        TriggerBSOD()
        Exit Sub
    End If
    UpdateClock()

    ' ── Wave Management ──
    If Not IsWaveActive Then
        WaveCooldownTimer = WaveCooldownTimer - delta
        If WaveCooldownTimer <= 0.0 Then
            StartNextWave()
        End If
    Else
        WaveTimer = WaveTimer + delta

        If SpawnIndex < TotalEnemiesThisWave Then
            SpawnDelayTimer = SpawnDelayTimer - delta
            If SpawnDelayTimer <= 0.0 Then
                SpawnNextEnemy()
                SpawnIndex = SpawnIndex + 1
                SpawnDelayTimer = SpawnDelay
            End If
        End If

        If EnemiesAlive <= 0 And SpawnIndex >= TotalEnemiesThisWave Then
            IsWaveActive = False
            WaveCooldownTimer = WaveCooldown
        End If

        If WaveTimer >= WaveDuration Then
            IsWaveActive = False
            WaveCooldownTimer = WaveCooldown * 0.5
        End If
    End If

    ' ── Auto-Shoot ──
    ShootTimer = ShootTimer + delta
    If ShootTimer >= ShootInterval Then
        ShootTimer = 0.0
        AutoShoot()
    End If
End Sub

' ════════════════════════════════════════════════════════════
Sub StartNextWave()
    Wave = Wave + 1
    WaveTimer = 0.0
    IsWaveActive = True
    EnemiesAlive = 0
    SpawnIndex = 0
    TotalEnemiesThisWave = 5 + Wave * 3
    SpawnDelay = 1.2 - Wave * 0.05
    If SpawnDelay < 0.25 Then SpawnDelay = 0.25
    SpawnDelayTimer = 0.0
    UpdateHUD()
End Sub

Sub SpawnNextEnemy()
    Dim ratio As Single = 0.7 - Wave * 0.04
    If ratio < 0.35 Then ratio = 0.35

    Dim scene_path As String
    If Rnd() < ratio Then
        scene_path = OverflowScene
    Else
        scene_path = DateBugScene
    End If

    Dim scn As PackedScene = Load(scene_path)
    If scn = Nothing Then Exit Sub

    Dim inst As Node2D = scn.Instantiate()

    Dim edge As Integer = Int(Rnd() * 4.0)
    Dim px As Single = 0.0
    Dim py As Single = 0.0
    Select Case edge
        Case 0
            px = 64.0 + Rnd() * 512.0
            py = -40.0
        Case 1
            px = 680.0
            py = 64.0 + Rnd() * 352.0
        Case 2
            px = 64.0 + Rnd() * 512.0
            py = 520.0
        Case 3
            px = -40.0
            py = 64.0 + Rnd() * 352.0
    End Select
    inst.position = Vector2(px, py)

    If inst.HasMethod("SetWaveScale") Then
        Dim ws As Single = 1.0 + (Wave - 1) * 0.12
        inst.SetWaveScale(ws)
    End If

    GetNode("LevelContainer").AddChild(inst)
    EnemiesAlive = EnemiesAlive + 1
End Sub

' ════════════════════════════════════════════════════════════
Sub AutoShoot()
    Dim player As Node2D = GetTree().GetFirstNodeInGroup("player")
    If player = Nothing Then Exit Sub

    Dim enemies As Variant = GetTree().GetNodesInGroup("enemies")
    If enemies = Nothing Then Exit Sub
    If enemies.size() = 0 Then Exit Sub

    Dim nearest As Variant = Nothing
    Dim nearDist As Single = 9999999.0
    Dim i As Integer
    For i = 0 To enemies.size() - 1
        Dim enemy As Variant = enemies[i]
        If enemy <> Nothing Then
            Dim edx As Single = enemy.GlobalPosition.X - player.GlobalPosition.X
            Dim edy As Single = enemy.GlobalPosition.Y - player.GlobalPosition.Y
            Dim edist As Single = Sqr(edx * edx + edy * edy)
            If edist < nearDist Then
                nearDist = edist
                nearest = enemy
            End If
        End If
    Next
    If nearest = Nothing Then Exit Sub

    Dim bscn As PackedScene = Load(BulletScene)
    If bscn = Nothing Then Exit Sub

    Dim bullet As Node2D = bscn.Instantiate()
    bullet.position = player.GlobalPosition

    Dim bdx As Single = nearest.GlobalPosition.X - player.GlobalPosition.X
    Dim bdy As Single = nearest.GlobalPosition.Y - player.GlobalPosition.Y
    Dim blen As Single = Sqr(bdx * bdx + bdy * bdy)
    If blen < 1.0 Then Exit Sub
    Dim bdir As Vector2 = Vector2(bdx / blen, bdy / blen)

    If bullet.HasMethod("SetDamage") Then
        bullet.SetDamage(BulletDamage)
    End If

    GetNode("LevelContainer").AddChild(bullet)
    If bullet.HasMethod("Launch") Then
        bullet.Launch(bdir)
    End If
    GetNode("SFX_Shoot").Play()
End Sub

' ════════════════════════════════════════════════════════════
Sub GiveXP(amount As Integer)
    PlayerXP = PlayerXP + amount
    Dim xp_needed As Integer = PlayerLevel * 100
    If PlayerXP >= xp_needed Then
        PlayerXP = PlayerXP - xp_needed
        LevelUp()
    End If
    UpdateHUD()
End Sub

Sub LevelUp()
    PlayerLevel = PlayerLevel + 1
    BulletDamage = BulletDamage + 10
    If PlayerLevel Mod 3 = 0 Then
        ShootInterval = ShootInterval - 0.05
        If ShootInterval < 0.15 Then ShootInterval = 0.15
    End If
    GetNode("SFX_LevelUp").Play()
    UpdateHUD()
End Sub

Sub EnemyDied()
    EnemiesAlive = EnemiesAlive - 1
    If EnemiesAlive < 0 Then EnemiesAlive = 0
End Sub

Sub UpdatePlayerHP(hp As Integer, maxhp As Integer)
    PlayerHP = hp
    PlayerMaxHP = maxhp
    UpdateHUD()
    If hp <= 0 Then
        BSOD("MEMORY VIOLATION" & vbCrLf & "Page fault in non-paged area" & vbCrLf & vbCrLf & "STOP: 0x0000000A" & vbCrLf & vbCrLf & "Score: " & Str(Score) & "  Wave: " & Str(Wave))
    End If
End Sub

Sub AddScore(points As Integer)
    Score = Score + points
    UpdateHUD()
End Sub

Sub AddCoin(amount As Integer)
End Sub

' ════════════════════════════════════════════════════════════
Sub UpdateHUD()
    Dim xp_needed As Integer = PlayerLevel * 100
    GetNode("HUD/ScoreLabel").Text = "SCORE: " & Str(Score)
    GetNode("HUD/CoinsLabel").Text = "WAVE " & Str(Wave) & "  LVL " & Str(PlayerLevel) & " [" & Str(PlayerXP) & "/" & Str(xp_needed) & " XP]  HP " & Str(PlayerHP) & "/" & Str(PlayerMaxHP)
End Sub

Sub UpdateClock()
    Dim remaining As Single = CountdownMax - CountdownTimer
    If remaining < 0.0 Then remaining = 0.0
    Dim total_secs As Integer = Int(86400.0 - remaining)
    Dim disp_h As Integer = Int(total_secs / 3600) Mod 24
    Dim disp_m As Integer = Int(total_secs / 60) Mod 60
    Dim disp_s As Integer = total_secs Mod 60
    Dim h_str As String = Right("00" & Str(disp_h), 2)
    Dim m_str As String = Right("00" & Str(disp_m), 2)
    Dim s_str As String = Right("00" & Str(disp_s), 2)
    GetNode("HUD/LevelLabel").Text = h_str & ":" & m_str & ":" & s_str & " Y2K"
End Sub

' ════════════════════════════════════════════════════════════
Sub TriggerBSOD()
    BSOD("*** Y2K BUG DETECTED ***" & vbCrLf & vbCrLf & "A fatal exception 0E has occurred at" & vbCrLf & "0028:Y2K:00:00:00 (YEAR_ROLLOVER)" & vbCrLf & vbCrLf & "STOP: 0x00000050" & vbCrLf & "PAGE_FAULT_IN_NONPAGED_AREA" & vbCrLf & vbCrLf & "Final Score: " & Str(Score) & "   Wave: " & Str(Wave))
End Sub

Sub BSOD(msg As String)
    IsGameOver = True
    GetTree().Paused = True
    GetNode("GameOverOverlay/Dim").Color = Color(0.0, 0.0, 0.6, 1.0)
    GetNode("GameOverOverlay/Title").Text = msg
    GetNode("GameOverOverlay").Visible = True
End Sub

Sub RestartBtn_Click()
    GetTree().Paused = False
    GetTree().ReloadCurrentScene()
End Sub

Sub PlayBtn_Click()
    GetNode("MainMenuOverlay").Visible = False
    GetTree().Paused = False
End Sub

Sub ExitBtn_Click()
    GetTree().Quit()
End Sub

Sub PlaySFX_Hit()
    GetNode("SFX_Hit").Play()
End Sub

Sub PlaySFX_XP()
    GetNode("SFX_XP").Play()
End Sub

Sub PlaySFX_Shoot()
    GetNode("SFX_Shoot").Play()
End Sub

Sub PlaySFX_LevelUp()
    GetNode("SFX_LevelUp").Play()
End Sub

Sub PlaySound(index As Integer)
    Select Case index
        Case 0: GetNode("SFX_Shoot").Play()
        Case 1: GetNode("SFX_Hit").Play()
        Case 2: GetNode("SFX_XP").Play()
        Case 3: GetNode("SFX_LevelUp").Play()
    End Select
End Sub
"""

# ─────────────────────────────────────────────────────────────────────────────
# Actor_Hero.vg — TopHero, 4-directional top-down
# ─────────────────────────────────────────────────────────────────────────────

HERO_VG = r"""' Actor_Hero.vg — TopHero (top-down, 4-directional)
' BLUE SCREEN survivor. Arrow keys to move; auto-fires via Main.vg.
Option Explicit

Dim Speed As Single
Dim vx As Single
Dim vy As Single
Dim MaxHP As Integer
Dim CurrentHP As Integer
Dim IsInvincible As Boolean
Dim InvincibleTimer As Single
Dim FlashTimer As Single

Sub _Ready()
    Speed = 160.0
    MaxHP = 100
    CurrentHP = MaxHP
    IsInvincible = False
    InvincibleTimer = 0.0
    FlashTimer = 0.0
    AddToGroup("player")
    Dim main As Node2D = GetTree().CurrentScene
    If main <> Nothing And main.HasMethod("UpdatePlayerHP") Then
        main.UpdatePlayerHP(CurrentHP, MaxHP)
    End If
End Sub

Sub _PhysicsProcess(delta As Single)
    vx = 0.0
    vy = 0.0
    If Input.IsActionPressed("ui_left") Then
        vx = -Speed
    ElseIf Input.IsActionPressed("ui_right") Then
        vx = Speed
    End If
    If Input.IsActionPressed("ui_up") Then
        vy = -Speed
    ElseIf Input.IsActionPressed("ui_down") Then
        vy = Speed
    End If
    ' Normalize diagonal so the player doesn't move faster at 45°
    If vx <> 0.0 And vy <> 0.0 Then
        vx = vx * 0.7071
        vy = vy * 0.7071
    End If
    SetVelocity Me, vx, vy
    MoveAndSlide Me

    ' Invincibility flash after taking damage
    If IsInvincible Then
        InvincibleTimer = InvincibleTimer - delta
        FlashTimer = FlashTimer + delta
        If Int(FlashTimer * 10) Mod 2 = 0 Then
            Me.Modulate = Color(1.0, 0.3, 0.3, 1.0)
        Else
            Me.Modulate = Color(1.0, 1.0, 1.0, 0.3)
        End If
        If InvincibleTimer <= 0.0 Then
            IsInvincible = False
            Me.Modulate = Color(1.0, 1.0, 1.0, 1.0)
        End If
    End If
End Sub

Sub TakeDamage(amount As Integer)
    If IsInvincible Then Exit Sub
    CurrentHP = CurrentHP - amount
    If CurrentHP < 0 Then CurrentHP = 0
    IsInvincible = True
    InvincibleTimer = 1.5
    FlashTimer = 0.0
    Dim main As Node2D = GetTree().CurrentScene
    If main <> Nothing And main.HasMethod("UpdatePlayerHP") Then
        main.UpdatePlayerHP(CurrentHP, MaxHP)
    End If
    If main <> Nothing And main.HasMethod("PlaySFX_Hit") Then
        main.PlaySFX_Hit()
    End If
End Sub

Sub Powerup()
    CurrentHP = CurrentHP + 20
    If CurrentHP > MaxHP Then CurrentHP = MaxHP
    Dim main As Node2D = GetTree().CurrentScene
    If main <> Nothing And main.HasMethod("UpdatePlayerHP") Then
        main.UpdatePlayerHP(CurrentHP, MaxHP)
    End If
End Sub

'--- USER CODE: Hero_custom ---
' (add your code here)
'--- END USER CODE ---
"""

# ─────────────────────────────────────────────────────────────────────────────
# Actor_Overflow.vg — TopGoblin: slow, high HP, grows when bloodied
# ─────────────────────────────────────────────────────────────────────────────

OVERFLOW_VG = r"""' Actor_Overflow.vg — TopGoblin: Overflow (slow, heavy, grows near death)
' A memory-overflowing process that swells as it takes damage.
Option Explicit

Dim Speed As Single
Dim vx As Single
Dim vy As Single
Dim MaxHP As Integer
Dim CurrentHP As Integer
Dim Damage As Integer
Dim ScoreValue As Integer
Dim XPValue As Integer
Dim IsInvincible As Boolean
Dim InvincibleTimer As Single

Sub _Ready()
    Speed = 55.0
    MaxHP = 80
    CurrentHP = MaxHP
    Damage = 15
    ScoreValue = 100
    XPValue = 40
    IsInvincible = False
    InvincibleTimer = 0.0
    AddToGroup("enemies")
End Sub

Sub SetWaveScale(scale_factor As Single)
    MaxHP = Int(80.0 * scale_factor)
    CurrentHP = MaxHP
End Sub

Sub _PhysicsProcess(delta As Single)
    vx = Me.velocity.x
    vy = Me.velocity.y

    Dim player As Node2D = GetTree().GetFirstNodeInGroup("player")
    If player <> Nothing Then
        Dim dx As Single = player.GlobalPosition.X - Me.GlobalPosition.X
        Dim dy As Single = player.GlobalPosition.Y - Me.GlobalPosition.Y
        Dim dist As Single = Sqr(dx * dx + dy * dy)
        If dist > 1.0 Then
            vx = (dx / dist) * Speed
            vy = (dy / dist) * Speed
        End If
    End If

    SetVelocity Me, vx, vy
    MoveAndSlide Me

    ' Visual feedback: swell when health is below 50%
    If CurrentHP > 0 Then
        Dim hp_ratio As Single = CurrentHP / MaxHP
        If hp_ratio < 0.5 Then
            Dim swell As Single = 1.0 + (0.5 - hp_ratio) * 0.8
            Me.Scale = Vector2(swell, swell)
        Else
            Me.Scale = Vector2(1.0, 1.0)
        End If
    End If

    If IsInvincible Then
        InvincibleTimer = InvincibleTimer - delta
        If InvincibleTimer <= 0.0 Then
            IsInvincible = False
            Me.Modulate = Color(1.0, 1.0, 1.0, 1.0)
        End If
    End If
End Sub

Sub TakeDamage(amount As Integer)
    If IsInvincible Then Exit Sub
    CurrentHP = CurrentHP - amount
    Me.Modulate = Color(1.5, 0.4, 0.4, 1.0)
    IsInvincible = True
    InvincibleTimer = 0.15
    If CurrentHP <= 0 Then
        Die()
    End If
End Sub

Sub Die()
    Dim main As Node2D = GetTree().CurrentScene
    If main <> Nothing And main.HasMethod("AddScore") Then
        main.AddScore(ScoreValue)
    End If
    If main <> Nothing And main.HasMethod("GiveXP") Then
        main.GiveXP(XPValue)
    End If
    If main <> Nothing And main.HasMethod("EnemyDied") Then
        main.EnemyDied()
    End If
    ' Drop XP orb
    Dim orb_scn As PackedScene = Load("res://build/BLUE_SCREEN/actors/Actor_XPOrb.tscn")
    If orb_scn <> Nothing Then
        Dim orb As Node2D = orb_scn.Instantiate()
        orb.position = Me.GlobalPosition
        Me.GetParent().AddChild(orb)
    End If
    QueueFree()
End Sub

Sub Hitbox_BodyEntered(body As Node2D)
    If body.IsInGroup("player") Then
        If body.HasMethod("TakeDamage") Then
            body.TakeDamage(Damage)
        End If
    End If
End Sub

Sub Hitbox_AreaEntered(area As Area2D)
End Sub

'--- USER CODE: Overflow_custom ---
' (add your code here)
'--- END USER CODE ---
"""

# ─────────────────────────────────────────────────────────────────────────────
# Actor_DateBug.vg — TopGoblin: fast, erratic, zigzag movement
# ─────────────────────────────────────────────────────────────────────────────

DATEBUG_VG = r"""' Actor_DateBug.vg — TopGoblin: DateBug (fast, erratic, zigzag)
' A Y2K date parser that careens toward the player on a chaotic path.
Option Explicit

Dim Speed As Single
Dim vx As Single
Dim vy As Single
Dim MaxHP As Integer
Dim CurrentHP As Integer
Dim Damage As Integer
Dim ScoreValue As Integer
Dim XPValue As Integer
Dim IsInvincible As Boolean
Dim InvincibleTimer As Single
Dim ZigzagTimer As Single
Dim ZigzagMag As Single

Sub _Ready()
    Speed = 130.0
    MaxHP = 30
    CurrentHP = MaxHP
    Damage = 10
    ScoreValue = 75
    XPValue = 30
    IsInvincible = False
    InvincibleTimer = 0.0
    ZigzagTimer = Rnd() * 6.28  ' Start at random phase
    ZigzagMag = (Rnd() * 60.0) + 40.0
    AddToGroup("enemies")
End Sub

Sub SetWaveScale(scale_factor As Single)
    MaxHP = Int(30.0 * scale_factor)
    CurrentHP = MaxHP
    Speed = 130.0 + (scale_factor - 1.0) * 30.0
End Sub

Sub _PhysicsProcess(delta As Single)
    vx = Me.velocity.x
    vy = Me.velocity.y

    Dim player As Node2D = GetTree().GetFirstNodeInGroup("player")
    If player <> Nothing Then
        Dim dx As Single = player.GlobalPosition.X - Me.GlobalPosition.X
        Dim dy As Single = player.GlobalPosition.Y - Me.GlobalPosition.Y
        Dim dist As Single = Sqr(dx * dx + dy * dy)
        If dist > 1.0 Then
            ' Normalised direction toward player
            Dim nx As Single = dx / dist
            Dim ny As Single = dy / dist
            ' Perpendicular vector for zigzag
            Dim px As Single = -ny
            Dim py As Single = nx
            ' Zigzag oscillation
            ZigzagTimer = ZigzagTimer + delta * 5.0
            Dim zz As Single = Sin(ZigzagTimer) * ZigzagMag * 0.01
            vx = (nx + px * zz) * Speed
            vy = (ny + py * zz) * Speed
        End If
    End If

    SetVelocity Me, vx, vy
    MoveAndSlide Me

    If IsInvincible Then
        InvincibleTimer = InvincibleTimer - delta
        If InvincibleTimer <= 0.0 Then
            IsInvincible = False
            Me.Modulate = Color(1.0, 1.0, 1.0, 1.0)
        End If
    End If
End Sub

Sub TakeDamage(amount As Integer)
    If IsInvincible Then Exit Sub
    CurrentHP = CurrentHP - amount
    Me.Modulate = Color(1.5, 0.5, 0.2, 1.0)
    IsInvincible = True
    InvincibleTimer = 0.12
    If CurrentHP <= 0 Then
        Die()
    End If
End Sub

Sub Die()
    Dim main As Node2D = GetTree().CurrentScene
    If main <> Nothing And main.HasMethod("AddScore") Then
        main.AddScore(ScoreValue)
    End If
    If main <> Nothing And main.HasMethod("GiveXP") Then
        main.GiveXP(XPValue)
    End If
    If main <> Nothing And main.HasMethod("EnemyDied") Then
        main.EnemyDied()
    End If
    ' Drop XP orb (50% chance — fast enemies drop less)
    If Rnd() < 0.5 Then
        Dim orb_scn As PackedScene = Load("res://build/BLUE_SCREEN/actors/Actor_XPOrb.tscn")
        If orb_scn <> Nothing Then
            Dim orb As Node2D = orb_scn.Instantiate()
            orb.position = Me.GlobalPosition
            Me.GetParent().AddChild(orb)
        End If
    End If
    QueueFree()
End Sub

Sub Hitbox_BodyEntered(body As Node2D)
    If body.IsInGroup("player") Then
        If body.HasMethod("TakeDamage") Then
            body.TakeDamage(Damage)
        End If
    End If
End Sub

Sub Hitbox_AreaEntered(area As Area2D)
End Sub

'--- USER CODE: DateBug_custom ---
' (add your code here)
'--- END USER CODE ---
"""

# ─────────────────────────────────────────────────────────────────────────────
# Actor_XPOrb.vg — Powerup: drifts toward player, awards XP on pickup
# ─────────────────────────────────────────────────────────────────────────────

XPORB_VG = r"""' Actor_XPOrb.vg — Powerup: XP Orb
' Dropped by enemies. Drifts toward the player; awards XP on contact.
Option Explicit

Dim Speed As Single
Dim MaxHP As Integer
Dim CurrentHP As Integer
Dim XPValue As Integer
Dim ScoreValue As Integer
Dim LifeTime As Single

Sub _Ready()
    Speed = 70.0
    MaxHP = 9999
    CurrentHP = MaxHP
    XPValue = 25
    ScoreValue = 10
    LifeTime = 12.0
    AddToGroup("powerup")
End Sub

Sub _PhysicsProcess(delta As Single)
    LifeTime = LifeTime - delta
    If LifeTime <= 0.0 Then
        QueueFree()
        Exit Sub
    End If

    ' Slowly drift toward nearest player
    Dim player As Node2D = GetTree().GetFirstNodeInGroup("player")
    If player <> Nothing Then
        Dim dx As Single = player.GlobalPosition.X - Me.GlobalPosition.X
        Dim dy As Single = player.GlobalPosition.Y - Me.GlobalPosition.Y
        Dim dist As Single = Sqr(dx * dx + dy * dy)
        If dist > 4.0 Then
            Dim vx As Single = (dx / dist) * Speed
            Dim vy As Single = (dy / dist) * Speed
            SetVelocity Me, vx, vy
            MoveAndSlide Me
        End If
    End If

    ' Pulse scale for visibility
    Dim pulse As Single = 0.85 + Sin(LifeTime * 6.0) * 0.15
    Me.Scale = Vector2(pulse, pulse)
End Sub

Sub Hitbox_BodyEntered(body As Node2D)
    If body.IsInGroup("player") Then
        Dim main As Node2D = GetTree().CurrentScene
        If main <> Nothing And main.HasMethod("GiveXP") Then
            main.GiveXP(XPValue)
        End If
        If main <> Nothing And main.HasMethod("AddScore") Then
            main.AddScore(ScoreValue)
        End If
        If main <> Nothing And main.HasMethod("PlaySFX_XP") Then
            main.PlaySFX_XP()
        End If
        QueueFree()
    End If
End Sub

Sub Hitbox_AreaEntered(area As Area2D)
End Sub

'--- USER CODE: XPOrb_custom ---
' (add your code here)
'--- END USER CODE ---
"""

# ─────────────────────────────────────────────────────────────────────────────
# Actor_Bullet.vg — Missile: add SetDamage, keep existing Launch logic
# ─────────────────────────────────────────────────────────────────────────────

BULLET_VG = r"""' Actor_Bullet.vg — Missile: Player auto-fire projectile
' Spawned by Main.vg AutoShoot(). Damage set at spawn time.
Option Explicit

Dim Speed As Single
Dim vx As Single
Dim vy As Single
Dim MaxHP As Integer
Dim CurrentHP As Integer
Dim Damage As Integer
Dim ScoreValue As Integer
Dim Gravity As Single
Dim IsInvincible As Boolean
Dim InvincibleTimer As Single
Dim CurrentAnim As String
Dim MoveDirection As Vector2
Dim LifeTime As Single

Sub _Ready()
    Speed = 400.0
    Gravity = 0.0
    MaxHP = 1
    CurrentHP = MaxHP
    Damage = 25
    ScoreValue = 0
    IsInvincible = False
    InvincibleTimer = 0.0
    CurrentAnim = "Idle"
    LifeTime = 3.0
End Sub

Sub _PhysicsProcess(delta As Single)
    Position = Position + MoveDirection * Speed * delta
    LifeTime = LifeTime - delta
    If LifeTime <= 0.0 Then
        QueueFree()
    End If
End Sub

Sub Launch(dir As Vector2)
    MoveDirection = dir.Normalized()
    LifeTime = 3.0
End Sub

Sub SetDamage(dmg As Integer)
    Damage = dmg
End Sub

Sub Hitbox_BodyEntered(body As Node2D)
    If body.HasMethod("TakeDamage") Then
        body.TakeDamage(Damage)
    End If
    QueueFree()
End Sub

Sub Hitbox_AreaEntered(area As Area2D)
End Sub

'--- USER CODE: Bullet_custom ---
' (add your code here)
'--- END USER CODE ---
"""

# ─────────────────────────────────────────────────────────────────────────────
# Write all files
# ─────────────────────────────────────────────────────────────────────────────

files = {
    f"{BASE}/Main.vg": MAIN_VG,
    f"{BASE}/actors/Actor_Hero.vg": HERO_VG,
    f"{BASE}/actors/Actor_Overflow.vg": OVERFLOW_VG,
    f"{BASE}/actors/Actor_DateBug.vg": DATEBUG_VG,
    f"{BASE}/actors/Actor_XPOrb.vg": XPORB_VG,
    f"{BASE}/actors/Actor_Bullet.vg": BULLET_VG,
}

for path, content in files.items():
    with open(path, "w", encoding="utf-8") as f:
        f.write(content.lstrip("\n"))
    print(f"Wrote {path}")

print("Done.")
