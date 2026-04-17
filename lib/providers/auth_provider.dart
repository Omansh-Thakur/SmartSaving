import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import '../models/user.dart';

final authServiceProvider = Provider((ref) => authService);

final authInitializeProvider = FutureProvider((ref) async {
  await authService.initialize();
  return authService.isAuthenticated;
});

final currentUserProvider =
    NotifierProvider<CurrentUserNotifier, AsyncValue<User?>>(() {
      return CurrentUserNotifier();
    });

class CurrentUserNotifier extends Notifier<AsyncValue<User?>> {
  @override
  AsyncValue<User?> build() => const AsyncValue.loading();

  Future<void> initialize() async {
    try {
      try {
        await authService.initialize();
        state = AsyncValue.data(authService.currentUser);
      } catch (e) {
        state = AsyncValue.error(e, StackTrace.current);
      }
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<bool> login(String email, String password) async {
    try {
      state = const AsyncValue.loading();
      final result = await authService.login(email, password);

      if (result['success'] as bool) {
        state = AsyncValue.data(result['user'] as User?);
        return true;
      } else {
        state = AsyncValue.error(
          Exception(result['message'] as String?),
          StackTrace.current,
        );
        return false;
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> register(String email, String password, String name) async {
    try {
      state = const AsyncValue.loading();
      final result = await authService.register(email, password, name);

      if (result['success'] as bool) {
        state = AsyncValue.data(result['user'] as User?);
        return true;
      } else {
        state = AsyncValue.error(
          Exception(result['message'] as String?),
          StackTrace.current,
        );
        return false;
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> updateProfile(String name, String? password) async {
    try {
      final result = await authService.updateProfile(name, password);
      
      if (result['success'] as bool) {
        state = AsyncValue.data(authService.currentUser);
        return true;
      } else {
        // Just throw back error message string so UI can catch it
        throw Exception(result['message'] as String? ?? 'Failed to update');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      await authService.logout();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  String? getErrorMessage() {
    return state
        .whenData((_) => null)
        .maybeWhen(
          error: (error, stackTrace) => error.toString(),
          orElse: () => null,
        );
  }
}
