Option Explicit

' Enhanced test for Whenever system with new operators
Dim health As Integer = 100
Dim score As Integer = 0
Dim username As String = "player"

' Set up Whenever sections with enhanced operators
Whenever Section HealthMonitor health Changes OnHealthChange
Whenever Section LowHealth health Below 30 OnLowHealth
Whenever Section CriticalHealth health Between 1 And 10 OnCriticalHealth
Whenever Section HighScore score Exceeds 1000 OnHighScore
Whenever Section AdminCheck username Contains "admin" OnAdminLogin

Sub Main()
    Print "Testing Enhanced Whenever System..."
    Print "================================="
    
    ' Display initial status
    Print WheneverStatus()
    
    ' Test different operators
    health = 75    ' Should trigger OnHealthChange
    health = 25    ' Should trigger OnHealthChange and OnLowHealth
    health = 5     ' Should trigger OnHealthChange and OnCriticalHealth
    
    score = 500    ' Should trigger nothing
    score = 1500   ' Should trigger OnHighScore
    
    username = "admin_user"  ' Should trigger OnAdminLogin
    
    ' Test suspend/resume
    Print "Suspending health monitoring..."
    Suspend Whenever HealthMonitor
    health = 50    ' Should NOT trigger OnHealthChange
    
    Print "Resuming health monitoring..."
    Resume Whenever HealthMonitor
    health = 60    ' Should trigger OnHealthChange
    
    ' Display final status
    Print "Active Whenever sections: " & ActiveWheneverCount()
    Print "Enhanced Whenever test completed."
End Sub

Sub OnHealthChange()
    Print "Health changed to: " & health
End Sub

Sub OnLowHealth()
    Print "WARNING: Low health detected! (" & health & ")"
End Sub

Sub OnCriticalHealth()
    Print "CRITICAL: Health is critically low! (" & health & ")"
End Sub

Sub OnHighScore()
    Print "Congratulations! High score achieved: " & score
End Sub

Sub OnAdminLogin()
    Print "Admin user logged in: " & username
End Sub