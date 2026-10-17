// Licensed under the MIT License.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

import 'otel_fullstory_suppression.dart';

const _loggerName = 'package.fullstory';

/// Bridges FullStory client SDK calls (event, identify, setUserVars,
/// getCurrentSessionURL) into OpenTelemetry log records. The session
/// URL is high-value context for cross-correlating crash traces with
/// session replays — emit it on identify so all subsequent traces
/// inherit it via baggage if your code propagates it.
class OTelFullstory {
  OTelFullstory({
    APILoggerProvider? loggerProvider,
    this.forwardEvent,
    this.forwardIdentify,
  }) : _loggerProvider = loggerProvider;

  final APILoggerProvider? _loggerProvider;
  final void Function(String name, Map<String, Object?>? properties)?
      forwardEvent;
  final void Function(String uid, Map<String, Object?>? userVars)?
      forwardIdentify;

  APILogger _logger() =>
      (_loggerProvider ?? OTelAPI.loggerProvider()).getLogger(_loggerName);

  void event(String name, {Map<String, Object?>? properties}) {
    forwardEvent?.call(name, properties);
    if (fullstoryInstrumentationSuppressed()) return;
    _emit(
      body: 'fullstory.event $name',
      eventType: 'event',
      attrs: [OTelAPI.attributeString('fullstory.event.name', name)],
      flatPrefix: 'fullstory.property.',
      payload: properties,
    );
  }

  void identify(String uid,
      {Map<String, Object?>? userVars, String? sessionUrl}) {
    forwardIdentify?.call(uid, userVars);
    if (fullstoryInstrumentationSuppressed()) return;
    final extras = <Attribute<Object>>[
      OTelAPI.attributeString('fullstory.uid', uid),
      OTelAPI.attributeString(User.userId.key, uid),
      if (sessionUrl != null)
        OTelAPI.attributeString('fullstory.session.url', sessionUrl),
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
      OTelAPI.attributeString('fullstory.event.type', eventType),
      ...attrs,
    ];
    if (payload != null && flatPrefix != null) {
      payload.forEach((k, v) {
        if (v == null) return;
        final key = '$flatPrefix$k';
        if (v is String) {
          all.add(OTelAPI.attributeString(key, v));
        } else if (v is int) {
          all.add(OTelAPI.attributeInt(key, v));
        } else if (v is double) {
          all.add(OTelAPI.attributeDouble(key, v));
        } else if (v is bool) {
          all.add(OTelAPI.attributeBool(key, v));
        } else {
          all.add(OTelAPI.attributeString(key, v.toString()));
        }
      });
    }
    _logger().emit(
      severityNumber: Severity.INFO,
      severityText: 'info',
      body: body,
      attributes: OTelAPI.attributes(all),
    );
  }
}
