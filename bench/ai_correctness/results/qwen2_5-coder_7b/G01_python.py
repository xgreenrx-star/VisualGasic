def btnClickHandler(event):
    lblStatus.config(text=lblStatus.cget('text') + "\nNew line added")

if __name__ == '__main__':
    # Simulate button click event
    btnClickHandler(None)
    print("Label text after click:", lblStatus.cget('text'))