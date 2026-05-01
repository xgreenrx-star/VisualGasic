if __name__ == '__main__':
    with open('output.txt', 'w') as file:
        file.write("Line 1\n")
        file.write("Line 2\n")
        file.write("Line 3\n")

    with open('output.txt', 'r') as file:
        lines = file.readlines()
        for i, line in enumerate(lines, start=1):
            print(f"{i}: {line.strip()}")