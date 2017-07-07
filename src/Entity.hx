import haxe.ds.ObjectMap;
import haxegon.*;

enum DoorColor {
	DoorColor_White;
	DoorColor_Black;
}

enum ItemType {
	ItemType_None;
	ItemType_Weapon;
	ItemType_Armor;
	ItemType_Consumable;
	ItemType_Bomb;
	ItemType_Money;
}

enum ConsumableType {
	ConsumableType_None;
	ConsumableType_Healing;
	ConsumableType_Damage;
	ConsumableType_Speed;
}

enum ArmorType {
	ArmorType_None;
	ArmorType_Chest;
	ArmorType_Legs;
	ArmorType_Head;
}

enum WeaponType {
	WeaponType_None;
	WeaponType_Sword;
	WeaponType_Spear;
	WeaponType_Bow;
	WeaponType_Laser;
}

enum DudeType {
	DudeType_None;
	DudeType_Follower;
	DudeType_Shooter;
	DudeType_Stander;
	DudeType_Ghost;
}

@:publicFields
class Entity {
	static var all = new Array<Dynamic>();
	static var entities = new ObjectMap<Dynamic, Array<Dynamic>>();

	static function get(type: Dynamic): Array<Dynamic> {
		if (!entities.exists(type)) {
			entities.set(type, new Array<Dynamic>());
		}
		return entities.get(type);
	}

	static var id_max = 0;
	var id = 0;

	function new() {
		var type = Type.getClass(this);
		if (!entities.exists(type)) {
			entities.set(type, new Array<Dynamic>());
		}
		entities.get(type).push(this);
		all.push(this);

		id = id_max;
		id_max++;
	}

	function delete() {
		for (type in entities) {
			for (entity in type) {
				if (entity == this)
				{
					type.remove(this);
					break;
				}
			}
		}
		all.remove(this);
	}
}

class Player extends Entity {
	var x = 0;
	var y = 0;
	var real_x = 0;
	var real_y = 0;
	var attacked = false;
	var angle = 0.0;
	var moved = false;
	var dx = 0;
	var dy = 0;

	var hp = 10;
	var hp_max = 10;
	var default_hp_max = 10;
	var armor = 0;
	var incoming_damage = 0;

	var weapon = WeaponType_None;
}

class Dude extends Entity {
	var x = 0;
	var y = 0;
	var real_x = 0;
	var real_y = 0;
	var active = false;
	var attacked = false;
	var blown = false;
	var moved = false;
	var following_player = false;
	var dx = 0;
	var dy = 0;
	var hit = false;
	var dead = false;
	static var classs = Dude;
	var hp = 3;
	var hp_max = 3;
	var dmg = 0;
	static var names = ["Dave", "Stephen", "Max", "Vinny"];
	var name = names[Random.int(0, names.length - 1)];
	var info = "";
	var points = new Array<IntVector2>(); // for debug
	var angle = 0.0;

	var type = DudeType_None;
}

class Item extends Entity {
	var x = 0;
	var y = 0;
	var name = "name";
	var info = "Hello!\nItem info here";
	var tile = 0;
	var on_ground = true;

	var type = ItemType_None;
	var armor_type = ArmorType_None;
	var weapon_type = WeaponType_None;
	var consumable_type = ConsumableType_None;
	var value = 0; // used for weapon damage, consumable effect interchangibly
	var value_max = 0;
	var amount = 1;

	var hp_bonus = 0; 
	var dmg_bonus = 0; 
}