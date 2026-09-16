import 'package:flutter/material.dart';
import 'package:stormy_kit/stormy_kit.dart';

/// Storage Demo Page
/// 展示 stormy_kit/core/storage 的使用方式
class StorageDemoPage extends StatefulWidget {
  const StorageDemoPage({super.key});

  @override
  State<StorageDemoPage> createState() => _StorageDemoPageState();
}

class _StorageDemoPageState extends State<StorageDemoPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('StormyStorage Demo'),
        centerTitle: true,
        foregroundColor: theme.colorScheme.onPrimary,
        bottom: BaseTabBar(
          controller: _tabController,
          tabs: const ['基础存取', '过期管理', '列表操作', 'Box 管理'],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _BasicStorageTab(),
          _ExpiryTab(),
          _ListTab(),
          _BoxManagerTab(),
        ],
      ),
    );
  }
}

// ============================================================================
// Tab 1: 基础存取
// ============================================================================
class _BasicStorageTab extends StatefulWidget {
  const _BasicStorageTab();

  @override
  State<_BasicStorageTab> createState() => _BasicStorageTabState();
}

class _BasicStorageTabState extends State<_BasicStorageTab> {
  final _keyController = TextEditingController();
  final _valueController = TextEditingController();
  String? _currentBucketName;
  List<MapEntry<Object, dynamic>> _entries = [];

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  @override
  void dispose() {
    _keyController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  void _loadEntries() {
    final storage = StormyStorage.instance;
    final bucketName = _currentBucketName ?? storage.currentBucketName;

    setState(() {
      _currentBucketName = bucketName;
      final accessor = storage.bucket(bucketName);
      final keys = accessor.getKeys();
      _entries = keys.map((key) {
        return MapEntry(key, accessor.get(key));
      }).toList();
    });
  }

  Future<void> _setString() async {
    if (_keyController.text.isEmpty) return;
    await StormyStorage.instance
        .bucket(_currentBucketName!)
        .setString(_keyController.text, _valueController.text);
    _loadEntries();
  }

  Future<void> _setInt() async {
    if (_keyController.text.isEmpty) return;
    final value = int.tryParse(_valueController.text);
    if (value == null) return;
    await StormyStorage.instance
        .bucket(_currentBucketName!)
        .setInt(_keyController.text, value);
    _loadEntries();
  }

  Future<void> _setBool() async {
    if (_keyController.text.isEmpty) return;
    final value = _valueController.text.toLowerCase() == 'true';
    await StormyStorage.instance
        .bucket(_currentBucketName!)
        .setBool(_keyController.text, value);
    _loadEntries();
  }

  Future<void> _setJson() async {
    if (_keyController.text.isEmpty || _valueController.text.isEmpty) return;
    try {
      // 简单 JSON 解析
      final json = {
        'data': _valueController.text,
        'timestamp': DateTime.now().toIso8601String()
      };
      await StormyStorage.instance
          .bucket(_currentBucketName!)
          .setJson(_keyController.text, json);
      _loadEntries();
    } catch (e) {
      _showSnackBar('JSON 格式错误');
    }
  }

  void _getValue() {
    if (_keyController.text.isEmpty) return;
    final value = StormyStorage.instance
        .bucket(_currentBucketName!)
        .get(_keyController.text);
    setState(() {
      _valueController.text = value?.toString() ?? '';
    });
  }

  Future<void> _deleteValue() async {
    if (_keyController.text.isEmpty) return;
    await StormyStorage.instance
        .bucket(_currentBucketName!)
        .remove(_keyController.text);
    _loadEntries();
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 当前 Box 信息
          Container(
            padding: EdgeInsets.all(12.r),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Row(
              children: [
                Icon(Icons.folder,
                    size: 20.r, color: theme.colorScheme.primary),
                SizedBox(width: 8.w),
                DropdownButton<String>(
                  value: _currentBucketName ??
                      StormyStorage.instance.currentBucketName,
                  isDense: true,
                  underline: const SizedBox(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  items: StormyStorage.instance.bucketNames.map((name) {
                    return DropdownMenuItem(
                      value: name,
                      child: Text('当前 Box: $name'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _currentBucketName = val;
                      });
                      _loadEntries();
                    }
                  },
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadEntries,
                  iconSize: 20.r,
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),

          // 输入区域
          Text('Key', style: theme.textTheme.titleSmall),
          SizedBox(height: 8.h),
          BaseInput(
            controller: _keyController,
            hintText: '输入 Key',
          ),
          SizedBox(height: 12.h),

          Text('Value', style: theme.textTheme.titleSmall),
          SizedBox(height: 8.h),
          BaseInput(
            controller: _valueController,
            hintText: '输入 Value',
          ),
          SizedBox(height: 16.h),

          // 操作按钮
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              BaseButton(text: '存入 String', onPressed: _setString),
              BaseButton(text: '存入 Int', onPressed: _setInt),
              BaseButton(text: '存入 Bool', onPressed: _setBool),
              BaseButton(text: '存入 Json', onPressed: _setJson),
              BaseButton(text: '读取', onPressed: _getValue),
              BaseButton(text: '删除', onPressed: _deleteValue),
            ],
          ),
          SizedBox(height: 24.h),

          // 存储数据展示
          Text('存储数据 (${_entries.length} 条)',
              style: theme.textTheme.titleMedium),
          SizedBox(height: 8.h),
          Container(
            constraints: BoxConstraints(maxHeight: 300.h),
            decoration: BoxDecoration(
              border: Border.all(color: theme.dividerColor),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: _entries.isEmpty
                ? Padding(
                    padding: EdgeInsets.all(16.r),
                    child: Text('暂无数据', style: theme.textTheme.bodyMedium),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: _entries.length,
                    itemBuilder: (context, index) {
                      final entry = _entries[index];
                      return ListTile(
                        dense: true,
                        title: Text(
                          entry.key.toString(),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          '$entry.value',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Tab 2: 过期管理
// ============================================================================
class _ExpiryTab extends StatefulWidget {
  const _ExpiryTab();

  @override
  State<_ExpiryTab> createState() => _ExpiryTabState();
}

class _ExpiryTabState extends State<_ExpiryTab> {
  final _keyController = TextEditingController();
  final _secondsController = TextEditingController(text: '60');
  String _expireStatus = '';
  String _clearResult = '';
  String? _currentBucketName;

  @override
  void initState() {
    super.initState();
    _currentBucketName = StormyStorage.instance.currentBucketName;
  }

  Future<void> _setWithExpiry() async {
    if (_keyController.text.isEmpty) return;
    final seconds = int.tryParse(_secondsController.text);
    if (seconds == null) return;

    await StormyStorage.instance.bucket(_currentBucketName!).set(
          _keyController.text,
          '过期数据 - ${DateTime.now()}',
          expiresIn: Duration(seconds: seconds),
        );

    setState(() {
      _expireStatus = '已设置过期时间: $seconds秒';
    });
  }

  void _checkExpiry() {
    if (_keyController.text.isEmpty) return;
    final isExpired = StormyStorage.instance
        .bucket(_currentBucketName!)
        .isExpired(_keyController.text);
    final remaining = StormyStorage.instance
        .bucket(_currentBucketName!)
        .getExpiresIn(_keyController.text);

    setState(() {
      if (isExpired) {
        _expireStatus = '已过期';
      } else if (remaining != null) {
        _expireStatus = '未过期 (剩余: ${remaining.inSeconds}秒)';
      } else {
        _expireStatus = '未过期 (无过期时间或不存在)';
      }
    });
  }

  Future<void> _clearExpired() async {
    final count =
        await StormyStorage.instance.bucket(_currentBucketName!).clearExpired();
    setState(() {
      _clearResult = '已清理 $count 条过期数据';
    });
  }

  @override
  void dispose() {
    _keyController.dispose();
    _secondsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('过期管理功能演示', style: theme.textTheme.titleMedium),
              DropdownButton<String>(
                value: _currentBucketName,
                isDense: true,
                underline: const SizedBox(),
                items: StormyStorage.instance.bucketNames.map((name) {
                  return DropdownMenuItem(value: name, child: Text(name));
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _currentBucketName = val;
                      _expireStatus = '';
                      _clearResult = '';
                    });
                  }
                },
              ),
            ],
          ),
          SizedBox(height: 16.h),

          Text('Key', style: theme.textTheme.titleSmall),
          SizedBox(height: 8.h),
          BaseInput(
            controller: _keyController,
            hintText: '输入 Key',
          ),
          SizedBox(height: 12.h),

          Text('过期时间（秒）', style: theme.textTheme.titleSmall),
          SizedBox(height: 8.h),
          BaseInput(
            controller: _secondsController,
            hintText: '输入秒数',
            keyboardType: TextInputType.number,
          ),
          SizedBox(height: 16.h),

          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              BaseButton(text: '设置过期数据', onPressed: _setWithExpiry),
              BaseButton(text: '检查过期状态', onPressed: _checkExpiry),
              BaseButton(text: '清理过期数据', onPressed: _clearExpired),
            ],
          ),
          SizedBox(height: 24.h),

          // 状态展示
          if (_expireStatus.isNotEmpty) ...[
            Container(
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 20),
                  SizedBox(width: 8.w),
                  Text(_expireStatus),
                ],
              ),
            ),
            SizedBox(height: 12.h),
          ],
          if (_clearResult.isNotEmpty)
            Container(
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cleaning_services, size: 20),
                  SizedBox(width: 8.w),
                  Text(_clearResult),
                ],
              ),
            ),
          SizedBox(height: 24.h),

          // 说明
          Container(
            padding: EdgeInsets.all(12.r),
            decoration: BoxDecoration(
              border: Border.all(color: theme.dividerColor),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('使用说明', style: theme.textTheme.titleSmall),
                SizedBox(height: 8.h),
                Text('1. 输入 Key 和过期时间（秒）点击"设置过期数据"',
                    style: theme.textTheme.bodySmall),
                Text('2. 点击"检查过期状态"查看数据是否过期', style: theme.textTheme.bodySmall),
                Text('3. 点击"清理过期数据"删除所有过期数据', style: theme.textTheme.bodySmall),
                Text('4. 过期数据会在 get 时自动删除', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Tab 3: 列表操作
// ============================================================================
class _ListTab extends StatefulWidget {
  const _ListTab();

  @override
  State<_ListTab> createState() => _ListTabState();
}

class _ListTabState extends State<_ListTab> {
  final _listIdController = TextEditingController(text: 'demo_list');
  final _itemController = TextEditingController();
  final _queryPageController = TextEditingController(text: '1');
  final _queryPageSizeController = TextEditingController(text: '10');

  List<MapEntry<String, dynamic>>? _currentList;

  int _currentPage = 1;
  final int _pageSize = 10;

  List<MapEntry<String, dynamic>> get _paginatedList {
    if (_currentList == null) return [];
    int start = (_currentPage - 1) * _pageSize;
    if (start >= _currentList!.length) return [];
    int end = start + _pageSize;
    if (end > _currentList!.length) end = _currentList!.length;
    return _currentList!.sublist(start, end);
  }

  int get _totalPages {
    if (_currentList == null || _currentList!.isEmpty) return 1;
    return (_currentList!.length / _pageSize).ceil();
  }

  @override
  void initState() {
    super.initState();
    _loadList();
  }

  @override
  void dispose() {
    _listIdController.dispose();
    _itemController.dispose();
    _queryPageController.dispose();
    _queryPageSizeController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _loadList() {
    try {
      final listBox =
          StormyStorage.instance.list<dynamic>(_listIdController.text);
      final ids = listBox.getIds();
      final values = listBox.getAll();

      final list =
          List.generate(ids.length, (i) => MapEntry(ids[i], values[i]));
      setState(() {
        _currentList = list;
        int total = (list.length / _pageSize).ceil();
        if (total == 0) total = 1;
        if (_currentPage > total) _currentPage = total;
      });
    } catch (e) {
      _showSnackBar(e.toString());
      setState(() {
        _currentList = [];
      });
    }
  }

  Future<void> _addItem() async {
    if (_itemController.text.isEmpty) return;
    try {
      final listBox =
          StormyStorage.instance.list<dynamic>(_listIdController.text);
      await listBox.add(_itemController.text);
      _itemController.clear();
      _loadList();
    } catch (e) {
      _showSnackBar(e.toString());
    }
  }

  Future<void> _removeItem() async {
    final index = int.tryParse(_itemController.text);
    final list = _currentList;
    if (list == null || index == null || index < 0 || index >= list.length) {
      _showSnackBar('请输入正确的索引值');
      return;
    }
    try {
      final listBox =
          StormyStorage.instance.list<dynamic>(_listIdController.text);
      await listBox.remove(list[index].key);
      _itemController.clear();
      _loadList();
    } catch (e) {
      _showSnackBar(e.toString());
    }
  }

  Future<void> _updateItem() async {
    final parts = _itemController.text.split(':');
    final list = _currentList;
    if (list == null || parts.length != 2) {
      _showSnackBar('格式错误，请使用 索引:新内容');
      return;
    }
    final index = int.tryParse(parts[0]);
    if (index == null || index < 0 || index >= list.length) return;

    try {
      final listBox =
          StormyStorage.instance.list<dynamic>(_listIdController.text);
      await listBox.update(list[index].key, parts[1]);
      _itemController.clear();
      _loadList();
    } catch (e) {
      _showSnackBar(e.toString());
    }
  }

  Future<void> _clearList() async {
    try {
      final listBox =
          StormyStorage.instance.list<dynamic>(_listIdController.text);
      await listBox.clear();
      _loadList();
    } catch (e) {
      _showSnackBar(e.toString());
    }
  }

  Future<void> _addBatchItems() async {
    try {
      final listBox =
          StormyStorage.instance.list<dynamic>(_listIdController.text);
      final startIndex = _currentList?.length ?? 0;
      final newItems =
          List.generate(100, (index) => '批量项 ${startIndex + index}');
      await listBox.addAll(newItems);
      _loadList();
    } catch (e) {
      _showSnackBar(e.toString());
    }
  }

  void _querySpecificPage() {
    final pageNum = int.tryParse(_queryPageController.text) ?? 1;
    final queryPageSize = int.tryParse(_queryPageSizeController.text) ?? 10;

    try {
      final listBox =
          StormyStorage.instance.list<dynamic>(_listIdController.text);
      final list = listBox.getAll();

      int start = (pageNum - 1) * queryPageSize;
      List<dynamic> result = [];
      if (start < list.length && start >= 0) {
        int end = start + queryPageSize;
        if (end > list.length) end = list.length;
        result = list.sublist(start, end);
      }

      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('第 $pageNum 页查询结果 (共 ${result.length} 条)'),
            content: SizedBox(
              width: double.maxFinite,
              height: 300,
              child: ListView.builder(
                itemCount: result.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    dense: true,
                    leading: Text('${start + index}',
                        style: TextStyle(fontSize: 12)),
                    title: Text('${result[index]}'),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('关闭'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      _showSnackBar(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('原生列表存储功能演示', style: theme.textTheme.titleMedium),
          SizedBox(height: 16.h),

          Text('Key (表字段)', style: theme.textTheme.titleSmall),
          SizedBox(height: 8.h),
          BaseInput(
            controller: _listIdController,
            hintText: '输入存储列表的 Key',
          ),
          SizedBox(height: 12.h),

          Text('内容操作（插入值、或者是 更新 0:新的内容）', style: theme.textTheme.titleSmall),
          SizedBox(height: 8.h),
          BaseInput(
            controller: _itemController,
            hintText: '输入列表项目内容',
          ),
          SizedBox(height: 16.h),

          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              BaseButton(text: '加载', onPressed: _loadList),
              BaseButton(text: '添加', onPressed: _addItem),
              BaseButton(text: '批量生成100条', onPressed: _addBatchItems),
              BaseButton(text: '更新(索引:值)', onPressed: _updateItem),
              BaseButton(text: '删除(按索引)', onPressed: _removeItem),
              BaseButton(text: '完全清空该列表', onPressed: _clearList),
            ],
          ),
          SizedBox(height: 24.h),

          // 新增查询指定分页的功能区
          Text('单独查询测试 (输入页码与每页数量)', style: theme.textTheme.titleSmall),
          SizedBox(height: 8.h),
          Row(
            children: [
              Expanded(
                flex: 1,
                child: BaseInput(
                  controller: _queryPageController,
                  hintText: '页码',
                  keyboardType: TextInputType.number,
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                flex: 1,
                child: BaseInput(
                  controller: _queryPageSizeController,
                  hintText: '数量',
                  keyboardType: TextInputType.number,
                ),
              ),
              SizedBox(width: 8.w),
              BaseButton(
                text: '弹窗展示结果',
                onPressed: _querySpecificPage,
              ),
            ],
          ),
          SizedBox(height: 16.h),

          // 列表展示
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(12.r),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('原生集合的内容 (共 ${_currentList?.length ?? 0} 条)',
                        style: theme.textTheme.titleSmall),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 20),
                      onPressed: _loadList,
                    ),
                  ],
                ),
                if (_currentList == null || _currentList!.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.r),
                    child: Text('当前集合无数据', style: theme.textTheme.bodyMedium),
                  )
                else ...[
                  ...List.generate(_paginatedList.length, (index) {
                    // 显示真实索引
                    final realIndex = (_currentPage - 1) * _pageSize + index;
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 12.r,
                        child: Text('$realIndex',
                            style: TextStyle(fontSize: 10.sp)),
                      ),
                      title: Text('${_paginatedList[index].value}'),
                    );
                  }),
                  // 分页控件
                  if (_totalPages > 1) ...[
                    SizedBox(height: 8.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios, size: 16),
                          onPressed: _currentPage > 1
                              ? () => setState(() => _currentPage--)
                              : null,
                        ),
                        Text('第 $_currentPage / $_totalPages 页',
                            style: theme.textTheme.bodyMedium),
                        IconButton(
                          icon: const Icon(Icons.arrow_forward_ios, size: 16),
                          onPressed: _currentPage < _totalPages
                              ? () => setState(() => _currentPage++)
                              : null,
                        ),
                      ],
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Tab 4: Box 管理
// ============================================================================
class _BoxManagerTab extends StatefulWidget {
  const _BoxManagerTab();

  @override
  State<_BoxManagerTab> createState() => _BoxManagerTabState();
}

class _BoxManagerTabState extends State<_BoxManagerTab> {
  String? _selectedBucket;
  bool _isEncrypted = false;
  int _keyCount = 0;

  @override
  void initState() {
    super.initState();
    _loadBoxInfo();
  }

  void _loadBoxInfo() {
    final storage = StormyStorage.instance;
    setState(() {
      _selectedBucket ??= storage.currentBucketName;
      _keyCount = storage.bucket(_selectedBucket!).getKeys().length;
      _isEncrypted = storage.bucketNames.contains('secure_data') &&
          _selectedBucket == 'secure_data';
    });
  }

  void _switchBox(String? bucketName) {
    if (bucketName == null) return;
    setState(() {
      _selectedBucket = bucketName;
    });
    _loadBoxInfo();
  }

  Future<void> _clearCurrentBox() async {
    if (_selectedBucket == null) return;
    await StormyStorage.instance.bucket(_selectedBucket!).clear();
    _loadBoxInfo();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Box "$_selectedBucket" 已清空')),
      );
    }
  }

  Future<void> _testEncryptedBox() async {
    // 演示加密 Box 功能
    await StormyStorage.instance
        .bucket(_selectedBucket!)
        .setString('encrypted_test', '这是一条加密数据');
    final value = StormyStorage.instance
        .bucket(_selectedBucket!)
        .getString('encrypted_test');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_selectedBucket == 'secure_data'
              ? '加密 Box 写入/读取成功: $value'
              : '非加密 Box 测试完成'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final storage = StormyStorage.instance;
    final bucketNames = storage.bucketNames;

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Box 管理功能演示', style: theme.textTheme.titleMedium),
          SizedBox(height: 16.h),

          // Box 选择器
          Text('切换 Box', style: theme.textTheme.titleSmall),
          SizedBox(height: 8.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.r),
            decoration: BoxDecoration(
              border: Border.all(color: theme.dividerColor),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: DropdownButton<String>(
              value: _selectedBucket,
              isExpanded: true,
              underline: const SizedBox(),
              items: bucketNames.map((name) {
                return DropdownMenuItem<String>(
                  value: name,
                  child: Row(
                    children: [
                      Icon(
                        name == 'secure_data' ? Icons.lock : Icons.folder,
                        size: 18.r,
                        color: theme.colorScheme.primary,
                      ),
                      SizedBox(width: 8.w),
                      Text(name),
                      if (name == 'secure_data')
                        Padding(
                          padding: EdgeInsets.only(left: 8.w),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6.r,
                              vertical: 2.r,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                            child: Text(
                              '加密',
                              style: TextStyle(
                                fontSize: 10.sp,
                                color: theme.colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: _switchBox,
            ),
          ),
          SizedBox(height: 24.h),

          // Box 信息展示
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16.r),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Column(
              children: [
                _InfoRow(label: 'Box 名称', value: _selectedBucket ?? '-'),
                SizedBox(height: 8.h),
                _InfoRow(label: '数据条数', value: '$_keyCount'),
                SizedBox(height: 8.h),
                _InfoRow(
                  label: '加密状态',
                  value: _isEncrypted ? '已加密' : '未加密',
                  valueColor: _isEncrypted
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                ),
              ],
            ),
          ),
          SizedBox(height: 24.h),

          // 操作按钮
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              BaseButton(
                text: '清空当前 Box',
                onPressed: _clearCurrentBox,
              ),
              BaseButton(
                text: '测试加密功能',
                onPressed: _testEncryptedBox,
              ),
              BaseButton(
                text: '刷新信息',
                onPressed: _loadBoxInfo,
              ),
            ],
          ),
          SizedBox(height: 24.h),

          // 所有 Box 概览
          Text('所有 Box 概览', style: theme.textTheme.titleSmall),
          SizedBox(height: 8.h),
          ...bucketNames.map((name) {
            final keyCount = storage.bucket(name).getKeys().length;
            final config = storage.getBucketConfig(name);
            return Container(
              margin: EdgeInsets.only(bottom: 8.h),
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                border: Border.all(color: theme.dividerColor),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Row(
                children: [
                  Icon(
                    name == 'secure_data' ? Icons.lock : Icons.folder,
                    size: 24.r,
                    color: theme.colorScheme.primary,
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: theme.textTheme.titleSmall),
                        Text(
                          '分类: ${config?.category ?? "-"} | 数据: $keyCount 条',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (name == _selectedBucket)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.r,
                        vertical: 4.r,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                      child: Text(
                        '当前',
                        style: TextStyle(
                          color: theme.colorScheme.onPrimary,
                          fontSize: 10.sp,
                        ),
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: theme.textTheme.bodyMedium),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
