class Enemy {
    name: string;
    health: number;

    constructor(name: string, health: number) {
        this.name = name;
        this.health = health;
    }

    TakeDamage(amount: number): void {
        this.health = Math.max(0, this.health - amount);
    }
}

const enemy = new Enemy("Goblin", 100);
enemy.TakeDamage(30);
console.log(enemy.health);
enemy.TakeDamage(80);
console.log(enemy.health);