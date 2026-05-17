import Toybox.Lang;

const CG_EMPTY = 0;
const CG_WHITE = 1;
const CG_BLACK = -1;

const CG_PAWN = 1;
const CG_KNIGHT = 2;
const CG_BISHOP = 3;
const CG_ROOK = 4;
const CG_QUEEN = 5;
const CG_KING = 6;

const CG_FLAG_EP = 1;
const CG_FLAG_CASTLE = 2;
const CG_FLAG_DOUBLE = 4;

const CG_BIG = 30000;
const CG_MATE = 20000;

class ChessGame {

    var _board;
    var _whiteToMove;
    var _whiteKingSquare;
    var _blackKingSquare;
    var _enPassant;
    var _wkCastle;
    var _wqCastle;
    var _bkCastle;
    var _bqCastle;
    var _elo;
    var _depth;
    var _nodeLimit;
    var _noise;
    var _nodes;
    var _seed;
    var _status;
    var _gameOver;
    var _lastFrom;
    var _lastTo;
    var _knightJumps;
    var _bishopDirs;
    var _rookDirs;
    var _queenDirs;

    function initialize() {
        _seed = 137;
        _knightJumps = [[1, 2], [2, 1], [2, -1], [1, -2], [-1, -2], [-2, -1], [-2, 1], [-1, 2]];
        _bishopDirs = [[1, 1], [1, -1], [-1, 1], [-1, -1]];
        _rookDirs = [[1, 0], [-1, 0], [0, 1], [0, -1]];
        _queenDirs = [[1, 1], [1, -1], [-1, 1], [-1, -1], [1, 0], [-1, 0], [0, 1], [0, -1]];
        setElo(900);
        reset();
    }

    function reset() {
        _board = new [64];

        for (var i = 0; i < 64; i += 1) {
            _board[i] = CG_EMPTY;
        }

        _board[0] = -CG_ROOK;
        _board[1] = -CG_KNIGHT;
        _board[2] = -CG_BISHOP;
        _board[3] = -CG_QUEEN;
        _board[4] = -CG_KING;
        _board[5] = -CG_BISHOP;
        _board[6] = -CG_KNIGHT;
        _board[7] = -CG_ROOK;

        for (var blackPawn = 8; blackPawn < 16; blackPawn += 1) {
            _board[blackPawn] = -CG_PAWN;
        }

        for (var whitePawn = 48; whitePawn < 56; whitePawn += 1) {
            _board[whitePawn] = CG_PAWN;
        }

        _board[56] = CG_ROOK;
        _board[57] = CG_KNIGHT;
        _board[58] = CG_BISHOP;
        _board[59] = CG_QUEEN;
        _board[60] = CG_KING;
        _board[61] = CG_BISHOP;
        _board[62] = CG_KNIGHT;
        _board[63] = CG_ROOK;

        _whiteToMove = true;
        _whiteKingSquare = 60;
        _blackKingSquare = 4;
        _enPassant = -1;
        _wkCastle = true;
        _wqCastle = true;
        _bkCastle = true;
        _bqCastle = true;
        _lastFrom = -1;
        _lastTo = -1;
        _gameOver = false;
        refreshStatus();
    }

    function setElo(elo) {
        _elo = elo;

        if (elo <= 600) {
            _depth = 1;
            _nodeLimit = 24;
            _noise = 260;
        } else if (elo <= 900) {
            _depth = 1;
            _nodeLimit = 36;
            _noise = 120;
        } else if (elo <= 1200) {
            _depth = 1;
            _nodeLimit = 48;
            _noise = 55;
        } else {
            _depth = 1;
            _nodeLimit = 60;
            _noise = 18;
        }
    }

    function getElo() {
        return _elo;
    }

    function getStatus() {
        return _status;
    }

    function isGameOver() {
        return _gameOver;
    }

    function isWhiteToMove() {
        return _whiteToMove;
    }

    function getPiece(square) {
        return _board[square];
    }

    function getLastFrom() {
        return _lastFrom;
    }

    function getLastTo() {
        return _lastTo;
    }

    function getLegalMovesForSquare(square) {
        var legal = [];

        if (_gameOver) {
            return legal;
        }

        var side = _whiteToMove ? CG_WHITE : CG_BLACK;

        if (!isOwnPiece(_board[square], side)) {
            return legal;
        }

        var moves = getAllLegalMoves(side);

        for (var i = 0; i < moves.size(); i += 1) {
            var move = moves[i];

            if (move[0] == square) {
                legal.add(move);
            }
        }

        return legal;
    }

    function playMove(move) {
        makeMove(move);
        refreshStatus();
    }

    function playComputerMove() {
        if (_gameOver) {
            return;
        }

        var move = chooseComputerMove();

        if (move != null) {
            makeMove(move);
            refreshStatus();
        }
    }

    function chooseComputerMove() {
        var side = _whiteToMove ? CG_WHITE : CG_BLACK;
        var moves = getAllLegalMoves(side);

        if (moves.size() == 0) {
            return null;
        }

        _nodes = 0;

        var bestMove = moves[0];
        var bestScore = side == CG_WHITE ? -CG_BIG : CG_BIG;

        for (var i = 0; i < moves.size(); i += 1) {
            var move = moves[i];
            var state = makeMove(move);
            var score = evaluate();
            undoMove(move, state);

            score += rootNoise();

            if (side == CG_WHITE) {
                if (score > bestScore) {
                    bestScore = score;
                    bestMove = move;
                }
            } else {
                if (score < bestScore) {
                    bestScore = score;
                    bestMove = move;
                }
            }
        }

        return bestMove;
    }

    function refreshStatus() {
        var side = _whiteToMove ? CG_WHITE : CG_BLACK;
        var inCheck = isKingInCheck(side);

        if (!hasLegalMove(side)) {
            _gameOver = true;
            _status = inCheck ? (side == CG_WHITE ? "Black wins" : "White wins") : "Stalemate";
            return;
        }

        _gameOver = false;
        _status = side == CG_WHITE ? "White" : "Black";

        if (inCheck) {
            _status += " check";
        }
    }

    function hasLegalMove(side) {
        var pseudo = generatePseudoMoves(side);

        for (var i = 0; i < pseudo.size(); i += 1) {
            var move = pseudo[i];
            var state = makeMove(move);
            var legal = !isKingInCheck(side);
            undoMove(move, state);

            if (legal) {
                return true;
            }
        }

        return false;
    }

    function getAllLegalMoves(side) {
        var legal = [];
        var pseudo = generatePseudoMoves(side);

        for (var i = 0; i < pseudo.size(); i += 1) {
            var move = pseudo[i];
            var state = makeMove(move);

            if (!isKingInCheck(side)) {
                legal.add(move);
            }

            undoMove(move, state);
        }

        return legal;
    }

    function generatePseudoMoves(side) {
        var moves = [];

        for (var square = 0; square < 64; square += 1) {
            var piece = _board[square];

            if (!isOwnPiece(piece, side)) {
                continue;
            }

            var absPiece = absNumber(piece);

            if (absPiece == CG_PAWN) {
                addPawnMoves(moves, square, side);
            } else if (absPiece == CG_KNIGHT) {
                addKnightMoves(moves, square, side);
            } else if (absPiece == CG_BISHOP) {
                addSlidingMoves(moves, square, side, _bishopDirs);
            } else if (absPiece == CG_ROOK) {
                addSlidingMoves(moves, square, side, _rookDirs);
            } else if (absPiece == CG_QUEEN) {
                addSlidingMoves(moves, square, side, _queenDirs);
            } else if (absPiece == CG_KING) {
                addKingMoves(moves, square, side);
            }
        }

        return moves;
    }

    function addPawnMoves(moves, square, side) {
        var x = fileOf(square);
        var y = rankOf(square);
        var direction = side == CG_WHITE ? -1 : 1;
        var startRank = side == CG_WHITE ? 6 : 1;
        var promotionRank = side == CG_WHITE ? 0 : 7;
        var oneY = y + direction;

        if (isOnBoard(x, oneY)) {
            var one = toSquare(x, oneY);

            if (_board[one] == CG_EMPTY) {
                addPawnMove(moves, square, one, oneY == promotionRank, 0);

                if (y == startRank) {
                    var twoY = y + direction + direction;
                    var two = toSquare(x, twoY);

                    if (_board[two] == CG_EMPTY) {
                        addMove(moves, square, two, CG_EMPTY, CG_FLAG_DOUBLE);
                    }
                }
            }
        }

        for (var dx = -1; dx <= 1; dx += 2) {
            var captureX = x + dx;
            var captureY = oneY;

            if (!isOnBoard(captureX, captureY)) {
                continue;
            }

            var target = toSquare(captureX, captureY);

            if (isEnemyPiece(_board[target], side)) {
                addPawnMove(moves, square, target, captureY == promotionRank, 0);
            } else if (target == _enPassant) {
                addMove(moves, square, target, CG_EMPTY, CG_FLAG_EP);
            }
        }
    }

    function addPawnMove(moves, from, to, promotes, flags) {
        if (promotes) {
            addMove(moves, from, to, CG_QUEEN, flags);
        } else {
            addMove(moves, from, to, CG_EMPTY, flags);
        }
    }

    function addKnightMoves(moves, square, side) {
        var x = fileOf(square);
        var y = rankOf(square);

        for (var i = 0; i < _knightJumps.size(); i += 1) {
            var targetX = x + _knightJumps[i][0];
            var targetY = y + _knightJumps[i][1];

            if (!isOnBoard(targetX, targetY)) {
                continue;
            }

            var target = toSquare(targetX, targetY);

            if (!isOwnPiece(_board[target], side)) {
                addMove(moves, square, target, CG_EMPTY, 0);
            }
        }
    }

    function addSlidingMoves(moves, square, side, directions) {
        var x = fileOf(square);
        var y = rankOf(square);

        for (var i = 0; i < directions.size(); i += 1) {
            var dx = directions[i][0];
            var dy = directions[i][1];
            var targetX = x + dx;
            var targetY = y + dy;

            while (isOnBoard(targetX, targetY)) {
                var target = toSquare(targetX, targetY);

                if (_board[target] == CG_EMPTY) {
                    addMove(moves, square, target, CG_EMPTY, 0);
                } else {
                    if (isEnemyPiece(_board[target], side)) {
                        addMove(moves, square, target, CG_EMPTY, 0);
                    }

                    break;
                }

                targetX += dx;
                targetY += dy;
            }
        }
    }

    function addKingMoves(moves, square, side) {
        var x = fileOf(square);
        var y = rankOf(square);

        for (var dx = -1; dx <= 1; dx += 1) {
            for (var dy = -1; dy <= 1; dy += 1) {
                if (dx == 0 && dy == 0) {
                    continue;
                }

                var targetX = x + dx;
                var targetY = y + dy;

                if (!isOnBoard(targetX, targetY)) {
                    continue;
                }

                var target = toSquare(targetX, targetY);

                if (!isOwnPiece(_board[target], side)) {
                    addMove(moves, square, target, CG_EMPTY, 0);
                }
            }
        }

        addCastleMoves(moves, side);
    }

    function addCastleMoves(moves, side) {
        if (side == CG_WHITE) {
            if (_wkCastle && _board[60] == CG_KING && _board[63] == CG_ROOK && _board[61] == CG_EMPTY && _board[62] == CG_EMPTY) {
                addMove(moves, 60, 62, CG_EMPTY, CG_FLAG_CASTLE);
            }

            if (_wqCastle && _board[60] == CG_KING && _board[56] == CG_ROOK && _board[59] == CG_EMPTY && _board[58] == CG_EMPTY && _board[57] == CG_EMPTY) {
                addMove(moves, 60, 58, CG_EMPTY, CG_FLAG_CASTLE);
            }
        } else {
            if (_bkCastle && _board[4] == -CG_KING && _board[7] == -CG_ROOK && _board[5] == CG_EMPTY && _board[6] == CG_EMPTY) {
                addMove(moves, 4, 6, CG_EMPTY, CG_FLAG_CASTLE);
            }

            if (_bqCastle && _board[4] == -CG_KING && _board[0] == -CG_ROOK && _board[3] == CG_EMPTY && _board[2] == CG_EMPTY && _board[1] == CG_EMPTY) {
                addMove(moves, 4, 2, CG_EMPTY, CG_FLAG_CASTLE);
            }
        }
    }

    function addMove(moves, from, to, promotion, flags) {
        moves.add([from, to, promotion, flags]);
    }

    function makeMove(move) {
        var from = move[0];
        var to = move[1];
        var promotion = move[2];
        var flags = move[3];
        var piece = _board[from];
        var captured = _board[to];
        var epCapturedIndex = -1;
        var state = [captured, _enPassant, _wkCastle, _wqCastle, _bkCastle, _bqCastle, _lastFrom, _lastTo, epCapturedIndex];

        _board[from] = CG_EMPTY;

        if ((flags & CG_FLAG_EP) != 0) {
            epCapturedIndex = piece > 0 ? to + 8 : to - 8;
            captured = _board[epCapturedIndex];
            state[0] = captured;
            state[8] = epCapturedIndex;
            _board[epCapturedIndex] = CG_EMPTY;
        }

        if (promotion != CG_EMPTY) {
            _board[to] = piece > 0 ? promotion : -promotion;
        } else {
            _board[to] = piece;
        }

        if (absNumber(piece) == CG_KING) {
            if (piece > 0) {
                _whiteKingSquare = to;
            } else {
                _blackKingSquare = to;
            }
        }

        if ((flags & CG_FLAG_CASTLE) != 0) {
            moveCastleRook(to);
        }

        _enPassant = -1;

        if ((flags & CG_FLAG_DOUBLE) != 0) {
            _enPassant = piece > 0 ? to + 8 : to - 8;
        }

        updateCastlingRights(from, to, piece, captured);

        _lastFrom = from;
        _lastTo = to;
        _whiteToMove = !_whiteToMove;

        return state;
    }

    function undoMove(move, state) {
        var from = move[0];
        var to = move[1];
        var promotion = move[2];
        var flags = move[3];

        _whiteToMove = !_whiteToMove;

        var movedSide = _whiteToMove ? CG_WHITE : CG_BLACK;
        var piece = _board[to];

        if (promotion != CG_EMPTY) {
            piece = movedSide == CG_WHITE ? CG_PAWN : -CG_PAWN;
        }

        _board[from] = piece;
        _board[to] = state[0];

        if (absNumber(piece) == CG_KING) {
            if (piece > 0) {
                _whiteKingSquare = from;
            } else {
                _blackKingSquare = from;
            }
        }

        if ((flags & CG_FLAG_EP) != 0) {
            _board[to] = CG_EMPTY;
            _board[state[8]] = state[0];
        }

        if ((flags & CG_FLAG_CASTLE) != 0) {
            undoCastleRook(to);
        }

        _enPassant = state[1];
        _wkCastle = state[2];
        _wqCastle = state[3];
        _bkCastle = state[4];
        _bqCastle = state[5];
        _lastFrom = state[6];
        _lastTo = state[7];
    }

    function moveCastleRook(kingTo) {
        if (kingTo == 62) {
            _board[61] = _board[63];
            _board[63] = CG_EMPTY;
        } else if (kingTo == 58) {
            _board[59] = _board[56];
            _board[56] = CG_EMPTY;
        } else if (kingTo == 6) {
            _board[5] = _board[7];
            _board[7] = CG_EMPTY;
        } else if (kingTo == 2) {
            _board[3] = _board[0];
            _board[0] = CG_EMPTY;
        }
    }

    function undoCastleRook(kingTo) {
        if (kingTo == 62) {
            _board[63] = _board[61];
            _board[61] = CG_EMPTY;
        } else if (kingTo == 58) {
            _board[56] = _board[59];
            _board[59] = CG_EMPTY;
        } else if (kingTo == 6) {
            _board[7] = _board[5];
            _board[5] = CG_EMPTY;
        } else if (kingTo == 2) {
            _board[0] = _board[3];
            _board[3] = CG_EMPTY;
        }
    }

    function updateCastlingRights(from, to, piece, captured) {
        var absPiece = absNumber(piece);

        if (absPiece == CG_KING) {
            if (piece > 0) {
                _wkCastle = false;
                _wqCastle = false;
            } else {
                _bkCastle = false;
                _bqCastle = false;
            }
        }

        if (absPiece == CG_ROOK) {
            if (from == 63) {
                _wkCastle = false;
            } else if (from == 56) {
                _wqCastle = false;
            } else if (from == 7) {
                _bkCastle = false;
            } else if (from == 0) {
                _bqCastle = false;
            }
        }

        if (captured == CG_ROOK) {
            if (to == 63) {
                _wkCastle = false;
            } else if (to == 56) {
                _wqCastle = false;
            }
        } else if (captured == -CG_ROOK) {
            if (to == 7) {
                _bkCastle = false;
            } else if (to == 0) {
                _bqCastle = false;
            }
        }
    }

    function search(depth, alpha, beta) {
        _nodes += 1;

        if (depth <= 0 || _nodes >= _nodeLimit) {
            return evaluate();
        }

        var side = _whiteToMove ? CG_WHITE : CG_BLACK;
        var moves = getAllLegalMoves(side);

        if (moves.size() == 0) {
            if (isKingInCheck(side)) {
                return side == CG_WHITE ? -CG_MATE - depth : CG_MATE + depth;
            }

            return 0;
        }

        if (side == CG_WHITE) {
            var bestWhite = -CG_BIG;

            for (var i = 0; i < moves.size(); i += 1) {
                var state = makeMove(moves[i]);
                var whiteScore = search(depth - 1, alpha, beta);
                undoMove(moves[i], state);

                if (whiteScore > bestWhite) {
                    bestWhite = whiteScore;
                }

                if (bestWhite > alpha) {
                    alpha = bestWhite;
                }

                if (beta <= alpha || _nodes >= _nodeLimit) {
                    break;
                }
            }

            return bestWhite;
        }

        var bestBlack = CG_BIG;

        for (var j = 0; j < moves.size(); j += 1) {
            var blackState = makeMove(moves[j]);
            var blackScore = search(depth - 1, alpha, beta);
            undoMove(moves[j], blackState);

            if (blackScore < bestBlack) {
                bestBlack = blackScore;
            }

            if (bestBlack < beta) {
                beta = bestBlack;
            }

            if (beta <= alpha || _nodes >= _nodeLimit) {
                break;
            }
        }

        return bestBlack;
    }

    function evaluate() {
        var score = 0;

        for (var square = 0; square < 64; square += 1) {
            var piece = _board[square];

            if (piece == CG_EMPTY) {
                continue;
            }

            var sign = piece > 0 ? 1 : -1;
            var absPiece = absNumber(piece);
            var value = pieceValue(absPiece);
            var bonus = positionalBonus(square, absPiece, sign);

            score += sign * (value + bonus);
        }

        return score;
    }

    function pieceValue(piece) {
        if (piece == CG_PAWN) {
            return 100;
        } else if (piece == CG_KNIGHT) {
            return 320;
        } else if (piece == CG_BISHOP) {
            return 330;
        } else if (piece == CG_ROOK) {
            return 500;
        } else if (piece == CG_QUEEN) {
            return 900;
        }

        return 0;
    }

    function positionalBonus(square, piece, sign) {
        var x = fileOf(square);
        var y = rankOf(square);
        var centerX = x <= 3 ? x : 7 - x;
        var centerY = y <= 3 ? y : 7 - y;
        var bonus = (centerX + centerY) * 3;

        if (piece == CG_PAWN) {
            if (sign > 0) {
                bonus += (6 - y) * 6;
            } else {
                bonus += (y - 1) * 6;
            }
        } else if (piece == CG_KING) {
            bonus = 0;
        }

        return bonus;
    }

    function isKingInCheck(side) {
        var kingSquare = findKing(side);

        if (kingSquare < 0) {
            return true;
        }

        return isSquareAttacked(kingSquare, -side);
    }

    function findKing(side) {
        if (side == CG_WHITE) {
            if (_whiteKingSquare != null && _board[_whiteKingSquare] == CG_KING) {
                return _whiteKingSquare;
            }
        } else {
            if (_blackKingSquare != null && _board[_blackKingSquare] == -CG_KING) {
                return _blackKingSquare;
            }
        }

        var king = side == CG_WHITE ? CG_KING : -CG_KING;

        for (var i = 0; i < 64; i += 1) {
            if (_board[i] == king) {
                if (side == CG_WHITE) {
                    _whiteKingSquare = i;
                } else {
                    _blackKingSquare = i;
                }

                return i;
            }
        }

        return -1;
    }

    function isSquareAttacked(square, bySide) {
        var x = fileOf(square);
        var y = rankOf(square);
        var pawnY = bySide == CG_WHITE ? y + 1 : y - 1;

        for (var pawnDx = -1; pawnDx <= 1; pawnDx += 2) {
            var pawnX = x + pawnDx;

            if (isOnBoard(pawnX, pawnY) && _board[toSquare(pawnX, pawnY)] == bySide * CG_PAWN) {
                return true;
            }
        }

        for (var i = 0; i < _knightJumps.size(); i += 1) {
            var knightX = x + _knightJumps[i][0];
            var knightY = y + _knightJumps[i][1];

            if (isOnBoard(knightX, knightY) && _board[toSquare(knightX, knightY)] == bySide * CG_KNIGHT) {
                return true;
            }
        }

        if (isAttackedBySlider(x, y, bySide, 1, 1, true)) {
            return true;
        }

        if (isAttackedBySlider(x, y, bySide, 1, -1, true)) {
            return true;
        }

        if (isAttackedBySlider(x, y, bySide, -1, 1, true)) {
            return true;
        }

        if (isAttackedBySlider(x, y, bySide, -1, -1, true)) {
            return true;
        }

        if (isAttackedBySlider(x, y, bySide, 1, 0, false)) {
            return true;
        }

        if (isAttackedBySlider(x, y, bySide, -1, 0, false)) {
            return true;
        }

        if (isAttackedBySlider(x, y, bySide, 0, 1, false)) {
            return true;
        }

        if (isAttackedBySlider(x, y, bySide, 0, -1, false)) {
            return true;
        }

        for (var kingDx = -1; kingDx <= 1; kingDx += 1) {
            for (var kingDy = -1; kingDy <= 1; kingDy += 1) {
                if (kingDx == 0 && kingDy == 0) {
                    continue;
                }

                var kingX = x + kingDx;
                var kingY = y + kingDy;

                if (isOnBoard(kingX, kingY) && _board[toSquare(kingX, kingY)] == bySide * CG_KING) {
                    return true;
                }
            }
        }

        return false;
    }

    function isAttackedBySlider(x, y, bySide, dx, dy, diagonal) {
        var targetX = x + dx;
        var targetY = y + dy;

        while (isOnBoard(targetX, targetY)) {
            var piece = _board[toSquare(targetX, targetY)];

            if (piece != CG_EMPTY) {
                if (isOwnPiece(piece, bySide)) {
                    var absPiece = absNumber(piece);

                    if (diagonal && (absPiece == CG_BISHOP || absPiece == CG_QUEEN)) {
                        return true;
                    }

                    if (!diagonal && (absPiece == CG_ROOK || absPiece == CG_QUEEN)) {
                        return true;
                    }
                }

                return false;
            }

            targetX += dx;
            targetY += dy;
        }

        return false;
    }

    function rootNoise() {
        if (_noise <= 0) {
            return 0;
        }

        return nextRandom(_noise + _noise + 1) - _noise;
    }

    function nextRandom(maxValue) {
        _seed = (_seed * 73 + 41) % 9973;

        if (maxValue <= 0) {
            return 0;
        }

        return _seed % maxValue;
    }

    function fileOf(square) {
        return square % 8;
    }

    function rankOf(square) {
        return (square / 8).toNumber();
    }

    function toSquare(x, y) {
        return y * 8 + x;
    }

    function isOnBoard(x, y) {
        return x >= 0 && x < 8 && y >= 0 && y < 8;
    }

    function isOwnPiece(piece, side) {
        return piece * side > 0;
    }

    function isEnemyPiece(piece, side) {
        return piece * side < 0;
    }

    function absNumber(value) {
        return value < 0 ? -value : value;
    }
}
