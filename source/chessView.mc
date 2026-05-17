import Toybox.Graphics;
import Toybox.Timer;
import Toybox.WatchUi;

class chessView extends WatchUi.View {

    var _game;
    var _cursor;
    var _selected;
    var _legalMoves;
    var _boardX;
    var _boardY;
    var _cell;
    var _boardSize;
    var _message;
    var _computerTimer;
    var _computerPending;

    function initialize() {
        View.initialize();
        _game = new ChessGame();
        _cursor = 52;
        _selected = -1;
        _legalMoves = [];
        _boardX = 0;
        _boardY = 0;
        _cell = 0;
        _boardSize = 0;
        _message = "Tap a white piece";
        _computerTimer = null;
        _computerPending = false;
    }

    function onLayout(dc as Dc) as Void {
    }

    function onShow() as Void {
        if (!_game.isGameOver() && !_game.isWhiteToMove()) {
            scheduleComputerMove();
            return;
        }

        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        updateGeometry(dc);
        drawHeader(dc);
        drawBoard(dc);
        drawFooter(dc);
    }

    function onHide() as Void {
        stopComputerTimer();
    }

    function newGame() as Void {
        stopComputerTimer();
        _game.reset();
        _cursor = 52;
        clearSelection();
        _message = "New game";
        WatchUi.requestUpdate();
    }

    function setElo(elo) as Void {
        _game.setElo(elo);
        _message = "ELO " + _game.getElo().format("%d");
        WatchUi.requestUpdate();
    }

    function moveCursor(dx, dy) as Void {
        var x = _cursor % 8;
        var y = (_cursor / 8).toNumber();

        x += dx;
        y += dy;

        if (x < 0) {
            x = 0;
        } else if (x > 7) {
            x = 7;
        }

        if (y < 0) {
            y = 0;
        } else if (y > 7) {
            y = 7;
        }

        _cursor = y * 8 + x;
        WatchUi.requestUpdate();
    }

    function advanceCursor(step) as Void {
        _cursor += step;

        while (_cursor < 0) {
            _cursor += 64;
        }

        while (_cursor >= 64) {
            _cursor -= 64;
        }

        WatchUi.requestUpdate();
    }

    function selectCurrent() as Void {
        if (_game.isGameOver()) {
            _message = _game.getStatus();
            WatchUi.requestUpdate();
            return;
        }

        if (!_game.isWhiteToMove()) {
            scheduleComputerMove();
            return;
        }

        var piece = _game.getPiece(_cursor);

        if (_selected < 0) {
            if (piece > 0) {
                _selected = _cursor;
                _legalMoves = _game.getLegalMovesForSquare(_selected);
                _message = _legalMoves.size() == 0 ? "No legal moves" : "Pick target";
            } else {
                _message = "White to move";
            }

            WatchUi.requestUpdate();
            return;
        }

        var move = findSelectedMove(_cursor);

        if (move != null) {
            _game.playMove(move);
            clearSelection();

            if (!_game.isGameOver()) {
                scheduleComputerMove();
            } else {
                _message = _game.getStatus();
            }
        } else if (piece > 0) {
            _selected = _cursor;
            _legalMoves = _game.getLegalMovesForSquare(_selected);
            _message = _legalMoves.size() == 0 ? "No legal moves" : "Pick target";
        } else {
            _message = "Illegal";
        }

        WatchUi.requestUpdate();
    }

    function scheduleComputerMove() as Void {
        _message = "Black thinking";

        if (_computerPending) {
            WatchUi.requestUpdate();
            return;
        }

        _computerPending = true;

        if (_computerTimer == null) {
            _computerTimer = new Timer.Timer();
        }

        _computerTimer.start(method(:finishComputerMove), 100, false);
        WatchUi.requestUpdate();
    }

    function finishComputerMove() as Void {
        _computerPending = false;

        if (!_game.isGameOver() && !_game.isWhiteToMove()) {
            _game.playComputerMove();
        }

        _message = _game.getStatus();
        WatchUi.requestUpdate();
    }

    function stopComputerTimer() as Void {
        if (_computerPending && _computerTimer != null) {
            _computerTimer.stop();
        }

        _computerPending = false;
    }

    function cancelSelection() {
        if (_selected >= 0) {
            clearSelection();
            _message = "Selection cleared";
            WatchUi.requestUpdate();
            return true;
        }

        return false;
    }

    function handleTap(x, y) {
        var square = squareFromPoint(x, y);

        if (square < 0) {
            return false;
        }

        _cursor = square;
        selectCurrent();
        return true;
    }

    function clearSelection() as Void {
        _selected = -1;
        _legalMoves = [];
    }

    function findSelectedMove(target) {
        for (var i = 0; i < _legalMoves.size(); i += 1) {
            var move = _legalMoves[i];

            if (move[1] == target) {
                return move;
            }
        }

        return null;
    }

    function squareFromPoint(x, y) {
        if (x < _boardX || y < _boardY || x >= _boardX + _boardSize || y >= _boardY + _boardSize) {
            return -1;
        }

        var file = ((x - _boardX) / _cell).toNumber();
        var rank = ((y - _boardY) / _cell).toNumber();

        if (file < 0 || file > 7 || rank < 0 || rank > 7) {
            return -1;
        }

        return rank * 8 + file;
    }

    function updateGeometry(dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var header = 28;
        var footer = 24;
        var availableHeight = height - header - footer;
        var size = width;

        if (availableHeight < size) {
            size = availableHeight;
        }

        _cell = (size / 8).toNumber();

        if (_cell < 1) {
            _cell = 1;
        }

        _boardSize = _cell * 8;
        _boardX = ((width - _boardSize) / 2).toNumber();
        _boardY = header + ((availableHeight - _boardSize) / 2).toNumber();
    }

    function drawHeader(dc) as Void {
        var text = _game.getStatus() + "  E" + _game.getElo().format("%d");
        var fitted = Graphics.fitTextToArea(text, Graphics.FONT_SMALL, dc.getWidth(), 24, true);

        if (fitted != null) {
            text = fitted;
        }

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.drawText(dc.getWidth() / 2, 4, Graphics.FONT_SMALL, text, Graphics.TEXT_JUSTIFY_CENTER);
    }

    function drawFooter(dc) as Void {
        var text = _message;

        if (text == null || text.length() == 0) {
            text = "Menu: ELO";
        }

        var fitted = Graphics.fitTextToArea(text, Graphics.FONT_XTINY, dc.getWidth(), 18, true);

        if (fitted != null) {
            text = fitted;
        }

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLACK);
        dc.drawText(dc.getWidth() / 2, _boardY + _boardSize + 4, Graphics.FONT_XTINY, text, Graphics.TEXT_JUSTIFY_CENTER);
    }

    function drawBoard(dc) as Void {
        for (var rank = 0; rank < 8; rank += 1) {
            for (var file = 0; file < 8; file += 1) {
                var square = rank * 8 + file;
                var x = _boardX + file * _cell;
                var y = _boardY + rank * _cell;
                var color = ((rank + file) % 2 == 0) ? Graphics.COLOR_DK_GRAY : Graphics.COLOR_BLACK;

                dc.setColor(color, Graphics.COLOR_BLACK);
                dc.fillRectangle(x, y, _cell, _cell);

                if (square == _game.getLastFrom() || square == _game.getLastTo()) {
                    dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_BLACK);
                    dc.drawRectangle(x + 1, y + 1, _cell - 2, _cell - 2);
                }

                drawPiece(dc, square, x, y);

                if (isLegalTarget(square)) {
                    drawLegalTarget(dc, square, x, y);
                }

                if (square == _cursor) {
                    dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_BLACK);
                    dc.drawRectangle(x, y, _cell - 1, _cell - 1);
                }

                if (square == _selected) {
                    dc.setColor(Graphics.COLOR_BLUE, Graphics.COLOR_BLACK);
                    dc.drawRectangle(x + 2, y + 2, _cell - 4, _cell - 4);
                }
            }
        }
    }

    function drawPiece(dc, square, x, y) as Void {
        var piece = _game.getPiece(square);

        if (piece == CG_EMPTY) {
            return;
        }

        var text = pieceText(piece);
        var font = Graphics.FONT_SMALL;

        if (_cell >= 42) {
            font = Graphics.FONT_LARGE;
        } else if (_cell >= 30) {
            font = Graphics.FONT_MEDIUM;
        }

        var color = piece > 0 ? Graphics.COLOR_WHITE : Graphics.COLOR_ORANGE;

        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x + (_cell / 2), y + (_cell / 2), font, text, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function drawLegalTarget(dc, square, x, y) as Void {
        dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_BLACK);

        if (_game.getPiece(square) == CG_EMPTY) {
            dc.fillCircle(x + (_cell / 2), y + (_cell / 2), dotRadius());
        } else {
            dc.drawRectangle(x + 3, y + 3, _cell - 6, _cell - 6);
        }
    }

    function pieceText(piece) {
        var absPiece = piece < 0 ? -piece : piece;

        if (absPiece == CG_PAWN) {
            return piece > 0 ? "P" : "p";
        } else if (absPiece == CG_KNIGHT) {
            return piece > 0 ? "N" : "n";
        } else if (absPiece == CG_BISHOP) {
            return piece > 0 ? "B" : "b";
        } else if (absPiece == CG_ROOK) {
            return piece > 0 ? "R" : "r";
        } else if (absPiece == CG_QUEEN) {
            return piece > 0 ? "Q" : "q";
        }

        return piece > 0 ? "K" : "k";
    }

    function isLegalTarget(square) {
        for (var i = 0; i < _legalMoves.size(); i += 1) {
            if (_legalMoves[i][1] == square) {
                return true;
            }
        }

        return false;
    }

    function dotRadius() {
        var radius = (_cell / 7).toNumber();

        if (radius < 2) {
            radius = 2;
        }

        return radius;
    }
}
