class Enemy {
    name: string;
    health: number;

    constructor(name: string, health: number) {
        this.name = name;
        this.health = health;
    }

    TakeDamage(amount: number): void {
        this.health -= amount;
        if (this.health < 0) {
            this.health = 0;
        }
    }
}

const enemy = new Enemy("Goblin", 150);
console.log(`Initial Health: ${enemy.health}`);
enemy.TakeDamage(30);
console.log(`Health after 30 damage: ${enemy.health}`);
enemy.TakeDamage(80);
console.log(`Health after 80 damage: ${enemy.health}`);