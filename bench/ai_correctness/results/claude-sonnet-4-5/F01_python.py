if __name__ == '__main__':
    with open('output.txt', 'w') as f:
        f.write('Line 1\n')
        f.write('Line 2\n')
        f.write('Line 3\n')
    
    with open('output.txt', 'r') as f:
        for line_number, line in enumerate(f, start=1):
            print(f'{line_number}: {line.rstrip()}')