import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neutrawise/domain/models/user_profile.dart';

final userRepositoryProvider = Provider((ref) => UserRepository(Supabase.instance.client));

class UserRepository {
  final SupabaseClient _client;

  UserRepository(this._client);

  Future<UserProfile?> getUserProfile(String userId) async {
    try {
      final response = await _client.from('users').select().eq('id', userId).single();
      return UserProfile.fromJson(response);
    } catch (e) {
      return null; 
    }
  }

  Future<void> saveUserProfile(UserProfile profile) async {
    await _client.from('users').upsert(profile.toJson());
  }
}
