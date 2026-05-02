extends SceneTree

func _init():
    var text = "the quick brown fox"
    var words = text.split(" ")
    print(words.size())
    for word in words:
        print(word)
    quit()