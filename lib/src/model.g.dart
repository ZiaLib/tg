// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TelegramSessionSocks5Proxy _$TelegramSessionSocks5ProxyFromJson(
        Map<String, dynamic> json) =>
    TelegramSessionSocks5Proxy(
      host: json['host'] as String,
      port: (json['port'] as num).toInt(),
      username: json['username'] as String?,
      password: json['password'] as String?,
    );

Map<String, dynamic> _$TelegramSessionSocks5ProxyToJson(
        TelegramSessionSocks5Proxy instance) =>
    <String, dynamic>{
      'host': instance.host,
      'port': instance.port,
      'username': instance.username,
      'password': instance.password,
    };

ProxyConfig _$ProxyConfigFromJson(Map<String, dynamic> json) => ProxyConfig(
      type: $enumDecode(_$ProxyTypeEnumMap, json['type']),
    );

Map<String, dynamic> _$ProxyConfigToJson(ProxyConfig instance) =>
    <String, dynamic>{
      'type': _$ProxyTypeEnumMap[instance.type]!,
    };

const _$ProxyTypeEnumMap = {
  ProxyType.none: 'none',
  ProxyType.socks5: 'socks5',
};

Socks5ProxyConfig _$Socks5ProxyConfigFromJson(Map<String, dynamic> json) =>
    Socks5ProxyConfig(
      host: json['host'] as String,
      port: (json['port'] as num).toInt(),
      username: json['username'] as String?,
      password: json['password'] as String?,
    );

Map<String, dynamic> _$Socks5ProxyConfigToJson(Socks5ProxyConfig instance) =>
    <String, dynamic>{
      'host': instance.host,
      'port': instance.port,
      'username': instance.username,
      'password': instance.password,
    };

TelegramSessionDevice _$TelegramSessionDeviceFromJson(
        Map<String, dynamic> json) =>
    TelegramSessionDevice(
      deviceModel: json['deviceModel'] as String?,
      appVersion: json['appVersion'] as String?,
      systemVersion: json['systemVersion'] as String?,
      systemLangCode: json['systemLangCode'] as String?,
      langCode: json['langCode'] as String?,
    );

Map<String, dynamic> _$TelegramSessionDeviceToJson(
        TelegramSessionDevice instance) =>
    <String, dynamic>{
      'deviceModel': instance.deviceModel,
      'appVersion': instance.appVersion,
      'systemVersion': instance.systemVersion,
      'systemLangCode': instance.systemLangCode,
      'langCode': instance.langCode,
    };

TelegramSession _$TelegramSessionFromJson(Map<String, dynamic> json) =>
    TelegramSession(
      proxyConfig:
          ProxyConfig.fromJson(json['proxyConfig'] as Map<String, dynamic>),
      dcOption: const DcOptionConverter()
          .fromJson(json['dcOption'] as Map<String, dynamic>?),
      authorizationKey: json['authorizationKey'] == null
          ? null
          : AuthorizationKey.fromJson(
              json['authorizationKey'] as Map<String, dynamic>),
      device: json['device'] == null
          ? null
          : TelegramSessionDevice.fromJson(
              json['device'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$TelegramSessionToJson(TelegramSession instance) =>
    <String, dynamic>{
      'proxyConfig': instance.proxyConfig,
      'dcOption': const DcOptionConverter().toJson(instance.dcOption),
      'authorizationKey': instance.authorizationKey,
      'device': instance.device,
    };
