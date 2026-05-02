import csv
from io import StringIO

if __name__ == '__main__':
    csv_string = "name,age\nAlice,30\nBob,25\nCarol,42"
    
    reader = csv.DictReader(StringIO(csv_string))
    
    ages = []
    for row in reader:
        ages.append(int(row['age']))
    
    average_age = sum(ages) / len(ages)
    
    print(average_age)