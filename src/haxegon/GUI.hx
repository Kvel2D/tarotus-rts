package haxegon;

using haxegon.MathExtensions;


@:publicFields
class GUI {
	static var x: Float = 0;
	static var y: Float = 0;
	static var slider_cache = {hash: "", dragged: false};

	static var button_off_color = Col.GRAY;
	static var button_on_color = Col.PINK;
	static var button_text_off_color = Col.WHITE;
	static var button_text_on_color = Col.WHITE;
	static var slider_background_color = Col.GRAY; 
	static var slider_handle_color = Col.PINK;
	static var slider_text_color = Col.WHITE;


	static function set_pallete(off: Int, on: Int, text_off: Int, text_on: Int) {
		button_off_color = off;
		slider_background_color = off;
		
		button_on_color = on;
		slider_handle_color = on;

		button_text_off_color = text_off;
		button_text_on_color = text_on;
		slider_text_color = text_off;
	}

	static function image_button(x: Float, y: Float, image: String, button_function: Void->Void) {
		var image_width = Gfx.image_width(image);
		var image_height = Gfx.image_height(image);
		var button_width = image_width * 1.1;
		var button_height = image_height * 1.1;

		if (Mouse.left_click() && Math.point_box_intersect(Mouse.x, Mouse.y, x, y, button_width, button_height)) {
			button_function();
		}
		Gfx.draw_image(x, y, image);
	}

	static function auto_text_button(text: String, button_function: Void->Void, skips: Int = 0) {
		var text_height = Text.height();
		var button_height = text_height * 1.25;
		y += (button_height + 2) * (skips);

		text_button(x, y, text, button_function);

		y += (button_height + 2);
	}

	static function text_button(button_x: Float, button_y: Float, text: String, button_function: Void->Void) {
		var text_width = Text.width(text);
		var text_height = Text.height();
		var button_width = text_width * 1.1;
		var button_height = text_height * 1.25;

		if (Math.point_box_intersect(Mouse.x, Mouse.y, button_x, button_y, button_width, button_height)) {
			Gfx.fill_box(button_x, button_y, button_width, button_height, button_on_color);
			if (Mouse.left_click()) {
				button_function();
			}
			Text.display(button_x, button_y, text, button_text_on_color);
		} else {
			Gfx.fill_box(button_x, button_y, button_width, button_height, button_off_color);
			Text.display(button_x, button_y, text, button_text_off_color);
		}
	}

	static function auto_slider(text: String, set_function: Float->Void, current: Float, min: Float, max: Float, 
		handle_width: Float, area_width: Float, skips: Int = 0) {
		var text_width = Text.width(text);
		var text_height = Text.height();
		var height = text_height * 1.25;
		y += (height + 2) * (skips);

		slider(x, y, text, set_function, current, min, max, handle_width, area_width);

		y += (height + 2);
	}


	static function slider(slider_x: Float, slider_y: Float, text: String, set_function: Float->Void, current: Float,
		min: Float, max: Float, handle_width: Float, area_width: Float, skips: Int = 0) {
		var text_width = Text.width(text);
		var text_height = Text.height();
		var height = text_height * 1.25;


		Gfx.fill_box(slider_x, slider_y, area_width + text_width * 1.2, height, slider_background_color);
		Gfx.fill_box(slider_x + area_width * (current - min) / (max - min), slider_y + height * 0.05, handle_width, height * 0.9, slider_handle_color);

		var hash = '${text}_${slider_x}_${slider_y}';
		if (slider_cache.hash == hash) {
			if (slider_cache.dragged && Mouse.left_held()) {
				var value = current;
				if (Mouse.x < slider_x) {
					value = min;
				} else if (Mouse.x > slider_x + area_width) {
					value = max;
				} else {
					value = (Mouse.x - slider_x) / area_width * (max - min) + min; 
				}
				set_function(value);
			} else {
				slider_cache.hash = "";
			}
		} else {
			if (Mouse.left_click() && Math.point_box_intersect(Mouse.x, Mouse.y, slider_x - area_width * 0.1, y - height * 0.5, area_width * 1.2, height * 1.1)) {
				slider_cache.hash = hash;
				slider_cache.dragged = true;
			}
		}

		var value_string = Math.fixed_float(current, 3);
		Text.display(slider_x + area_width / 2 - Text.width(value_string) / 2, y, value_string, Col.WHITE);
		Text.display(slider_x + area_width + handle_width, y, text);
	}

	static function enum_setter(setter_x: Float, setter_y: Float, set_function: Dynamic->Void, current: Dynamic,  enum_type: Dynamic) {
		var temp_x = x;
		var temp_y = y;
		var temp_color = Col.WHITE;
		x = setter_x;
		y = setter_y;

		var enums = Type.allEnums(enum_type);
		for (i in 0...enums.length) {
			if (enums[i] == current) {
				temp_color = button_off_color;
				button_off_color = Col.GREEN;
			}
			auto_text_button('${enums[i]}', function() { set_function(Type.allEnums(enum_type)[i]); });
			if (enums[i] == current) {
				button_off_color = temp_color;
			}
		}

		x = temp_x;
		y = temp_y;
	}

	function new(){}
}