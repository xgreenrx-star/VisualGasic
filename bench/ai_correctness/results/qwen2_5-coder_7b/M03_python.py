import math

def euclidean_distance(x1, y1, x2, y2):
    return math.sqrt((x2 - x1)**2 + (y2 - y1)**2)

if __name__ == '__main__':
    distance = euclidean_distance(0, 0, 3, 4)
    print(distance)