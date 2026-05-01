extends SceneTree

func _init():
    var sentence = "the quick brown fox jumps over the lazy dog the"
    var words = sentence.split(" ")
    var word_count = {}
    
    for word in words:
        if word != "":
            if word in word_count:
                word_count[word] += 1
            else:
                word_count[word] = 1
    
    for word, count in word_count:
        print(word + ": " + str(count))
    
    quit()