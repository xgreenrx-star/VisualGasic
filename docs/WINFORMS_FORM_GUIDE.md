# WinForms-Style Forms in Visual Gasic

## Overview

Visual Gasic now provides a proper WinForms-compatible Form implementation that follows the same patterns and lifecycle as Windows Forms.

## Form Base Class Architecture

### Key Features

1. **WinForms-Compatible Properties**
   - `Text` - Form title
   - `FormBorderStyle` - Border appearance
   - `WindowState` - Normal/Minimized/Maximized
   - `StartPosition` - Initial positioning
   - `ControlBox`, `MinimizeBox`, `MaximizeBox` - Window controls
   - `AcceptButton`, `CancelButton` - Default buttons

2. **Form Lifecycle Events**
   - `Form_Load()` - Called once before form is displayed
   - `Form_Shown()` - Called after form is first made visible
   - `Form_Closing(evt)` - Called when form is about to close (cancelable)
   - `Form_Closed()` - Called after form has closed
   - `Form_Resize()` - Called when form size changes

3. **Modal Dialog Support**
   - `ShowDialog()` - Show as modal dialog
   - `DialogResult` - Standard return values (OK, Cancel, Yes, No, etc.)

## Creating a Form in Visual Gasic

### Basic Form Structure

```vb
' MyForm.vg
Option Explicit

' Form initialization (like WinForms Designer-generated code)
Sub InitializeComponent()
    ' Set form properties
    Me.Text = "My Application"
    Me.FormBorderStyle = FormBorderStyleEnum.Sizable
    Me.StartPosition = FormStartPositionEnum.CenterScreen
    Me.Size = Vector2(800, 600)
    
    ' Create controls
    Dim btnOK As Button
    Set btnOK = Button.new()
    btnOK.Text = "OK"
    btnOK.Position = Vector2(650, 520)
    btnOK.Size = Vector2(120, 40)
    Me.add_child(btnOK)
    
    ' Wire up events (use Callable pattern)
    btnOK.pressed.connect(Callable(Me, "btnOK_Click"))
End Sub

' Form Load event - called before form is shown
Sub Form_Load()
    Print "Form is loading..."
    ' Initialize data, load settings, etc.
End Sub

' Form Shown event - called after form becomes visible
Sub Form_Shown()
    Print "Form is now visible"
End Sub

' Button click event handler
Sub btnOK_Click()
    Print "OK clicked"
    Me.Close()
End Sub

' Form Closing event - can cancel close
Sub Form_Closing(evt)
    ' Ask for confirmation
    ' evt.Cancel = True  ' Uncomment to prevent closing
End Sub

' Form Closed event - cleanup
Sub Form_Closed()
    Print "Form closed"
End Sub

' Form Resize event
Sub Form_Resize()
    Print "Form resized to: " & Me.Size
End Sub
```

## FormBorderStyle Options

```vb
Enum FormBorderStyleEnum
    None = 0              ' No border, no title bar
    FixedSingle = 1       ' Fixed border, not resizable
    Fixed3D = 2           ' 3D border, not resizable
    FixedDialog = 3       ' Dialog-style border, not resizable
    Sizable = 4           ' Standard resizable window (default)
    FixedToolWindow = 5   ' Tool window, not resizable
    SizableToolWindow = 6 ' Tool window, resizable
End Enum
```

## StartPosition Options

```vb
Enum FormStartPositionEnum
    Manual = 0                    ' Position set by user
    CenterScreen = 1              ' Centered on screen
    WindowsDefaultLocation = 2    ' Default OS position
    WindowsDefaultBounds = 3      ' Default position and size
    CenterParent = 4              ' Centered on parent form
End Enum
```

## WindowState

```vb
Enum FormWindowStateEnum
    Normal = 0      ' Normal window
    Minimized = 1   ' Minimized to taskbar
    Maximized = 2   ' Maximized to fill screen
End Enum
```

## Modal Dialogs

```vb
' ShowDialog example
Sub ShowSettingsDialog()
    Dim dlg As SettingsDialog
    Set dlg = SettingsDialog.new()
    
    Dim result As Integer
    result = dlg.ShowDialog(Me)
    
    If result = DialogResultEnum.OK Then
        ' User clicked OK
        ' Apply settings
    ElseIf result = DialogResultEnum.Cancel Then
        ' User cancelled
    End If
End Sub

' In the dialog form:
Sub btnOK_Click()
    Me._dialog_result = DialogResultEnum.OK
    Me.Close()
End Sub

Sub btnCancel_Click()
    Me._dialog_result = DialogResultEnum.Cancel
    Me.Close()
End Sub
```

## Standard Methods

- `Show()` - Show the form (non-modal)
- `ShowDialog(parent)` - Show as modal dialog
- `Hide()` - Hide the form
- `Close()` - Close the form
- `Activate()` - Bring form to front
- `CenterToScreen()` - Center on screen
- `CenterToParent()` - Center on parent

## Comparison with WinForms

| WinForms | Visual Gasic | Notes |
|----------|--------------|-------|
| `Form.Text` | `Me.Text` | Form title |
| `Form.Size` | `Me.Size` | Vector2 instead of Size struct |
| `Form.Location` | `Me.Position` | Vector2 for consistency with Godot |
| `Form.Load +=` | `Sub Form_Load()` | Event handler method |
| `Form.FormClosing +=` | `Sub Form_Closing(evt)` | Can cancel via evt.Cancel |
| `Form.Controls.Add()` | `Me.add_child()` | Godot scene tree |
| `this.ShowDialog()` | `Me.ShowDialog()` | Modal dialog |
| `this.Close()` | `Me.Close()` | Close form |

## Best Practices

1. **Always call InitializeComponent()** in your form constructor or Form_Load
2. **Use Form_Load** for initialization logic (like WinForms)
3. **Use Form_Shown** for actions that need the form to be visible
4. **Handle Form_Closing** to validate/save data before closing
5. **Set StartPosition** appropriately for your use case
6. **Use DialogResult** for modal forms to communicate outcome
7. **Don't forget to wire up event handlers** using Callable pattern

## Example: Complete Login Form

```vb
' LoginForm.vg
Option Explicit

Dim txtUsername As LineEdit
Dim txtPassword As LineEdit
Dim btnLogin As Button
Dim btnCancel As Button
Dim lblMessage As Label

Sub InitializeComponent()
    Me.Text = "Login"
    Me.FormBorderStyle = FormBorderStyleEnum.FixedDialog
    Me.StartPosition = FormStartPositionEnum.CenterScreen
    Me.Size = Vector2(400, 250)
    Me.MinimizeBox = False
    Me.MaximizeBox = False
    
    ' Username label and textbox
    Dim lblUser As Label
    Set lblUser = Label.new()
    lblUser.Text = "Username:"
    lblUser.Position = Vector2(30, 30)
    Me.add_child(lblUser)
    
    Set txtUsername = LineEdit.new()
    txtUsername.Position = Vector2(120, 25)
    txtUsername.Size = Vector2(250, 30)
    Me.add_child(txtUsername)
    
    ' Password label and textbox
    Dim lblPass As Label
    Set lblPass = Label.new()
    lblPass.Text = "Password:"
    lblPass.Position = Vector2(30, 80)
    Me.add_child(lblPass)
    
    Set txtPassword = LineEdit.new()
    txtPassword.Position = Vector2(120, 75)
    txtPassword.Size = Vector2(250, 30)
    txtPassword.secret = True
    Me.add_child(txtPassword)
    
    ' Message label
    Set lblMessage = Label.new()
    lblMessage.Position = Vector2(30, 120)
    lblMessage.Size = Vector2(340, 30)
    lblMessage.visible = False
    Me.add_child(lblMessage)
    
    ' Buttons
    Set btnLogin = Button.new()
    btnLogin.Text = "Login"
    btnLogin.Position = Vector2(150, 170)
    btnLogin.Size = Vector2(100, 40)
    btnLogin.pressed.connect(Callable(Me, "btnLogin_Click"))
    Me.add_child(btnLogin)
    Me.AcceptButton = btnLogin
    
    Set btnCancel = Button.new()
    btnCancel.Text = "Cancel"
    btnCancel.Position = Vector2(270, 170)
    btnCancel.Size = Vector2(100, 40)
    btnCancel.pressed.connect(Callable(Me, "btnCancel_Click"))
    Me.add_child(btnCancel)
    Me.CancelButton = btnCancel
End Sub

Sub Form_Load()
    txtUsername.grab_focus()
End Sub

Sub btnLogin_Click()
    If txtUsername.Text = "" Or txtPassword.Text = "" Then
        lblMessage.Text = "Please enter username and password"
        lblMessage.add_theme_color_override("font_color", Color.RED)
        lblMessage.visible = True
        Exit Sub
    End If
    
    ' Validate credentials
    If txtUsername.Text = "admin" And txtPassword.Text = "password" Then
        Me._dialog_result = DialogResultEnum.OK
        Me.Close()
    Else
        lblMessage.Text = "Invalid credentials"
        lblMessage.add_theme_color_override("font_color", Color.RED)
        lblMessage.visible = True
        txtPassword.Text = ""
        txtPassword.grab_focus()
    End If
End Sub

Sub btnCancel_Click()
    Me._dialog_result = DialogResultEnum.Cancel
    Me.Close()
End Sub
```

## Migration from Old System

The old VGForm.vg approach had several issues:
- No proper lifecycle events
- Required manual positioning and chrome setup
- Didn't follow WinForms patterns
- Limited designer support

The new system provides:
- **Proper WinForms lifecycle** - Form_Load, Form_Shown, etc.
- **Automatic positioning** - StartPosition property
- **Standard window chrome** - Godot's native window decorations
- **Modal dialog support** - ShowDialog() method
- **Event-driven architecture** - Standard event handlers
- **Designer-friendly** - InitializeComponent() pattern

## Future Enhancements

- Visual Designer integration
- Control anchoring and docking
- MDI (Multiple Document Interface) support
- Form inheritance in designer
- Component model integration
- Property grid support
