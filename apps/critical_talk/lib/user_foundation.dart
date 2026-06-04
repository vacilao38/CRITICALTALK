import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

typedef AppSupportDirectoryProvider = Future<Directory> Function();

abstract class UserAuthService {
  const UserAuthService();

  Future<AuthSession> loadSession();

  Future<UserRegistrationResult> register({
    required String userName,
    required String password,
    required List<int> organicEntropy,
  });

  Future<CriticalUser> login({
    required String userName,
    required String password,
  });

  Future<void> logout();

  Future<CriticalUser> updateProfile({
    required String userId,
    required String userName,
    UserMedia? avatar,
    UserMedia? banner,
    required double bannerAlignmentY,
  });
}

class FileUserAuthService extends UserAuthService {
  FileUserAuthService({
    this.directoryProvider = getApplicationSupportDirectory,
    UserSecurityPolicy? securityPolicy,
  }) : securityPolicy = securityPolicy ?? const UserSecurityPolicy();

  final AppSupportDirectoryProvider directoryProvider;
  final UserSecurityPolicy securityPolicy;

  static const _storeFileName = 'critical_talk_users.secure.json';
  static const _keyFileName = 'critical_talk_device.key';
  static const _cipherVersion = 1;
  static const _associatedData = <int>[
    99,
    114,
    105,
    116,
    105,
    99,
    97,
    108,
    95,
    116,
    97,
    108,
    107,
    95,
    117,
    115,
    101,
    114,
    115,
    95,
    118,
    49,
  ];

  final _cipher = AesGcm.with256bits();
  final _hashAlgorithm = Sha256();

  @override
  Future<AuthSession> loadSession() async {
    final store = await _readStore();
    final activeId = store.activeUserId;
    final activeUser = activeId == null
        ? null
        : store.users
              .cast<_StoredUser>()
              .where((user) => user.userId == activeId)
              .map((user) => user.toDomain())
              .firstOrNull;

    return AuthSession(currentUser: activeUser);
  }

  @override
  Future<UserRegistrationResult> register({
    required String userName,
    required String password,
    required List<int> organicEntropy,
  }) async {
    final trimmedUserName = userName.trim();
    final userNameErrors = validateUserName(trimmedUserName);
    final passwordErrors = validatePassword(password);

    if (userNameErrors.isNotEmpty || passwordErrors.isNotEmpty) {
      throw UserAuthException(
        [...userNameErrors, ...passwordErrors].join('\n'),
      );
    }

    final store = await _readStore();
    final normalizedName = normalizeUserName(trimmedUserName);

    if (store.users.any((user) => user.normalizedUserName == normalizedName)) {
      throw const UserAuthException('Esse nome de usuario ja esta em uso.');
    }

    final createdAt = DateTime.now().toUtc();
    final passwordSalt = _randomBytes(16);
    final passwordHash = await _hashPassword(
      password: password,
      salt: passwordSalt,
    );
    final userId = await _generateUserId(
      userName: trimmedUserName,
      createdAt: createdAt,
      organicEntropy: organicEntropy,
    );

    final user = _StoredUser(
      userId: userId,
      userName: trimmedUserName,
      normalizedUserName: normalizedName,
      createdAtIso: createdAt.toIso8601String(),
      passwordSaltBase64: base64Encode(passwordSalt),
      passwordHashBase64: base64Encode(passwordHash),
      profile: const UserProfile(profileIds: [], bannerAlignmentY: 0),
    );

    final nextStore = store.copyWith(
      activeUserId: userId,
      users: [...store.users, user],
    );

    await _writeStore(nextStore);

    return UserRegistrationResult(user: user.toDomain(), firstTimeKey: userId);
  }

  @override
  Future<CriticalUser> login({
    required String userName,
    required String password,
  }) async {
    final store = await _readStore();
    final normalizedName = normalizeUserName(userName);
    final storedUser = store.users
        .cast<_StoredUser>()
        .where((user) => user.normalizedUserName == normalizedName)
        .firstOrNull;

    if (storedUser == null) {
      throw const UserAuthException('Usuario ou senha invalidos.');
    }

    final salt = base64Decode(storedUser.passwordSaltBase64);
    final candidateHash = await _hashPassword(password: password, salt: salt);
    final expectedHash = base64Decode(storedUser.passwordHashBase64);

    if (!_constantTimeEquals(candidateHash, expectedHash)) {
      throw const UserAuthException('Usuario ou senha invalidos.');
    }

    await _writeStore(store.copyWith(activeUserId: storedUser.userId));
    return storedUser.toDomain();
  }

  @override
  Future<void> logout() async {
    final store = await _readStore();
    await _writeStore(store.copyWith(activeUserId: null));
  }

  @override
  Future<CriticalUser> updateProfile({
    required String userId,
    required String userName,
    UserMedia? avatar,
    UserMedia? banner,
    required double bannerAlignmentY,
  }) async {
    final trimmedUserName = userName.trim();
    final userNameErrors = validateUserName(trimmedUserName);

    if (userNameErrors.isNotEmpty) {
      throw UserAuthException(userNameErrors.join('\n'));
    }

    final normalizedName = normalizeUserName(trimmedUserName);
    final store = await _readStore();
    final duplicate = store.users.any(
      (user) =>
          user.userId != userId && user.normalizedUserName == normalizedName,
    );

    if (duplicate) {
      throw const UserAuthException('Esse nome de usuario ja esta em uso.');
    }

    final index = store.users.indexWhere((user) => user.userId == userId);

    if (index == -1) {
      throw const UserAuthException('Usuario nao encontrado.');
    }

    final updatedUser = store.users[index].copyWith(
      userName: trimmedUserName,
      normalizedUserName: normalizedName,
      profile: store.users[index].profile.copyWith(
        avatar: avatar,
        banner: banner,
        bannerAlignmentY: bannerAlignmentY.clamp(-1.0, 1.0),
      ),
    );

    final nextUsers = [...store.users]..[index] = updatedUser;
    await _writeStore(store.copyWith(users: nextUsers));
    return updatedUser.toDomain();
  }

  Future<List<int>> _hashPassword({
    required String password,
    required List<int> salt,
  }) async {
    final algorithm = Argon2id(
      memory: securityPolicy.argonMemoryKiB,
      iterations: securityPolicy.argonIterations,
      parallelism: securityPolicy.argonParallelism,
      hashLength: securityPolicy.passwordHashLength,
    );
    final secretKey = await algorithm.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );
    return secretKey.extractBytes();
  }

  Future<String> _generateUserId({
    required String userName,
    required DateTime createdAt,
    required List<int> organicEntropy,
  }) async {
    final randomSeed = _randomBytes(32);
    final organicSeed = organicEntropy.isEmpty
        ? _randomBytes(16)
        : List<int>.from(organicEntropy.map((value) => value & 0xFF));
    final digest = await _hashAlgorithm.hash([
      ...randomSeed,
      ...utf8.encode(normalizeUserName(userName)),
      ...utf8.encode(createdAt.microsecondsSinceEpoch.toString()),
      ...organicSeed,
    ]);
    final hex = _hexEncode(digest.bytes);

    return [
      'ctu',
      hex.substring(0, 8),
      hex.substring(8, 12),
      hex.substring(12, 16),
      hex.substring(16, 24),
    ].join('-');
  }

  Future<_EncryptedStore> _readStore() async {
    final directory = await _ensureDirectory();
    final storeFile = File(p.join(directory.path, _storeFileName));

    if (!await storeFile.exists()) {
      return const _EncryptedStore(activeUserId: null, users: []);
    }

    final payload =
        jsonDecode(await storeFile.readAsString()) as Map<String, dynamic>;
    final version = payload['version'];

    if (version != _cipherVersion) {
      throw const UserAuthException(
        'Versao de armazenamento local nao suportada.',
      );
    }

    final key = await _readOrCreateDeviceKey(directory);
    final secretBox = SecretBox(
      base64Decode(payload['cipherText'] as String),
      nonce: base64Decode(payload['nonce'] as String),
      mac: Mac(base64Decode(payload['mac'] as String)),
    );
    final clearBytes = await _cipher.decrypt(
      secretBox,
      secretKey: SecretKey(key),
      aad: _associatedData,
    );
    final decoded = jsonDecode(utf8.decode(clearBytes)) as Map<String, dynamic>;

    return _EncryptedStore.fromJson(decoded);
  }

  Future<void> _writeStore(_EncryptedStore store) async {
    final directory = await _ensureDirectory();
    final storeFile = File(p.join(directory.path, _storeFileName));
    final key = await _readOrCreateDeviceKey(directory);
    final clearBytes = utf8.encode(jsonEncode(store.toJson()));
    final secretBox = await _cipher.encrypt(
      clearBytes,
      secretKey: SecretKey(key),
      aad: _associatedData,
    );

    final payload = {
      'version': _cipherVersion,
      'cipherText': base64Encode(secretBox.cipherText),
      'nonce': base64Encode(secretBox.nonce),
      'mac': base64Encode(secretBox.mac.bytes),
    };

    await storeFile.writeAsString(jsonEncode(payload), flush: true);
  }

  Future<Directory> _ensureDirectory() async {
    final directory = await directoryProvider();
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<List<int>> _readOrCreateDeviceKey(Directory directory) async {
    final keyFile = File(p.join(directory.path, _keyFileName));

    if (await keyFile.exists()) {
      final encoded =
          jsonDecode(await keyFile.readAsString()) as Map<String, dynamic>;
      return base64Decode(encoded['key'] as String);
    }

    final keyBytes = _randomBytes(32);
    await keyFile.writeAsString(
      jsonEncode({'key': base64Encode(keyBytes)}),
      flush: true,
    );
    return keyBytes;
  }

  List<int> _randomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }

  bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) {
      return false;
    }

    var result = 0;
    for (var index = 0; index < a.length; index++) {
      result |= a[index] ^ b[index];
    }
    return result == 0;
  }

  String _hexEncode(List<int> bytes) {
    final buffer = StringBuffer();
    for (final byte in bytes) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }
}

class UserSecurityPolicy {
  const UserSecurityPolicy({
    this.argonMemoryKiB = 19456,
    this.argonIterations = 2,
    this.argonParallelism = 1,
    this.passwordHashLength = 32,
  });

  final int argonMemoryKiB;
  final int argonIterations;
  final int argonParallelism;
  final int passwordHashLength;
}

class AuthSession {
  const AuthSession({required this.currentUser});

  final CriticalUser? currentUser;

  bool get isAuthenticated => currentUser != null;
}

class UserRegistrationResult {
  const UserRegistrationResult({
    required this.user,
    required this.firstTimeKey,
  });

  final CriticalUser user;
  final String firstTimeKey;
}

class CriticalUser {
  const CriticalUser({
    required this.userId,
    required this.userName,
    required this.createdAt,
    required this.profile,
  });

  final String userId;
  final String userName;
  final DateTime createdAt;
  final UserProfile profile;

  String get initials {
    final trimmed = userName.trim();
    if (trimmed.isEmpty) {
      return '??';
    }

    final length = trimmed.length >= 2 ? 2 : 1;
    return trimmed.substring(0, length).toUpperCase().padRight(2, ' ');
  }

  String get maskedId {
    if (userId.length <= 10) {
      return userId;
    }

    return '${userId.substring(0, 8)}...${userId.substring(userId.length - 6)}';
  }

  CriticalUser copyWith({
    String? userId,
    String? userName,
    DateTime? createdAt,
    UserProfile? profile,
  }) {
    return CriticalUser(
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      createdAt: createdAt ?? this.createdAt,
      profile: profile ?? this.profile,
    );
  }
}

class UserProfile {
  const UserProfile({
    this.avatar,
    this.banner,
    required this.profileIds,
    required this.bannerAlignmentY,
  });

  final UserMedia? avatar;
  final UserMedia? banner;
  final List<String> profileIds;
  final double bannerAlignmentY;

  UserProfile copyWith({
    UserMedia? avatar,
    bool clearAvatar = false,
    UserMedia? banner,
    bool clearBanner = false,
    List<String>? profileIds,
    double? bannerAlignmentY,
  }) {
    return UserProfile(
      avatar: clearAvatar ? null : avatar ?? this.avatar,
      banner: clearBanner ? null : banner ?? this.banner,
      profileIds: profileIds ?? this.profileIds,
      bannerAlignmentY: bannerAlignmentY ?? this.bannerAlignmentY,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'avatar': avatar?.toJson(),
      'banner': banner?.toJson(),
      'profileIds': profileIds,
      'bannerAlignmentY': bannerAlignmentY,
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      avatar: json['avatar'] == null
          ? null
          : UserMedia.fromJson(json['avatar'] as Map<String, dynamic>),
      banner: json['banner'] == null
          ? null
          : UserMedia.fromJson(json['banner'] as Map<String, dynamic>),
      profileIds: (json['profileIds'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(),
      bannerAlignmentY: (json['bannerAlignmentY'] as num?)?.toDouble() ?? 0,
    );
  }
}

class UserMedia {
  const UserMedia({required this.fileName, required this.bytes});

  final String fileName;
  final Uint8List bytes;

  Map<String, dynamic> toJson() {
    return {'fileName': fileName, 'bytesBase64': base64Encode(bytes)};
  }

  factory UserMedia.fromJson(Map<String, dynamic> json) {
    return UserMedia(
      fileName: json['fileName'] as String? ?? 'arquivo',
      bytes: base64Decode(json['bytesBase64'] as String? ?? ''),
    );
  }
}

class UserAuthException implements Exception {
  const UserAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

List<String> validateUserName(String value) {
  final trimmed = value.trim();
  final errors = <String>[];

  if (trimmed.length < 3) {
    errors.add('O nome de usuario precisa ter pelo menos 3 caracteres.');
  }
  if (trimmed.length > 24) {
    errors.add('O nome de usuario pode ter no maximo 24 caracteres.');
  }
  if (!RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(trimmed)) {
    errors.add('Use apenas letras, numeros, ponto, traco ou sublinhado.');
  }

  return errors;
}

List<String> validatePassword(String value) {
  final errors = <String>[];

  if (value.length < 8) {
    errors.add('A senha precisa ter pelo menos 8 caracteres.');
  }
  if (!RegExp(r'[A-Z]').hasMatch(value)) {
    errors.add('Inclua pelo menos uma letra maiuscula.');
  }
  if (!RegExp(r'[a-z]').hasMatch(value)) {
    errors.add('Inclua pelo menos uma letra minuscula.');
  }
  if (!RegExp(r'[0-9]').hasMatch(value)) {
    errors.add('Inclua pelo menos um numero.');
  }
  if (!RegExp(r'[^A-Za-z0-9]').hasMatch(value)) {
    errors.add('Inclua pelo menos um caractere especial.');
  }

  return errors;
}

String normalizeUserName(String value) {
  return value.trim().toLowerCase();
}

class _EncryptedStore {
  const _EncryptedStore({required this.activeUserId, required this.users});

  final String? activeUserId;
  final List<_StoredUser> users;

  _EncryptedStore copyWith({
    Object? activeUserId = _sentinel,
    List<_StoredUser>? users,
  }) {
    return _EncryptedStore(
      activeUserId: activeUserId == _sentinel
          ? this.activeUserId
          : activeUserId as String?,
      users: users ?? this.users,
    );
  }

  factory _EncryptedStore.fromJson(Map<String, dynamic> json) {
    return _EncryptedStore(
      activeUserId: json['activeUserId'] as String?,
      users: (json['users'] as List<dynamic>? ?? const [])
          .map((item) => _StoredUser.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'activeUserId': activeUserId,
      'users': users.map((user) => user.toJson()).toList(),
    };
  }
}

class _StoredUser {
  const _StoredUser({
    required this.userId,
    required this.userName,
    required this.normalizedUserName,
    required this.createdAtIso,
    required this.passwordSaltBase64,
    required this.passwordHashBase64,
    required this.profile,
  });

  final String userId;
  final String userName;
  final String normalizedUserName;
  final String createdAtIso;
  final String passwordSaltBase64;
  final String passwordHashBase64;
  final UserProfile profile;

  _StoredUser copyWith({
    String? userName,
    String? normalizedUserName,
    UserProfile? profile,
  }) {
    return _StoredUser(
      userId: userId,
      userName: userName ?? this.userName,
      normalizedUserName: normalizedUserName ?? this.normalizedUserName,
      createdAtIso: createdAtIso,
      passwordSaltBase64: passwordSaltBase64,
      passwordHashBase64: passwordHashBase64,
      profile: profile ?? this.profile,
    );
  }

  CriticalUser toDomain() {
    return CriticalUser(
      userId: userId,
      userName: userName,
      createdAt: DateTime.parse(createdAtIso).toLocal(),
      profile: profile,
    );
  }

  factory _StoredUser.fromJson(Map<String, dynamic> json) {
    return _StoredUser(
      userId: json['userId'] as String,
      userName: json['userName'] as String,
      normalizedUserName: json['normalizedUserName'] as String,
      createdAtIso: json['createdAtIso'] as String,
      passwordSaltBase64: json['passwordSaltBase64'] as String,
      passwordHashBase64: json['passwordHashBase64'] as String,
      profile: UserProfile.fromJson(json['profile'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'userName': userName,
      'normalizedUserName': normalizedUserName,
      'createdAtIso': createdAtIso,
      'passwordSaltBase64': passwordSaltBase64,
      'passwordHashBase64': passwordHashBase64,
      'profile': profile.toJson(),
    };
  }
}

const _sentinel = Object();

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
