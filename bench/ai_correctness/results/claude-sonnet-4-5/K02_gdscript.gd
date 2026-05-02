extends SceneTree

class Enemy:
    var name: String
    var health: int
    
    func _init(enemy_name: String, enemy_health: int):
        name = enemy_name
        health = enemy_health
    
    func TakeDamage(amount: int):
        health -= amount
        if health < 0:
            health = 0

func _init():
    var enemy = Enemy.new("Goblin", 100)
    
    enemy.TakeDamage(30)
    print(enemy.health)
    
    enemy.TakeDamage(80)
    print(enemy.health)
    
    quit()