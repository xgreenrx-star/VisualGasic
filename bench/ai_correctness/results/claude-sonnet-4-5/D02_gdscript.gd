extends SceneTree

func _init():
    var sentence = "the quick brown fox jumps over the lazy dog the"
    var words = sentence.split(" ")
    var word_count = {}
    
    for word in words:
        if word != "":
            if word_count.has(word):
                word_count[word] += 1
            else:
                word_count[word] = 1
    
    for word in word_count.keys():
        print(word + ": " + str(word_count[word]))
    
    quit()