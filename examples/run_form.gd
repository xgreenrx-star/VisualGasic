extends SceneTree

func _init():
    var form = ClassDB.instantiate("GasicForm")
    if form == null:
        print("Error: GasicForm class not found.")
        quit()
        return

    form.name = "MyForm"
    
    var btn = Button.new()
    btn.name = "Button1"
    form.add_child(btn)
    
    var txt = LineEdit.new()
    txt.name = "Text1"
    form.add_child(txt)
    
    var script = load("res://test_form.bas")
    if script == null:
        print("Error: Could not load script")
        quit()
        return
        
    form.set_script(script)
    
    # Adding to root to trigger _ready.
    # SceneTree.root is a Window.
    root.add_child(form)
    
    # _ready should have run now (or deferred?)
    # Call deferred to ensure _ready runs.
    # Actually add_child triggers _ready immediately if in tree.
    
    print("Simulating Click on Button1...")
    btn.pressed.emit()
    
    print("Simulating Text Change on Text1...")
    txt.text_changed.emit("Hello World")
    
    # Wait a bit or quit
    quit()
