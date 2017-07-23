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

enum WeaponType {
	WeaponType_None;
	WeaponType_Sword;
	WeaponType_Spear;
	WeaponType_Bow;
	WeaponType_Laser;
}

enum DudeType {
	DudeType_None;
	DudeType_Melee;
	DudeType_Ranged;
	DudeType_Hero;
}

enum DudeFaction {
	DudeFaction_Player;
	DudeFaction_Enemy;
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
	var moved = false;
	var dx = 0;
	var dy = 0;
	var dead = false;
	var hp = 3;
	var hp_max = 3;
	var incoming_damage = 0;
	var dmg = 0;
	var angle = 0.0;

	var type = DudeType_None;
	var faction = DudeFaction_Enemy;
}
