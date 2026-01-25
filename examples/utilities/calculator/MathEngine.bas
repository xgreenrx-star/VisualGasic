' MathEngine.bas - Mathematical operations for Advanced Calculator
Imports System.Math
Imports System.Collections.Generic

Option Explicit On
Option Strict On

Public Class MathEngine
    ' Constants
    Public Const PI As Double = 3.141592653589793
    Public Const E As Double = 2.718281828459045
    
    ' Angle mode
    Public Enum AngleMode
        Degrees
        Radians
        Gradians
    End Enum
    
    Private angleMode As AngleMode = AngleMode.Degrees
    
    Public Property CurrentAngleMode As AngleMode
        Get
            Return angleMode
        End Get
        Set(value As AngleMode)
            angleMode = value
        End Set
    End Property
    
    ' Basic arithmetic operations
    Public Function Add(a As Double, b As Double) As Double
        Return a + b
    End Function
    
    Public Function Subtract(a As Double, b As Double) As Double
        Return a - b
    End Function
    
    Public Function Multiply(a As Double, b As Double) As Double
        Return a * b
    End Function
    
    Public Function Divide(a As Double, b As Double) As Double
        If b = 0 Then
            Throw New DivideByZeroException("Cannot divide by zero")
        End If
        Return a / b
    End Function
    
    Public Function Power(base As Double, exponent As Double) As Double
        Return Pow(base, exponent)
    End Function
    
    Public Function Modulo(a As Double, b As Double) As Double
        If b = 0 Then
            Throw New DivideByZeroException("Cannot perform modulo with zero")
        End If
        Return a Mod b
    End Function
    
    ' Advanced mathematical functions
    Public Function SquareRoot(value As Double) As Double
        If value < 0 Then
            Throw New ArgumentException("Cannot calculate square root of negative number")
        End If
        Return Sqrt(value)
    End Function
    
    Public Function CubeRoot(value As Double) As Double
        If value >= 0 Then
            Return Pow(value, 1.0 / 3.0)
        Else
            Return -Pow(-value, 1.0 / 3.0)
        End If
    End Function
    
    Public Function NthRoot(value As Double, n As Double) As Double
        If n = 0 Then
            Throw New ArgumentException("Root degree cannot be zero")
        End If
        
        If n Mod 2 = 0 And value < 0 Then
            Throw New ArgumentException("Cannot calculate even root of negative number")
        End If
        
        If value >= 0 Then
            Return Pow(value, 1.0 / n)
        Else
            Return -Pow(-value, 1.0 / n)
        End If
    End Function
    
    ' Trigonometric functions
    Private Function ConvertToRadians(angle As Double) As Double
        Select Case angleMode
            Case AngleMode.Degrees
                Return angle * PI / 180.0
            Case AngleMode.Radians
                Return angle
            Case AngleMode.Gradians
                Return angle * PI / 200.0
            Case Else
                Return angle
        End Select
    End Function
    
    Private Function ConvertFromRadians(angle As Double) As Double
        Select Case angleMode
            Case AngleMode.Degrees
                Return angle * 180.0 / PI
            Case AngleMode.Radians
                Return angle
            Case AngleMode.Gradians
                Return angle * 200.0 / PI
            Case Else
                Return angle
        End Select
    End Function
    
    Public Function Sine(angle As Double) As Double
        Return Sin(ConvertToRadians(angle))
    End Function
    
    Public Function Cosine(angle As Double) As Double
        Return Cos(ConvertToRadians(angle))
    End Function
    
    Public Function Tangent(angle As Double) As Double
        Dim radians As Double = ConvertToRadians(angle)
        If Cos(radians) = 0 Then
            Throw New ArgumentException("Tangent is undefined at this angle")
        End If
        Return Tan(radians)
    End Function
    
    Public Function ArcSine(value As Double) As Double
        If value < -1 Or value > 1 Then
            Throw New ArgumentException("Arc sine domain error: value must be between -1 and 1")
        End If
        Return ConvertFromRadians(Asin(value))
    End Function
    
    Public Function ArcCosine(value As Double) As Double
        If value < -1 Or value > 1 Then
            Throw New ArgumentException("Arc cosine domain error: value must be between -1 and 1")
        End If
        Return ConvertFromRadians(Acos(value))
    End Function
    
    Public Function ArcTangent(value As Double) As Double
        Return ConvertFromRadians(Atan(value))
    End Function
    
    Public Function ArcTangent2(y As Double, x As Double) As Double
        Return ConvertFromRadians(Atan2(y, x))
    End Function
    
    ' Hyperbolic functions
    Public Function SineHyperbolic(value As Double) As Double
        Return Sinh(value)
    End Function
    
    Public Function CosineHyperbolic(value As Double) As Double
        Return Cosh(value)
    End Function
    
    Public Function TangentHyperbolic(value As Double) As Double
        Return Tanh(value)
    End Function
    
    ' Logarithmic functions
    Public Function NaturalLog(value As Double) As Double
        If value <= 0 Then
            Throw New ArgumentException("Natural logarithm domain error: value must be positive")
        End If
        Return Log(value)
    End Function
    
    Public Function CommonLog(value As Double) As Double
        If value <= 0 Then
            Throw New ArgumentException("Common logarithm domain error: value must be positive")
        End If
        Return Log10(value)
    End Function
    
    Public Function LogBase(value As Double, base As Double) As Double
        If value <= 0 Then
            Throw New ArgumentException("Logarithm domain error: value must be positive")
        End If
        If base <= 0 Or base = 1 Then
            Throw New ArgumentException("Logarithm base error: base must be positive and not equal to 1")
        End If
        Return Log(value) / Log(base)
    End Function
    
    ' Exponential functions
    Public Function Exponential(exponent As Double) As Double
        Return Exp(exponent)
    End Function
    
    Public Function Power10(exponent As Double) As Double
        Return Pow(10, exponent)
    End Function
    
    Public Function PowerBase(base As Double, exponent As Double) As Double
        If base = 0 And exponent <= 0 Then
            Throw New ArgumentException("Invalid operation: 0 to non-positive power")
        End If
        If base < 0 And exponent <> Math.Floor(exponent) Then
            Throw New ArgumentException("Complex result: negative base to non-integer power")
        End If
        Return Pow(base, exponent)
    End Function
    
    ' Statistical functions
    Public Function Factorial(n As Integer) As Double
        If n < 0 Then
            Throw New ArgumentException("Factorial domain error: value must be non-negative")
        End If
        
        If n = 0 Or n = 1 Then
            Return 1
        End If
        
        Dim result As Double = 1
        For i As Integer = 2 To n
            result *= i
            If Double.IsInfinity(result) Then
                Throw New OverflowException("Factorial result too large")
            End If
        Next
        
        Return result
    End Function
    
    Public Function Combination(n As Integer, r As Integer) As Double
        If n < 0 Or r < 0 Or r > n Then
            Throw New ArgumentException("Invalid combination parameters")
        End If
        
        If r = 0 Or r = n Then
            Return 1
        End If
        
        ' Use the formula C(n,r) = n! / (r! * (n-r)!)
        ' Optimize by calculating C(n,r) = (n * (n-1) * ... * (n-r+1)) / (r * (r-1) * ... * 1)
        Dim result As Double = 1
        Dim k As Integer = Math.Min(r, n - r)  ' Choose smaller to minimize computation
        
        For i As Integer = 0 To k - 1
            result = result * (n - i) / (i + 1)
        Next
        
        Return result
    End Function
    
    Public Function Permutation(n As Integer, r As Integer) As Double
        If n < 0 Or r < 0 Or r > n Then
            Throw New ArgumentException("Invalid permutation parameters")
        End If
        
        If r = 0 Then
            Return 1
        End If
        
        ' P(n,r) = n! / (n-r)!
        Dim result As Double = 1
        For i As Integer = n To n - r + 1 Step -1
            result *= i
        Next
        
        Return result
    End Function
    
    ' Number theory functions
    Public Function GreatestCommonDivisor(a As Integer, b As Integer) As Integer
        a = Math.Abs(a)
        b = Math.Abs(b)
        
        While b <> 0
            Dim temp As Integer = b
            b = a Mod b
            a = temp
        End While
        
        Return a
    End Function
    
    Public Function LeastCommonMultiple(a As Integer, b As Integer) As Integer
        If a = 0 Or b = 0 Then
            Return 0
        End If
        
        Return Math.Abs(a * b) / GreatestCommonDivisor(a, b)
    End Function
    
    Public Function IsPrime(n As Integer) As Boolean
        If n < 2 Then
            Return False
        End If
        
        If n = 2 Then
            Return True
        End If
        
        If n Mod 2 = 0 Then
            Return False
        End If
        
        Dim sqrt_n As Integer = CInt(Math.Sqrt(n))
        For i As Integer = 3 To sqrt_n Step 2
            If n Mod i = 0 Then
                Return False
            End If
        Next
        
        Return True
    End Function
    
    ' Utility functions
    Public Function AbsoluteValue(value As Double) As Double
        Return Math.Abs(value)
    End Function
    
    Public Function Sign(value As Double) As Integer
        Return Math.Sign(value)
    End Function
    
    Public Function Floor(value As Double) As Double
        Return Math.Floor(value)
    End Function
    
    Public Function Ceiling(value As Double) As Double
        Return Math.Ceiling(value)
    End Function
    
    Public Function Round(value As Double, Optional decimals As Integer = 0) As Double
        Return Math.Round(value, decimals)
    End Function
    
    Public Function Truncate(value As Double) As Double
        Return Math.Truncate(value)
    End Function
    
    Public Function Min(a As Double, b As Double) As Double
        Return Math.Min(a, b)
    End Function
    
    Public Function Max(a As Double, b As Double) As Double
        Return Math.Max(a, b)
    End Function
    
    ' Complex number operations (basic)
    Public Structure ComplexNumber
        Public Real As Double
        Public Imaginary As Double
        
        Public Sub New(real As Double, imaginary As Double)
            Me.Real = real
            Me.Imaginary = imaginary
        End Sub
        
        Public Function Magnitude() As Double
            Return Sqrt(Real * Real + Imaginary * Imaginary)
        End Function
        
        Public Function Phase() As Double
            Return Atan2(Imaginary, Real)
        End Function
        
        Public Overrides Function ToString() As String
            If Imaginary >= 0 Then
                Return $"{Real} + {Imaginary}i"
            Else
                Return $"{Real} - {Math.Abs(Imaginary)}i"
            End If
        End Function
    End Structure
    
    Public Function AddComplex(a As ComplexNumber, b As ComplexNumber) As ComplexNumber
        Return New ComplexNumber(a.Real + b.Real, a.Imaginary + b.Imaginary)
    End Function
    
    Public Function SubtractComplex(a As ComplexNumber, b As ComplexNumber) As ComplexNumber
        Return New ComplexNumber(a.Real - b.Real, a.Imaginary - b.Imaginary)
    End Function
    
    Public Function MultiplyComplex(a As ComplexNumber, b As ComplexNumber) As ComplexNumber
        Dim real As Double = a.Real * b.Real - a.Imaginary * b.Imaginary
        Dim imaginary As Double = a.Real * b.Imaginary + a.Imaginary * b.Real
        Return New ComplexNumber(real, imaginary)
    End Function
    
    Public Function DivideComplex(a As ComplexNumber, b As ComplexNumber) As ComplexNumber
        Dim denominator As Double = b.Real * b.Real + b.Imaginary * b.Imaginary
        If denominator = 0 Then
            Throw New DivideByZeroException("Cannot divide by zero complex number")
        End If
        
        Dim real As Double = (a.Real * b.Real + a.Imaginary * b.Imaginary) / denominator
        Dim imaginary As Double = (a.Imaginary * b.Real - a.Real * b.Imaginary) / denominator
        Return New ComplexNumber(real, imaginary)
    End Function
    
    ' Equation solving
    Public Function SolveQuadratic(a As Double, b As Double, c As Double) As (root1 As ComplexNumber, root2 As ComplexNumber)
        If a = 0 Then
            Throw New ArgumentException("Coefficient 'a' cannot be zero in quadratic equation")
        End If
        
        Dim discriminant As Double = b * b - 4 * a * c
        
        If discriminant >= 0 Then
            ' Real roots
            Dim sqrtDiscriminant As Double = Sqrt(discriminant)
            Dim root1 As New ComplexNumber((-b + sqrtDiscriminant) / (2 * a), 0)
            Dim root2 As New ComplexNumber((-b - sqrtDiscriminant) / (2 * a), 0)
            Return (root1, root2)
        Else
            ' Complex roots
            Dim sqrtNegDiscriminant As Double = Sqrt(-discriminant)
            Dim root1 As New ComplexNumber(-b / (2 * a), sqrtNegDiscriminant / (2 * a))
            Dim root2 As New ComplexNumber(-b / (2 * a), -sqrtNegDiscriminant / (2 * a))
            Return (root1, root2)
        End If
    End Function
    
    ' Unit conversions
    Public Function DegreesToRadians(degrees As Double) As Double
        Return degrees * PI / 180.0
    End Function
    
    Public Function RadiansToDegrees(radians As Double) As Double
        Return radians * 180.0 / PI
    End Function
    
    Public Function DegreesToGradians(degrees As Double) As Double
        Return degrees * 10.0 / 9.0
    End Function
    
    Public Function GradiansToDegrees(gradians As Double) As Double
        Return gradians * 9.0 / 10.0
    End Function
End Class