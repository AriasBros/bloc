part of 'replay_cubit.dart';

typedef _Predicate<T> = bool Function(T);
typedef _FromJson<T> = T Function(Map<String, dynamic> json);
typedef _ToJson<T> = Map<String, dynamic> Function(T state);
typedef _Emit<T> = void Function(T state);

class _ChangeStack<T> {
  _ChangeStack({
    this.limit,
    required _Predicate<T> shouldReplay,
    _FromJson<T>? stateFromJson,
    _ToJson<T>? stateToJson,
    _Emit<T>? emit,
  })  : _shouldReplay = shouldReplay,
        _emit = emit,
        _stateFromJson = stateFromJson,
        _stateToJson = stateToJson;

  final Queue<_Change<T>> _history = ListQueue();
  final Queue<_Change<T>> _redos = ListQueue();
  final _Predicate<T> _shouldReplay;
  final _FromJson<T>? _stateFromJson;
  final _ToJson<T>? _stateToJson;
  final _Emit<T>? _emit;

  int? limit;

  bool get canRedo => _redos.any((c) => _shouldReplay(c._newValue));
  bool get canUndo => _history.any((c) => _shouldReplay(c._oldValue));

  void add(_Change<T> change) {
    if (limit != null && limit == 0) return;

    _history.addLast(change);
    _redos.clear();

    if (limit != null && _history.length > limit!) {
      if (limit! > 0) _history.removeFirst();
    }
  }

  void clear() {
    _history.clear();
    _redos.clear();
  }

  void redo() {
    if (canRedo) {
      final change = _redos.removeFirst();
      _history.addLast(change);
      return _shouldReplay(change._newValue) ? change.execute() : redo();
    }
  }

  void undo() {
    if (canUndo) {
      final change = _history.removeLast();
      _redos.addFirst(change);
      return _shouldReplay(change._oldValue) ? change.undo() : undo();
    }
  }

  void restore(Map<String, dynamic> json) {
    var history = json['history'] as List<dynamic>;
    _restoreQueue(_history, history);
  }

  void _restoreQueue(Queue<_Change<T>> queue, List<dynamic> json) {
    for (var data in json) {
      var oldState = _stateFromJson!(data['oldValue'] as Map<String, dynamic>);
      var newState = _stateFromJson!(data['newValue'] as Map<String, dynamic>);

      queue.add(_Change<T>(
        oldState,
        newState,
        () => _emit!(newState),
        (val) => _emit!(val),
      ));
    }
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'history': _history.map((change) => change.toJson(_stateToJson!)).toList(),
    };
  }
}

class _Change<T> {
  _Change(
    this._oldValue,
    this._newValue,
    this._execute(),
    this._undo(T oldValue),
  );

  final T _oldValue;
  final T _newValue;
  final Function _execute;
  final Function(T oldValue) _undo;

  void execute() => _execute();
  void undo() => _undo(_oldValue);

  Map<String, dynamic> toJson(_ToJson<T> toJson) {
    return <String, dynamic>{
      'newValue': toJson(_newValue),
      'oldValue': toJson(_oldValue),
    };
  }
}
