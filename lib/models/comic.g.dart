// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint

part of 'comic.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ComicAdapter extends TypeAdapter<Comic> {
  @override
  final int typeId = 0;

  @override
  Comic read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Comic(
      id: fields[0] as String,
      title: fields[1] as String,
      folderPath: fields[2] as String,
      filePaths: (fields[3] as List).cast<String>(),
      sortNumber: fields[4] as int,
      isFavorite: fields[5] as bool,
      bookmarkedPages: (fields[6] as List).cast<int>(),
      lastReadPage: fields[7] as int,
      coverImagePath: fields[8] as String?,
      lastOpenedAt: fields[9] as DateTime?,
      seriesName: fields[10] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Comic obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.folderPath)
      ..writeByte(3)
      ..write(obj.filePaths)
      ..writeByte(4)
      ..write(obj.sortNumber)
      ..writeByte(5)
      ..write(obj.isFavorite)
      ..writeByte(6)
      ..write(obj.bookmarkedPages)
      ..writeByte(7)
      ..write(obj.lastReadPage)
      ..writeByte(8)
      ..write(obj.coverImagePath)
      ..writeByte(9)
      ..write(obj.lastOpenedAt)
      ..writeByte(10)
      ..write(obj.seriesName);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ComicAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AppSettingsAdapter extends TypeAdapter<AppSettings> {
  @override
  final int typeId = 1;

  @override
  AppSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AppSettings(
      rootDirectoryPath: fields[0] as String?,
      isDarkMode: fields[1] as bool,
      useVerticalScroll: fields[2] as bool,
      lastOpenedComicId: fields[3] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, AppSettings obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.rootDirectoryPath)
      ..writeByte(1)
      ..write(obj.isDarkMode)
      ..writeByte(2)
      ..write(obj.useVerticalScroll)
      ..writeByte(3)
      ..write(obj.lastOpenedComicId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
