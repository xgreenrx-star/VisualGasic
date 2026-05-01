if __name__ == '__main__':
    sentence = "the quick brown fox jumps over the lazy dog the"
    word_counts = {}
    for word in sentence.split():
        if word in word_counts:
            word_counts[word] += 1
        else:
            word_counts[word] = 1
    for word, count in word_counts.items():
        print(f"{word}: {count}")