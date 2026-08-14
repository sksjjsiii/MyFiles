// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'logic.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class GoldTransactionAdapter extends TypeAdapter<GoldTransaction> {
  @override
  final int typeId = 0;

  @override
  GoldTransaction read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return GoldTransaction(
      id: fields[0] as String,
      type: fields[1] as String,
      purchaseDate: fields[2] as DateTime,
      purchasePricePerUnit: fields[3] as double,
      quantity: fields[4] as double,
      description: fields[5] as String,
      remainingQuantity: fields[6] as double?,
    );
  }

  @override
  void write(BinaryWriter writer, GoldTransaction obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.type)
      ..writeByte(2)
      ..write(obj.purchaseDate)
      ..writeByte(3)
      ..write(obj.purchasePricePerUnit)
      ..writeByte(4)
      ..write(obj.quantity)
      ..writeByte(5)
      ..write(obj.description)
      ..writeByte(6)
      ..write(obj.remainingQuantity);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GoldTransactionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CoinTransactionAdapter extends TypeAdapter<CoinTransaction> {
  @override
  final int typeId = 1;

  @override
  CoinTransaction read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CoinTransaction(
      id: fields[0] as String,
      coinType: fields[1] as String,
      purchaseDate: fields[2] as DateTime,
      purchasePricePerUnit: fields[3] as double,
      count: fields[4] as int,
      description: fields[5] as String,
      remainingCount: fields[6] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, CoinTransaction obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.coinType)
      ..writeByte(2)
      ..write(obj.purchaseDate)
      ..writeByte(3)
      ..write(obj.purchasePricePerUnit)
      ..writeByte(4)
      ..write(obj.count)
      ..writeByte(5)
      ..write(obj.description)
      ..writeByte(6)
      ..write(obj.remainingCount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CoinTransactionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SaleTransactionAdapter extends TypeAdapter<SaleTransaction> {
  @override
  final int typeId = 2;

  @override
  SaleTransaction read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SaleTransaction(
      id: fields[0] as String,
      lotId: fields[1] as String,
      saleDate: fields[2] as DateTime,
      salePricePerUnit: fields[3] as double,
      quantity: fields[4] as double,
      isGold: fields[5] as bool,
      coinType: fields[6] as String?,
      purchasePricePerUnit: fields[7] as double,
      purchaseDate: fields[8] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, SaleTransaction obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.lotId)
      ..writeByte(2)
      ..write(obj.saleDate)
      ..writeByte(3)
      ..write(obj.salePricePerUnit)
      ..writeByte(4)
      ..write(obj.quantity)
      ..writeByte(5)
      ..write(obj.isGold)
      ..writeByte(6)
      ..write(obj.coinType)
      ..writeByte(7)
      ..write(obj.purchasePricePerUnit)
      ..writeByte(8)
      ..write(obj.purchaseDate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SaleTransactionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
