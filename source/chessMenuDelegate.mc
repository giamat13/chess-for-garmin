import Toybox.Lang;
import Toybox.WatchUi;

class chessMenuDelegate extends WatchUi.MenuInputDelegate {

    var _view;

    function initialize(view) {
        MenuInputDelegate.initialize();
        _view = view;
    }

    function onMenuItem(item as Symbol) as Void {
        if (item == :new_game) {
            _view.newGame();
        } else if (item == :elo_600) {
            _view.setElo(600);
        } else if (item == :elo_900) {
            _view.setElo(900);
        } else if (item == :elo_1200) {
            _view.setElo(1200);
        } else if (item == :elo_1500) {
            _view.setElo(1500);
        }

        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }

}
