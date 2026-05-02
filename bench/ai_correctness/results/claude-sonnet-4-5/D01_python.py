if __name__ == '__main__':
    prices = {"apple": 0.5, "bread": 2.25, "cheese": 5.99}
    
    for key, value in prices.items():
        print(f"{key}: {value}")
    
    total = sum(prices.values())
    print(f"Total: {total}")