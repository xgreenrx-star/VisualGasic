extends SceneTree

func _init():
    var sentence = "the quick brown fox"
    var words = sentence.split(" ")
    print("Number of words: ", words.size())
    for word in words:
        print(word)
    quit()