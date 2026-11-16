import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/review_catalog_repository.dart';

class SupabaseReviewCatalogRepository implements ReviewCatalogRepository {
  SupabaseReviewCatalogRepository(this.client);

  final SupabaseClient client;

  @override
  Future<List<ReviewCatalogItem>> list(
    String clinic,
    String search,
    int offset, {
    String source = 'inventario_comercial',
  }) async {
    final rows = source == 'grok_pautas'
        ? await client.rpc(
            'review_pauta_list',
            params: {
              'p_clinic': clinic,
              'p_search': search,
              'p_limit': 50,
              'p_offset': offset,
            },
          ) as List
        : await client.rpc(
            'review_catalog_list',
            params: {
              'p_clinic': clinic,
              'p_status': null,
              'p_search': search,
              'p_limit': 50,
              'p_offset': offset,
            },
          ) as List;
    return rows
        .map((row) => ReviewCatalogItem.read(
              Map<String, dynamic>.from(row as Map),
            ))
        .toList();
  }

  @override
  Future<Map<String, dynamic>> progress(
    String clinic, {
    String source = 'inventario_comercial',
  }) async {
    final result = await client.rpc(
      'review_catalog_progress',
      params: {'p_clinic': clinic, 'p_source': source},
    );
    return Map<String, dynamic>.from(result as Map);
  }

  @override
  Future<bool> isPlatformOwner() async {
    final result = await client.rpc('review_catalog_is_platform_owner');
    return result == true;
  }

  @override
  Future<void> setGlobalStatus(String sourceKey, String status) async {
    await client.rpc(
      'review_catalog_set_global_status',
      params: {
        'p_source_key': sourceKey,
        'p_new_status': status,
      },
    );
  }

  @override
  Future<void> setClinicStatus(
    String clinic,
    String sourceKey,
    String status,
  ) async {
    await client.rpc(
      'review_catalog_set_status',
      params: {
        'p_clinic': clinic,
        'p_source_key': sourceKey,
        'p_new_status': status,
      },
    );
  }

  @override
  Future<void> setPersonalStatus(String sourceKey, String status) async {
    await client.rpc(
      'review_catalog_set_personal_status',
      params: {
        'p_source_key': sourceKey,
        'p_new_status': status,
      },
    );
  }

  @override
  Future<void> report({
    required String clinic,
    required String reviewer,
    required ReviewCatalogItem item,
    required String comment,
    String? expected,
    String? source,
  }) async {
    if (client.auth.currentUser?.id != reviewer) {
      throw StateError('review_session_changed');
    }
    await client.from('catalog_review_reports').insert({
      'clinic_id': clinic,
      'source_catalog': item.key.startsWith('grok_pautas:')
          ? 'grok_pautas'
          : 'inventario_comercial',
      'source_key': item.key,
      'module': 'vademecum',
      'reviewer_id': reviewer,
      'catalog_version': item.version,
      'observed_snapshot': item.snapshot,
      'expected_value': expected?.trim().isEmpty == true
          ? null
          : expected?.trim(),
      'source_reference': source?.trim().isEmpty == true
          ? null
          : source?.trim(),
      'comment': comment.trim(),
    });
  }
}
