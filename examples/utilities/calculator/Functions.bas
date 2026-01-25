' Functions.bas - Additional mathematical and utility functions for Advanced Calculator
Imports System.Math
Imports System.Collections.Generic
Imports System.Text.RegularExpressions
Imports System.Globalization

Option Explicit On
Option Strict On

Public Class Functions
    ' Constants for various calculations
    Public Const GOLDEN_RATIO As Double = 1.618033988749895
    Public Const EULER_MASCHERONI As Double = 0.5772156649015329
    Public Const PLANCK_CONSTANT As Double = 6.62607015E-34
    Public Const SPEED_OF_LIGHT As Double = 299792458
    Public Const AVOGADRO_NUMBER As Double = 6.02214076E23
    Public Const BOLTZMANN_CONSTANT As Double = 1.380649E-23
    
    ' Financial functions
    Public Shared Function PresentValue(rate As Double, periods As Integer, payment As Double, Optional futureValue As Double = 0, Optional type As Integer = 0) As Double
        If rate = 0 Then
            Return -(payment * periods + futureValue)
        End If
        
        Dim pvFactor As Double = (1 - Math.Pow(1 + rate, -periods)) / rate
        If type = 1 Then
            pvFactor *= (1 + rate)
        End If
        
        Return -(payment * pvFactor + futureValue / Math.Pow(1 + rate, periods))
    End Function
    
    Public Shared Function FutureValue(rate As Double, periods As Integer, payment As Double, Optional presentValue As Double = 0, Optional type As Integer = 0) As Double
        If rate = 0 Then
            Return -(presentValue + payment * periods)
        End If
        
        Dim fvFactor As Double = (Math.Pow(1 + rate, periods) - 1) / rate
        If type = 1 Then
            fvFactor *= (1 + rate)
        End If
        
        Return -(presentValue * Math.Pow(1 + rate, periods) + payment * fvFactor)
    End Function
    
    Public Shared Function PaymentAmount(rate As Double, periods As Integer, presentValue As Double, Optional futureValue As Double = 0, Optional type As Integer = 0) As Double
        If rate = 0 Then
            Return -(presentValue + futureValue) / periods
        End If
        
        Dim factor As Double = (1 - Math.Pow(1 + rate, -periods)) / rate
        If type = 1 Then
            factor *= (1 + rate)
        End If
        
        Return -(presentValue + futureValue / Math.Pow(1 + rate, periods)) / factor
    End Function
    
    Public Shared Function CompoundInterest(principal As Double, rate As Double, periods As Integer, Optional compoundsPerPeriod As Integer = 1) As Double
        Return principal * Math.Pow(1 + rate / compoundsPerPeriod, compoundsPerPeriod * periods)
    End Function
    
    Public Shared Function SimpleInterest(principal As Double, rate As Double, time As Double) As Double
        Return principal * (1 + rate * time)
    End Function
    
    ' Statistical functions
    Public Shared Function Mean(values As Double()) As Double
        If values Is Nothing Or values.Length = 0 Then
            Throw New ArgumentException("Values array cannot be null or empty")
        End If
        
        Return values.Sum() / values.Length
    End Function
    
    Public Shared Function Median(values As Double()) As Double
        If values Is Nothing Or values.Length = 0 Then
            Throw New ArgumentException("Values array cannot be null or empty")
        End If
        
        Dim sortedValues As Double() = New Double(values.Length - 1) {}
        Array.Copy(values, sortedValues, values.Length)
        Array.Sort(sortedValues)
        
        Dim n As Integer = sortedValues.Length
        If n Mod 2 = 0 Then
            Return (sortedValues(n \ 2 - 1) + sortedValues(n \ 2)) / 2.0
        Else
            Return sortedValues(n \ 2)
        End If
    End Function
    
    Public Shared Function Mode(values As Double()) As Double()
        If values Is Nothing Or values.Length = 0 Then
            Throw New ArgumentException("Values array cannot be null or empty")
        End If
        
        Dim frequency As New Dictionary(Of Double, Integer)
        
        For Each value As Double In values
            If frequency.ContainsKey(value) Then
                frequency(value) += 1
            Else
                frequency(value) = 1
            End If
        Next
        
        Dim maxFrequency As Integer = frequency.Values.Max()
        Dim modes As New List(Of Double)
        
        For Each kvp As KeyValuePair(Of Double, Integer) In frequency
            If kvp.Value = maxFrequency Then
                modes.Add(kvp.Key)
            End If
        Next
        
        Return modes.ToArray()
    End Function
    
    Public Shared Function StandardDeviation(values As Double(), Optional population As Boolean = False) As Double
        If values Is Nothing Or values.Length = 0 Then
            Throw New ArgumentException("Values array cannot be null or empty")
        End If
        
        Dim meanValue As Double = Mean(values)
        Dim sumSquaredDifferences As Double = 0
        
        For Each value As Double In values
            sumSquaredDifferences += Math.Pow(value - meanValue, 2)
        Next
        
        Dim denominator As Integer = If(population, values.Length, values.Length - 1)
        If denominator = 0 Then
            Throw New ArgumentException("Cannot calculate sample standard deviation with only one value")
        End If
        
        Return Math.Sqrt(sumSquaredDifferences / denominator)
    End Function
    
    Public Shared Function Variance(values As Double(), Optional population As Boolean = False) As Double
        Dim stdDev As Double = StandardDeviation(values, population)
        Return stdDev * stdDev
    End Function
    
    Public Shared Function Correlation(x As Double(), y As Double()) As Double
        If x Is Nothing Or y Is Nothing Or x.Length = 0 Or y.Length = 0 Then
            Throw New ArgumentException("Arrays cannot be null or empty")
        End If
        
        If x.Length <> y.Length Then
            Throw New ArgumentException("Arrays must have the same length")
        End If
        
        Dim n As Integer = x.Length
        Dim sumX As Double = x.Sum()
        Dim sumY As Double = y.Sum()
        Dim sumXY As Double = 0
        Dim sumXSquared As Double = 0
        Dim sumYSquared As Double = 0
        
        For i As Integer = 0 To n - 1
            sumXY += x(i) * y(i)
            sumXSquared += x(i) * x(i)
            sumYSquared += y(i) * y(i)
        Next
        
        Dim numerator As Double = n * sumXY - sumX * sumY
        Dim denominator As Double = Math.Sqrt((n * sumXSquared - sumX * sumX) * (n * sumYSquared - sumY * sumY))
        
        If denominator = 0 Then
            Return 0
        End If
        
        Return numerator / denominator
    End Function
    
    ' Geometry functions
    Public Shared Function CircleArea(radius As Double) As Double
        If radius < 0 Then
            Throw New ArgumentException("Radius cannot be negative")
        End If
        Return Math.PI * radius * radius
    End Function
    
    Public Shared Function CircleCircumference(radius As Double) As Double
        If radius < 0 Then
            Throw New ArgumentException("Radius cannot be negative")
        End If
        Return 2 * Math.PI * radius
    End Function
    
    Public Shared Function SphereVolume(radius As Double) As Double
        If radius < 0 Then
            Throw New ArgumentException("Radius cannot be negative")
        End If
        Return (4.0 / 3.0) * Math.PI * Math.Pow(radius, 3)
    End Function
    
    Public Shared Function SphereSurfaceArea(radius As Double) As Double
        If radius < 0 Then
            Throw New ArgumentException("Radius cannot be negative")
        End If
        Return 4 * Math.PI * radius * radius
    End Function
    
    Public Shared Function CylinderVolume(radius As Double, height As Double) As Double
        If radius < 0 Or height < 0 Then
            Throw New ArgumentException("Radius and height cannot be negative")
        End If
        Return Math.PI * radius * radius * height
    End Function
    
    Public Shared Function CylinderSurfaceArea(radius As Double, height As Double) As Double
        If radius < 0 Or height < 0 Then
            Throw New ArgumentException("Radius and height cannot be negative")
        End If
        Return 2 * Math.PI * radius * (radius + height)
    End Function
    
    Public Shared Function ConeVolume(radius As Double, height As Double) As Double
        If radius < 0 Or height < 0 Then
            Throw New ArgumentException("Radius and height cannot be negative")
        End If
        Return (1.0 / 3.0) * Math.PI * radius * radius * height
    End Function
    
    Public Shared Function TriangleArea(base As Double, height As Double) As Double
        If base < 0 Or height < 0 Then
            Throw New ArgumentException("Base and height cannot be negative")
        End If
        Return 0.5 * base * height
    End Function
    
    Public Shared Function TriangleAreaHeron(a As Double, b As Double, c As Double) As Double
        If a <= 0 Or b <= 0 Or c <= 0 Then
            Throw New ArgumentException("Side lengths must be positive")
        End If
        
        If a + b <= c Or a + c <= b Or b + c <= a Then
            Throw New ArgumentException("Invalid triangle: sum of two sides must be greater than the third")
        End If
        
        Dim s As Double = (a + b + c) / 2.0
        Return Math.Sqrt(s * (s - a) * (s - b) * (s - c))
    End Function
    
    Public Shared Function Distance2D(x1 As Double, y1 As Double, x2 As Double, y2 As Double) As Double
        Return Math.Sqrt(Math.Pow(x2 - x1, 2) + Math.Pow(y2 - y1, 2))
    End Function
    
    Public Shared Function Distance3D(x1 As Double, y1 As Double, z1 As Double, x2 As Double, y2 As Double, z2 As Double) As Double
        Return Math.Sqrt(Math.Pow(x2 - x1, 2) + Math.Pow(y2 - y1, 2) + Math.Pow(z2 - z1, 2))
    End Function
    
    ' Physics functions
    Public Shared Function KineticEnergy(mass As Double, velocity As Double) As Double
        If mass < 0 Then
            Throw New ArgumentException("Mass cannot be negative")
        End If
        Return 0.5 * mass * velocity * velocity
    End Function
    
    Public Shared Function PotentialEnergy(mass As Double, height As Double, Optional gravity As Double = 9.81) As Double
        If mass < 0 Then
            Throw New ArgumentException("Mass cannot be negative")
        End If
        Return mass * gravity * height
    End Function
    
    Public Shared Function Force(mass As Double, acceleration As Double) As Double
        If mass < 0 Then
            Throw New ArgumentException("Mass cannot be negative")
        End If
        Return mass * acceleration
    End Function
    
    Public Shared Function Momentum(mass As Double, velocity As Double) As Double
        If mass < 0 Then
            Throw New ArgumentException("Mass cannot be negative")
        End If
        Return mass * velocity
    End Function
    
    Public Shared Function ElectricPower(voltage As Double, current As Double) As Double
        Return voltage * current
    End Function
    
    Public Shared Function OhmsLaw(Optional voltage As Double? = Nothing, Optional current As Double? = Nothing, Optional resistance As Double? = Nothing) As Double
        Dim providedCount As Integer = 0
        If voltage.HasValue Then providedCount += 1
        If current.HasValue Then providedCount += 1
        If resistance.HasValue Then providedCount += 1
        
        If providedCount <> 2 Then
            Throw New ArgumentException("Exactly two parameters must be provided")
        End If
        
        If voltage.HasValue And current.HasValue Then
            ' Calculate resistance: R = V / I
            If current.Value = 0 Then
                Throw New DivideByZeroException("Current cannot be zero when calculating resistance")
            End If
            Return voltage.Value / current.Value
        ElseIf voltage.HasValue And resistance.HasValue Then
            ' Calculate current: I = V / R
            If resistance.Value = 0 Then
                Throw New DivideByZeroException("Resistance cannot be zero when calculating current")
            End If
            Return voltage.Value / resistance.Value
        ElseIf current.HasValue And resistance.HasValue Then
            ' Calculate voltage: V = I * R
            Return current.Value * resistance.Value
        Else
            Throw New ArgumentException("Invalid parameter combination")
        End If
    End Function
    
    ' Unit conversion functions
    Public Structure UnitConverter
        ' Temperature conversions
        Public Shared Function CelsiusToFahrenheit(celsius As Double) As Double
            Return (celsius * 9.0 / 5.0) + 32.0
        End Function
        
        Public Shared Function FahrenheitToCelsius(fahrenheit As Double) As Double
            Return (fahrenheit - 32.0) * 5.0 / 9.0
        End Function
        
        Public Shared Function CelsiusToKelvin(celsius As Double) As Double
            Return celsius + 273.15
        End Function
        
        Public Shared Function KelvinToCelsius(kelvin As Double) As Double
            If kelvin < 0 Then
                Throw New ArgumentException("Kelvin temperature cannot be negative")
            End If
            Return kelvin - 273.15
        End Function
        
        ' Length conversions
        Public Shared Function MetersToFeet(meters As Double) As Double
            Return meters * 3.28084
        End Function
        
        Public Shared Function FeetToMeters(feet As Double) As Double
            Return feet / 3.28084
        End Function
        
        Public Shared Function MetersToInches(meters As Double) As Double
            Return meters * 39.3701
        End Function
        
        Public Shared Function InchesToMeters(inches As Double) As Double
            Return inches / 39.3701
        End Function
        
        Public Shared Function KilometersToMiles(kilometers As Double) As Double
            Return kilometers * 0.621371
        End Function
        
        Public Shared Function MilesToKilometers(miles As Double) As Double
            Return miles / 0.621371
        End Function
        
        ' Weight conversions
        Public Shared Function KilogramsToPounds(kilograms As Double) As Double
            Return kilograms * 2.20462
        End Function
        
        Public Shared Function PoundsToKilograms(pounds As Double) As Double
            Return pounds / 2.20462
        End Function
        
        Public Shared Function GramsToOunces(grams As Double) As Double
            Return grams * 0.035274
        End Function
        
        Public Shared Function OuncesToGrams(ounces As Double) As Double
            Return ounces / 0.035274
        End Function
        
        ' Volume conversions
        Public Shared Function LitersToGallons(liters As Double) As Double
            Return liters * 0.264172
        End Function
        
        Public Shared Function GallonsToLiters(gallons As Double) As Double
            Return gallons / 0.264172
        End Function
        
        Public Shared Function LitersToQuarts(liters As Double) As Double
            Return liters * 1.05669
        End Function
        
        Public Shared Function QuartsToLiters(quarts As Double) As Double
            Return quarts / 1.05669
        End Function
    End Structure
    
    ' Number system conversions
    Public Shared Function DecimalToBinary(decimal_value As Long) As String
        If decimal_value = 0 Then
            Return "0"
        End If
        
        Dim binary As String = ""
        Dim absValue As Long = Math.Abs(decimal_value)
        
        While absValue > 0
            binary = (absValue Mod 2).ToString() & binary
            absValue \= 2
        End While
        
        If decimal_value < 0 Then
            binary = "-" & binary
        End If
        
        Return binary
    End Function
    
    Public Shared Function BinaryToDecimal(binary As String) As Long
        If String.IsNullOrEmpty(binary) Then
            Throw New ArgumentException("Binary string cannot be null or empty")
        End If
        
        Dim isNegative As Boolean = False
        If binary.StartsWith("-") Then
            isNegative = True
            binary = binary.Substring(1)
        End If
        
        If Not Regex.IsMatch(binary, "^[01]+$") Then
            Throw New ArgumentException("Invalid binary string")
        End If
        
        Dim result As Long = 0
        Dim power As Integer = 0
        
        For i As Integer = binary.Length - 1 To 0 Step -1
            If binary(i) = "1"c Then
                result += CLng(Math.Pow(2, power))
            End If
            power += 1
        Next
        
        If isNegative Then
            result = -result
        End If
        
        Return result
    End Function
    
    Public Shared Function DecimalToHex(decimal_value As Long) As String
        If decimal_value = 0 Then
            Return "0"
        End If
        
        Return Math.Abs(decimal_value).ToString("X") & If(decimal_value < 0, " (negative)", "")
    End Function
    
    Public Shared Function HexToDecimal(hex As String) As Long
        If String.IsNullOrEmpty(hex) Then
            Throw New ArgumentException("Hex string cannot be null or empty")
        End If
        
        ' Remove common hex prefixes
        hex = hex.Replace("0x", "").Replace("0X", "").Replace("#", "")
        
        Try
            Return Convert.ToInt64(hex, 16)
        Catch ex As Exception
            Throw New ArgumentException("Invalid hexadecimal string", ex)
        End Try
    End Function
    
    Public Shared Function DecimalToOctal(decimal_value As Long) As String
        If decimal_value = 0 Then
            Return "0"
        End If
        
        Return Convert.ToString(Math.Abs(decimal_value), 8) & If(decimal_value < 0, " (negative)", "")
    End Function
    
    Public Shared Function OctalToDecimal(octal As String) As Long
        If String.IsNullOrEmpty(octal) Then
            Throw New ArgumentException("Octal string cannot be null or empty")
        End If
        
        Try
            Return Convert.ToInt64(octal, 8)
        Catch ex As Exception
            Throw New ArgumentException("Invalid octal string", ex)
        End Try
    End Function
    
    ' Matrix operations (basic)
    Public Class Matrix
        Private data(,) As Double
        Public ReadOnly Property Rows As Integer
        Public ReadOnly Property Columns As Integer
        
        Public Sub New(rows As Integer, columns As Integer)
            If rows <= 0 Or columns <= 0 Then
                Throw New ArgumentException("Matrix dimensions must be positive")
            End If
            
            Me.Rows = rows
            Me.Columns = columns
            ReDim data(rows - 1, columns - 1)
        End Sub
        
        Public Property Item(row As Integer, column As Integer) As Double
            Get
                If row < 0 Or row >= Rows Or column < 0 Or column >= Columns Then
                    Throw New IndexOutOfRangeException("Matrix index out of range")
                End If
                Return data(row, column)
            End Get
            Set(value As Double)
                If row < 0 Or row >= Rows Or column < 0 Or column >= Columns Then
                    Throw New IndexOutOfRangeException("Matrix index out of range")
                End Set
                data(row, column) = value
            End Set
        End Property
        
        Public Shared Function Add(a As Matrix, b As Matrix) As Matrix
            If a.Rows <> b.Rows Or a.Columns <> b.Columns Then
                Throw New ArgumentException("Matrices must have the same dimensions for addition")
            End If
            
            Dim result As New Matrix(a.Rows, a.Columns)
            For i As Integer = 0 To a.Rows - 1
                For j As Integer = 0 To a.Columns - 1
                    result(i, j) = a(i, j) + b(i, j)
                Next
            Next
            
            Return result
        End Function
        
        Public Shared Function Multiply(a As Matrix, b As Matrix) As Matrix
            If a.Columns <> b.Rows Then
                Throw New ArgumentException("Matrix dimensions incompatible for multiplication")
            End If
            
            Dim result As New Matrix(a.Rows, b.Columns)
            For i As Integer = 0 To a.Rows - 1
                For j As Integer = 0 To b.Columns - 1
                    Dim sum As Double = 0
                    For k As Integer = 0 To a.Columns - 1
                        sum += a(i, k) * b(k, j)
                    Next
                    result(i, j) = sum
                Next
            Next
            
            Return result
        End Function
        
        Public Function Determinant() As Double
            If Rows <> Columns Then
                Throw New InvalidOperationException("Determinant can only be calculated for square matrices")
            End If
            
            Return CalculateDeterminant(data, Rows)
        End Function
        
        Private Shared Function CalculateDeterminant(matrix(,) As Double, size As Integer) As Double
            If size = 1 Then
                Return matrix(0, 0)
            End If
            
            If size = 2 Then
                Return matrix(0, 0) * matrix(1, 1) - matrix(0, 1) * matrix(1, 0)
            End If
            
            Dim det As Double = 0
            For col As Integer = 0 To size - 1
                Dim subMatrix(size - 2, size - 2) As Double
                
                For i As Integer = 1 To size - 1
                    Dim subcol As Integer = 0
                    For j As Integer = 0 To size - 1
                        If j <> col Then
                            subMatrix(i - 1, subcol) = matrix(i, j)
                            subcol += 1
                        End If
                    Next
                Next
                
                det += (If(col Mod 2 = 0, 1, -1)) * matrix(0, col) * CalculateDeterminant(subMatrix, size - 1)
            Next
            
            Return det
        End Function
        
        Public Overrides Function ToString() As String
            Dim result As New System.Text.StringBuilder()
            For i As Integer = 0 To Rows - 1
                result.Append("[")
                For j As Integer = 0 To Columns - 1
                    result.Append($"{data(i, j):F2}")
                    If j < Columns - 1 Then
                        result.Append(", ")
                    End If
                Next
                result.Append("]")
                If i < Rows - 1 Then
                    result.AppendLine()
                End If
            Next
            Return result.ToString()
        End Function
    End Class
    
    ' Miscellaneous utility functions
    Public Shared Function IsPerfectSquare(n As Long) As Boolean
        If n < 0 Then
            Return False
        End If
        
        Dim sqrt As Long = CLng(Math.Sqrt(n))
        Return sqrt * sqrt = n
    End Function
    
    Public Shared Function IsPerfectCube(n As Long) As Boolean
        Dim cubeRoot As Long = CLng(Math.Round(Math.Pow(Math.Abs(n), 1.0 / 3.0)))
        Return cubeRoot * cubeRoot * cubeRoot = n
    End Function
    
    Public Shared Function Fibonacci(n As Integer) As Long
        If n < 0 Then
            Throw New ArgumentException("Fibonacci number index cannot be negative")
        End If
        
        If n <= 1 Then
            Return n
        End If
        
        Dim a As Long = 0
        Dim b As Long = 1
        
        For i As Integer = 2 To n
            Dim temp As Long = a + b
            a = b
            b = temp
        Next
        
        Return b
    End Function
    
    Public Shared Function DigitalRoot(n As Long) As Integer
        n = Math.Abs(n)
        
        If n = 0 Then
            Return 0
        End If
        
        Return If(n Mod 9 = 0, 9, CInt(n Mod 9))
    End Function
    
    Public Shared Function ReverseNumber(n As Long) As Long
        Dim isNegative As Boolean = n < 0
        n = Math.Abs(n)
        
        Dim reversed As Long = 0
        While n > 0
            reversed = reversed * 10 + (n Mod 10)
            n \= 10
        End While
        
        Return If(isNegative, -reversed, reversed)
    End Function
    
    Public Shared Function IsPalindrome(n As Long) As Boolean
        Return n = ReverseNumber(n)
    End Function
End Class