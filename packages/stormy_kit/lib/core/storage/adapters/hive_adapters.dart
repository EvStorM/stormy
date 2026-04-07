import 'package:hive_ce/hive.dart';
import '../models/storage_entry.dart';

/// Hive [TypeAdapter] for [StorageEntry]
/// 使用原生二进制序列化以获得最优性能
class StorageEntryAdapter extends TypeAdapter<StorageEntry<dynamic>> {
  @override
  final int typeId = 222;

  @override
  StorageEntry<dynamic> read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return StorageEntry<dynamic>(
      value: fields[0],
      expiresAt: fields[1] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, StorageEntry<dynamic> obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.value)
      ..writeByte(1)
      ..write(obj.expiresAt);
  }
}
