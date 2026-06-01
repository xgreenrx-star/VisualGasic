VERSION 5.00
Begin VB.Form Form1 
   Caption         =   "Control Array"
   ClientHeight    =   2000
   ClientWidth     =   3000
   Begin VB.CommandButton Btn 
      Caption         =   "0"
      Index           =   0
      Left            =   200
      Top             =   200
      Width           =   500
      Height          =   500
   End
   Begin VB.CommandButton Btn 
      Caption         =   "1"
      Index           =   1
      Left            =   800
      Top             =   200
      Width           =   500
      Height          =   500
   End
   Begin VB.CommandButton Btn 
      Caption         =   "2"
      Index           =   2
      Left            =   1400
      Top             =   200
      Width           =   500
      Height          =   500
   End
   Begin VB.Label lblOut 
      Caption         =   "?"
      Left            =   200
      Top             =   1000
      Width           =   2600
      Height          =   400
   End
End
Attribute VB_Name = "Form1"
Option Explicit

Private Sub Btn_Click(Index As Integer)
    lblOut.Caption = "You clicked " & Btn(Index).Caption
End Sub
