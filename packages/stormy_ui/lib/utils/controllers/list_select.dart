/// 列表选择状态管理控制器
///
/// 使用方式：
///
/// 1. 在父组件中使用 ListSelectScope 包裹列表：
/// ```dart
/// ListSelectScope<ProjectItem>(
///   controller: _controller,  // 外部传入 controller
///   child: YourListView(),
/// )
/// ```
///
/// 2. 父组件通过 controller 控制选择状态：
/// ```dart
/// // 创建 controller
/// final controller = ListSelectController<ProjectItem>();
///
/// // 切换选择模式
/// controller.toggleSelectMode();
/// controller.setSelectMode(true);
///
/// // 全选/取消全选
/// controller.selectAll(['id1', 'id2']);
/// controller.selectAllByItems(items);
/// controller.deselectAll();
///
/// // 获取已选 id
/// controller.selectedIds
/// controller.selectedCount
///
/// // 退出选择模式（清空选择）
/// controller.exitSelectMode();
/// ```
///
/// 3. 子组件直接通过 context 使用：
/// ```dart
/// // 判断是否在选择模式
/// context.isSelectMode<ProjectItem>()
///
/// // 判断当前项是否选中
/// context.isItemSelectedByScope<ProjectItem>(item)
///
/// // 切换选择状态
/// context.toggleItemSelectionByScope<ProjectItem>(item)
///
/// // 获取已选数量
/// context.selectedCount<ProjectItem>()
/// ```
library;

import 'package:flutter/material.dart';

/// 选择控制器（供父组件使用）
class ListSelectController<T> extends ChangeNotifier {
  ListSelectController();

  ListSelectState<T>? _state;

  void _attach(ListSelectState<T> state) {
    if (_state == state) return;
    _state?.removeListener(_onStateChanged);
    _state = state;
    _state?.addListener(_onStateChanged);
    notifyListeners();
  }

  void _onStateChanged() {
    notifyListeners();
  }

  /// 是否处于选择模式
  bool get isSelectMode => _state?.isSelectMode ?? false;

  /// 设置选择模式
  void setSelectMode(bool value) {
    _state?.setSelectMode(value);
  }

  /// 切换选择模式
  void toggleSelectMode() {
    _state?.toggleSelectMode();
  }

  /// 退出选择模式并清空选择
  void exitSelectMode() {
    _state?.setSelectMode(false);
  }

  /// 全选
  void selectAll(List<String> ids) {
    _state?.selectAll(ids);
  }

  /// 通过项目列表全选
  void selectAllByItems(List<T> items, String Function(T) getId) {
    _state?.selectAll(items.map(getId).toList());
  }

  /// 取消全选
  void deselectAll() {
    _state?.clearSelection();
  }

  /// 切换单个项目选择状态
  void toggleSelection(String id) {
    _state?.toggleSelection(id);
  }

  /// 选中单个项目
  void selectItem(String id) {
    _state?.selectItem(id);
  }

  /// 取消选中单个项目
  void deselectItem(String id) {
    _state?.deselectItem(id);
  }

  /// 获取已选中的 ID 集合
  Set<String> get selectedIds => _state?.selectedIds ?? {};

  /// 获取已选中的数量
  int get selectedCount => _state?.selectedCount ?? 0;

  /// 是否有选中项
  bool get hasSelection => _state?.hasSelection ?? false;
}

/// 选择状态管理器
class ListSelectState<T> extends ChangeNotifier {
  ListSelectState({this.isSelectMode = false, Set<String>? selectedIds})
    : _selectedIds = selectedIds ?? {};

  bool isSelectMode;
  final Set<String> _selectedIds;

  Set<String> get selectedIds => Set.unmodifiable(_selectedIds);

  bool isItemSelected(String id) => _selectedIds.contains(id);

  bool isItemSelectedByItem(T item, String Function(T) getId) =>
      _selectedIds.contains(getId(item));

  void toggleSelectMode() {
    isSelectMode = !isSelectMode;
    if (!isSelectMode) {
      _selectedIds.clear();
    }
    notifyListeners();
  }

  void setSelectMode(bool value) {
    if (isSelectMode != value) {
      isSelectMode = value;
      if (!value) {
        _selectedIds.clear();
      }
      notifyListeners();
    }
  }

  void toggleSelection(String id) {
    if (_selectedIds.contains(id)) {
      _selectedIds.remove(id);
    } else {
      _selectedIds.add(id);
    }
    notifyListeners();
  }

  void selectItem(String id) {
    if (!_selectedIds.contains(id)) {
      _selectedIds.add(id);
      notifyListeners();
    }
  }

  void deselectItem(String id) {
    if (_selectedIds.remove(id)) {
      notifyListeners();
    }
  }

  void selectAll(List<String> ids) {
    _selectedIds.addAll(ids);
    notifyListeners();
  }

  void clearSelection() {
    if (_selectedIds.isNotEmpty) {
      _selectedIds.clear();
      notifyListeners();
    }
  }

  int get selectedCount => _selectedIds.length;

  bool get hasSelection => _selectedIds.isNotEmpty;
}

/// InheritedWidget 封装
class ListSelectInherited<T> extends InheritedWidget {
  const ListSelectInherited({
    super.key,
    required this.state,
    required super.child,
    required this.getItemId,
    required this.controller,
  });

  final ListSelectState<T> state;
  final ListSelectController<T> controller;
  final String Function(T) getItemId;

  @override
  bool updateShouldNotify(ListSelectInherited<T> oldWidget) => true;
}

/// 父容器组件
class ListSelectScope<T> extends StatefulWidget {
  const ListSelectScope({
    super.key,
    required this.child,
    required this.getItemId,
    required this.controller,
    this.initialSelectedIds,
    this.isSelectMode = false,
  });

  final Widget child;
  final String Function(T) getItemId;
  final ListSelectController<T> controller;
  final Set<String>? initialSelectedIds;
  final bool isSelectMode;

  @override
  State<ListSelectScope<T>> createState() => _ListSelectScopeState<T>();
}

class _ListSelectScopeState<T> extends State<ListSelectScope<T>> {
  late ListSelectState<T> _state;
  bool _isStateCreatedByScope = false;

  @override
  void initState() {
    super.initState();
    _initState();
  }

  void _initState() {
    // 优先使用 controller 已关联的 state，如果没有则创建新的
    _state =
        widget.controller._state ??
        ListSelectState<T>(
          isSelectMode: widget.isSelectMode,
          selectedIds: widget.initialSelectedIds,
        );
    _isStateCreatedByScope = widget.controller._state == null;
    widget.controller._attach(_state);
  }

  @override
  void didUpdateWidget(ListSelectScope<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 同步外部 isSelectMode 到 state
    if (widget.isSelectMode != oldWidget.isSelectMode) {
      _state.setSelectMode(widget.isSelectMode);
    }
    // 处理 controller 变化
    if (widget.controller != oldWidget.controller) {
      widget.controller._attach(_state);
    }
  }

  @override
  void dispose() {
    if (_isStateCreatedByScope) {
      _state.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenedListSelectInherited<T>(
      controller: widget.controller,
      state: _state,
      getItemId: widget.getItemId,
      child: widget.child,
    );
  }
}

/// 监听 controller 状态变化的 InheritedWidget
class ListenedListSelectInherited<T> extends StatefulWidget {
  const ListenedListSelectInherited({
    super.key,
    required this.state,
    required this.controller,
    required this.getItemId,
    required this.child,
  });

  final ListSelectState<T> state;
  final ListSelectController<T> controller;
  final String Function(T) getItemId;
  final Widget child;

  @override
  State<ListenedListSelectInherited<T>> createState() =>
      _ListenedListSelectInheritedState<T>();
}

class _ListenedListSelectInheritedState<T>
    extends State<ListenedListSelectInherited<T>> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(ListenedListSelectInherited<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    // controller 状态变化时触发重建
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ListSelectInherited<T>(
      state: widget.state,
      controller: widget.controller,
      getItemId: widget.getItemId,
      child: widget.child,
    );
  }
}

/// 便捷扩展
extension ListSelectContextExtension on BuildContext {
  /// 获取选择状态
  ListSelectState? listSelectState() {
    final inherited =
        dependOnInheritedWidgetOfExactType<ListSelectInherited<dynamic>>();
    return inherited?.state;
  }

  /// 获取选择控制器
  ListSelectController<T>? listSelectController<T>() {
    final inherited =
        dependOnInheritedWidgetOfExactType<ListSelectInherited<T>>();
    return inherited?.controller;
  }

  /// 判断项目是否选中
  bool isItemSelected<T>(T item, String Function(T) getId) {
    final inherited =
        dependOnInheritedWidgetOfExactType<ListSelectInherited<T>>();
    if (inherited == null) return false;
    return inherited.state.isItemSelectedByItem(item, getId);
  }

  /// 便捷判断项目是否选中（使用 Scope 中定义的 getItemId）
  bool isItemSelectedByScope<T>(T item) {
    final inherited =
        dependOnInheritedWidgetOfExactType<ListSelectInherited<T>>();
    if (inherited == null) return false;
    return inherited.state.isItemSelectedByItem(item, inherited.getItemId);
  }

  /// 切换项目选择状态
  void toggleItemSelection<T>(T item, String Function(T) getId) {
    final inherited =
        dependOnInheritedWidgetOfExactType<ListSelectInherited<T>>();
    inherited?.state.toggleSelection(getId(item));
  }

  /// 便捷切换项目选择状态（使用 Scope 中定义的 getItemId）
  void toggleItemSelectionByScope<T>(T item) {
    final inherited =
        dependOnInheritedWidgetOfExactType<ListSelectInherited<T>>();
    final id = inherited?.getItemId(item);
    if (id != null) {
      inherited?.state.toggleSelection(id);
    }
  }

  /// 判断是否处于选择模式
  bool isSelectMode<T>() {
    final inherited =
        dependOnInheritedWidgetOfExactType<ListSelectInherited<T>>();
    return inherited?.state.isSelectMode ?? false;
  }

  /// 全选
  void selectAllItems<T>(List<T> items, String Function(T) getId) {
    final inherited =
        dependOnInheritedWidgetOfExactType<ListSelectInherited<T>>();
    final state = inherited?.state;
    if (state != null) {
      state.selectAll(items.map(getId).toList());
    }
  }

  /// 便捷全选
  void selectAllItemsByScope<T>(List<T> items) {
    final inherited =
        dependOnInheritedWidgetOfExactType<ListSelectInherited<T>>();
    final state = inherited?.state;
    final getId = inherited?.getItemId;
    if (state != null && getId != null) {
      state.selectAll(items.map(getId).toList());
    }
  }

  /// 清空选择
  void clearSelection<T>() {
    final inherited =
        dependOnInheritedWidgetOfExactType<ListSelectInherited<T>>();
    inherited?.state.clearSelection();
  }

  /// 获取已选中的数量
  int selectedCount<T>() {
    final inherited =
        dependOnInheritedWidgetOfExactType<ListSelectInherited<T>>();
    return inherited?.state.selectedCount ?? 0;
  }
}
