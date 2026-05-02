extends SceneTree

func _init():
    var csv_string = "name,age\nAlice,30\nBob,25\nCarol,42"
    var lines = csv_string.split("\n")
    
    var total_age = 0
    var count = 0
    
    for i in range(1, lines.size()):
        var fields = lines[i].split(",")
        if fields.size() >= 2:
            total_age += int(fields[1])
            count += 1
    
    var average_age = float(total_age) / float(count)
    print(average_age)
    
    quit()