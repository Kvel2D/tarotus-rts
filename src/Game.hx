import haxegon.*;
import haxe.ds.ObjectMap;
import haxe.ds.Vector;
import Entity;

using haxegon.MathExtensions;
using Lambda;

enum GameState {
    GameState_PlayerChoice;
    GameState_Turn;
    GameState_Visuals;
    GameState_TurnResult;
    GameState_CardFlip;
    GameState_GameOver;
}

enum CardType {
    CardType_None;
    CardType_Bonus;
    CardType_Player;
    CardType_Enemy;
}

enum BonusType {
    BonusType_None;
    BonusType_Healing;
    BonusType_Damage;
}

@:publicFields
class Card {
    var type = CardType_None;
    var dude_type = DudeType_None;
    var bonus_type = BonusType_None;
    var covered = false;
    var visited = false;
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
    var GOD_MODE = false;

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

    var state = GameState_PlayerChoice;
    var state_timer = 0; // reset to 0 by state at completion
    static inline var move_visual_timer_max = 7;
    static inline var weapon_visual_timer_max = 10;
    static inline var bow_visual_timer_max = 50;
    static inline var card_flip_timer_max = 30;
    static inline var turn_delay = 5;
    var flipped_card: Card;
    var message_text = '';
    var message_timer = 0;
    static inline var message_x = map_width * tilesize / 2;
    static inline var message_y = (map_height - 1) * tilesize;
    static var message_timer_max = 360;

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
    var history = new Array<Array<String>>();
    static inline var choice_timer_max = 20;
    var choice_timer = choice_timer_max;
    var no_action = false;
    var flipped_good_card = false;
    var flipped_bad_card = false;

    var win = false;

    var player_color = Col.ORANGE;
    var enemy_color = Col.DARKBLUE;

    function new() {

        player = new Player();
        player.x = 2;
        player.y = 1;
        player.real_x = player.x * tilesize;
        player.real_y = player.y * tilesize;

        // Set card positions/types
        for (i in 0...cards.length) {
            cards[i] = new Vector<Card>(cardmap_height);

            for (j in 0...cards[i].length) {
                cards[i][j] = new Card();
                var card = cards[i][j];
                card.x = i;
                card.y = j;
                card.covered = true;
            }
        }

        var shuffled = new Array<Card>();
        for (x in 0...cardmap_width) {
            for (y in 0...cardmap_height) {
                shuffled.push(cards[x][y]);
            }
        }
        Random.shuffle(shuffled);

        var dude_types = new Array<DudeType>();
        for (i in 0...Math.floor(shuffled.length / 2)) {
            if (Random.chance(15)) {
                dude_types.push(get_chance(DudeType, dude_type_order, dude_type_chances));
            } else if (Random.chance(30)) {
                dude_types.push(DudeType_Ranged);
            } else {
                dude_types.push(DudeType_Melee);
            }
        }

        // Set types, half is enemy, half is player, one unassigned
        for (i in 0...Math.floor(shuffled.length / 2)) {
            shuffled[i].type = CardType_Enemy;
            shuffled[i].dude_type = dude_types[i];
        }
        for (i in Math.floor(shuffled.length / 2)...(shuffled.length - 1)) {
            if (Random.chance(80)) {
                shuffled[i].type = CardType_Player;
                shuffled[i].dude_type = dude_types[i - Math.floor(shuffled.length / 2)];
            } else {
                shuffled[i].type = CardType_Bonus;
            }
        }

        var unassigned = shuffled[shuffled.length - 1];
        unassigned.type = CardType_None;
        unassigned.covered = false;

        // Generate cards
        for (i in 0...cards.length) {
            for (j in 0...cards[i].length) {
                generate_card(cards[i][j]);
            }
        }

        // Pre draw stuff
        Gfx.create_image('ground', card_width * tilesize, card_height * tilesize);
        Gfx.draw_to_image('ground');
        Gfx.clear_screen(Col.BLACK);
        for (x in 0...card_width) {
            for (y in 0...card_height) {
                Gfx.draw_tile(x * tilesize, y * tilesize, Tiles.Space);
            }
        }
        Gfx.line_thickness = 7;
        for (x in 0...2) {
            Gfx.draw_line(x * card_width * tilesize, 0, x * card_width * tilesize, (cardmap_height - 1) * card_height * tilesize, Col.NIGHTBLUE);
        }
        for (y in 0...2) {
            Gfx.draw_line(0, y * card_height * tilesize, (cardmap_width - 1) * card_width * tilesize, y * card_height * tilesize, Col.NIGHTBLUE);
        }
        Gfx.line_thickness = 1;

        Gfx.create_image('all_card_backs', map_width * tilesize, map_height * tilesize);
        Gfx.draw_to_image('all_card_backs');
        var font_size = Text.currentsize;
        Text.change_size(40);
        for (x in 0...cardmap_width) {
            for (y in 0...cardmap_height) {
                if (unassigned.x == x && unassigned.y == y) {
                    continue;
                }
                draw_card_cover(cards[x][y]);
            }
        }
        Text.change_size(font_size);


        Gfx.create_image('background', Main.screen_height, Main.screen_height);
        Gfx.draw_to_image('background');
        Gfx.draw_image(0, 0, 'all_card_backs');
        Gfx.draw_image(unassigned.x * card_width * tilesize, 
            unassigned.y * card_height * tilesize, 'ground');

        Gfx.create_image('all_card_fronts', map_width * tilesize, map_height * tilesize);
        Gfx.draw_to_image('all_card_fronts');
        for (x in 0...cardmap_width) {
            for (y in 0...cardmap_height) {
                Gfx.draw_image(x * card_width * tilesize, y * card_height * tilesize, 'ground');
            }
        }
        for (dude in Entity.get(Dude)) {
            draw_dude(dude);
        }
        Gfx.draw_to_screen();

        // Canvas for flipping card visual
        Gfx.create_image('card_back', card_width * tilesize, card_height * tilesize);
        Gfx.create_image('card_front', card_width * tilesize, card_height * tilesize);
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

        if (chance_history.get(enum_type).length > 7) {
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

    var dude_type_order = [
    DudeType_Melee,
    DudeType_Ranged,
    DudeType_Hero,
    ];
    var dude_type_chances: Array<Chance> = [
    {val: 1, min: 1, max: 5},
    {val: 1, min: 1, max: 4},
    {val: 1, min: 1, max: 3},
    ];

    // start_index is used to skip EnumType_None
    function random_enum(enum_type:Dynamic, start_index:Int = 1):Dynamic {
        var k = Random.int(start_index, Type.allEnums(enum_type).length - 1);
        return Type.allEnums(enum_type)[k];
    }

    function generate_card(card:Card) {

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

            trace('random_cell_in_card() failed to find a free cell!');
            return out;
        }

        if (card.type == CardType_Player || card.type == CardType_Enemy) {

            var number_of_dudes = 0;
            var hp = 0;
            var dmg = 0;
            switch (card.dude_type) {
                case DudeType_Melee: {
                    number_of_dudes = Random.int(4, 5);
                    hp = 5;
                    dmg = 1;
                }
                case DudeType_Ranged: {
                    number_of_dudes = Random.int(3, 4);
                    hp = 3;
                    dmg = 1;
                }
                case DudeType_Hero: {
                    number_of_dudes = 1;
                    hp = 20;
                    dmg = 3;
                }
                default:
            }

            while (number_of_dudes > 0) {
                number_of_dudes--;

                // Spawn dude
                var dude = new Dude();
                var free_map = get_free_map(false);
                var free_cell = random_cell_in_card(card.x, card.y, function(x, y) { return free_map[x][y]; });
                dude.x = free_cell.x;
                dude.y = free_cell.y;
                dude.real_x = dude.x * tilesize;
                dude.real_y = dude.y * tilesize;
                dude.hp_max = hp;
                dude.hp = dude.hp_max;
                dude.dmg = dmg;
                dude.type = card.dude_type;

                if (card.type == CardType_Player) {
                    dude.faction = DudeFaction_Player;
                } else if (card.type == CardType_Enemy) {
                    dude.faction = DudeFaction_Enemy;
                }
            }
        } else if (card.type == CardType_Bonus) {
            if (Random.chance(50)) {
                card.bonus_type = BonusType_Healing;
            } else {
                card.bonus_type = BonusType_Damage;
            }
        }
    }

    function serialize(entity:Dynamic) {
        var fields = Type.getInstanceFields(Type.getClass(entity));
        var fields_string = '';
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

    function make_message(text: String) {
        message_text = text;
        message_timer = message_timer_max;
    }

    // each bool tells what to filter out
    function get_free_map(filter_covered_cards = true, filter_dudes = true, filter_items = true, 
        filter_player = true): Vector<Vector<Bool>> 
    {
        // Mark items/dudes/player/covered cards as false, don't ignore player
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

        return free_map;
    }

    // Returns empty array if no path is available
    function a_star(x1:Int, y1:Int, x2:Int, y2:Int, include_covered_cards = false):Array<IntVector2> {
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
        move_map = get_free_map(!include_covered_cards);
        move_map[x2][y2] = true; // destination cell needs to be 'free' for the algorithm to find paths correctly

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

    function draw_card_cover(card: Card) {
        var x = card.x;
        var y = card.y;
        if (DRAW_IMAGE_COVER) {
            Gfx.draw_image(x * card_width * tilesize, y * card_height * tilesize, 'card');
        }
        if (DRAW_TRANSPARENT_COVER) {
            var card_color = Col.PINK;
            switch (card.type) {
                case CardType_Player: card_color = Col.GREEN;
                case CardType_Enemy: card_color = Col.RED;
                case CardType_Bonus: card_color = Col.GREEN;
                default:
            }
            Gfx.fill_box(x * card_width * tilesize, y * card_height * tilesize,
                card_width * tilesize, card_height * tilesize, card_color, 0.5);
        }
        if (DRAW_CARD_LEVEL) {
            Text.display(x * card_width * tilesize, y * card_height * tilesize, '${card.level}', Col.WHITE);
            Text.display((x + 1) * card_width * tilesize - tilesize / 2, (y + 1) * card_height * tilesize - tilesize, 
                '${card.level}', Col.WHITE);
        }
        if (card.type == CardType_Bonus) {
            var draw_x = x * card_width * tilesize + 1.5 * tilesize;
            var draw_y = y * card_height * tilesize + 2 * tilesize;
            switch (card.bonus_type) {
                case BonusType_Healing: Text.display(draw_x, draw_y, 'H', Col.WHITE);
                case BonusType_Damage: Text.display(draw_x, draw_y, 'D', Col.WHITE);
                default: Text.display(draw_x, draw_y, 'DEFAULT', Col.WHITE);
            }
        }

        if (card.type == CardType_Player || card.type == CardType_Enemy) {
            var draw_x = x * card_width * tilesize + tilesize;
            var draw_y = y * card_height * tilesize + 2 * tilesize;
            switch (card.dude_type) {
                case DudeType_Melee: Gfx.draw_tile(draw_x, draw_y, Tiles.Sword);
                case DudeType_Ranged: Gfx.draw_tile(draw_x, draw_y, Tiles.Bow);
                case DudeType_Hero: Gfx.draw_tile(draw_x, draw_y, Tiles.Mace);
                default:
            }
        }
    }

    function draw_dude(dude: Dude) {
        var dude_tile = Tiles.Temp;
        switch (dude.faction) {
            case DudeFaction_Player: {
                switch (dude.type) {
                    case DudeType_Melee: dude_tile = Tiles.MeleePlayer;
                    case DudeType_Ranged: dude_tile = Tiles.RangedPlayer;
                    case DudeType_Hero: dude_tile = Tiles.HeroPlayer;
                    default:
                }
            }
            case DudeFaction_Enemy: {
                switch (dude.type) {
                    case DudeType_Melee: dude_tile = Tiles.MeleeEnemy;
                    case DudeType_Ranged: dude_tile = Tiles.RangedEnemy;
                    case DudeType_Hero: dude_tile = Tiles.HeroEnemy;
                    default:
                }
            }
            default:
        }
        Gfx.rotation(dude.angle);
        Gfx.draw_tile(dude.real_x, dude.real_y, dude_tile);
        if (!dude.dead) {
            Text.display(dude.real_x, dude.real_y, '${dude.hp}/${dude.hp_max}', Col.WHITE);
        }
    }

    function render() {
        Gfx.draw_image(0, 0, 'background');

        if (DRAW_COORDINATES) {
            for (dx in -2...3) {
                for (dy in -2...3) {
                    Text.display((player.x + dx) * tilesize + 5, (player.y + dy) * tilesize + 10, '${(player.x + dx)},${(player.y + dy)}');
                }
            }
        }

        for (dude in Entity.get(Dude)) {
            if (dude.active) {
                draw_dude(dude);
            }
        }
        Gfx.rotation(0);

        Text.display(inventory_x, 0, '${Gfx.render_fps()}');
        Text.display(inventory_x, 30, '${state}');

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
    }

    function out_of_bounds(x:Int, y:Int):Bool {
        return x < 0 || y < 0 || x >= map_width || y >= map_height;
    }

    function card_at_position(x:Int, y:Int):IntVector2 {
        return {x: Std.int(x / card_width), y: Std.int(y / card_height)};
    }

    function update_player_choice() {

        render();
        
        // Turn over a card
        if (Mouse.left_click() || Mouse.right_click()) {
            var x = Std.int(Mouse.x / tilesize);
            var y = Std.int(Mouse.y / tilesize);
            if (!out_of_bounds(x, y)) {
                var card_pos = card_at_position(x, y);
                var clicked_card = cards[card_pos.x][card_pos.y];
                if (clicked_card.covered) {

                    if ((clicked_card.type == CardType_Enemy && !flipped_bad_card)
                        || (clicked_card.type != CardType_Enemy && !flipped_good_card))
                    {
                        flipped_card = clicked_card;
                        if (flipped_card.type == CardType_Enemy) {
                            flipped_bad_card = true;
                        } else {
                            flipped_good_card = true;
                        }

                        state = GameState_CardFlip;
                        choice_timer = choice_timer_max;

                        // Draw flipped card sides for animation
                        Gfx.draw_to_image('card_back');
                        Gfx.draw_image(-flipped_card.x * card_width * tilesize, -flipped_card.y * card_height * tilesize, 'all_card_backs');
                        Gfx.draw_to_image('card_front');
                        Gfx.draw_image(-flipped_card.x * card_width * tilesize, -flipped_card.y * card_height * tilesize, 'all_card_fronts');
                        Gfx.draw_to_screen();

                        // Update background
                        Gfx.draw_to_image('background');
                        Gfx.draw_image(flipped_card.x * card_width * tilesize,
                            flipped_card.y * card_height * tilesize, 'ground');
                        Gfx.draw_to_screen();

                        for (dude in Entity.get(Dude)) {
                            var dude_card = card_at_position(dude.x, dude.y);
                            if (dude_card.x == flipped_card.x && dude_card.y == flipped_card.y) {
                                dude.active = true;
                            }
                        }
                    }
                }
            }
        }

        var font_size = Text.currentsize;
        Text.change_size(40);
        Text.display(inventory_x, 800, 
            'Turn over one red card\nand one green to continue', Col.WHITE);
        Text.change_size(font_size);
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

    function update_turn() {

        if (state_timer < turn_delay) {
            state_timer++;
            render();
            return;
        } else {
            state_timer = 0;
        }

        function closest_dude(dude: Dude): Dude {
            var closest_dude: Dude = null;
            var closest_dst: Float = 1000000;
            for (other_dude in Entity.get(Dude)) {
                if (other_dude != dude 
                    && other_dude.faction != dude.faction 
                    && other_dude.active 
                    && !other_dude.dead) 
                {
                    var dst = Math.dst2(other_dude.x, other_dude.y, dude.x, dude.y);
                    if (dst < closest_dst) {
                        closest_dst = dst;
                        closest_dude = other_dude;
                    }
                }
            }
            return closest_dude;
        }

        for (dude in Entity.get(Dude)) {
            if (dude.active && !dude.dead) {
                if (dude.type == DudeType_Melee || dude.type == DudeType_Hero) {
                    var closest_dude = closest_dude(dude);
                    if (closest_dude != null) {
                        var dst = Math.dst2(closest_dude.x, closest_dude.y, dude.x, dude.y);
                        if (dst <= 2) {
                                // Attack if enemy is close
                                dude.attacked = true;
                                closest_dude.incoming_damage += dude.dmg;
                                dude.dx = Math.sign(closest_dude.x - dude.x);
                                dude.dy = Math.sign(closest_dude.y - dude.y);
                            } else {
                                // Move to closest dude
                                var path = a_star(dude.x, dude.y, closest_dude.x, closest_dude.y);
                                if (path.length > 1) {
                                    dude.moved = true;
                                    dude.dx = path[path.length - 2].x - dude.x;
                                    dude.dy = path[path.length - 2].y - dude.y;
                                }
                            }
                        }
                    } else if (dude.type == DudeType_Ranged) {
                        var closest_dude = closest_dude(dude);
                        
                        if (closest_dude != null) {
                            var dst = Math.dst2(closest_dude.x, closest_dude.y, dude.x, dude.y);
                            if (dst <= 9) {
                                // Attack if enemy is close
                                dude.attacked = true;
                                closest_dude.incoming_damage += dude.dmg;
                                dude.dx = Math.sign(closest_dude.x - dude.x);
                                dude.dy = Math.sign(closest_dude.y - dude.y);
                            } else {
                                // Move to closest dude
                                var path = a_star(dude.x, dude.y, closest_dude.x, closest_dude.y);
                                if (path.length > 1) {
                                    dude.moved = true;
                                    dude.dx = path[path.length - 2].x - dude.x;
                                    dude.dy = path[path.length - 2].y - dude.y;
                                }
                            }
                        }
                    }
                }
            }

        // Apply damage
        for (dude in Entity.get(Dude)) {
            if (dude.active) {
                dude.hp -= dude.incoming_damage;
                dude.incoming_damage = 0;
                if (dude.hp <= 0) {
                    dude.dead = true;
                }
            }
        }

        render();

        state = GameState_Visuals;
    }

    function update_visuals() {
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
            } else if (dude.dead) {
                dude.angle = 20 * state_timer / move_visual_timer_max;
                if (state_timer < move_visual_timer_max) {
                    all_visuals_complete = false;
                }
            }
        }


        render();

        for (dude in Entity.get(Dude)) {
            if (dude.attacked) {
                var attack_color = Col.WHITE;
                if (dude.faction == DudeFaction_Player) {
                    attack_color = player_color;
                } else if (dude.faction == DudeFaction_Enemy) {
                    attack_color = enemy_color;
                }
                if (state_timer < weapon_visual_timer_max) {
                    var visual_pos = poke_visual_pos(dude.x, dude.y, dude.dx, dude.dy,
                        50, state_timer, weapon_visual_timer_max);
                    Gfx.fill_circle(visual_pos.x, visual_pos.y, 10, attack_color);
                    all_visuals_complete = false;
                }
                // Draw attack visual
                switch (dude.type) {
                    case DudeType_Melee: {
                        if (state_timer < weapon_visual_timer_max) {
                            var visual_pos = poke_visual_pos(dude.x, dude.y, dude.dx, dude.dy,
                                50, state_timer, weapon_visual_timer_max);
                            Gfx.fill_circle(visual_pos.x, visual_pos.y, 10, attack_color);
                            all_visuals_complete = false;
                        }
                    }
                    default:
                }
            }
        }

        state_timer++;
        if (all_visuals_complete) {
            state = GameState_TurnResult;
            state_timer = 0;
        }
    }

    function update_turn_result() {
        var no_action = true;

        var dead_dudes = new Array<Dude>();
        for (dude in Entity.get(Dude)) {
            if (dude.active) {
                if (dude.attacked || dude.moved) {
                    no_action = false;
                }

                if (dude.dead) {
                    dead_dudes.push(dude);
                } else if (dude.moved) {
                    dude.x += dude.dx;
                    dude.y += dude.dy;
                    dude.real_x = dude.x * tilesize;
                    dude.real_y = dude.y * tilesize;
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

        render();

        var entity_states = new Array<String>();
        entity_states.push(serialize(player));
        for (dude in Entity.get(Dude)) {
            entity_states.push(serialize(dude));
        }
        history.push(entity_states);

        choice_timer--;
        if (choice_timer <= 0 || no_action) {
            var no_cards_left = true;
            for (x in 0...cardmap_width) {
                for (y in 0...cardmap_height) {
                    if (cards[x][y].covered) {
                        no_cards_left = false;
                    }
                }
            }

            if (no_cards_left) {
                for (dude in Entity.get(Dude)) {
                    if (dude.active && !dude.dead && dude.faction == DudeFaction_Player) {
                        win = true;
                    }
                }
                state = GameState_GameOver;
            } else {
                state = GameState_PlayerChoice;
            }
        } else {
            state = GameState_Turn;
        }
    }

    function update_card_flip() {
        render();
        Gfx.fill_box(flipped_card.x * card_width * tilesize, flipped_card.y * card_height * tilesize, card_width * tilesize, card_height * tilesize, Col.BLACK);
        if (state_timer / card_flip_timer_max < 0.5) {
            Gfx.scale(1 - 2 * state_timer / card_flip_timer_max, 1);
            Gfx.draw_image(flipped_card.x * card_width * tilesize, flipped_card.y * card_height * tilesize, 'card_back');
            Gfx.scale(1, 1);
        } else {
            Gfx.scale(2 * (state_timer / card_flip_timer_max - 0.5), 1);
            Gfx.draw_image(flipped_card.x * card_width * tilesize, flipped_card.y * card_height * tilesize, 'card_front');
            Gfx.scale(1, 1);
        }
        Text.display(0, 0, '${state_timer}', Col.YELLOW);

        state_timer++;
        if (state_timer > card_flip_timer_max) {
            state_timer = 0;

            flipped_card.covered = false;
            if (flipped_card.type == CardType_Bonus) {
                switch (flipped_card.bonus_type) {
                    case BonusType_Healing: {
                        for (dude in Entity.get(Dude)) {
                            if (dude.active 
                                && dude.faction == DudeFaction_Player 
                                && !dude.dead) 
                            {
                                dude.hp = dude.hp_max * 2;
                            }
                        }
                    }
                    case BonusType_Damage: {
                        for (dude in Entity.get(Dude)) {
                            if (dude.active 
                                && dude.faction == DudeFaction_Player 
                                && !dude.dead) 
                            {
                                dude.dmg *= 5;
                            }
                        }
                    }
                    default:
                }
            }
            
            if (flipped_good_card && flipped_bad_card) {
                state = GameState_Turn;
                flipped_good_card = false;
                flipped_bad_card = false;
            } else {
                state = GameState_PlayerChoice;
            }
        }
    }

    function update_game_over() {
        render();

        if (win) {
            Text.display(0, 0, 'YOU WIN');
        } else {
            Text.display(0, 0, 'YOU LOSE');
        }
    }

    function update() {
        if (Input.just_pressed(Key.Z) && history.length > 0 && state == GameState_PlayerChoice) {
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

        switch (state) {
            case GameState_PlayerChoice: update_player_choice();
            case GameState_Turn: update_turn();
            case GameState_Visuals: update_visuals();
            case GameState_TurnResult: update_turn_result();
            case GameState_CardFlip: update_card_flip();
            case GameState_GameOver: update_game_over();
        }
    }
}