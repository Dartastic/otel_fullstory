// Licensed under the Dartastic Pro Software License Agreement.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_fullstory/otel_fullstory.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemoryLogExporter logs;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_fullstory-test',
    );
    logs = harness.logs;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(LogRecord r) {
    final list = r.attributes?.toList() ?? <Attribute<Object>>[];
    return {for (final a in list) a.key: a.value};
  }

  test('event records log record', () async {
    OTelFullstory().event('Checkout', properties: {'value': 99});
    await harness.flushLogs();
    final r =
        logs.records.firstWhere((r) => r.body == 'fullstory.event Checkout');
    final a = attrsOf(r);
    expect(a['fullstory.event.name'], 'Checkout');
    expect(a['fullstory.property.value'], 99);
  });

  test('identify records session.url', () async {
    OTelFullstory().identify(
      'u-1',
      userVars: {'plan': 'pro'},
      sessionUrl: 'https://app.fullstory.com/ui/abc/session/123',
    );
    await harness.flushLogs();
    final r =
        logs.records.firstWhere((r) => r.body == 'fullstory.identify u-1');
    final a = attrsOf(r);
    expect(a['fullstory.uid'], 'u-1');
    expect(a['user.id'], 'u-1');
    expect(a['fullstory.user.plan'], 'pro');
    expect(a['fullstory.session.url'],
        'https://app.fullstory.com/ui/abc/session/123');
  });

  test('suppression skips emit but forwards', () async {
    var forwarded = 0;
    await runWithoutFullstoryInstrumentationAsync(() async {
      OTelFullstory(forwardEvent: (_, __) => forwarded++).event('x');
    });
    await harness.flushLogs();
    expect(forwarded, 1);
    expect(logs.records.where((r) => r.body == 'fullstory.event x'), isEmpty);
  });
}
