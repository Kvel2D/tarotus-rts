import haxegon.*;

enum MainState {
    MainState_Game;
}


@:publicFields
class Main {
    static inline var screen_width = Game.map_width * Game.tilesize;
    static inline var screen_height = Game.map_height * Game.tilesize;
    static var state = MainState_Game;
    static var game: Game;

    function new() {
        Gfx.resize_screen(screen_width, screen_height);
        Text.setfont("Seraphimb1", 30);

        Gfx.load_tiles("tiles", Game.tilesize, Game.tilesize);
        Gfx.load_image("card");

        game = new Game();
    }


    function update() {
        switch (state) {
            case MainState_Game: game.update();
        }
    }
}
