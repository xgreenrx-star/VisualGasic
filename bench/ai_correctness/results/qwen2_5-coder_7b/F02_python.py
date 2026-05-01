import csv

data = "name,age\nAlice,30\nBob,25\nCarol,42"

if __name__ == '__main__':
    ages = [int(row[1]) for row in csv.reader(data.splitlines()) if row[0] != 'name']
    average_age = sum(ages) / len(ages)
    print(average_age)