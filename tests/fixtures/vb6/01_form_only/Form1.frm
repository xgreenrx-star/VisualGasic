VERSION 5.00
Begin VB.Form Form1 
   Caption         =   "Smoke Test"
   ClientHeight    =   3000
   ClientLeft      =   60
   ClientTop       =   345
   ClientWidth     =   4500
   ScaleHeight     =   3000
   ScaleWidth      =   4500
   StartUpPosition =   3  'Windows Default
   Begin VB.CommandButton cmdHello 
      Caption         =   "Say Hello"
      Height          =   495
      Left            =   1200
      TabIndex        =   1
      Top             =   1200
      Width           =   2000
   End
   Begin VB.Label lblOutput 
      Caption         =   "Ready."
      Height          =   315
      Left            =   240
      TabIndex        =   0
      Top             =   240
      Width           =   4000
   End
End
Attribute VB_Name = "Form1"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Explicit

Private Sub cmdHello_Click()
    lblOutput.Caption = "Hello, World!"
End Sub
