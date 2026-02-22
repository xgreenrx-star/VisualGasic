Option Explicit

' Enhanced Whenever System Test - All Three Major Enhancements
Dim health As Integer = 100
Dim mana As Integer = 50
Dim score As Integer = 0
Dim level As Integer = 1
Dim username As String = "player"
Dim stamina As Integer = 100

Sub Main()
    Print "Testing All Enhanced Whenever Features"
    Print "======================================"
    
    ' Enhancement #1: Multiple Callbacks
    Print "1. Testing Multiple Callbacks..."
    Whenever Section GameOver health Becomes 0 ShowGameOver, PlayDeathSound, SaveScore
    
    ' Enhancement #2: Complex Expressions  
    Print "2. Testing Complex Expressions..."
    Whenever Section CriticalState (health < 20 And mana < 10) TriggerEmergencyMode
    Whenever Section PowerMode (score > 500 And level > 2) EnablePowerMode
    
    ' Enhancement #3: Scoped Sections
    Print "3. Testing Scoped Sections..."
    CallBossEncounter()
    
    ' Test the multiple callbacks
    Print "Testing multiple callbacks..."
    health = 0  ' Should trigger all three: ShowGameOver, PlayDeathSound, SaveScore
    
    ' Reset and test complex expressions
    health = 100
    Print "Testing complex expressions..."
    health = 15
    mana = 5    ' Should trigger TriggerEmergencyMode
    
    score = 600
    level = 3   ' Should trigger EnablePowerMode
    
    Print ""
    Print "Final Status:"
    Print WheneverStatus()
    
    Print "Enhanced Whenever System Test Complete!"
End Sub

Sub CallBossEncounter()
    Print "Entering Boss Encounter (Local Scope)..."
    EnterScope("BossEncounter")
    
    ' Local scoped sections - will auto-cleanup when leaving BossEncounter
    Whenever Section Local BossHealth health Below 30 BossRageMode
    Whenever Section Local BossStunned (health < 10 And stamina > 80) BossStunRecovery
    
    ' Simulate boss encounter
    Print "Boss fight simulation..."
    health = 25  ' Should trigger BossRageMode
    stamina = 90
    health = 8   ' Should trigger BossStunRecovery
    
    Print "Boss defeated! Leaving scope..."
    ExitScope("BossEncounter")
    Print "Local Whenever sections should now be cleaned up."
End Sub

' Enhancement #1: Multiple Callback Procedures
Sub ShowGameOver()
    Print "GAME OVER! Health reached zero."
End Sub

Sub PlayDeathSound()
    Print "Playing death sound effect..."
End Sub

Sub SaveScore()
    Print "Saving final score: " & score
End Sub

' Enhancement #2: Complex Expression Callbacks
Sub TriggerEmergencyMode()
    Print "EMERGENCY MODE: Low health (" & health & ") AND low mana (" & mana & ")!"
End Sub

Sub EnablePowerMode()
    Print "POWER MODE ACTIVATED: High score (" & score & ") and sufficient level (" & level & ")!"
End Sub

' Enhancement #3: Local Scoped Callbacks
Sub BossRageMode()
    Print "Boss enters RAGE MODE! Health: " & health
End Sub

Sub BossStunRecovery()
    Print "Boss is stunned but recovering! Health: " & health & ", Stamina: " & stamina
End Sub

' Scope management helpers (these would be built into the system)
Sub EnterScope(scopeName As String)
    Print "Entering scope: " & scopeName
End Sub

Sub ExitScope(scopeName As String) 
    Print "Exiting scope: " & scopeName
End Sub