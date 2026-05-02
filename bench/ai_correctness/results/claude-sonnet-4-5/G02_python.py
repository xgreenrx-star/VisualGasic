import tkinter as tk

counter = 0

def update_counter():
    global counter
    counter += 1
    lblTime.config(text=str(counter))
    root.after(1000, update_counter)

if __name__ == '__main__':
    root = tk.Tk()
    root.title("Counter")
    
    lblTime = tk.Label(root, text="0", font=("Arial", 24))
    lblTime.pack(padx=50, pady=50)
    
    update_counter()
    
    root.mainloop()