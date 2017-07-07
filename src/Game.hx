import haxegon.*;
import haxe.ds.ObjectMap;
import haxe.ds.Vector;
import Entity;

using haxegon.MathExtensions;
using Lambda;

enum GameState {
    GameState_PlayerTurn;
    GameState_PlayerVisual;
    GameState_PlayerTurnResult;
    GameState_EnemyVisual;
    GameState_EnemyTurnResult;
    GameState_ItemDrag;
    GameState_CardFlip;
    GameState_Shop;
}

enum CardType {
    CardType_None;
    CardType_Dude;
    CardType_Treasure;
    CardType_Weapon;
    CardType_Arcana;
    CardType_Shop;
}

enum ArcanaType {
    ArcanaType_None;
    ArcanaType_Fool;
    ArcanaType_Magician;
    ArcanaType_Priestess;
    ArcanaType_Empress;
    ArcanaType_Emperor;
    ArcanaType_Hierophant;
    ArcanaType_Lovers;
    ArcanaType_Chariot;
    ArcanaType_Strength;
    ArcanaType_Hermit;
    ArcanaType_Fortune;
    ArcanaType_Justice;
    ArcanaType_HangedMan;
    ArcanaType_Death;
    ArcanaType_Temperance;
    ArcanaType_Devil;
    ArcanaType_Tower;
    ArcanaType_Star;
    ArcanaType_Moon;
    ArcanaType_Sun;
    ArcanaType_Judgement;
}

@:publicFields
class Card {
    var type = CardType_None;
    var arcana = ArcanaType_None;
    var covered = false;
    var visited = false;
    var arcana_activated = false;
    var turn_age = 0;
    var update_age = 0;
    var x = 0;
    var y = 0;
    var level = 0;
    var completed = true;
    var my_dudes = new Array<Dude>();
    var just_updated_timer = 0;

    function new() {}
}

typedef Chance = {
    val: Int,
    min: Float,
    max: Float,
}

typedef Particle = {
    x: Float,
    y: Float,
    color: Int,
    width: Float,
    width_final: Float,
    t: Float,
    t_max: Float,
    dx: Float,
    dy: Float,
    ddy: Float
}

@:publicFields
class Game {
    static inline var DRAW_COORDINATES = false;
    static inline var UPDATE_CARDS = true;
    static inline var DRAW_IMAGE_COVER = true;
    static inline var DRAW_TRANSPARENT_COVER = true;
    static inline var DRAW_CARD_LEVEL = true;
    static inline var ARROW_HACK = false;
    static inline var DRAW_LOS_DEBUG = false;
    var GOD_MODE = false;

    static var default_card_type = null;
    static var default_arcana_type = null;
    static var default_item_type = ItemType_Consumable;
    static var default_weapon_type = null;
    static var default_armor_type = null;
    static var default_consumable_type = null;

    static inline var tilesize = 64;
    static inline var cardmap_width = 5;
    static inline var cardmap_height = 3;
    static inline var card_width = 3;
    static inline var card_height = 5;
    static inline var map_width = cardmap_width * card_width;
    static inline var map_height = cardmap_height * card_height;
    static inline var inventory_slots = 5;
    static inline var inventory_x = 1000;
    static inline var inventory_y = 64;
    static inline var inventory_slot_size = 64;
    static inline var trash_x = inventory_x;
    static inline var trash_y = inventory_y + inventory_slot_size * inventory_slots + 10;
    static inline var shop_inventory_slots = 3;
    static inline var shop_inventory_x = 200;
    static inline var shop_inventory_y = 600;
    static inline var shop_inventory_slot_size = 64;

    var state = GameState_PlayerTurn;
    var state_timer = 0; // reset to 0 by state at completion
    static inline var move_visual_timer_max = 7;
    static inline var weapon_visual_timer_max = 10;
    static inline var bow_visual_timer_max = 50;
    static inline var card_flip_timer_max = 30;
    var flipped_card = {x: 0, y: 0};
    var drag_dx = 0;
    var drag_dy = 0;
    var dragged_item:Item = null;
    var dragged_item_inventory_slot = 0;
    var hover_info = "";
    var message_text = "";
    var message_timer = 0;
    static inline var message_x = map_width * tilesize / 2;
    static inline var message_y = (map_height - 1) * tilesize;
    static var message_timer_max = 360;
    var explosion_x = 0;
    var explosion_y = 0;
    var explosion_happened = false;

    var walls = Data.bool_2dvector(map_width, map_height);
    var cards = new Vector<Vector<Card>>(cardmap_width);
    var cards_covered = 0;
    static inline var total_cards = cardmap_width * cardmap_height;
    static inline var card_update_timer_max = 10; // turns
    var card_update_timer = card_update_timer_max;
    var card_level = 1; // level of generated cards(updated after every x cards are generaed)
    static inline var card_level_increment_timer_min = 5;
    static inline var card_level_increment_timer_max = 8;
    var card_level_increment_timer = Random.int(card_level_increment_timer_min, card_level_increment_timer_max);
    var card_type_history = new Array<CardType>();
    static inline var too_old_age = 30;
    static inline var max_money_amount = 10;

    var player:Player;
    var inventory = new Vector<Item>(inventory_slots);
    var shop_inventories = new Map<String, Vector<Item>>();
    var history = new Array<Array<String>>();
    var fist_damage = 1;
    var money = 0;

    var active_arcana: ArcanaType = ArcanaType_None;
    var arcana_timer = 0;
    var damage_potion_timer = 0;
    var speed_potion_timer = 0;

    function new() {

        Walls.generate();

        // Canvas for card flip animation
        Gfx.create_image("card_front", card_width * tilesize, card_height * tilesize);
        Gfx.create_image("card_back", card_width * tilesize, card_height * tilesize);
        Gfx.create_image("map_canvas", map_width * tilesize, map_height * tilesize);

        for (i in 0...inventory_slots) {
            inventory[i] = null;
        }

        player = new Player();
        player.x = 2;
        player.y = 1;
        player.real_x = player.x * tilesize;
        player.real_y = player.y * tilesize;
        var player_card = card_at_position(player.x, player.y);

        // Set card positions/types
        for (i in 0...cards.length) {
            cards[i] = new Vector<Card>(cardmap_height);

            for (j in 0...cards[i].length) {
                cards[i][j] = new Card();
                var card = cards[i][j];


                card.x = i;
                card.y = j;
                reset_card(card);

                if (Random.chance(40) && (i != player_card.x || j != player_card.y)) {
                    card.type = generate_card_type();
                    if (default_card_type != null) {
                        card.type = default_card_type;
                    }
                    card.covered = true;
                    cards_covered++;
                } else {
                    card.type = CardType_None;
                    card.covered = false;
                }
            }
        }

        // Generate cards
        for (x in 0...cardmap_width) {
            for (y in 0...cardmap_height) {
                generate_card(cards[x][y]);
                cards[x][y].level = card_level;
            }
        }

        walls[player.x][player.y] = false;
    }

    // start_index is used to skip EnumType_None
    function random_enum(enum_type:Dynamic, start_index:Int = 0):Dynamic {
        var k = Random.int(start_index, Type.allEnums(enum_type).length - 1);
        return Type.allEnums(enum_type)[k];
    }

    var chance_history = new ObjectMap<Dynamic, Array<Int>>();
    function get_chance(enum_type: Dynamic, enums: Array<Dynamic>, chances: Array<Chance>): Dynamic {
        var chances_incremented = new Vector<Int>(chances.length);
        for (i in 0...chances.length) {
            chances_incremented[i] = chances[i].val;
        }

        var counts = new Vector<Int>(chances.length);
        for (i in 0...chances.length) {
            counts[i] = 0;
        }
        if (!chance_history.exists(enum_type)) {
            chance_history.set(enum_type, new Array<Int>());
        }

        if (chance_history.get(enum_type).length > 15) {
            chance_history.get(enum_type).pop();
        }
        var history = chance_history.get(enum_type);
        for (i in 0...history.length) {
            counts[history[i]]++;
        }

        for (i in 0...chances.length) {
            // If there are too many cards of type, halve the chances
            if (counts[i] / history.length > chances[i].max && chances[i].max != 0) {
                chances_incremented[i] = Math.floor(chances_incremented[i] / 2);
            }
            // If there are too little cards of type, double the chances
            if (counts[i] / history.length < chances[i].min && chances[i].min != 0) {
                chances_incremented[i] = Math.ceil(chances_incremented[i] * 2);
            }
        }

        var chance_sum = 0;
        for (i in 0...chances.length) {
            chance_sum += chances_incremented[i];
            chances_incremented[i] = chance_sum; 
        }

        var k = Random.int(1, chance_sum);
        var selected = 0;
        for (i in 0...chances.length) {
            if (k <= chances_incremented[i]) {
                chance_history.get(enum_type).insert(0, enums[i]);
                return enums[i];
            }
        }

        return enums[0];
    }

    var card_type_order = [
    CardType_Arcana,
    CardType_Weapon,
    CardType_Treasure,
    CardType_Dude,
    CardType_Shop,
    ];
    // var card_type_chances: Array<Chance> = [
    // {val: 80, min: 0, max: 1},
    // {val: 2, min: 0, max: 2},
    // {val: 10, min: 0, max: 2},
    // {val: 100, min: 2, max: 8},
    // {val: 10, min: 0, max: 1},
    // ];
    // Real values
    var card_type_chances: Array<Chance> = [
    {val: 1, min: 0, max: 1},
    {val: 1, min: 0, max: 2},
    {val: 2, min: 0, max: 2},
    {val: 15, min: 2, max: 8},
    {val: 1, min: 0, max: 1},
    ];

    var treasure_order = [
    ItemType_Consumable,
    ItemType_Bomb,
    ItemType_Armor,
    ItemType_Money,
    ];
    // var treasure_chances: Array<Chance> = [
    // {val: 4, min: 0, max: 5},
    // {val: 4, min: 0, max: 5},
    // {val: 4, min: 0, max: 5},
    // {val: 20, min: 0, max: 5},
    // ];
    // Real values
    var treasure_chances: Array<Chance> = [
    {val: 4, min: 0, max: 5},
    {val: 4, min: 0, max: 5},
    {val: 2, min: 0, max: 4},
    {val: 2, min: 0, max: 5},
    ];

    var shop_order = [
    ItemType_Consumable,
    ItemType_Bomb,
    ItemType_Armor,
    ];
    var shop_chances: Array<Chance> = [
    {val: 4, min: 0, max: 5},
    {val: 4, min: 0, max: 5},
    {val: 4, min: 0, max: 5},
    ];

    var weapon_order = [
    WeaponType_Sword,
    WeaponType_Spear,
    WeaponType_Bow,
    WeaponType_Laser,
    ];
    var weapon_chances: Array<Chance> = [
    {val: 4, min: 0, max: 5},
    {val: 4, min: 0, max: 5},
    {val: 4, min: 0, max: 5},
    {val: 1, min: 0, max: 2},
    ];

    var armor_order = [
    ArmorType_Chest,
    ArmorType_Legs,
    ArmorType_Head,
    ];
    var armor_chances: Array<Chance> = [
    {val: 4, min: 0, max: 5},
    {val: 4, min: 0, max: 5},
    {val: 4, min: 0, max: 5},
    ];

    var dude_order = [
    DudeType_Follower,
    DudeType_Stander,
    DudeType_Shooter,
    DudeType_Ghost,
    ];
    var dude_chances: Array<Chance> = [
    {val: 12, min: 0, max: 17},
    {val: 2, min: 0, max: 4},
    {val: 2, min: 0, max: 4},
    {val: 1, min: 0, max: 5},
    ];

    var spawned_weapon = false;
    function generate_card_type():Dynamic {
        var type = CardType_None;

        // Force card type(arcana card effect or treasure card after completing dude card)
        if (arcana_timer > 0 && (active_arcana == ArcanaType_Strength
            || active_arcana == ArcanaType_Death
            || active_arcana == ArcanaType_Star
            )) 
        {
            switch (active_arcana) {
                case ArcanaType_Strength: type = CardType_Weapon;
                case ArcanaType_Death: type = CardType_Dude;
                case ArcanaType_Star: type = CardType_Treasure;
                default: trace("Unhandled case in generate_card_type() arcana effect!");
            }

            arcana_timer--;
            if (arcana_timer <= 0) {
                active_arcana = null;
            }
        } else if (!spawned_weapon) {
            type = CardType_Weapon;
            spawned_weapon = true;
        } else {
            type = get_chance(CardType, card_type_order, card_type_chances);
        }

        return type;
    }

    function reset_card(card: Card) {
        // Remove items on card
        var removed_items = new Array<Item>();
        for (item in Entity.get(Item)) {
            if (item.on_ground && Std.int(item.x / card_width) == card.x && Std.int(item.y / card_height) == card.y) {
                removed_items.push(item);
            }
        }
        for (item in removed_items) {
            item.delete();
        }
        // Remove dudes on card
        var removed_dudes = new Array<Dude>();
        for (dude in Entity.get(Dude)) {
            if (Std.int(dude.x / card_width) == card.x && Std.int(dude.y / card_height) == card.y) {
                removed_dudes.push(dude);
            }
        }
        for (dude in removed_dudes) {
            dude.delete();
        }
        card.covered = true;
        card.visited = false;
        card.arcana_activated = false;
        card.turn_age = 0;
        card.update_age = 0;
        card.completed = true; // only used for dude card type
        card.my_dudes.splice(0, card.my_dudes.length);
    }

    function generate_item(order, chances, card = null): Item {            
        var item = new Item();
        item.on_ground = false;
        if (card != null && card.type == CardType_Weapon) {
            item.type = ItemType_Weapon;
        } else {
            item.type = get_chance(ItemType, order, chances);
        }

        if (default_item_type != null) {
            item.type = default_item_type;
        }

        item.info += '\nI am ${item.type}!';

        if (item.type == ItemType_Consumable) {
            item.consumable_type = random_enum(ConsumableType, 1);
            if (default_consumable_type != null) {
                item.consumable_type = default_consumable_type;
            }
            item.value = 2 * card_level;
            switch (item.consumable_type) {
                case ConsumableType_Healing: item.tile = Tiles.GreenPotion;
                case ConsumableType_Damage: item.tile = Tiles.RedPotion;
                case ConsumableType_Speed: item.tile = Tiles.BluePotion;
                default:
            }
            item.name = "Potion";
        } else if (item.type == ItemType_Armor) {
            item.armor_type = get_chance(ArmorType, armor_order, armor_chances);
            if (default_armor_type != null) {
                item.consumable_type = default_armor_type;
            }
            item.name = "Armor";
            switch (item.armor_type) {
                case ArmorType_Chest: item.tile = Tiles.Chest;
                case ArmorType_Head: item.tile = Tiles.Head;
                case ArmorType_Legs: item.tile = Tiles.Legs;
                default: item.tile = Tiles.None;
            }

            // Calculate stats
            var stat_weight = Std.int(Random.float(0.75 * card_level, 1.25 * card_level));
            if (stat_weight <= 0) {
                stat_weight = 1;
            }
            var max_imbalance = Std.int(Random.float(0.5 * card_level, card_level));
            if (max_imbalance <= 0) {
                max_imbalance = 1;
            }
            // Split weight between hp and dmg, possibly turning one negative and not going above max_imbalance
            if (Random.chance(50)) {
                item.hp_bonus = Random.pick_int(-1, 1) * Random.int(1, max_imbalance);
                item.dmg_bonus = stat_weight - item.hp_bonus;
                if (item.dmg_bonus < 0 && item.dmg_bonus < max_imbalance) {
                    item.dmg_bonus = -max_imbalance;
                } else if (item.dmg_bonus > 0 && item.dmg_bonus > max_imbalance) {
                    item.dmg_bonus = max_imbalance;
                }
            } else {
                item.dmg_bonus = Random.pick_int(-1, 1) * Random.int(1, max_imbalance);
                item.hp_bonus = stat_weight - item.dmg_bonus;
                if (item.hp_bonus < 0 && item.hp_bonus < max_imbalance) {
                    item.hp_bonus = -max_imbalance;
                } else if (item.hp_bonus > 0 && item.hp_bonus > max_imbalance) {
                    item.hp_bonus = max_imbalance;
                }
            }
        } else if (item.type == ItemType_Weapon) {
            item.weapon_type = get_chance(WeaponType, weapon_order, weapon_chances);
            if (default_weapon_type != null) {
                item.weapon_type = default_weapon_type;
            }

            item.name = "Weapon";
            switch (item.weapon_type) {
                case WeaponType_Sword: item.value = Math.ceil((card_level) * (1 + Random.float(-0.2, 0.2)));
                case WeaponType_Spear: item.value = Math.ceil((0.5 * card_level) * (1 + Random.float(-0.2, 0.2)));
                case WeaponType_Bow: item.value = Math.ceil((0.3 * card_level) * (1 + Random.float(-0.2, 0.2)));
                case WeaponType_Laser: {
                    item.value = Math.ceil((3 * card_level) * (1 + Random.float(-0.2, 0.2)));
                    item.value_max = item.value;
                }
                default: item.value = 0;
            }
            switch (item.weapon_type) {
                case WeaponType_Sword: item.tile = Tiles.Sword;
                case WeaponType_Spear: item.tile = Tiles.Spear;
                case WeaponType_Bow: item.tile = Tiles.Bow;
                default: item.tile = Tiles.None;
            }
        } else if (item.type == ItemType_Bomb) {
            item.tile = Tiles.Bomb;
            item.name = "Bomb";
        } else if (item.type == ItemType_Money) {
            item.tile = Tiles.Money;
            item.name = "Money";
            item.amount = Random.int(2, 4);
        }

        return item;
    }

    function generate_card(card:Card) {
        var k = Random.int(0, Walls.all.length - 1);
        var walls_preset = Walls.all[k];
        for (i in 0...card_width) {
            for (j in 0...card_height) {
                walls[card.x * card_width + i][card.y * card_height + j] = (walls_preset[j][i] == 1);
            }
        }

        function random_cell_in_card(card_x: Int, card_y: Int, is_good: Int->Int->Bool): IntVector2 {
            var out: IntVector2 = {x: -1, y: -1};
            var x_start = card.x * card_width;
            var x_end = x_start + card_width;
            var y_start = card.y * card_height;
            var y_end = y_start + card_height;
            
            var free_cell_amount = 0;
            for (x in x_start...x_end) {
                for (y in y_start...y_end) {
                    if (is_good(x, y)) {
                        free_cell_amount++;
                    }
                }
            }

            var k = Random.int(0, free_cell_amount - 1);
            var i = 0;
            for (x in x_start...x_end) {
                for (y in y_start...y_end) {
                    if (is_good(x, y)) {
                        if (i == k) {
                            out.x = x;
                            out.y = y;
                            return out;
                        }
                        i++;
                    }
                }
            }

            trace("random_cell_in_card() failed to find a free cell!");
            return out;
        }


        // Check for paths here and delete walls randomly until there's a path
        // from player to every free cell on card
        var max_loops = card_width * card_height;
        var path_exists = false;
        var loop_number = 0;
        while (!path_exists) {
            if (loop_number > max_loops) {
                break;
            }

            path_exists = true;

            for (i in 0...card_width) {
                if (!path_exists) {
                    break;
                }
                for (j in 0...card_height) {
                    var x = card.x * card_width + i;
                    var y = card.y * card_height + j;
                    if (!walls[x][y]) {
                        var path = a_star(player.x, player.y, x, y, true);
                        if (path.length == 0) {
                            path_exists = false;
                            break;
                        }
                    }
                }
            }

            if (!path_exists) {
                var random_wall = random_cell_in_card(card.x, card.y, function(x, y) { return walls[x][y]; });
                if (random_wall.x == -1) {
                    break;
                } else {
                    walls[random_wall.x][random_wall.y] = false;
                }
            }
            
            loop_number++;
        }

        function set_down_item(item) {
            var free_map = get_free_map(false);
            var free_cell = random_cell_in_card(card.x, card.y, function(x, y) { return free_map[x][y]; });
            if (free_cell.x == -1 || free_cell.y == -1) {
                trace("set_down_item() failed, deleted item");
                item.delete();
            }

            item.x = free_cell.x;
            item.y = free_cell.y;
            item.on_ground = true;
            walls[item.x][item.y] = false;
        }

        //TODO: make a better formula for dude values based on card level
        if (card.type == CardType_Dude) {
            card.completed = false;

            var number_of_dudes: Int;
            var one_dude = Random.chance(80);
            if (one_dude) {
                number_of_dudes = 1;
            } else {
                number_of_dudes = 2;
            }
            while (number_of_dudes > 0) {
                number_of_dudes--;

                // Spawn dude
                var dude = new Dude();
                card.my_dudes.push(dude);
                var free_map = get_free_map(false);
                var free_cell = random_cell_in_card(card.x, card.y, function(x, y) { return free_map[x][y]; });
                dude.x = free_cell.x;
                dude.y = free_cell.y;
                dude.real_x = dude.x * tilesize;
                dude.real_y = dude.y * tilesize;
                update_dude_info(dude);
                var min_hp = 2;
                if (number_of_dudes > 1) {
                    min_hp = 1;
                }
                dude.hp_max = Std.int(Math.max(min_hp, Math.ceil(card_level * (1.4 + Random.float(-0.5, 0.5)) / number_of_dudes)));
                dude.hp = dude.hp_max;
                dude.dmg = Std.int(Math.max(min_hp, Math.ceil(card_level * (1.4 + Random.float(-0.5, 0.5)))));
                dude.type = get_chance(DudeType, dude_order, dude_chances);
            }

            // Spawn items
            if (Random.chance(50)) {
                var item = generate_item(treasure_order, treasure_chances);
                set_down_item(item);
            }
        } else if (card.type == CardType_Treasure || card.type == CardType_Weapon) {

            var item = generate_item(treasure_order, treasure_chances, card);
            set_down_item(item);
            if (item != null && active_arcana == ArcanaType_Temperance) {
                // Temperance effect: spawn another item with a 50% chance
                if (Random.chance(50)) {
                    var second_item = generate_item(treasure_order, treasure_chances, card);
                    set_down_item(second_item);
                }

                arcana_timer--;
                if (arcana_timer <= 0) {
                    active_arcana = null;
                }
            }
        } else if (card.type == CardType_Arcana) {
            card.arcana = random_enum(ArcanaType, 1);
            if (default_arcana_type != null) {
                card.arcana = default_arcana_type;
            }

            // remove wall at activation cell
            walls[card.x * card_width + 1][card.y * card_height + 2] = false;
        } else if (card.type == CardType_Shop) {
            for (i in 0...card_width) {
                for (j in 0...card_height) {
                    walls[card.x * card_width + i][card.y * card_height + j] = false;
                }
            }
            var walls_preset = [
            [0, 0, 0],
            [1, 0, 1],
            [0, 0, 0],
            [1, 0, 1],
            [0, 0, 0],
            ];
            for (i in 0...card_width) {
                for (j in 0...card_height) {
                    walls[card.x * card_width + i][card.y * card_height + j] = (walls_preset[j][i] == 1);
                }
            }

            // Generate shop inventory
            var shop = new Vector<Item>(shop_inventory_slots);
            for (i in 0...shop_inventory_slots) {
                shop[i] = generate_item(shop_order, shop_chances);

            }

            shop_inventories.set('${card.x}_${card.y}', shop);
        }
    }

    function serialize(entity:Dynamic) {
        var fields = Type.getInstanceFields(Type.getClass(entity));
        var fields_string = "";
        for (f in fields) {
            var field = Std.string(Reflect.field(entity, f));
            if (field.indexOf('function') != -1) {
                continue;
            }
            var enum_type = Type.resolveEnum(field.split('_')[0]);
            if (enum_type != null) {
                // for enums record it's index
                var enums = Type.allEnums(enum_type);
                for (i in 0...enums.length) {
                    if (Std.string(enums[i]) == field) {
                        // enumname_enumindex
                        fields_string += f + '=' + field.split('_')[0] + '_' + i + '|';
                        break;
                    }
                }
            } else {
                fields_string += f + '=' + field + '|';
            }
        }
        return fields_string;
    }

    function unserialize(entity:Dynamic, fields_string:String) {
        var fields = fields_string.split('|');
        fields.splice(fields.length - 1, 1);
        for (f in fields) {
            var pair = f.split('=');
            if ((~/^\d+$/).match(pair[0])) {
                // Number
                Reflect.setField(entity, pair[0], Std.parseFloat(pair[1]));
            } else if (pair[1] == 'false') {
                // Bool
                Reflect.setField(entity, pair[0], false);
            } else if (pair[1] == 'true') {
                // Bool
                Reflect.setField(entity, pair[0], true);
            } else if (Type.resolveEnum(pair[1].split('_')[0]) != null) {
                // Enum
                var enum_type = Type.resolveEnum(pair[1].split('_')[0]);
                var enum_index = Std.parseInt(pair[1].split('_')[1]);
                var enum_value = Type.allEnums(enum_type)[enum_index];
                Reflect.setField(entity, pair[0], enum_value);
            } else if (pair[1].indexOf('[') != -1) {
                // Array member serialization is not supported
                Reflect.setField(entity, pair[0], new Array());
            } else {
                // String
                Reflect.setField(entity, pair[0], pair[1]);
            }
        }
    }

    // Arcana timer is used both for arcanas that are timed by turns and 
    // arcanas that are timed by card spawns!
    function do_arcana_magic(type: ArcanaType) {
        switch (type) {
            case ArcanaType_None:

            case ArcanaType_Fool: {
                make_message("All cards were uncovered");
                for (x in 0...cardmap_width) {
                    for (y in 0...cardmap_height) {
                        var card = cards[x][y];
                        if (card.covered) {
                            card.covered = false;
                            for (dude in Entity.get(Dude)) {
                                var dude_card = card_at_position(dude.x, dude.y);
                                if (dude_card.x == card.x && dude_card.y == card.y) {
                                    dude.active = true;
                                }
                            }
                        }
                    }
                }
            }

            case ArcanaType_Strength: {
                make_message("Next 5 cards are weapon cards");
                arcana_timer = 5;
            }
            case ArcanaType_Death: {
                make_message("Next 5 cards are dude cards");
                arcana_timer = 5;
            }
            case ArcanaType_Star: {
                make_message("Next 5 cards are treasure cards");
                arcana_timer = 5;
            }

            case ArcanaType_Hermit: {
                make_message("All enemies were removed");
                for (dude in Entity.get(Dude)) {
                    if (dude.active) {
                        dude.delete();
                    }
                }
            }
            case ArcanaType_Magician: {
                make_message("All covered cards were replaced");
                for (x in 0...cardmap_width) {
                    for (y in 0...cardmap_height) {
                        var card = cards[x][y];
                        if (card.covered) {
                            reset_card(card);
                            card.type = generate_card_type();
                            generate_card(card);
                        }
                    }
                }
            }
            case ArcanaType_Priestess: {
                player.hp_max++;
                player.hp = player.hp_max;
                make_message("Maximum health has been increased");
            }
            case ArcanaType_Empress: {
                arcana_timer = 10;
                make_message("Cards are replaced faster for some time");
            }
            case ArcanaType_Emperor: {
                var no_weapons = true;
                for (i in 0...inventory_slots) {
                    var item = inventory[i];
                    if (item != null && item.type == ItemType_Weapon) {
                        item.value = Math.ceil(item.value * 1.2);
                        no_weapons = false;
                        break;
                    }
                }
                if (no_weapons) {
                    fist_damage++;
                }
                make_message("Current weapon has become stronger");
            }
            case ArcanaType_Hierophant: {

                make_message("All your armor has been repaired");
            }
            case ArcanaType_Lovers: {
                arcana_timer = 13;
                make_message("Enemies are friendly for some time");
            }
            case ArcanaType_Chariot: {
                for (x in 0...cardmap_width) {
                    for (y in 0...cardmap_height) {
                        var card = cards[x][y];
                        if (!card.covered) {
                            for (x2 in card.x * card_width...(card.x + 1) * card_width) {
                                for (y2 in card.y * card_height...(card.y + 1) * card_height) {
                                    walls[x2][y2] = false;
                                }
                            }
                        }
                    }
                }
                make_message("All walls were destroyed");
            }
            case ArcanaType_Fortune: {
                arcana_timer = 15;
                make_message("All money is doubled for some time");
            }
            case ArcanaType_Justice: {
                var player_card = card_at_position(player.x, player.y);

                for (x in 0...cardmap_width) {
                    for (y in 0...cardmap_height) {
                        var card = cards[x][y];
                        if (!card.covered && card != player_card) {
                            reset_card(card);
                            generate_card(card);
                        }
                    }
                }
                make_message("Recover all uncovered cards");
            }
            case ArcanaType_HangedMan: {
                // use timer so that it's possible to teleport only when standing on the arcana cell
                // (i.e. only during that turn)
                arcana_timer = 1;
                make_message("Click to teleport anywhere");
            }
            case ArcanaType_Temperance: {
                arcana_timer = 5;
                make_message("Cards might have more items for some time");
            }
            case ArcanaType_Devil: {
                arcana_timer = 15;
                make_message("All damage dealt is doubled for some time");
            }
            case ArcanaType_Tower: {

                make_message("All armor has been repaired");
            }
            case ArcanaType_Moon: {
                arcana_timer = 10;
                make_message("Health is slowly regenerated");
            }
            case ArcanaType_Sun: {
                arcana_timer = 10;
            }
            case ArcanaType_Judgement: {
                make_message("All cards were recovered");
                var player_card = card_at_position(player.x, player.y);
                for (x in 0...cardmap_width) {
                    for (y in 0...cardmap_height) {
                        var card = cards[x][y];
                        if (!card.covered && (card.x != player_card.x || card.y != player_card.y)) {
                            reset_card(card);
                            cards_covered++;
                            card.covered = true;

                            card.type = generate_card_type();
                            if (default_card_type != null) {
                                card.type = default_card_type;
                            }

                            generate_card(card);

                            card.level = card_level;

                            card_level_increment_timer--;
                            if (card_level_increment_timer <= 0) {
                                card_level++;
                                card_level_increment_timer = Random.int(card_level_increment_timer_min, card_level_increment_timer_max); 
                            }

                            card.just_updated_timer = 60;
                        }
                    }
                }
            }
            default: {
                make_message("This arcana is not implemented");
            }
        }
        active_arcana = type;
        if (arcana_timer != 0) {
            // do_arcana_timer() is called in turn result, so arcana_timer will be decremented immedeatly
            arcana_timer++;
        }
        trace(type);
    }

    function make_message(text: String) {
        message_text = text;
        message_timer = message_timer_max;
    }

    function update_dude_info(dude: Dude) {
        dude.info = '${dude.name}\n${dude.hp}/${dude.hp_max}';
    }

    // each bool tells what to filter out
    function get_free_map(filter_covered_cards = true, filter_dudes = true, filter_items = true, 
        filter_walls = true, filter_player = true): Vector<Vector<Bool>> 
    {
        // Mark items/dudes/walls/player/covered cards as false, don't ignore player
        var free_map = Data.bool_2dvector(map_width, map_height, true);
        if (filter_covered_cards) {
            for (x in 0...cardmap_width) {
                for (y in 0...cardmap_height) {
                    if (cards[x][y].covered) {
                        for (x2 in 0...card_width) {
                            for (y2 in 0...card_height) {
                                free_map[x * card_width + x2][y * card_height + y2] = false;
                            }
                        }
                    }
                }
            }
        }
        if (filter_dudes) {
            for (dude in Entity.get(Dude)) {
                if (dude.moved) {
                    free_map[dude.x + dude.dx][dude.y + dude.dy] = false;
                } else {
                    free_map[dude.x][dude.y] = false;
                }
            }
        }
        if (filter_items) {
            for (item in Entity.get(Item)) {
                if (item.on_ground) {
                    free_map[item.x][item.y] = false;
                }
            }
        }
        if (filter_walls) {
            for (x in 0...map_width) {
                for (y in 0...map_height) {
                    if (walls[x][y]) {
                        free_map[x][y] = false;
                    }
                }
            }
        }
        if (filter_player) {
            free_map[player.x][player.y] = false;
        }

        return free_map;
    }

    function a_star(x1:Int, y1:Int, x2:Int, y2:Int, include_covered_cards = false, only_walls = false):Array<IntVector2> {
        function heuristic_score(x1:Int, y1:Int, x2:Int, y2:Int):Int {
            return Std.int(Math.abs(x2 - x1) + Math.abs(y2 - y1));
        }
        function path(prev:Vector<Vector<IntVector2>>, x:Int, y:Int):Array<IntVector2> {
            var current = {x: x, y: y};
            var temp = {x: x, y: y};
            var path:Array<IntVector2> = [{x: current.x, y: current.y}];
            while (prev[current.x][current.y].x != -1) {
                temp.x = current.x;
                temp.y = current.y;
                current.x = prev[temp.x][temp.y].x;
                current.y = prev[temp.x][temp.y].y;
                path.push({x: current.x, y: current.y});
            }
            return path;
        }

        var move_map: Vector<Vector<Bool>>;
        if (only_walls) {
            move_map = get_free_map(!include_covered_cards, false, false, true, false);
        } else {
            move_map = get_free_map(!include_covered_cards);
        }
        move_map[x2][y2] = true; // destination cell needs to be "free" for the algorithm to find paths correctly

        var infinity = 10000000;
        var closed = Data.bool_2dvector(map_width, map_height, false);
        var open = Data.bool_2dvector(map_width, map_height, false);
        open[x1][y1] = true;
        for (x in 0...cardmap_width) {
            for (y in 0...cardmap_height) {
                if (!move_map[x][y]) {
                    open[x][y] = false;
                }
            }
        }
        var open_length = 1;
        var prev = new Vector<Vector<IntVector2>>(map_width);
        for (x in 0...map_width) {
            prev[x] = new Vector<IntVector2>(map_height);
            for (y in 0...map_height) {
                prev[x][y] = {x: -1, y: -1};
            }
        }

        var g_score = Data.int_2dvector(map_width, map_height, infinity);
        g_score[x1][y1] = 0;
        var f_score = Data.int_2dvector(map_width, map_height, infinity);

        f_score[x1][y1] = heuristic_score(x1, y1, x2, y2);

        while (open_length != 0) {
            var current = function() {
                var lowest_score = infinity;
                var lowest_node = {x: x1, y: y1};
                for (x in 0...map_width) {
                    for (y in 0...map_height) {
                        if (open[x][y] && f_score[x][y] <= lowest_score) {
                            lowest_node.x = x;
                            lowest_node.y = y;
                            lowest_score = f_score[x][y];
                        }
                    }
                }
                return lowest_node;
            }();

            if (current.x == x2 && current.y == y2) {
                return path(prev, current.x, current.y);
            }

            open[current.x][current.y] = false;
            open_length--;
            closed[current.x][current.y] = true;
            for (dx in -1...2) {
                for (dy in -1...2) {
                    if (Math.abs(dx) + Math.abs(dy) != 1) {
                        continue;
                    }
                    var neighbor_x = Std.int(current.x + dx);
                    var neighbor_y = Std.int(current.y + dy);
                    if (out_of_bounds(neighbor_x, neighbor_y) || !move_map[neighbor_x][neighbor_y]) {
                        continue;
                    }

                    if (closed[neighbor_x][neighbor_y]) {
                        continue;
                    }
                    var tentative_g_score = g_score[current.x][current.y] + 1;
                    if (!open[neighbor_x][neighbor_y]) {
                        open[neighbor_x][neighbor_y] = true;
                        open_length++;
                    } else if (tentative_g_score >= g_score[neighbor_x][neighbor_y]) {
                        continue;
                    }

                    prev[neighbor_x][neighbor_y].x = current.x;
                    prev[neighbor_x][neighbor_y].y = current.y;
                    g_score[neighbor_x][neighbor_y] = tentative_g_score;
                    f_score[neighbor_x][neighbor_y] = g_score[neighbor_x][neighbor_y] + heuristic_score(neighbor_x, neighbor_y, x2, y2);
                }
            }
        }
        return new Array<IntVector2>();
    }

    function draw_item(x: Float, y: Float, item: Item) {
        Gfx.draw_tile(x, y, item.tile);
        Text.display(x, y, item.name);
        Text.display(x, y + tilesize / 2, '${item.value}');
        if (item.type == ItemType_Money) {
            Text.display(x + tilesize - tilesize / 10, y + tilesize / 2, '${item.amount}');
        }
    }

    function render() {
        for (x in 0...map_width) {
            for (y in 0...map_height) {
                if (walls[x][y]) {
                    Gfx.draw_tile(x * tilesize, y * tilesize, Tiles.Wall);
                } else {
                    Gfx.draw_tile(x * tilesize, y * tilesize, Tiles.Space);
                }
            }
        }

        if (DRAW_COORDINATES) {
            for (dx in -2...3) {
                for (dy in -2...3) {
                    Text.display((player.x + dx) * tilesize + 5, (player.y + dy) * tilesize + 10, '${(player.x + dx)},${(player.y + dy)}');
                }
            }
        }

        Gfx.line_thickness = 7;
        for (x in 0...cardmap_width) {
            Gfx.draw_line(x * card_width * tilesize, 0, x * card_width * tilesize, (cardmap_height - 1) * card_height * tilesize, Col.NIGHTBLUE);
        }
        for (y in 0...cardmap_height) {
            Gfx.draw_line(0, y * card_height * tilesize, (cardmap_width - 1) * card_width * tilesize, y * card_height * tilesize, Col.NIGHTBLUE);
        }
        Gfx.line_thickness = 1;

        for (item in Entity.get(Item)) {
            if (item.on_ground && item != dragged_item) {
                draw_item(item.x * tilesize, item.y * tilesize, item);
            }
        }
        for (i in 0...inventory_slots) {
            Gfx.draw_box(inventory_x, inventory_y + i * inventory_slot_size, inventory_slot_size, inventory_slot_size, Col.WHITE);
            if (inventory[i] != null) {
                draw_item(inventory_x, inventory_y + i * inventory_slot_size, inventory[i]);
            }
        }
        Gfx.draw_tile(trash_x, trash_y, Tiles.Trash);

        if (player.angle != 0 && player.incoming_damage == 0) {
            if (Math.abs(player.angle) < 0.1) {
                player.angle = 0;
            } else {
                player.angle = Math.lerp(player.angle, 0, 0.4);
            }
        }
        Gfx.rotation(player.angle); 
        Gfx.draw_tile(player.real_x, player.real_y, Tiles.Player);
        Gfx.rotation(0); 

        for (dude in Entity.get(Dude)) {
            if (dude.angle != 0 && !dude.hit) {
                if (Math.abs(dude.angle) < 0.1) {
                    dude.angle = 0;
                } else {
                    dude.angle = Math.lerp(dude.angle, 0, 0.4);
                }
            }
            Gfx.rotation(dude.angle);
            var dude_tile = Tiles.None; 
            switch (dude.type) {
                case DudeType_Follower: dude_tile = Tiles.Dude;
                case DudeType_Shooter: dude_tile = Tiles.Shooter;
                case DudeType_Stander: dude_tile = Tiles.Stander;
                case DudeType_Ghost: dude_tile = Tiles.Ghost;
                default: trace("Unmatched dude type in render()!");
            }
            Gfx.draw_tile(dude.real_x, dude.real_y, dude_tile);
            Gfx.rotation(0); 
            if (!dude.dead) {
                Text.display(dude.real_x, dude.real_y, '${dude.hp}/${dude.hp_max}', Col.WHITE);
            }

            if (active_arcana == ArcanaType_Lovers) {
                Gfx.draw_tile(dude.real_x, dude.real_y, Tiles.Heart);
            }
        }


        var font_size = Text.currentsize;
        Text.change_size(40);
        var card: Card;
        if (active_arcana == ArcanaType_Sun) {
            Gfx.image_alpha(0.3);
        }
        for (x in 0...cardmap_width) {
            for (y in 0...cardmap_height) {
                card = cards[x][y];

                var card_color = 0;
                switch (card.type) {
                    case CardType_Dude: card_color = Col.RED;
                    case CardType_Treasure: card_color = Col.YELLOW;
                    case CardType_Weapon: card_color = Col.GREEN;
                    case CardType_Arcana: card_color = Col.DARKGREEN;
                    case CardType_Shop: card_color = Col.BROWN;
                    case CardType_None: card_color = Col.BLACK;
                }

                if (card.covered) {
                    if (DRAW_IMAGE_COVER) {
                        Gfx.draw_image(x * card_width * tilesize, y * card_height * tilesize, "card");
                    }
                    if (DRAW_TRANSPARENT_COVER) {
                        Gfx.fill_box(x * card_width * tilesize, y * card_height * tilesize,
                            card_width * tilesize, card_height * tilesize, card_color, 0.5);
                    }
                    if (DRAW_CARD_LEVEL) {
                        Text.display(x * card_width * tilesize, y * card_height * tilesize, '${card.level}', Col.WHITE);
                        Text.display((x + 1) * card_width * tilesize - tilesize / 2, (y + 1) * card_height * tilesize - tilesize, 
                            '${card.level}', Col.WHITE);
                    }
                } else {
                    if (card.type == CardType_Arcana) {
                        var arcana_name = '${card.arcana}';
                        arcana_name = arcana_name.substr(arcana_name.indexOf('_') + 1);
                        Text.display(x * card_width * tilesize, y * card_height * tilesize, arcana_name, Col.WHITE);
                        var arcana_color = Col.GRAY;
                        if (card.arcana_activated) {
                            arcana_color = Col.DARKGREEN;
                        }
                        Gfx.fill_circle((x * card_width + 1.5) * tilesize, (y * card_height + 2.5) * tilesize, 
                            tilesize * 0.75, arcana_color, 0.5);
                    } else if (card.type == CardType_Dude) {
                        if (card.completed) {
                            Gfx.fill_box(x * card_width * tilesize, y * card_height * tilesize,
                                card_width * tilesize, card_height * tilesize, card_color, 0.15);
                        }
                    } else if (card.type == CardType_Shop) {
                        Text.display(x * card_width * tilesize, (y + 1) * card_height * tilesize - tilesize, "Shop", Col.WHITE);
                        Gfx.fill_circle((x * card_width + 1.5) * tilesize, (y * card_height + 2.5) * tilesize, 
                            tilesize * 0.75, Col.BROWN, 0.5);
                    }
                }


                if (card.just_updated_timer > 0) {
                    card.just_updated_timer--;

                    Gfx.fill_circle((x * card_width + 1.5) * tilesize, (y * card_height + 2.5) * tilesize, 
                        card.just_updated_timer * 1.5, Col.YELLOW, 0.5);
                }
            }
        }
        if (active_arcana == ArcanaType_Sun) {
            Gfx.image_alpha(1);
        }
        Text.change_size(font_size);


        if (dragged_item != null) {
            draw_item(Mouse.x - drag_dx, Mouse.y - drag_dy, dragged_item);
        }

        Text.display(inventory_x, 0, '${Gfx.render_fps()}');
        Text.display(inventory_x, 30, '${state}');

        Text.display(inventory_x, 470, 'Money: ${money}');
        Text.display(inventory_x, 500, 'Health: ${player.hp}/${player.hp_max}');
        Text.display(inventory_x, 530, 'Armor: ${player.armor}');
        var player_damage = fist_damage;
        for (i in 0...inventory_slots) {
            if (inventory[i] != null && inventory[i].type == ItemType_Weapon) {
                player_damage = inventory[i].value;
                break;
            }
        }
        for (i in 0...inventory_slots) {
            if (inventory[i] != null) {
                player_damage += inventory[i].dmg_bonus;
            }
        }
        var damage = player_damage;
        if (damage_potion_timer > 0) {
            damage++;
        }
        if (active_arcana == ArcanaType_Devil && arcana_timer > 0) {
            damage *= 2;
        }
        Text.display(inventory_x, 560, 'Damage: ${damage}');
        Text.display(inventory_x, 600, hover_info);

        if (message_timer > 0) {
            message_timer--;

            var size = Text.currentsize;
            var new_size: Float;
            if (message_timer > message_timer_max * 0.95) {
                new_size = Math.lerp(size * 1, size * 1.25, (message_timer_max - message_timer) / (message_timer_max * 0.05));
            } else {
                new_size = size * 1.25;
            }
            Text.change_size(new_size);

            var x = message_x - Text.width(message_text) / 2;
            var y = message_y - Text.height() / 2;

            // Reset message timer on mouse hover
            if (Math.point_box_intersect(Mouse.x, Mouse.y, x, y, Text.width(message_text), Text.height())) {
                message_timer = Std.int(message_timer_max / 2);
            }


            if (message_timer > message_timer_max * 0.3) {
                Text.display(x, y, message_text);
            } else {
                var c = Std.int(message_timer / message_timer_max / 0.3 * 255);
                Text.display(x, y, message_text, Col.rgb(c, c, c));
            }
            Text.change_size(size);
        }

        if (DRAW_LOS_DEBUG) {
            for (dude in Entity.get(Dude)) {
                for (i in 0...dude.points.length) {
                    var point = dude.points[i];
                    Gfx.fill_circle(point.x * tilesize + tilesize / 2, point.y * tilesize + tilesize / 2, 10, Col.GREEN);
                }
            }
        }

        if (player.hp <= 0) {
            Text.display(100, 300, "GAME OVER", Col.WHITE);
        }
    }

    function out_of_bounds(x:Int, y:Int):Bool {
        return x < 0 || y < 0 || x >= map_width || y >= map_height;
    }

    function unequip(item: Item) {
        for (i in 0...inventory.length) {
            if (inventory[i] != null && inventory[i] == item) {
                inventory[i] = null;
                break;
            }
        }

        if (item.type == ItemType_Weapon) {
            player.weapon = WeaponType_None;
        }
        
        // Reset and count all bonuses again, for safety
        if (item.hp_bonus != 0) {
            player.hp_max = player.default_hp_max;
            for (i in 0...inventory_slots) {
                // Add up all hp bonuses again with the new item
                if (inventory[i] != null) {
                    player.hp_max += inventory[i].hp_bonus;
                }
            }
            // player hp can't go below 1 from armor hp bonus
            if (player.hp <= 0) {
                player.hp_max = 1;
            }
        }
    }

    function equip(item: Item, slot: Int) {
        inventory[slot] = item;

        if (item.type == ItemType_Weapon) {
            player.weapon = item.weapon_type;
        }

        // Reset and count all bonuses again, for safety
        if (item.hp_bonus != 0) {
            player.hp_max = player.default_hp_max;
            for (i in 0...inventory_slots) {
                // Add up all hp bonuses again with the new item
                if (inventory[i] != null) {
                    player.hp_max += inventory[i].hp_bonus;
                }
            }
            // player hp can't go below 1 from armor hp bonus
            if (player.hp <= 0) {
                player.hp_max = 1;
            }
        }
    }

    function card_at_position(x:Int, y:Int):IntVector2 {
        return {x: Std.int(x / card_width), y: Std.int(y / card_height)};
    }

    function update_player_turn() {
        //
        // MOVEMENT
        //
        player.dx = 0;
        player.dy = 0;
        if (Input.pressed(Key.A)) {
            player.dx--;
        }
        if (Input.pressed(Key.D)) {
            player.dx++;
        }
        if (Input.pressed(Key.W)) {
            player.dy--;
        }
        if (Input.pressed(Key.S)) {
            player.dy++;
        }
        // No diagonal movement
        if (player.dy != 0 && player.dx != 0) {
            player.dx = 0;
            player.dy = 0;
        }
        var move_x = player.x + player.dx;
        var move_y = player.y + player.dy;
        if (!out_of_bounds(move_x, move_y)) {
            var move_card = card_at_position(move_x, move_y);
            if (cards[move_card.x][move_card.y].covered) {
                state = GameState_CardFlip;
                flipped_card.x = move_card.x;
                flipped_card.y = move_card.y;

                // Draw flipped card sides for animation
                Gfx.draw_to_image("map_canvas");
                Gfx.clear_screen(Col.BLACK);
                render();
                Gfx.draw_to_image("card_back");
                Gfx.clear_screen(Col.BLACK);
                Gfx.draw_image(-move_card.x * card_width * tilesize, -move_card.y * card_height * tilesize, "map_canvas");

                cards[move_card.x][move_card.y].covered = false;
                Gfx.draw_to_image("map_canvas");
                Gfx.clear_screen(Col.BLACK);
                render();
                cards[move_card.x][move_card.y].covered = true;
                Gfx.draw_to_image("card_front");
                Gfx.clear_screen(Col.BLACK);
                Gfx.draw_image(-move_card.x * card_width * tilesize, -move_card.y * card_height * tilesize, "map_canvas");

                Gfx.draw_to_screen();


                for (dude in Entity.get(Dude)) {
                    var dude_card = card_at_position(dude.x, dude.y);
                    if (dude_card.x == move_card.x && dude_card.y == move_card.y) {
                        dude.active = true;
                    }
                }
            }

            function space_is_free(x:Int, y:Int, ignored_entity:Dynamic = null):Bool {
                if (out_of_bounds(x, y)) {
                    return false;
                }
                for (dude in Entity.get(Dude)) {
                    if (dude != ignored_entity && dude.x + dude.dx == x && dude.y + dude.dy == y) {
                        return false;
                    }
                }
                for (item in Entity.get(Item)) {
                    if (item.on_ground && item.x == x && item.y == y) {
                        return false;
                    }
                }
                if (player != ignored_entity) {
                    if (player.moved && player.x + player.dx == x && player.y + player.dy == y) {
                        return false;
                    } else if (player.x == x && player.y == y) {
                        return false;
                    }
                }
                return !walls[x][y];
            }
            if ((player.dx != 0 || player.dy != 0) && state != GameState_CardFlip && space_is_free(move_x, move_y, player)) {
                state = GameState_PlayerVisual;
                player.moved = true;
                player.attacked = false;
            }
        }


        //
        // ATTACK
        //
        if (!player.moved) {
            player.dx = 0;
            player.dy = 0;

            // Attack by clicking
            if (Mouse.right_click()) {
                var x = Std.int(Mouse.x / tilesize);
                var y = Std.int(Mouse.y / tilesize);

                var clicked_on_dude = false;
                for (dude in Entity.get(Dude)) {
                    if (dude.active && dude.x == x && dude.y == y) {
                        clicked_on_dude = true;
                        break;
                    }
                }

                if (clicked_on_dude) {
                    var dx = Mouse.x - player.x * tilesize - tilesize / 2;
                    var dy = Mouse.y - player.y * tilesize - tilesize / 2;
                    if (Math.abs(dx) >= Math.abs(dy)) {
                        player.dx = Math.sign(dx);
                    } else {
                        player.dy = Math.sign(dy);
                    }
                }
            }

            if (player.dx == 0 && player.dy == 0) {

                // Attack with arrow keys
                if (Input.pressed(Key.LEFT)) {
                    player.dx--;
                }
                if (Input.pressed(Key.RIGHT)) {
                    player.dx++;
                }
                if (Input.pressed(Key.UP)) {
                    player.dy--;
                }
                if (Input.pressed(Key.DOWN)) {
                    player.dy++;
                }
            }

            // No diagonal attack
            if (player.dy != 0 && player.dx != 0) {
                player.dx = 0;
                player.dy = 0;
            }

            if (player.dx != 0 || player.dy != 0) {
                state = GameState_PlayerVisual;
                player.attacked = true;
                player.moved = false;
            }
        }


        // Skip turn
        if (Input.pressed(Key.SPACE)) {
            state = GameState_PlayerVisual;
        }


        // Teleport arcana
        if (active_arcana == ArcanaType_HangedMan && state == GameState_PlayerTurn) {
            if (Mouse.left_click() || Mouse.right_click()) {
                var x = Std.int(Mouse.x / tilesize);
                var y = Std.int(Mouse.y / tilesize);
                var move_map = get_free_map(false);
                if (!out_of_bounds(x, y) && move_map[x][y]) {
                    player.x = x;
                    player.y = y;
                    player.real_x = x * tilesize;
                    player.real_y = y * tilesize;
                    state = GameState_PlayerTurnResult;
                }
            }
        }

        function consume_potion(potion) {
                    trace(player.hp);
            switch(potion.consumable_type) {
                case ConsumableType_Healing: {
                    trace(player.hp);
                    player.hp += potion.value;
                    if (player.hp > player.hp_max) {
                        player.hp = player.hp_max;
                    }   
                    trace(player.hp);
                }
                case ConsumableType_Damage: {
                    damage_potion_timer = 20;
                }
                case ConsumableType_Speed: {
                    speed_potion_timer = 20;
                }
                default: trace('${potion.consumable_type} is unhandled 
                    in update_player_turn()');
            }
            potion.delete();
        }

        // Item interactions
        if (state == GameState_PlayerTurn) {
            var x = Std.int(Mouse.x / tilesize);
            var y = Std.int(Mouse.y / tilesize);

            if (Mouse.x < inventory_x - 1) {
                // Ground items
                // left click = put into inventory or swap if weapon/armor
                // right click = use if consumable
                var clicked_item: Item = null;

                for (item in Entity.get(Item)) {
                    if (item.on_ground && item.x == x && item.y == y) {
                        clicked_item = item;
                        break;
                    }
                }
                if (clicked_item != null 
                    && (Math.abs(clicked_item.x - player.x) >= 2 || Math.abs(clicked_item.y - player.y) >= 2)) 
                {
                    clicked_item = null;
                }

                if (clicked_item != null) {
                    if (Mouse.left_click()) {
                        // Drag start
                        for (item in Entity.get(Item)) {
                            if (item.on_ground && item.x == x && item.y == y) {
                                dragged_item = item;
                                drag_dx = Mouse.x - x * tilesize;
                                drag_dy = Mouse.y - y * tilesize;
                                break;
                            }
                        }
                        if (dragged_item != null
                            && Math.abs(dragged_item.x - player.x) < 2
                            && Math.abs(dragged_item.y - player.y) < 2) 
                        {
                            state = GameState_ItemDrag;
                        } else {
                            dragged_item = null;
                        }
                    } else if (Mouse.right_click()) {
                        // Pick up or drop
                        if (clicked_item.type == ItemType_Weapon) {
                            var equipped_weapon: Item = null;
                            var equipped_weapon_inventory_slot = 0;

                            for (i in 0...inventory_slots) {
                                if (inventory[i] != null && inventory[i].type == ItemType_Weapon) {
                                    equipped_weapon = inventory[i];
                                    equipped_weapon_inventory_slot = i;
                                    break;
                                }
                            }
                            if (equipped_weapon == null) {
                                // Find free slot
                                for (i in 0...inventory_slots) {
                                    if (inventory[i] == null) {
                                        equipped_weapon_inventory_slot = i;
                                        break;
                                    }
                                }
                            }

                            if (equipped_weapon != null) {
                                unequip(equipped_weapon);
                                equipped_weapon.x = clicked_item.x;
                                equipped_weapon.y = clicked_item.y;
                                equipped_weapon.on_ground = true;
                            }

                            equip(clicked_item, equipped_weapon_inventory_slot);
                            clicked_item.on_ground = false;
                        } else if (clicked_item.type == ItemType_Armor) {
                            var equipped_armor: Item = null;
                            var equipped_armor_inventory_slot = 0;

                            for (i in 0...inventory_slots) {
                                if (inventory[i] != null 
                                    && inventory[i].type == ItemType_Armor 
                                    && inventory[i].armor_type == clicked_item.armor_type) 
                                {
                                    equipped_armor = inventory[i];
                                    equipped_armor_inventory_slot = i;
                                    break;
                                }
                            }
                            if (equipped_armor == null) {
                                // Find free slot
                                for (i in 0...inventory_slots) {
                                    if (inventory[i] == null) {
                                        equipped_armor_inventory_slot = i;
                                        break;
                                    }
                                }
                            }

                            if (equipped_armor != null) {
                                unequip(equipped_armor);
                                equipped_armor.x = clicked_item.x;
                                equipped_armor.y = clicked_item.y;
                                equipped_armor.on_ground = true;
                            }

                            equip(clicked_item, equipped_armor_inventory_slot);
                            clicked_item.on_ground = false;
                        } else {

                            if (clicked_item.type == ItemType_Money) {
                                money += clicked_item.amount;
                                clicked_item.on_ground = false;
                                clicked_item.delete();
                            } else {
                                var open_slot_found = false;

                                for (i in 0...inventory_slots) {
                                    if (inventory[i] == null) {
                                        equip(clicked_item, i);
                                        clicked_item.on_ground = false;
                                        open_slot_found = true;
                                        break;
                                    }
                                }

                                if (!open_slot_found) {
                                    make_message("Inventory is full");
                                }
                            }
                        }
                    }
                }
            } else {
                // Inventory item

                var clicked_item: Item = null;
                var clicked_slot = 0;

                // Find item under mouse
                for (i in 0...inventory_slots) {
                    if (inventory[i] != null
                        && Math.point_box_intersect(Mouse.x, Mouse.y, inventory_x, inventory_y + i * inventory_slot_size,
                            inventory_slot_size, inventory_slot_size)) 
                    {
                        clicked_item = inventory[i];
                        clicked_slot = i;
                        break;
                    }
                }

                if (clicked_item != null) {
                    if (Mouse.left_click()) {
                        state = GameState_ItemDrag;
                        dragged_item = clicked_item;
                        drag_dx = Mouse.x - inventory_x;
                        drag_dy = Mouse.y - inventory_y - clicked_slot * inventory_slot_size;
                        dragged_item_inventory_slot = clicked_slot;
                        inventory[clicked_slot] = null;
                    } else if (Mouse.right_click()) {
                        if (clicked_item.type == ItemType_Consumable) {
                            consume_potion(clicked_item);
                            inventory[clicked_slot] = null;
                            state = GameState_PlayerVisual;
                        }
                    }
                }
            }
        }

        render();
    }

    function update_item_drag() {

        if (Mouse.left_released()) {
            var put_in_inventory = false;
            var put_in_trash = false;
            var slot_index = -1;
            var bomb_used = false;

            if (Math.point_box_intersect(Mouse.x, Mouse.y, trash_x, trash_y, inventory_slot_size, inventory_slot_size)) {
                // Trash item
                if (dragged_item.on_ground) {
                    dragged_item.delete();
                } else {
                    unequip(dragged_item);
                    dragged_item.delete();
                }
                put_in_trash = true;
            } else if (Mouse.x > inventory_x - 5) {
                // Mouse is hovering over inventory, so check if it's possible
                for (i in 0...inventory_slots) {
                    if (Math.point_box_intersect(Mouse.x, Mouse.y, inventory_x, inventory_y + i * inventory_slot_size,
                        inventory_slot_size, inventory_slot_size)) 
                    {
                        slot_index = i;
                        break;
                    }
                }
                if (slot_index != -1) {
                    put_in_inventory = true;
                }

                // Can equip only one type of armor or weapon
                if (dragged_item.type == ItemType_Armor) {
                    for (i in 0...inventory_slots) {
                        if (i != slot_index 
                            && inventory[i] != null 
                            && inventory[i] != dragged_item
                            && inventory[i].type == ItemType_Armor 
                            && inventory[i].armor_type == dragged_item.armor_type) 
                        {
                            put_in_inventory = false;
                            break;
                        }
                    }
                }
                // Can equip only one weapon
                if (dragged_item.type == ItemType_Weapon) {
                    for (i in 0...inventory_slots) {
                        if (i != slot_index 
                            && inventory[i] != null 
                            && inventory[i] != dragged_item
                            && inventory[i].type == ItemType_Weapon) 
                        {
                            put_in_inventory = false;
                            break;
                        }
                    }
                }     
            }

            if (put_in_inventory) {
                if (dragged_item.on_ground) {
                    // Dropping item from ground into inventory

                    // If slot is occupied, switch two items
                    if (inventory[slot_index] != null) {
                        unequip(inventory[slot_index]);
                        inventory[slot_index].x = dragged_item.x;
                        inventory[slot_index].y = dragged_item.y;
                        inventory[slot_index].on_ground = true;
                    }
                    equip(dragged_item, slot_index);
                    dragged_item.on_ground = false;
                    dragged_item.x = -1;
                    dragged_item.y = -1;
                } else {
                    // Dropping item from inventory into inventory

                    // If slot is occupied, switch two items
                    if (inventory[slot_index] != null) {
                        inventory[dragged_item_inventory_slot] = inventory[slot_index];
                    }
                    inventory[slot_index] = dragged_item;
                }
            } else if (!put_in_trash) {
                var drop_x = Std.int(Mouse.x / tilesize);
                var drop_y = Std.int(Mouse.y / tilesize);

                var dropped_on_dude = false;
                for (dude in Entity.get(Dude)) {
                    if (dude.active && dude.x == drop_x && dude.y == drop_y) {
                        dropped_on_dude = true;
                        break;
                    }
                }

                var can_drop: Bool;
                if (dragged_item.type == ItemType_Bomb) {
                    // Bombs can be dropped on walls and enemies
                    can_drop = !out_of_bounds(drop_x, drop_y) 
                    && Math.abs(drop_x - player.x) < 2 
                    && Math.abs(drop_y - player.y) < 2;

                    if (walls[drop_x][drop_y] || dropped_on_dude) {
                        bomb_used = true;
                    }
                } else {
                    can_drop = !out_of_bounds(drop_x, drop_y) 
                    && Math.abs(drop_x - player.x) < 2 
                    && Math.abs(drop_y - player.y) < 2
                    && !walls[drop_x][drop_y]
                    && !dropped_on_dude;
                }
                // Can't drop item onto item
                for (item in Entity.get(Item)) {
                    if (item.on_ground && item.x == drop_x && item.y == drop_y) {
                        can_drop = false;
                    }
                }

                if (!can_drop) {
                    make_message("You can't drop the item there!");
                }

                function drop_bomb(item) {
                    if (walls[item.x][item.y]) {
                        explosion_happened = true;
                    }
                    walls[item.x][item.y] = false;
                    for (dude in Entity.get(Dude)) {
                        if (dude.active && dude.x == drop_x && dude.y == drop_y) {
                            dude.blown = true;
                            explosion_happened = true;
                            break;
                        }
                    }
                    if (explosion_happened) {
                        explosion_x = drop_x;
                        explosion_y = drop_y;
                        item.delete();
                    }
                }

                if (dragged_item.on_ground) {
                    // Change item position on ground
                    if (can_drop) {
                        dragged_item.x = drop_x;
                        dragged_item.y = drop_y;
                        if (dragged_item.type == ItemType_Bomb) {
                            drop_bomb(dragged_item);
                        }
                    }
                } else {
                    if (can_drop) {
                        unequip(dragged_item);
                        dragged_item.x = drop_x;
                        dragged_item.y = drop_y;
                        dragged_item.on_ground = true;

                        if (dragged_item.type == ItemType_Bomb) {
                            drop_bomb(dragged_item);
                        }
                    } else {
                        inventory[dragged_item_inventory_slot] = dragged_item;
                    }
                }
            }


            dragged_item = null;
            if (bomb_used) {
                state = GameState_PlayerVisual;
            } else {
                state = GameState_PlayerTurn;
            }
        }

        render();
    }

    function poke_visual_pos(x, y, dx, dy, dst: Float, timer, timer_max): Vector2 {
        // Starts at (x, y), goes dst away from it, comes back
        var progress = 0.5 - Math.abs(timer / timer_max - 0.5);
        return {x: (x + 0.5) * tilesize + dx * progress * dst + dx * tilesize / 2, y: (y + 0.5) * tilesize + dy * progress * dst + dy * tilesize / 2};
    }

    function straight_visual_pos(x, y, dx, dy, dst, timer, timer_max): Vector2 {
        // Goes in a straight line from (x, y) 
        var progress = timer / timer_max;
        return {x: (x + 0.5) * tilesize + dx * progress * dst, y: (y + 0.5) * tilesize + dy * progress * dst};
    }


    function update_player_visual() {
        var stop_visual = false;

        var move_progress = state_timer / move_visual_timer_max;
        if (player.moved) {
            player.real_x = Std.int(player.x * tilesize + player.dx * move_progress * tilesize);
            player.real_y = Std.int(player.y * tilesize + player.dy * move_progress * tilesize);
        }

        render();

        // Draw weapon visual
        if (player.attacked) {
            var angle = 0.0;
            if (player.dx == 1 && player.dy == 0) {
                angle = 0;
            } else if (player.dx == 0 && player.dy == 1) {
                angle = 90;
            } else if (player.dx == -1 && player.dy == 0) {
                angle = 180;
            } else if (player.dx == 0 && player.dy == -1) {
                angle = 270;
            }

            switch (player.weapon) {
                case WeaponType_None: {
                    var visual_pos = poke_visual_pos(player.x, player.y, player.dx, player.dy,
                        tilesize, state_timer, weapon_visual_timer_max);
                    Gfx.fill_circle(visual_pos.x, visual_pos.y, 10, Col.RED);
                }
                case WeaponType_Sword: {
                    var visual_pos = poke_visual_pos(player.x, player.y, player.dx, player.dy,
                        tilesize, state_timer, weapon_visual_timer_max);
                    var tri = [0, tilesize / 4, 0, -tilesize / 4, tilesize / 4, 0];
                    Math.rotate_vertices(tri, 0, 0, angle);
                    Math.translate_vertices(tri, visual_pos.x, visual_pos.y);
                    Gfx.fill_tri_array(tri, Col.RED);
                }
                case WeaponType_Spear: {
                    var visual_pos = poke_visual_pos(player.x, player.y, player.dx, player.dy,
                        2.5 * tilesize, state_timer, weapon_visual_timer_max);
                    var tri = [0, tilesize / 8, 0, -tilesize / 8, tilesize / 3, 0];
                    Math.rotate_vertices(tri, 0, 0, angle);
                    Math.translate_vertices(tri, visual_pos.x, visual_pos.y);
                    Gfx.fill_tri_array(tri, Col.RED);

                    // Stop at wall( think about another way to stop(what if another visual is longer?))
                    var visual_cell_x = Std.int(visual_pos.x / tilesize);
                    var visual_cell_y = Std.int(visual_pos.y / tilesize);
                    var visual_card_x = Std.int(visual_cell_x / card_width);
                    var visual_card_y = Std.int(visual_cell_y / card_height);
                    if (out_of_bounds(visual_cell_x, visual_cell_y) 
                        || walls[visual_cell_x][visual_cell_y]
                        || cards[visual_card_x][visual_card_y].covered) 
                    {
                        stop_visual = true;
                    }
                }
                case WeaponType_Bow: {
                    var visual_pos = straight_visual_pos(player.x, player.y, player.dx, player.dy,
                        Std.int(Math.max(map_width, map_height)) * tilesize, state_timer, bow_visual_timer_max);
                    var tri = [0, tilesize / 16, 0, -tilesize / 16, tilesize / 4, 0];
                    Math.rotate_vertices(tri, 0, 0, angle);
                    Math.translate_vertices(tri, visual_pos.x, visual_pos.y);
                    Gfx.fill_tri_array(tri, Col.RED);

                    // Stop at wall
                    var visual_cell_x = Std.int(visual_pos.x / tilesize);
                    var visual_cell_y = Std.int(visual_pos.y / tilesize);
                    var visual_card_x = Std.int(visual_cell_x / card_width);
                    var visual_card_y = Std.int(visual_cell_y / card_height);
                    if (out_of_bounds(visual_cell_x, visual_cell_y) 
                        || walls[visual_cell_x][visual_cell_y]
                        || cards[visual_card_x][visual_card_y].covered) 
                    {
                        stop_visual = true;
                    }
                }
                case WeaponType_Laser: {
                    var x1 = (player.x + 0.5) * tilesize;
                    var y1 = (player.y + 0.5) * tilesize;
                    var x2: Float;
                    if (player.dx < 0) {
                        x2 = 0;
                    } else if (player.dx > 0) {
                        x2 = map_width * tilesize;
                    } else {
                        x2 = x1;
                    }
                    var y2: Float;
                    if (player.dy < 0) {
                        y2 = 0;
                    } else if (player.dy > 0) {
                        y2 = map_height * tilesize;
                    } else {
                        y2 = y1;
                    }

                    var old_thickness = Gfx.line_thickness;
                    Gfx.line_thickness = 10;
                    Gfx.draw_line(x1, y1, x2, y2, Col.RED);
                    Gfx.line_thickness = old_thickness;
                }
            }
        }


        state_timer++;
        var max = 0;
        if (player.moved) {
            max = move_visual_timer_max;
        } else if (player.attacked) {
            if (player.weapon == WeaponType_Bow) {
                max = bow_visual_timer_max;
            } else {
                max = weapon_visual_timer_max;
            }
        }
        if (state_timer > max || stop_visual) {
            state = GameState_PlayerTurnResult;
            state_timer = 0;
        }
    }

    function update_player_turn_result() {
        if (player.moved) {
            player.x += player.dx;
            player.y += player.dy;
            player.real_x = player.x * tilesize;
            player.real_y = player.y * tilesize;
        } else if (player.attacked) {
            // decrease hp of hit dude, make him dead if hp = 0
            var hit_dude:Dude = null;
            var hit_cells: Array<IntVector2>;
            var attack_distance = 0;
            switch (player.weapon) {
                case WeaponType_None: attack_distance = 1;
                case WeaponType_Sword: attack_distance = 1;
                case WeaponType_Spear: attack_distance = 2;
                case WeaponType_Bow: attack_distance = Std.int(Math.max(map_width, map_height));
                case WeaponType_Laser: attack_distance = Std.int(Math.max(map_width, map_height));
            }

            var attack_damage = fist_damage;
            for (i in 0...inventory_slots) {
                if (inventory[i] != null && inventory[i].type == ItemType_Weapon) {
                    attack_damage = inventory[i].value;
                    break;
                }
            }
            // Add armor bonuses
            for (i in 0...inventory_slots) {
                if (inventory[i] != null) {
                    attack_damage += inventory[i].dmg_bonus;
                    break;
                }
            }
            // Damage potion adds damage
            if (damage_potion_timer > 0) {
                attack_damage++;
            }
            // Devil arcana doubles damage
            if (active_arcana == ArcanaType_Devil && arcana_timer > 0) {
                attack_damage *= 2;
            }
            if (GOD_MODE) {
                attack_damage = 100000;
            }

            var hit_cells = new Array<IntVector2>();
            var i = 0;
            var hit_x = 0;
            var hit_y = 0;
            while (i <= attack_distance) {
                hit_x = player.x + i * player.dx;
                hit_y = player.y + i * player.dy;
                if (out_of_bounds(hit_x, hit_y) || walls[hit_x][hit_y]) {
                    break;
                } else {
                    hit_cells.push({x: hit_x, y: hit_y});
                }
                i++;
            }
            for (dude in Entity.get(Dude)) {
                if (dude.active) {
                    for (cell in hit_cells) {
                        if (dude.x == cell.x && dude.y == cell.y) {
                            dude.hp -= attack_damage;
                            if (dude.hp <= 0) {
                                dude.dead = true;
                            } else {
                                dude.hit = true;
                            }
                            break;
                        }
                    }
                }
            }

            // Discharge laser
            if (player.weapon == WeaponType_Laser) {
                for (i in 0...inventory_slots) {
                    if (inventory[i] != null && inventory[i].type == ItemType_Weapon && inventory[i].weapon_type == WeaponType_Laser) {
                        if (player.attacked) {
                            inventory[i].value = 0;
                        }
                    }
                }
            }
        }

        // Recharge lasers
        for (item in Entity.get(Item)) {
            if (item.type == ItemType_Weapon && item.weapon_type == WeaponType_Laser) {
                if (item.value != item.value_max && Random.chance(30)) {
                    // Lasers on the ground also recharge
                    if (item.on_ground) {
                        item.value++;
                    } else if (!player.attacked) {
                        item.value++;
                    }
                }
            }
        }
        // "Attack" dudes that were hit with a bomb
        for (dude in Entity.get(Dude)) {
            if (dude.blown) {
                dude.hp -= 5;
                if (dude.hp <= 0) {
                    dude.dead = true;
                } else {
                    dude.hit = true;
                }
            }
        }
        // Moon arcana recharges health
        if (active_arcana == ArcanaType_Moon && arcana_timer > 0) {
            player.hp++;
            if (player.hp > player.hp_max) {
                player.hp = player.hp_max;
            }
        }
        player.moved = false;
        player.attacked = false;
        player.dx = 0;
        player.dy = 0;

        // Enemies do stuff after player
        // Speed potion makes enemies skip every other turn
        if (!(speed_potion_timer > 0)
            || (speed_potion_timer > 0) && speed_potion_timer % 2 == 0) {
            for (dude in Entity.get(Dude)) {
                if (dude.active && !dude.dead) {
                    switch (dude.type) {
                        case DudeType_Follower: {
                            if (active_arcana == ArcanaType_Lovers) {
                                // Enemies move randomly without attacking during lovers arcana
                                var move_map = get_free_map();
                                function random_nearby_cell(x, y): IntVector2 {
                                    for (dx in -1...2) {
                                        for (dy in -1...2) {
                                            if (Math.abs(dx + dy) == 1 
                                                && !out_of_bounds( x+ dx, y + dy) 
                                                && move_map[x + dx][y + dy]) 
                                            {
                                                return {x: x + dx, y: y + dy};
                                            }
                                        }
                                    }
                                    return {x: -1, y: -1};
                                }
                                var cell = random_nearby_cell(dude.x, dude.y);
                                if (cell.x != -1) {
                                    dude.moved = true;
                                    dude.dx = cell.x - dude.x;
                                    dude.dy = cell.y - dude.y;
                                }
                            } else {
                                // Check if dude can see player
                                if (!dude.following_player) {
                                    var can_see_player = true;
                                    dude.points = new Array<IntVector2>();
                                    // Check points on a line between dude and player
                                    var x0 = dude.x;
                                    var y0 = dude.y;
                                    var x1 = player.x;
                                    var y1 = player.y;
                                    var dx = (x1 - x0) / 50.0;
                                    var dy = (y1 - y0) / 50.0;
                                    var x = x0;
                                    var y = y0;
                                    var prev_x = x;
                                    var prev_y = y;
                                    for (t in 0...50) {
                                        x = Std.int(x0 + dx * t);
                                        y = Std.int(y0 + dy * t);
                                        if (x != prev_x || y != prev_y) {
                                            dude.points.push({x: x, y: y});
                                            if (walls[x][y]) {
                                                can_see_player = false;
                                            }
                                            prev_x = x;
                                            prev_y = y;
                                        }
                                    }

                                    if (can_see_player) {
                                        dude.following_player = true;
                                    }
                                }

                                // Dude has seen the player and is following him
                                if (dude.following_player) {
                                    var dude_player_dx = player.x - dude.x;
                                    var dude_player_dy = player.y - dude.y;
                                    // Attack if next to player
                                    if (Math.abs(dude_player_dx) + Math.abs(dude_player_dy) == 1) {
                                        dude.attacked = true;
                                        if (!player.moved) {
                                            player.incoming_damage += dude.dmg;
                                        }
                                        dude.dx = Math.sign(dude_player_dx);
                                        dude.dy = Math.sign(dude_player_dy);
                                    }

                                    // Otherwise chase player(to the new position)
                                    if (!dude.attacked) {
                                        var path = a_star(dude.x, dude.y, player.x, player.y);
                                        if (path.length > 1) {
                                            dude.moved = true;
                                            dude.dx = path[path.length - 2].x - dude.x;
                                            dude.dy = path[path.length - 2].y - dude.y;
                                        }
                                    }
                                }
                            }
                        }
                        case DudeType_Shooter: {
                            var dude_player_dx = Math.sign(player.x - dude.x);
                            var dude_player_dy = Math.sign(player.y - dude.y);
                            if (dude_player_dx == 0 || dude_player_dy == 0) {
                                var x: Int = Std.int(dude.x);
                                var y: Int = Std.int(dude.y);
                                while (true) {
                                    x += Std.int(dude_player_dx); 
                                    y += Std.int(dude_player_dy);
                                    if (out_of_bounds(x, y) || walls[x][y]) {
                                        break;
                                    } else if (!out_of_bounds(x, y) && x == player.x && y == player.y) {
                                        dude.attacked = true;
                                        player.incoming_damage += dude.dmg;
                                        dude.dx = dude_player_dx;
                                        dude.dy = dude_player_dy;
                                        break;
                                    }
                                }
                            }
                        }
                        case DudeType_Stander: {
                            var dude_player_dx = player.x - dude.x;
                            var dude_player_dy = player.y - dude.y;
                            if (Math.abs(dude_player_dx) + Math.abs(dude_player_dy) == 1) {
                                dude.attacked = true;
                                player.incoming_damage += dude.dmg;
                                dude.dx = dude_player_dx;
                                dude.dy = dude_player_dy;
                            }
                        }
                        case DudeType_Ghost: {
                            var dude_player_dx = player.x - dude.x;
                            var dude_player_dy = player.y - dude.y;
                            // Attack if next to player
                            if (Math.abs(dude_player_dx) + Math.abs(dude_player_dy) == 1) {
                                dude.attacked = true;
                                if (!player.moved) {
                                    player.incoming_damage += dude.dmg;
                                }
                                dude.dx = Math.sign(dude_player_dx);
                                dude.dy = Math.sign(dude_player_dy);
                            }

                            // Otherwise chase player(to the new position)
                            if (!dude.attacked) {
                                if (Random.chance(65)) {
                                    dude.moved = true;
                                    dude.dx = Math.sign(dude_player_dx);
                                    dude.dy = Math.sign(dude_player_dy);
                                    // Stop ghost from moving onto player
                                    if (Math.abs(dude_player_dx) == 1 && Math.abs(dude_player_dy) == 1) {
                                        if (Random.chance(50)) {
                                            dude.dx = 0;
                                        } else {
                                            dude.dy = 0;
                                        }
                                    }
                                }
                            }
                        }
                        default: trace("Unhandled dude type in update_player_turn_result()!");
                    }
                }
            }
        }

        // Update dude hp in info
        for (dude in Entity.get(Dude)) {
            update_dude_info(dude);
        }

        var card_with_player_pos = card_at_position(player.x, player.y);
        var card_with_player = cards[card_with_player_pos.x][card_with_player_pos.y];
        // Set card that has player to complete
        card_with_player.visited = true;
        // Activate arcana card if player stepped onto center
        if (card_with_player.type == CardType_Arcana && !card_with_player.arcana_activated 
            && (player.x - 1) % card_width == 0 && (player.y - 2) % card_height == 0) 
        {
            do_arcana_magic(card_with_player.arcana);
            card_with_player.arcana_activated = true;
        }

        render();

        // Time based arcanas here
        if (arcana_timer > 0 && 
            (active_arcana == ArcanaType_Lovers 
                || active_arcana == ArcanaType_Sun
                || active_arcana == ArcanaType_HangedMan
                || active_arcana == ArcanaType_Devil
                || active_arcana == ArcanaType_Moon
                || active_arcana == ArcanaType_Fortune)
            ) 
        {
            arcana_timer--;
            if (arcana_timer <= 0) {
                make_message('$active_arcana has ended');
                active_arcana = null;
            }
        }

        state = GameState_EnemyVisual;
    }

    function update_enemy_visual() {
        var all_visuals_complete = true;

        var visual_progress = 0.0;
        for (dude in Entity.get(Dude)) {
            if (dude.moved) {
                visual_progress = Math.min(1, state_timer / move_visual_timer_max);
                dude.real_x = Std.int(dude.x * tilesize + dude.dx * tilesize * visual_progress);
                dude.real_y = Std.int(dude.y * tilesize + dude.dy * tilesize * visual_progress);
                
                if (state_timer < move_visual_timer_max) {
                    all_visuals_complete = false;
                }
            } else if (dude.hit) {
                dude.angle = -Math.sin(state_timer / 2) * 15;
                if (state_timer < weapon_visual_timer_max) {
                    all_visuals_complete = false;
                }
            } else if (dude.dead) {
                dude.angle = 20 * state_timer / move_visual_timer_max;
                if (state_timer < move_visual_timer_max) {
                    all_visuals_complete = false;
                }
            }
        }

        if (player.incoming_damage > 0) {
            player.angle = Math.sin(state_timer / 2) * 15;
        }

        render();

        for (dude in Entity.get(Dude)) {
            if (dude.attacked) {
                // Draw attack visual
                switch (dude.type) {
                    case DudeType_Follower: {
                        if (state_timer < weapon_visual_timer_max) {
                            var visual_pos = poke_visual_pos(dude.x, dude.y, dude.dx, dude.dy,
                                50, state_timer, weapon_visual_timer_max);
                            Gfx.fill_circle(visual_pos.x, visual_pos.y, 10, Col.BLUE);
                            all_visuals_complete = false;
                        }
                    }
                    case DudeType_Stander: {
                        if (state_timer < weapon_visual_timer_max) {
                            var visual_pos = poke_visual_pos(dude.x, dude.y, dude.dx, dude.dy,
                                50, state_timer, weapon_visual_timer_max);
                            Gfx.fill_circle(visual_pos.x, visual_pos.y, 10, Col.BLUE);
                            all_visuals_complete = false;
                        }
                    }
                    case DudeType_Shooter: {
                        var visual_pos = poke_visual_pos(dude.x, dude.y, dude.dx, dude.dy,
                            Std.int(Math.max(map_width, map_height)) * tilesize, state_timer, 
                            bow_visual_timer_max);
                        Gfx.fill_circle(visual_pos.x, visual_pos.y, 10, Col.BLUE);

                        // Stop at wall
                        var stop_visual = false;
                        var visual_cell_x = Std.int(visual_pos.x / tilesize);
                        var visual_cell_y = Std.int(visual_pos.y / tilesize);
                        var visual_card_x = Std.int(visual_cell_x / card_width);
                        var visual_card_y = Std.int(visual_cell_y / card_height);
                        if (out_of_bounds(visual_cell_x, visual_cell_y) 
                            || walls[visual_cell_x][visual_cell_y]
                            || cards[visual_card_x][visual_card_y].covered
                            || (player.x == visual_cell_x && player.y == visual_cell_y)) 
                        {
                            stop_visual = true;
                        }

                        if (!stop_visual && state_timer < bow_visual_timer_max) {
                            all_visuals_complete = false;
                        }
                    }
                    case DudeType_Ghost: {
                        if (state_timer < weapon_visual_timer_max) {
                            var visual_pos = poke_visual_pos(dude.x, dude.y, dude.dx, dude.dy,
                                50, state_timer, weapon_visual_timer_max);
                            Gfx.fill_circle(visual_pos.x, visual_pos.y, 10, Col.WHITE);
                            all_visuals_complete = false;
                        }
                    }
                    default:
                }
            }
        }

        if (explosion_happened) {
            Gfx.fill_circle((explosion_x + 0.5) * tilesize, (explosion_y + 0.5) * tilesize, 30 * state_timer / move_visual_timer_max, Col.YELLOW);
            if (state_timer < move_visual_timer_max) {
                all_visuals_complete = false;
            }
        }


        state_timer++;
        if (all_visuals_complete) {
            state = GameState_EnemyTurnResult;
            state_timer = 0;

            for (dude in Entity.get(Dude)) {
                dude.hit = false;
            }
            explosion_happened = false;
        }
    }

    function update_enemy_turn_result() {
        var dead_dudes = new Array<Dude>();
        for (dude in Entity.get(Dude)) {
            if (dude.active) {
                if (dude.moved) {
                    dude.x += dude.dx;
                    dude.y += dude.dy;
                    dude.real_x = dude.x * tilesize;
                    dude.real_y = dude.y * tilesize;
                } else if (dude.dead) {
                    dead_dudes.push(dude);
                }
                dude.moved = false;
                dude.attacked = false;
                dude.dx = 0;
                dude.dy = 0;
            }
        }

        var dudes = Entity.get(Dude);
        for (dude in dead_dudes) {
            dudes.remove(dude);
        }

        // Dude cards get completed when all dudes spawned from it are dead
        for (x in 0...cardmap_width) {
            for (y in 0...cardmap_height) {
                var card = cards[x][y];
                if (!card.covered && card.type == CardType_Dude && !card.completed) {
                    var all_dudes_dead = true;
                    for (dude in card.my_dudes) {
                        if (!dude.dead) {
                            all_dudes_dead = false;
                            break;
                        }
                    }
                    if (all_dudes_dead) {
                        card.completed = true;
                    }
                }
            }
        }

        // Apply damage to player
        if (player.incoming_damage > 0) {
            player.hp -= player.incoming_damage;
            player.incoming_damage = 0;
        }

        // TODO: Do stuff with player death here

        // Increment card age
        for (x in 0...cardmap_width) {
            for (y in 0...cardmap_height) {
                if (!cards[x][y].covered) {
                    cards[x][y].turn_age++;
                }
            }
        }

        //
        //  CARD UPDATE
        //

        // Start updating cards when less than 5 / 15 cards are covered
        var uncovered_percentage = cards_covered / total_cards;
        if (uncovered_percentage < 5 / 15 && UPDATE_CARDS) {
            card_update_timer--;

            if (active_arcana == ArcanaType_Empress) {
                // empress accelerates updates
                card_update_timer--;

                arcana_timer--;
                if (arcana_timer <= 0) {
                    active_arcana = null;
                }
            }

            if (uncovered_percentage < 3 / 15) {
                // If only 1-2 cards left, update faster
                card_update_timer--;
            }
            if (card_update_timer <= 0) {
                // Update a card
                var card_queue = new Array<Card>();
                for (x in 0...cardmap_width) {
                    for (y in 0...cardmap_height) {
                        var card = cards[x][y];
                        if (!card.covered && card.completed) {
                            card_queue.push(cards[x][y]);
                        }
                    }
                }
                card_queue.sort(function(x, y) {return y.turn_age - x.turn_age;});

                function is_empty(card:Card) {
                    if (Std.int(player.x / card_width) == card.x && Std.int(player.y / card_height) == card.y) {
                        return false;
                    }
                    for (dude in Entity.get(Dude)) {
                        if (Std.int(dude.x / card_width) == card.x && Std.int(dude.y / card_height) == card.y) {
                            return false;
                        }
                    }
                    return true;
                }

                function is_completed(card:Card) {
                    // TODO: add specific checks for treasure cards, boss cards, etc.
                    if (!card.visited) {
                        return false;
                    }
                    return true;
                }

                var updated_card:Card = null;
                for (card in card_queue) {
                    if (is_empty(card) && is_completed(card) || card.update_age > too_old_age) {
                        updated_card = card;
                        break;
                    }
                }

                if (updated_card != null) {
                    // Reset card and re-generate
                    reset_card(updated_card);

                    card_update_timer = card_update_timer_max;
                    updated_card.type = generate_card_type();
                    if (default_card_type != null) {
                        updated_card.type = default_card_type;
                    }

                    generate_card(updated_card);

                    updated_card.level = card_level;
                    cards_covered++;

                    card_level_increment_timer--;
                    if (card_level_increment_timer <= 0) {
                        card_level++;
                        card_level_increment_timer = Random.int(card_level_increment_timer_min, card_level_increment_timer_max); 
                    }

                    for (x in 0...cardmap_width) {
                        for (y in 0...cardmap_height) {
                            cards[x][y].update_age++;
                        }
                    }

                    updated_card.just_updated_timer = 60;
                }
            }
        }

        render();


        var card_with_player_pos = card_at_position(player.x, player.y);
        var card_with_player = cards[card_with_player_pos.x][card_with_player_pos.y];
        // Activate shop card, if player stepped on one
        if (card_with_player.type == CardType_Shop && !card_with_player.arcana_activated 
            && (player.x - 1) % card_width == 0 && (player.y - 2) % card_height == 0) 
        {
            state = GameState_Shop;
        } else {
            state = GameState_PlayerTurn;
        }

        var entity_states = new Array<String>();
        entity_states.push(serialize(player));
        for (dude in Entity.get(Dude)) {
            entity_states.push(serialize(dude));
        }
        history.push(entity_states);
    }

    function update_card_flip() {
        render();
        Gfx.fill_box(flipped_card.x * card_width * tilesize, flipped_card.y * card_height * tilesize, card_width * tilesize, card_height * tilesize, Col.BLACK);
        if (state_timer / card_flip_timer_max < 0.5) {
            Gfx.scale(1 - 2 * state_timer / card_flip_timer_max, 1);
            Gfx.draw_image(flipped_card.x * card_width * tilesize, flipped_card.y * card_height * tilesize, "card_back");
            Gfx.scale(1, 1);
        } else {
            Gfx.scale(2 * (state_timer / card_flip_timer_max - 0.5), 1);
            Gfx.draw_image(flipped_card.x * card_width * tilesize, flipped_card.y * card_height * tilesize, "card_front");
            Gfx.scale(1, 1);
        }
        Text.display(0, 0, '${state_timer}', Col.YELLOW);

        state_timer++;
        if (state_timer > card_flip_timer_max) {
            state = GameState_PlayerTurn;
            state_timer = 0;
            cards[flipped_card.x][flipped_card.y].covered = false;
            // Fortune arcana doubles all money
            if (arcana_timer > 0 && active_arcana == ArcanaType_Fortune) {
                for (item in Entity.get(Item)) {
                    if (item.on_ground && item.type == ItemType_Money 
                        && Std.int(item.x / card_width) == flipped_card.x
                        && Std.int(item.y / card_height) == flipped_card.y) 
                    {
                        item.amount *= 2;
                    }
                }
            }
            cards_covered--;
        }
    }

    function update_shop() {
        var card_pos = card_at_position(player.x, player.y);
        var shop_inventory = shop_inventories['${card_pos.x}_${card_pos.y}'];

        render();
        // Draw shop ui
        Gfx.fill_box(1 * tilesize, 1 * tilesize, (map_width - 2) * tilesize, (map_height - 2) * tilesize, Col.GRAY);
        Text.display(2 * tilesize, 1 * tilesize, "Shop");
        GUI.x = 2 * tilesize;
        GUI.y = 2 * tilesize;
        GUI.auto_text_button("Upgrade weapon, cost: 3", function() {
            if (money >= 3) {
                money -= 3;
            }
            var found_weapon = false;
            for (i in 0...inventory_slots) {
                var item = inventory[i];
                if (item != null && item.type == ItemType_Weapon) {
                    item.value++;
                    found_weapon = true;
                    break;
                }
            } 

            if (!found_weapon) {
                fist_damage++;
            }
        });
        if (Input.pressed(Key.ESCAPE)) {
            state = GameState_PlayerTurn;
        }
        GUI.auto_text_button("Exit", function() { state = GameState_PlayerTurn; }, 3);
        Text.display((map_width - 10) * tilesize, (map_width - 3) * tilesize, "Right click items in inventory to sell them");
        Text.display((map_width - 10) * tilesize, (map_width - 2) * tilesize, "Right click items in shop to buy them");
        
        // Shop inventory
        for (i in 0...shop_inventory_slots) {
            Gfx.draw_box(shop_inventory_x + i * tilesize, shop_inventory_y, tilesize, tilesize, Col.WHITE);
            if (shop_inventory[i] != null) {
                draw_item(shop_inventory_x + i * tilesize, shop_inventory_y, shop_inventory[i]);
            }
        }


        if (Mouse.x >= inventory_x) {
            // Selling items
            var mouse_x = Std.int(Mouse.x / tilesize);
            var mouse_y = Std.int(Mouse.y / tilesize);
            var hover_item: Item = null;
            var hover_slot = 0;
            for (i in 0...inventory_slots) {
                if (inventory[i] != null
                    && Math.point_box_intersect(Mouse.x, Mouse.y, inventory_x, inventory_y + i * inventory_slot_size,
                        inventory_slot_size, inventory_slot_size)) 
                {
                    hover_item = inventory[i];
                    hover_slot = i;
                    break;
                }
            }

            if (hover_item != null) {
                // TODO: customize sell value
                var sell_value = 7;
                // Draw hover info
                Gfx.fill_box(Mouse.x, Mouse.y, tilesize * 2.5, tilesize * 0.75, Col.GRAY);
                if (hover_item.type != ItemType_Money) {
                    Text.display(Mouse.x, Mouse.y, 'Sells for: $sell_value');
                }

                if (Mouse.right_click()) {
                    money += sell_value;
                    unequip(hover_item);
                    hover_item.delete();
                }
            }
        } else {
            // Buying items
            var mouse_x = Std.int(Mouse.x / tilesize);
            var mouse_y = Std.int(Mouse.y / tilesize);
            var hover_item: Item = null;
            var hover_slot = 0;
            for (i in 0...shop_inventory_slots) {
                if (shop_inventory[i] != null
                    && Math.point_box_intersect(Mouse.x, Mouse.y, 
                        shop_inventory_x + i * shop_inventory_slot_size, shop_inventory_y,
                        shop_inventory_slot_size, shop_inventory_slot_size)) 
                {
                    hover_item = shop_inventory[i];
                    hover_slot = i;
                    break;
                }
            }

            if (hover_item != null) {

                // TODO: customize buy value
                var buy_value = 7;
                // Draw hover info
                Gfx.fill_box(Mouse.x, Mouse.y, tilesize * 2.5, tilesize * 0.75, Col.GRAY);
                Text.display(Mouse.x, Mouse.y, 'Cost: $buy_value');

                if (Mouse.right_click()) {
                    if (money < buy_value) {
                        make_message('You do not have enough money');
                    } else {
                        var free_slot_found = false;
                        for (i in 0...inventory_slots) {
                            if (inventory[i] == null) {
                                equip(hover_item, i);
                                free_slot_found = true;
                                break;
                            }
                        }

                        if (free_slot_found) {
                            money -= buy_value;
                            shop_inventory[hover_slot] = null;
                        } else {
                            make_message('Inventory is full');
                        }
                    }
                }
            }
        }
    }

    function update() {
        if (Input.just_pressed(Key.Z) && history.length > 0 && state == GameState_PlayerTurn) {
            var previous_state = history.pop();
            unserialize(player, previous_state[0]);
            player.dx = 0;
            player.dy = 0;
            Entity.get(Dude).splice(0, Entity.get(Dude).length);
            for (i in 1...previous_state.length) {
                var dude = new Dude();
                unserialize(dude, previous_state[i]);
                dude.dx = 0;
                dude.dy = 0;
            }
        }

        function get_item_info(item: Item): String {
            switch (item.type) {
                case ItemType_Consumable: {
                    return 'Consumable: ${item.name}\nType: ${item.consumable_type}\nValue: ${item.value}';
                }
                case ItemType_Armor: {
                    var info = 'Armor: ${item.name}\nType: ${item.armor_type}';
                    if (item.hp_bonus != 0) {
                        info += '\n+hp: ${item.hp_bonus}';
                    }
                    if (item.dmg_bonus != 0) {
                        info += '\n+dmg: ${item.dmg_bonus}';
                    }
                    return info;
                }
                case ItemType_Weapon: {
                    var info = 'Weapon: ${item.name}\nType: ${item.weapon_type}\nDamage: ${item.value}\n';
                    return info;
                }
                default: return "default item info";
            }
        }
        function get_dude_info(dude: Dude): String {
            return '${dude.name}\n${dude.hp}/${dude.hp_max}';
        }

        // Item info on hover
        // Enemies takes precedence over items
        var hover_x = Std.int(Mouse.x / tilesize);
        var hover_y = Std.int(Mouse.y / tilesize);
        hover_info = "";
        if (dragged_item != null) {
            // Dragged item always shows info
            hover_info = get_item_info(dragged_item);
        } else if (!out_of_bounds(hover_x, hover_y)) {
            // Ground items and enemies
            for (dude in Entity.get(Dude)) {
                if (dude.active && hover_x == dude.x && hover_y == dude.y) {
                    hover_info = get_dude_info(dude);
                    break;
                }
            }
            if (hover_info == "") {
                for (item in Entity.get(Item)) {
                    if (item.on_ground && hover_x == item.x && hover_y == item.y) {
                        hover_info = get_item_info(item);
                        break;
                    }
                }
            }
        } else {
            // Inventory items
            for (i in 0...inventory_slots) {
                if (inventory[i] != null
                    && Math.point_box_intersect(Mouse.x, Mouse.y, inventory_x, inventory_y + i * inventory_slot_size,
                        inventory_slot_size, inventory_slot_size)) 
                {
                    hover_info = get_item_info(inventory[i]);
                    break;
                }
            }
        }

        switch (state) {
            case GameState_PlayerTurn: update_player_turn();
            case GameState_ItemDrag: update_item_drag();
            case GameState_PlayerVisual: update_player_visual();
            case GameState_PlayerTurnResult: update_player_turn_result();
            case GameState_EnemyVisual: update_enemy_visual();
            case GameState_EnemyTurnResult: update_enemy_turn_result();
            case GameState_CardFlip: update_card_flip();
            case GameState_Shop: update_shop();
        }

        // GUI.enum_setter(1000, 800, function(x) { player.weapon = x; }, player.weapon, WeaponType);

        GUI.x = 1000;
        GUI.y = 750;
        GUI.auto_text_button("godmode", function() { GOD_MODE = true; });
        GUI.auto_text_button('increment card level: ${card_level}', function() { card_level++; });
        // Item tester
        // if (Input.just_pressed(Key.SPACE)) { 
        //     for (item in Entity.get(Item)) {
        //         if (item.x == player.x + 1 && item.y == player.y) {
        //             item.delete();
        //             break;
        //         }
        //     }

        //     var old_default_item_type = default_item_type;
        //     default_item_type = ItemType_Armor;
        //     var item = generate_item(treasure_order, treasure_chances);
        //     default_item_type = old_default_item_type;

        //     item.on_ground = true;
        //     item.x = player.x + 1;
        //     item.y = player.y;
        // }
    }
}