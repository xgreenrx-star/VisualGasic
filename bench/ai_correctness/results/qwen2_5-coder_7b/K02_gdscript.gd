extends SceneTree

func _init():
    var enemy = Enemy.new("Goblin", 100)
    enemy.TakeDamage(30)
    print(enemy.health)
    enemy.TakeDamage(80)
    print(enemy.health)
    quit()

class Enemy:
    var name: String
    var health: int

    func __init__(name: String, health: int):
        self.name = name
        self.health = health

    func TakeDamage(amount: int):
        self.health -= amount
        if self.health < 0:
            self.health = 0