// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

import 'otel_fullstory_suppression.dart';

const _loggerName = 'package.fullstory';

/// Bridges FullStory client SDK calls (event, identify, setUserVars,
/// getCurrentSessionURL) into OpenTelemetry log records. The session
/// URL is high-value context for cross-correlating crash traces with
/// session replays — emit it on identify so all subsequent traces
/// inherit it via baggage if your code propagates it.
class OTelFullstory {
  OTelFullstory({
    LoggerProvider? loggerProvider,
    this.forwardEvent,
    this.forwardIdentify,
  }) : _loggerProvider = loggerProvider;

  final LoggerProvider? _loggerProvider;
  final void Function(String name, Map<String, Object?>? properties)?
      forwardEvent;
  final void Function(String uid, Map<String, Object?>? userVars)?
      forwardIdentify;

  OTelLogger _logger() =>
      (_loggerProvider ?? OTel.loggerProvider()).getLogger(_loggerName);

  void event(String name, {Map<String, Object?>? properties}) {
    forwardEvent?.call(name, properties);
    if (fullstoryInstrumentationSuppressed()) return;
    _emit(
      body: 'fullstory.event $name',
      eventType: 'event',
      attrs: [OTel.attributeString('fullstory.event.name', name)],
      flatPrefix: 'fullstory.property.',
      payload: properties,
    );
  }

  void identify(String uid,
      {Map<String, Object?>? userVars, String? sessionUrl}) {
    forwardIdentify?.call(uid, userVars);
    if (fullstoryInstrumentationSuppressed()) return;
    final extras = <Attribute<Object>>[
      OTel.attributeString('fullstory.uid', uid),
      OTel.attributeString(User.userId.key, uid),
      if (sessionUrl != null)
        OTel.attributeString('fullstory.session.url', sessionUrl),
    ];
    _emit(
      body: 'fullstory.identify $uid',
      eventType: 'identify',
      attrs: extras,
      flatPrefix: 'fullstory.user.',
      payload: userVars,
    );
  }

  void _emit({
    required String body,
    required String eventType,
    required List<Attribute<Object>> attrs,
    String? flatPrefix,
    Map<String, Object?>? payload,
  }) {
    final all = <Attribute<Object>>[
      OTel.attributeString('fullstory.event.type', eventType),
      ...attrs,
    ];
    if (payload != null && flatPrefix != null) {
      payload.forEach((k, v) {
        if (v == null) return;
        final key = '$flatPrefix$k';
        if (v is String) {
          all.add(OTel.attributeString(key, v));
        } else if (v is int) {
          all.add(OTel.attributeInt(key, v));
        } else if (v is double) {
          all.add(OTel.attributeDouble(key, v));
        } else if (v is bool) {
          all.add(OTel.attributeBool(key, v));
        } else {
          all.add(OTel.attributeString(key, v.toString()));
        }
      });
    }
    _logger().emit(
      severityNumber: Severity.INFO,
      severityText: 'info',
      body: body,
      attributes: OTel.attributes(all),
    );
  }
}
