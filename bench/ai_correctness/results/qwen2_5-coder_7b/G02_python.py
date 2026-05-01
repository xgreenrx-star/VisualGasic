import time
from threading import Timer

counter = 0

def update_label():
    global counter
    counter += 1
    print(f"Time: {counter} seconds")
    Timer(1, update_label).start()

if __name__ == '__main__':
    update_label()