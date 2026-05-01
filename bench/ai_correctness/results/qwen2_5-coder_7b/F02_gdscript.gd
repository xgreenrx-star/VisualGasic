extends SceneTree

func _init():
    var csv = "name,age\nAlice,30\nBob,25\nCarol,42"
    var lines = csv.split("\n")
    var header = lines[0]
    var data_lines = lines[1:]
    var total_age = 0
    var count = 0
    
    for line in data_lines:
        var parts = line.split(",")
        if parts.size() == 2:
            var age = int(parts[1])
            total_age += age
            count += 1
    
    if count > 0:
        var average_age = total_age / count
        print(average_age)
    else:
        print("No data to calculate average.")
    
    quit()