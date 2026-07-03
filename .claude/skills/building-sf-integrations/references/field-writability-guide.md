<!-- Parent: building-sf-integrations/SKILL.md -->
# Field Writability Guide

外部システムから Salesforce にデータを push する際、`FIELD_NOT_WRITEABLE` エラーが発生することがある。
統合開発の前に対象フィールドの書き込み可否を確認すること。

## FIELD_NOT_WRITEABLE

**Error**: `Field is not writeable: ObjectName.FieldName`

**よくある原因**:
- 数式フィールド（Formula）— 計算値のため読み取り専用
- ロールアップサマリーフィールド — 集計値のため直接更新不可
- システムフィールド — `CreatedDate`, `LastModifiedDate`, `CreatedById` など
- 外部システム連携専用フィールド — 設定により書き込み不可
- 一部オブジェクトの参照フィールド — 作成後にロックされるケース（例: `Quote.OpportunityId`）

## 事前チェック: isUpdateable()

統合コードを書く前に、フィールドの書き込み可否を確認する。

```apex
// 特定フィールドの書き込み可否チェック
Map<String, SObjectField> fields = Account.getSObjectType().getDescribe().fields.getMap();
SObjectField targetField = fields.get('CustomField__c');
DescribeFieldResult dfr = targetField.getDescribe();

System.debug('Updateable: ' + dfr.isUpdateable());     // false = 書き込み不可
System.debug('Createable: ' + dfr.isCreateable());     // insert 時のみ可能か
System.debug('Is Formula: ' + dfr.isCalculated());     // 数式フィールドか
System.debug('Type: '       + dfr.getType());          // フィールド型
```

## 統合コードでの安全な書き込みパターン

```apex
// ❌ 書き込み可否を確認せず直接セット
record.CustomField__c = externalValue;
update record;

// ✅ isUpdateable() で確認してからセット
Map<String, SObjectField> fieldMap = targetObject.getSObjectType().getDescribe().fields.getMap();
Map<String, Object> fieldsToUpdate = new Map<String, Object>();

for (String fieldName : incomingPayload.keySet()) {
    SObjectField sField = fieldMap.get(fieldName.toLowerCase());
    if (sField != null && sField.getDescribe().isUpdateable()) {
        fieldsToUpdate.put(fieldName, incomingPayload.get(fieldName));
    } else {
        System.debug('Skipped non-writable field: ' + fieldName);
    }
}

for (String fieldName : fieldsToUpdate.keySet()) {
    record.put(fieldName, fieldsToUpdate.get(fieldName));
}
update record;
```

## sf CLI で事前確認する

```bash
# オブジェクトのフィールド一覧と書き込み可否を確認
sf sobject describe --sobject Account --target-org <alias> --json \
  | jq '.result.fields[] | {name: .name, updateable: .updateable, type: .type}' \
  | grep -A3 '"updateable": false'
```

## 書き込み不可フィールドの代表例

| Object | Field | 理由 |
|--------|-------|------|
| Any | `CreatedDate`, `LastModifiedDate` | システムフィールド |
| Any | Formula fields | 計算値 |
| Any | Roll-up summary fields | 集計値 |
| Quote | `OpportunityId` | 作成後ロック（org 設定による） |
| Task / Event | `WhatId` | 設定により読み取り専用 |
