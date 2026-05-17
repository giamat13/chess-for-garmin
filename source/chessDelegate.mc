import Toybox.Lang;
import Toybox.WatchUi;

class chessDelegate extends WatchUi.BehaviorDelegate {

    var _view;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onMenu() as Boolean {
        WatchUi.pushView(new Rez.Menus.MainMenu(), new chessMenuDelegate(_view), WatchUi.SLIDE_UP);
        return true;
    }

    function onActionMenu() as Boolean {
        return onMenu();
    }

    function onSelect() as Boolean {
        return false;
    }

    function onBack() as Boolean {
        return _view.cancelSelection();
    }

    function onNextPage() as Boolean {
        return false;
    }

    function onPreviousPage() as Boolean {
        return false;
    }

    function onNextMode() as Boolean {
        return false;
    }

    function onPreviousMode() as Boolean {
        return false;
    }

    function onSwipe(swipeEvent) as Boolean {
        var direction = swipeEvent.getDirection();

        if (direction == WatchUi.SWIPE_UP) {
            _view.moveCursor(0, -1);
        } else if (direction == WatchUi.SWIPE_DOWN) {
            _view.moveCursor(0, 1);
        } else if (direction == WatchUi.SWIPE_LEFT) {
            _view.moveCursor(-1, 0);
        } else if (direction == WatchUi.SWIPE_RIGHT) {
            _view.moveCursor(1, 0);
        }

        return true;
    }

    function onTap(clickEvent) as Boolean {
        var coordinates = clickEvent.getCoordinates();
        return _view.handleTap(coordinates[0], coordinates[1]);
    }

    function onKey(keyEvent) as Boolean {
        var key = keyEvent.getKey();

        if (key == WatchUi.KEY_LEFT) {
            _view.moveCursor(-1, 0);
        } else if (key == WatchUi.KEY_RIGHT) {
            _view.moveCursor(1, 0);
        } else if (key == WatchUi.KEY_UP) {
            _view.moveCursor(0, -1);
        } else if (key == WatchUi.KEY_DOWN) {
            _view.moveCursor(0, 1);
        } else if (key == WatchUi.KEY_ENTER) {
            _view.selectCurrent();
        } else {
            return false;
        }

        return true;
    }
}
