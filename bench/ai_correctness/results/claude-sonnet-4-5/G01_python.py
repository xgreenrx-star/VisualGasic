def on_button_click():
    current_text = lblStatus.cget("text")
    if current_text:
        lblStatus.config(text=current_text + "\nButton clicked")
    else:
        lblStatus.config(text="Button clicked")

if __name__ == '__main__':
    print("def on_button_click():")
    print("    current_text = lblStatus.cget(\"text\")")
    print("    if current_text:")
    print("        lblStatus.config(text=current_text + \"\\nButton clicked\")")
    print("    else:")
    print("        lblStatus.config(text=\"Button clicked\")")