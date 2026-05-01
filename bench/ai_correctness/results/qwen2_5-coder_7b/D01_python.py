if __name__ == '__main__':
    prices = {"apple": 0.5, "bread": 2.25, "cheese": 5.99}
    total = sum(prices.values())
    for item, price in prices.items():
        print(f"{item}: {price}")
    print(f"Total: {total}")