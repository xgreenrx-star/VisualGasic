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


