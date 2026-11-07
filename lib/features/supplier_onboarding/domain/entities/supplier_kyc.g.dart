// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'supplier_kyc.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SupplierDocumentImpl _$$SupplierDocumentImplFromJson(
  Map<String, dynamic> json,
) => _$SupplierDocumentImpl(
  id: json['id'] as String,
  type: $enumDecode(_$SupplierDocumentTypeEnumMap, json['type']),
  filePath: json['file_path'] as String,
  uploadedAt: DateTime.parse(json['uploaded_at'] as String),
);

Map<String, dynamic> _$$SupplierDocumentImplToJson(
  _$SupplierDocumentImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'type': _$SupplierDocumentTypeEnumMap[instance.type]!,
  'file_path': instance.filePath,
  'uploaded_at': instance.uploadedAt.toIso8601String(),
};

const _$SupplierDocumentTypeEnumMap = {
  SupplierDocumentType.rccmCertificate: 'rccm_certificate',
  SupplierDocumentType.entreprenantDeclaration: 'entreprenant_declaration',
  SupplierDocumentType.articlesOfAssociation: 'articles_of_association',
  SupplierDocumentType.taxId: 'tax_id',
  SupplierDocumentType.managerIdCard: 'manager_id_card',
  SupplierDocumentType.proofOfAddress: 'proof_of_address',
  SupplierDocumentType.nationalIdFront: 'national_id_front',
  SupplierDocumentType.nationalIdBack: 'national_id_back',
  SupplierDocumentType.selfieWithId: 'selfie_with_id',
};
