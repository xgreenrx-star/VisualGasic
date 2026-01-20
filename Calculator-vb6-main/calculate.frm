VERSION 5.00
Begin VB.Form Calculate 
   BackColor       =   &H8000000B&
   BorderStyle     =   1  'Fixed Single
   Caption         =   "calculator"
   ClientHeight    =   3570
   ClientLeft      =   4620
   ClientTop       =   3720
   ClientWidth     =   3030
   ControlBox      =   0   'False
   LinkTopic       =   "Form1"
   MaxButton       =   0   'False
   MinButton       =   0   'False
   ScaleHeight     =   3570
   ScaleWidth      =   3030
   Begin VB.CommandButton Num 
      Caption         =   "."
      BeginProperty Font 
         Name            =   "MS Sans Serif"
         Size            =   13.5
         Charset         =   178
         Weight          =   400
         Underline       =   0   'False
         Italic          =   0   'False
         Strikethrough   =   0   'False
      EndProperty
      Height          =   495
      Index           =   10
      Left            =   840
      TabIndex        =   19
      Top             =   2520
      Width           =   495
   End
   Begin VB.CommandButton Pow 
      Caption         =   "^"
      BeginProperty Font 
         Name            =   "MS Sans Serif"
         Size            =   12
         Charset         =   178
         Weight          =   400
         Underline       =   0   'False
         Italic          =   0   'False
         Strikethrough   =   0   'False
      EndProperty
      Height          =   375
      Left            =   2280
      TabIndex        =   18
      Top             =   2640
      Width           =   615
   End
   Begin VB.CommandButton Mod 
      Caption         =   "%"
      BeginProperty Font 
         Name            =   "MS Sans Serif"
         Size            =   12
         Charset         =   178
         Weight          =   400
         Underline       =   0   'False
         Italic          =   0   'False
         Strikethrough   =   0   'False
      EndProperty
      Height          =   375
      Left            =   2280
      TabIndex        =   17
      Top             =   3120
      Width           =   615
   End
   Begin VB.CommandButton Exit 
      BackColor       =   &H8000000D&
      Caption         =   "Exit"
      Height          =   375
      Left            =   120
      MaskColor       =   &H000000FF&
      TabIndex        =   16
      Top             =   3120
      Width           =   735
   End
   Begin VB.CommandButton Result 
      Caption         =   "="
      BeginProperty Font 
         Name            =   "MS Sans Serif"
         Size            =   13.5
         Charset         =   178
         Weight          =   400
         Underline       =   0   'False
         Italic          =   0   'False
         Strikethrough   =   0   'False
      EndProperty
      Height          =   375
      Left            =   1080
      TabIndex        =   15
      Top             =   3120
      Width           =   1095
   End
   Begin VB.CommandButton Div 
      Caption         =   "/"
      BeginProperty Font 
         Name            =   "MS Sans Serif"
         Size            =   12
         Charset         =   178
         Weight          =   400
         Underline       =   0   'False
         Italic          =   0   'False
         Strikethrough   =   0   'False
      EndProperty
      Height          =   375
      Left            =   2280
      TabIndex        =   14
      Top             =   2160
      Width           =   615
   End
   Begin VB.CommandButton Sub 
      Caption         =   "-"
      BeginProperty Font 
         Name            =   "MS Sans Serif"
         Size            =   12
         Charset         =   178
         Weight          =   400
         Underline       =   0   'False
         Italic          =   0   'False
         Strikethrough   =   0   'False
      EndProperty
      Height          =   375
      Left            =   2280
      TabIndex        =   13
      Top             =   1200
      Width           =   615
   End
   Begin VB.CommandButton Add 
      BackColor       =   &H8000000E&
      Caption         =   "+"
      BeginProperty Font 
         Name            =   "MS Sans Serif"
         Size            =   12
         Charset         =   178
         Weight          =   400
         Underline       =   0   'False
         Italic          =   0   'False
         Strikethrough   =   0   'False
      EndProperty
      Height          =   375
      Left            =   2280
      TabIndex        =   12
      Top             =   720
      Width           =   615
   End
   Begin VB.CommandButton Mul 
      Caption         =   "*"
      BeginProperty Font 
         Name            =   "MS Sans Serif"
         Size            =   12
         Charset         =   178
         Weight          =   400
         Underline       =   0   'False
         Italic          =   0   'False
         Strikethrough   =   0   'False
      EndProperty
      Height          =   375
      Left            =   2280
      TabIndex        =   11
      Top             =   1680
      Width           =   615
   End
   Begin VB.CommandButton Num 
      Caption         =   "0"
      Height          =   495
      Index           =   9
      Left            =   120
      TabIndex        =   10
      Top             =   2520
      Width           =   495
   End
   Begin VB.CommandButton Num 
      Caption         =   "9"
      Height          =   495
      Index           =   8
      Left            =   1560
      TabIndex        =   9
      Top             =   1920
      Width           =   495
   End
   Begin VB.CommandButton Num 
      Caption         =   "8"
      Height          =   495
      Index           =   7
      Left            =   840
      TabIndex        =   8
      Top             =   1920
      Width           =   495
   End
   Begin VB.CommandButton Num 
      Caption         =   "7"
      Height          =   495
      Index           =   6
      Left            =   120
      TabIndex        =   7
      Top             =   1920
      Width           =   495
   End
   Begin VB.CommandButton Num 
      Caption         =   "6"
      Height          =   495
      Index           =   5
      Left            =   1560
      TabIndex        =   6
      Top             =   1320
      Width           =   495
   End
   Begin VB.CommandButton Num 
      Caption         =   "5"
      Height          =   495
      Index           =   4
      Left            =   840
      TabIndex        =   5
      Top             =   1320
      Width           =   495
   End
   Begin VB.CommandButton Num 
      Caption         =   "4"
      Height          =   495
      Index           =   3
      Left            =   120
      TabIndex        =   4
      Top             =   1320
      Width           =   495
   End
   Begin VB.CommandButton Num 
      Caption         =   "3"
      Height          =   495
      Index           =   2
      Left            =   1560
      TabIndex        =   3
      Top             =   720
      Width           =   495
   End
   Begin VB.CommandButton Num 
      Caption         =   "2"
      Height          =   495
      Index           =   1
      Left            =   840
      TabIndex        =   2
      Top             =   720
      Width           =   495
   End
   Begin VB.CommandButton Num 
      Caption         =   "1"
      Height          =   495
      Index           =   0
      Left            =   120
      TabIndex        =   1
      Top             =   720
      Width           =   495
   End
   Begin VB.TextBox TextBox 
      BackColor       =   &H8000000E&
      Height          =   375
      Left            =   120
      TabIndex        =   0
      Top             =   240
      Width           =   2775
   End
End
Attribute VB_Name = "Calculate"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False

Dim Number, Operator As Integer


Private Sub Num_Click(Index As Integer) ' Numbers
TextBox.Text = TextBox.Text & Num(Index).Caption
End Sub

Private Sub Mul_Click() ' Multiplication
Number = Val(TextBox.Text)
TextBox.Text = ""
Operator = 1
End Sub
Private Sub Add_Click() ' Addition
Number = Val(TextBox.Text)
TextBox.Text = ""
Operator = 2
End Sub

Private Sub Sub_Click() ' Subtraction
Number = Val(TextBox.Text)
TextBox.Text = ""
Operator = 3
End Sub

Private Sub Div_Click() ' Division
Number = Val(TextBox.Text)
TextBox.Text = ""
Operator = 4
End Sub

Private Sub Pow_Click() ' Power
Number = Val(TextBox.Text)
TextBox.Text = ""
Operator = 5
End Sub

Private Sub Mod_Click() ' Modulus
Number = Val(TextBox.Text)
TextBox.Text = ""
Operator = 6
End Sub

Private Sub Result_Click() ' Result
If Operator = 1 Then TextBox.Text = Number * Val(TextBox.Text) ' Mul
If Operator = 2 Then TextBox.Text = Number + Val(TextBox.Text) ' Add
If Operator = 3 Then TextBox.Text = Number - Val(TextBox.Text) ' Sub
If Operator = 4 Then TextBox.Text = Number / Val(TextBox.Text) ' Div
If Operator = 5 Then TextBox.Text = Number ^ Val(TextBox.Text) ' Pow
If Operator = 6 Then TextBox.Text = Number Mod Val(TextBox.Text) ' Mod
End Sub

Private Sub Exit_Click() ' Exit
MsgBox "Baye"
End
End Sub

