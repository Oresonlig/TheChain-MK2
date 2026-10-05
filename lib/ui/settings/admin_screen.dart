/// Settings → Admin: Niklas egen översikt (2026-10-05). Bara hans konto ser
/// raden, och servern (mk2_admin_stats, supabase/002) svarar ingen annan.
/// Svarar på "vem tränar, i appen eller på hemsidan — och när kan den stängas?".
library;

import 'package:flutter/material.dart';

import '../../app/app_controller.dart';
import '../../theme/chain_theme.dart';
import '../../theme/background_scope.dart';
import '../../theme/surfaces.dart';
import '../format.dart';
import '../nanosuit_scaffold.dart';
import '../units.dart';
import 'settings_screen.dart' show settingsSection;

const kAdminEmail = 'niklgron@gmail.com';

/// En användare som adminsidan ser den.
class AdminUser {
  AdminUser(Map<String, Object?> r)
      : email = r['email'] as String? ?? '—',
        name = r['display_name'] as String?,
        created = _iso(r['created_at']),
        lastSignIn = _iso(r['last_sign_in_at']),
        providers = r['providers'] as String? ?? '',
        webUpdated = _iso(r['web_updated_at']),
        seen = (r['web_client_seen'] as Map?)?.cast<String, Object?>() ?? const {},
        workouts = (r['mk2_workouts'] as num?)?.toInt() ?? 0,
        lastWorkout = _ms(r['mk2_last_workout']),
        mk2Activity = _ms(r['mk2_last_activity']),
        devices = (r['mk2_devices'] as num?)?.toInt() ?? 0,
        build = r['mk2_build'] as String?,
        movedAt = _iso(r['moved_at']);

  final String email;
  final String? name;
  final DateTime? created, lastSignIn, webUpdated, lastWorkout, mk2Activity, movedAt;
  final String providers;
  final Map<String, Object?> seen;
  final int workouts, devices;
  final String? build;

  DateTime? seenAs(String kind) => _ms(seen[kind]);

  /// Senast på hemsidan (mobil, dator eller MK1-appen), annars radens ändring.
  DateTime? get webActivity {
    final all = [seenAs('webMobile'), seenAs('webDesktop'), seenAs('app'), webUpdated].whereType<DateTime>().toList()..sort();
    return all.isEmpty ? null : all.last;
  }

  static DateTime? _iso(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;
  static DateTime? _ms(Object? v) => v is num && v > 0 ? DateTime.fromMillisecondsSinceEpoch(v.toInt()) : null;
}

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key, required this.app});
  final AppController app;

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  late Future<List<AdminUser>> _load = _fetch();

  Future<List<AdminUser>> _fetch() async => [for (final r in await widget.app.adminStats()) AdminUser(r)];

  @override
  Widget build(BuildContext context) {
    final c = context.chain;
    final text = Theme.of(context).textTheme;
    return ChainScaffold(
      ambient: widget.app.repo?.settings().ambientEffects ?? true,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
          child: Row(children: [
            IconButton(tooltip: 'Back', onPressed: () => Navigator.pop(context), icon: Icon(Icons.arrow_back, color: c.textMuted)),
            Expanded(child: Text('ADMIN', style: text.titleLarge!.copyWith(letterSpacing: 3))),
            IconButton(
              tooltip: 'Refresh',
              onPressed: () => setState(() => _load = _fetch()),
              icon: Icon(Icons.refresh, color: c.textMuted),
            ),
          ]),
        ),
        Expanded(
          child: FutureBuilder<List<AdminUser>>(
            future: _load,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
              if (snap.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Could not load: ${snap.error}', style: text.bodySmall!.copyWith(color: c.fail)),
                );
              }
              return _list(context, snap.data!);
            },
          ),
        ),
      ]),
    );
  }

  Widget _list(BuildContext context, List<AdminUser> users) {
    final c = context.chain;
    final text = Theme.of(context).textTheme;
    final now = DateTime.now();
    bool within(DateTime? d, int days) => d != null && now.difference(d).inDays < days;
    int count(bool Function(AdminUser u) f) => users.where(f).length;
    Widget stat(String label, String v) => Expanded(
          child: Column(children: [
            Text(v, style: text.titleLarge!.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
            Text(label, style: text.labelSmall, textAlign: TextAlign.center),
          ]),
        );
    String ago(DateTime? d) => d == null ? '—' : daysAgo(d, now);

    return ListView(
      addRepaintBoundaries: glassListRepaintBoundaries,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        settingsSection(context, 'ACTIVE · LAST 7 DAYS', [
          Row(children: [
            stat('APP', '${count((u) => within(u.mk2Activity, 7))}'),
            stat('WEBSITE', '${count((u) => within(u.webActivity, 7))}'),
            stat('ACCOUNTS', '${users.length}'),
          ]),
        ]),
        settingsSection(context, 'ACTIVE · LAST 30 DAYS', [
          Row(children: [
            stat('APP', '${count((u) => within(u.mk2Activity, 30))}'),
            stat('WEBSITE', '${count((u) => within(u.webActivity, 30))}'),
            stat('MOVED', '${count((u) => u.movedAt != null)}'),
          ]),
        ]),
        for (final u in users)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Glass(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(u.name ?? u.email, style: text.titleMedium, overflow: TextOverflow.ellipsis)),
                  if (u.movedAt != null) Text('MOVED TO APP', style: text.labelSmall!.copyWith(color: c.success)),
                ]),
                if (u.name != null) Text(u.email, style: text.bodySmall),
                const SizedBox(height: 6),
                Text(
                  u.mk2Activity == null
                      ? 'App: not used yet'
                      : 'App: ${u.workouts} sessions · last ${ago(u.lastWorkout)}'
                          '${u.build == null ? '' : ' · ${u.build}'}'
                          '${u.devices > 1 ? ' · ${u.devices} devices' : ''}',
                  style: text.bodySmall!.copyWith(color: u.mk2Activity == null ? c.textFaint : c.textBody),
                ),
                Text(
                  'Website: ${ago(u.webActivity)}'
                  '${[
                    if (u.seenAs('webMobile') != null) 'mobile',
                    if (u.seenAs('webDesktop') != null) 'desktop',
                    if (u.seenAs('app') != null) 'MK1 app',
                  ].map((k) => ' · $k').join()}',
                  style: text.bodySmall!.copyWith(color: u.webActivity == null ? c.textFaint : c.textBody),
                ),
                Text(
                  // last_sign_in_at = senaste RIKTIGA inloggningen; man förblir
                  // inloggad mellan besöken — aktiviteten står på raderna ovan.
                  'Last login ${ago(u.lastSignIn)}${u.providers.isEmpty ? '' : ' · ${u.providers}'}'
                  '${u.created == null ? '' : ' · joined ${fmtDate(u.created!)}'}',
                  style: text.labelSmall,
                ),
              ]),
            ),
          ),
      ],
    );
  }
}
