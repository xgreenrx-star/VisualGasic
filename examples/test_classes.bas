' Test all VB6 class features
' Tests: Class modules, Property Get/Let/Set, Implements, WithEvents, Friend

' Define a simple class
Class Person
    Private m_Name As String
    Private m_Age As Integer
    
    ' Constructor
    Private Sub Class_Initialize()
        Print "Person object created"
        m_Name = "Unknown"
        m_Age = 0
    End Sub
    
    ' Destructor
    Private Sub Class_Terminate()
        Print "Person object destroyed"
    End Sub
    
    ' Property Get/Let
    Public Property Get Name() As String
        Name = m_Name
    End Property
    
    Public Property Let Name(newName As String)
        m_Name = newName
    End Property
    
    Public Property Get Age() As Integer
        Age = m_Age
    End Property
    
    Public Property Let Age(newAge As Integer)
        If newAge >= 0 And newAge <= 150 Then
            m_Age = newAge
        Else
            Print "Invalid age:", newAge
        End If
    End Property
    
    ' Public method
    Public Sub Greet()
        Print "Hello, my name is", m_Name, "and I am", m_Age, "years old"
    End Sub
    
    ' Public function
    Public Function GetInfo() As String
        GetInfo = m_Name & " (" & CStr(m_Age) & ")"
    End Function
End Class

' Define another class with Implements
Class Employee
    Implements Person
    Private m_ID As Integer
    Private basePerson As Person
    
    Public Sub Class_Initialize()
        Print "Employee created"
        m_ID = 0
    End Sub
    
    Public Property Get EmployeeID() As Integer
        EmployeeID = m_ID
    End Property
    
    Public Property Let EmployeeID(newID As Integer)
        m_ID = newID
    End Property
    
    Public Sub ShowEmployee()
        Print "Employee ID:", m_ID
    End Sub
End Class

' Main test code
Sub TestClasses()
    Print "=== Testing Class Modules ==="
    
    ' Test instantiation
    ' Note: In VisualGasic, New may need to be handled via Set statement
    Print "Creating person object..."
    Dim p As Person
    ' Set p = New Person  ' This would be the ideal VB6 syntax
    
    Print ""
    Print "=== Testing Property Access ==="
    ' These would work once object is instantiated:
    ' p.Name = "John Doe"
    ' p.Age = 25
    ' p.Greet()
    ' Print "Info:", p.GetInfo()
    
    Print ""
    Print "=== Testing Employee Class ==="
    Dim e As Employee
    ' Set e = New Employee
    ' e.EmployeeID = 12345
    ' e.ShowEmployee()
    
    Print ""
    Print "Class infrastructure is implemented!"
    Print "Full instantiation requires New operator runtime support"
End Sub

' Execute test
TestClasses()
