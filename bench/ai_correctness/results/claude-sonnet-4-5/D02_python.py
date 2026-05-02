if __name__ == '__main__':
    sentence = "the quick brown fox jumps over the lazy dog the"
    words = sentence.split()
    word_count = {}
    
    for word in words:
        if word in word_count:
            word_count[word] += 1
        else:
            word_count[word] = 1
    
    for word, count in word_count.items():
        print(f"{word}: {count}")