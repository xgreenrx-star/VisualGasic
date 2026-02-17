### 4. Persistence (Settings)
You can save and load simple settings (User Preferences) which persist between runs.

```basic
Sub cmdSave_Click()
    SaveSetting "MyApp", "User", "Name", txtName.text
End Sub

Sub Form_Load()
    txtName.text = GetSetting("MyApp", "User", "Name", "Guest")
End Sub
```

### 5. Simple Database (JSON)
You can load JSON files as data structures.

```basic
Sub LoadData()
    ' Loads user://gamedata.json
    dim db
    db = OpenDatabase("gamedata.json")
    
    If db Then
        Print "Level: " & db["Level"]
    End If
End Sub
```

### 6. File System Controls
If you add an `ItemList` control and name it `Dir1`, it will automatically populate with folders.
If you name it `File1`, it will populate with files.
