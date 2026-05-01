class Enemy:
    def __init__(self, name, health):
        self.name = name
        self.health = health

    def TakeDamage(self, amount):
        self.health -= amount
        if self.health < 0:
            self.health = 0

if __name__ == '__main__':
    enemy = Enemy("Goblin", 100)
    enemy.TakeDamage(30)
    print(enemy.health)  # Output: 70
    enemy.TakeDamage(80)
    print(enemy.health)  # Output: 0