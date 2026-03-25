import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  SupabaseClient get _supabase => Supabase.instance.client;

  Future<AuthResponse> signUp(String email, String password) async {
    print("AuthService: Attempting Sign-up for $email");
    try {
      final res = await _supabase.auth.signUp(email: email, password: password);
      print("AuthService: Sign-up success for ${res.user?.id}");
      return res;
    } catch (e) {
      print("AuthService: Sign-up error: $e");
      rethrow;
    }
  }

  Future<AuthResponse> login(String email, String password) async {
    print("AuthService: Attempting Login for $email");
    try {
      final res = await _supabase.auth.signInWithPassword(email: email, password: password);
      print("AuthService: Login success for ${res.user?.id}");
      return res;
    } catch (e) {
      print("AuthService: Login error: $e");
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  Session? get currentSession => _supabase.auth.currentSession;
  User? get currentUser => _supabase.auth.currentUser;
  
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;
}
