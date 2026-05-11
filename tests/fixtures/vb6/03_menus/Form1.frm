VERSION 5.00
Begin VB.Form Form1 
   Caption         =   "Menu Test"
   ClientHeight    =   2000
   ClientWidth     =   3500
   Begin VB.Menu mnuFile 
      Caption         =   "&File"
      Begin VB.Menu mnuFileNew 
         Caption         =   "&New"
         Shortcut        =   ^N
      End
      Begin VB.Menu mnuFileOpen 
         Caption         =   "&Open..."
         Shortcut        =   ^O
      End
      Begin VB.Menu mnuFileSep 
         Caption         =   "-"
      End
      Begin VB.Menu mnuFileExit 
         Caption         =   "E&xit"
      End
   End
   Begin VB.Menu mnuEdit 
      Caption         =   "&Edit"
      Begin VB.Menu mnuEditCut 
         Caption         =   "Cu&t"
      End
      Begin VB.Menu mnuEditPaste 
         Caption         =   "&Paste"
         Enabled         =   0   'False
      End
   End
End
Attribute VB_Name = "Form1"
Option Explicit

Private Sub mnuFileNew_Click()
    MsgBox "New"
End Sub

Private Sub mnuFileExit_Click()
    End
End Sub
