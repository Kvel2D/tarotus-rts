
@:publicFields
class Tiles {
    static inline var tileset_width = 10;
    static inline function tilenum(x: Int, y: Int): Int {
        return y * tileset_width + x;
    }

    static inline var Temp = tilenum(0, 1); // bugged tile

    static inline var Player = tilenum(0, 0);
    static inline var Wall = tilenum(1, 0);
    static inline var Space = tilenum(2, 0);
    static inline var RedDude = tilenum(3, 0);
    static inline var Box = tilenum(4, 0);
    static inline var Ball = tilenum(5, 0);
    static inline var Stick = tilenum(6, 0);
    static inline var Chest = tilenum(7, 0);
    static inline var Head = tilenum(5, 1);
    static inline var Legs = tilenum(6, 1);
    static inline var GreenPotion = tilenum(8, 0);
    static inline var Sword = tilenum(9, 0);
    static inline var Spear = tilenum(9, 1);
    static inline var Bow = tilenum(8, 1);
    static inline var Fist = tilenum(7, 1);
    static inline var Arrows = tilenum(4, 1);
    static inline var Trash = tilenum(1, 1);
    static inline var Bomb = tilenum(3, 1);
    static inline var Heart = tilenum(2, 1);
    static inline var Money = tilenum(0, 2);
    static inline var Shooter = tilenum(1, 2);
    static inline var Stander = tilenum(2, 2);
    static inline var Ghost = tilenum(3, 2);
    static inline var RedPotion = tilenum(4, 2);
    static inline var BluePotion = tilenum(5, 2);
    static inline var Mace = tilenum(6, 2);

    static inline var MeleePlayer = tilenum(0, 3);
    static inline var MeleeEnemy = tilenum(1, 3);
    static inline var HeroPlayer = tilenum(0, 4);
    static inline var HeroEnemy = tilenum(1, 4);
    static inline var RangedPlayer = tilenum(0, 5);
    static inline var RangedEnemy = tilenum(1, 5);
}