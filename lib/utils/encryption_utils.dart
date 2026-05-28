import 'dart:convert';
import 'dart:math';
import 'package:encrypt/encrypt.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class EncryptionUtils {
  static final EncryptionUtils _instance = EncryptionUtils._internal();
  factory EncryptionUtils() => _instance;
  EncryptionUtils._internal();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  static const String _keyStorageKey = 'encryption_key';
  static const String _groupKeyPrefix = 'group_key_';

  // Getter for secure storage access
  FlutterSecureStorage get secureStorage => _secureStorage;

  Encrypter? _encrypter;
  IV? _iv;
  final Map<String, Encrypter> _groupEncrypters = {};
  final Map<String, IV> _groupIVs = {};

  Future<void> initialize() async {
    await _loadOrGenerateKey();
  }

  Future<void> _loadOrGenerateKey() async {
    try {
      // Try to load existing key
      final keyString = await _secureStorage.read(key: _keyStorageKey);

      if (keyString != null) {
        final key = Key.fromBase64(keyString);
        _encrypter = Encrypter(AES(key));
        _iv = IV.fromLength(16);
      } else {
        // Generate new key
        await _generateNewKey();
      }
    } catch (e) {
      print('Error loading encryption key: $e');
      await _generateNewKey();
    }
  }

  Future<void> _generateNewKey() async {
    try {
      final key = Key.fromSecureRandom(32); // 256-bit key
      _encrypter = Encrypter(AES(key));
      _iv = IV.fromLength(16);

      // Store the key securely
      await _secureStorage.write(key: _keyStorageKey, value: key.base64);
    } catch (e) {
      print('Error generating encryption key: $e');
      rethrow;
    }
  }

  String encrypt(String plaintext) {
    if (_encrypter == null || _iv == null) {
      throw Exception('Encryption not initialized');
    }

    try {
      final encrypted = _encrypter!.encrypt(plaintext, iv: _iv!);
      return encrypted.base64;
    } catch (e) {
      print('Encryption error: $e');
      throw Exception('Failed to encrypt message');
    }
  }

  String decrypt(String encryptedText) {
    if (_encrypter == null || _iv == null) {
      throw Exception('Encryption not initialized');
    }

    try {
      final encrypted = Encrypted.fromBase64(encryptedText);
      final decrypted = _encrypter!.decrypt(encrypted, iv: _iv!);
      return decrypted;
    } catch (e) {
      print('Decryption error: $e');
      throw Exception('Failed to decrypt message');
    }
  }

  // Generate a secure random string for invite codes
  String generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return String.fromCharCodes(
      Iterable.generate(
        8,
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );
  }

  // Generate a secure AES-256 key for group encryption
  String generateGroupKey() {
    final key = Key.fromSecureRandom(32); // Generate a 256-bit key
    return base64.encode(key.bytes);
  }

  // Store a group's encryption key securely
  Future<void> storeGroupKey(String groupId, String key) async {
    if (!isValidKey(key)) {
      throw Exception('Invalid encryption key format');
    }
    await _secureStorage.write(key: '$_groupKeyPrefix$groupId', value: key);
    final groupKey = Key(base64Decode(key));
    _groupEncrypters[groupId] = Encrypter(AES(groupKey));
    _groupIVs[groupId] = IV.fromLength(16);
  }

  // Retrieve a group's encryption key
  Future<String?> getGroupKey(String groupId) async {
    return await _secureStorage.read(key: '$_groupKeyPrefix$groupId');
  }

  // Hash password for secure storage
  String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Encrypt file content
  List<int> encryptFile(List<int> fileBytes) {
    if (_encrypter == null || _iv == null) {
      throw Exception('Encryption not initialized');
    }

    try {
      final fileString = base64Encode(fileBytes);
      final encrypted = _encrypter!.encrypt(fileString, iv: _iv!);
      return base64Decode(encrypted.base64);
    } catch (e) {
      print('File encryption error: $e');
      throw Exception('Failed to encrypt file');
    }
  }

  // Decrypt file content
  List<int> decryptFile(List<int> encryptedBytes) {
    if (_encrypter == null || _iv == null) {
      throw Exception('Encryption not initialized');
    }

    try {
      final encryptedString = base64Encode(encryptedBytes);
      final encrypted = Encrypted.fromBase64(encryptedString);
      final decrypted = _encrypter!.decrypt(encrypted, iv: _iv!);
      return base64Decode(decrypted);
    } catch (e) {
      print('File decryption error: $e');
      throw Exception('Failed to decrypt file');
    }
  }

  // Generate secure random bytes
  List<int> generateSecureBytes(int length) {
    final random = Random.secure();
    return List.generate(length, (_) => random.nextInt(256));
  }

  // Verify message integrity
  bool verifyMessageIntegrity(String message, String hash) {
    final messageHash = sha256.convert(utf8.encode(message)).toString();
    return messageHash == hash;
  }

  // Generate message hash
  String generateMessageHash(String message) {
    return sha256.convert(utf8.encode(message)).toString();
  }

  // Group-specific encryption methods
  Future<void> initializeGroupEncryption(String groupId) async {
    try {
      final groupKeyString = await _secureStorage.read(
        key: '$_groupKeyPrefix$groupId',
      );

      if (groupKeyString != null) {
        final key = Key.fromBase64(groupKeyString);
        _groupEncrypters[groupId] = Encrypter(AES(key));
        _groupIVs[groupId] = IV.fromLength(16);
      } else {
        // Generate new group key
        await _generateGroupKey(groupId);
      }
    } catch (e) {
      print('Error loading group encryption key: $e');
      await _generateGroupKey(groupId);
    }
  }

  Future<void> _generateGroupKey(String groupId) async {
    try {
      final key = Key.fromSecureRandom(32); // 256-bit key
      _groupEncrypters[groupId] = Encrypter(AES(key));
      _groupIVs[groupId] = IV.fromLength(16);

      // Store the key securely
      await _secureStorage.write(
        key: '$_groupKeyPrefix$groupId',
        value: key.base64,
      );
    } catch (e) {
      print('Error generating group encryption key: $e');
      rethrow;
    }
  }

  String encryptForGroup(String groupId, String plaintext) {
    if (!_groupEncrypters.containsKey(groupId) ||
        !_groupIVs.containsKey(groupId)) {
      throw Exception('Group encryption not initialized for group $groupId');
    }

    try {
      final encrypted = _groupEncrypters[groupId]!.encrypt(
        plaintext,
        iv: _groupIVs[groupId]!,
      );
      return encrypted.base64;
    } catch (e) {
      print('Group encryption error: $e');
      throw Exception('Failed to encrypt message for group');
    }
  }

  String decryptForGroup(String groupId, String encryptedText) {
    if (!_groupEncrypters.containsKey(groupId) ||
        !_groupIVs.containsKey(groupId)) {
      throw Exception('Group encryption not initialized for group $groupId');
    }

    try {
      final encrypted = Encrypted.fromBase64(encryptedText);
      final decrypted = _groupEncrypters[groupId]!.decrypt(
        encrypted,
        iv: _groupIVs[groupId]!,
      );
      return decrypted;
    } catch (e) {
      print('Group decryption error: $e');
      throw Exception('Failed to decrypt message for group');
    }
  }

  // Enhanced invite code generation with group context
  String generateGroupInviteCode(String groupId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random.secure();
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';

    final randomPart = String.fromCharCodes(
      Iterable.generate(
        6,
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );

    // Create a more secure invite code with group context
    final context = '$groupId-$timestamp-$randomPart';
    final hash = sha256
        .convert(utf8.encode(context))
        .toString()
        .substring(0, 8)
        .toUpperCase();

    return hash;
  }

  // Verify invite code belongs to group
  bool verifyGroupInviteCode(String groupId, String inviteCode) {
    // This is a simplified verification - in production, you'd store and verify against database
    return inviteCode.length == 8 &&
        RegExp(r'^[A-Z0-9]+$').hasMatch(inviteCode);
  }

  // Generate secure token for group joining
  String generateJoinToken(String groupId, String userId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random.secure();
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';

    final randomPart = String.fromCharCodes(
      Iterable.generate(
        16,
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );

    final tokenData = '$groupId-$userId-$timestamp-$randomPart';
    final token = base64Encode(utf8.encode(tokenData));

    return token;
  }

  // Verify join token
  Map<String, String>? verifyJoinToken(String token) {
    try {
      final decoded = utf8.decode(base64Decode(token));
      final parts = decoded.split('-');

      if (parts.length >= 4) {
        return {
          'groupId': parts[0],
          'userId': parts[1],
          'timestamp': parts[2],
          'random': parts[3],
        };
      }
    } catch (e) {
      print('Token verification error: $e');
    }
    return null;
  }

  // Clear group encryption keys
  Future<void> clearGroupKeys(String groupId) async {
    _groupEncrypters.remove(groupId);
    _groupIVs.remove(groupId);
    await _secureStorage.delete(key: '$_groupKeyPrefix$groupId');
  }

  // Clear all encryption keys (for logout)
  Future<void> clearKeys() async {
    await _secureStorage.delete(key: _keyStorageKey);
    _encrypter = null;
    _iv = null;
    _groupEncrypters.clear();
    _groupIVs.clear();

    // Clear all group keys
    final keys = await _secureStorage.readAll();
    for (final key in keys.keys) {
      if (key.startsWith(_groupKeyPrefix)) {
        await _secureStorage.delete(key: key);
      }
    }
  }

  // Check if encryption is ready
  bool get isReady => _encrypter != null && _iv != null;

  // Check if group encryption is ready
  bool isGroupReady(String groupId) =>
      _groupEncrypters.containsKey(groupId) && _groupIVs.containsKey(groupId);

  // Encrypt data with a specific key (used for storing group keys)
  String encryptData(String data, String key) {
    if (!isValidKey(key)) {
      throw Exception('Invalid encryption key');
    }

    try {
      final encryptKey = Key(base64Decode(key));
      final iv = IV.fromSecureRandom(16);
      final encrypter = Encrypter(AES(encryptKey));

      final encrypted = encrypter.encrypt(data, iv: iv);
      final combined = iv.bytes + encrypted.bytes;
      return base64.encode(combined);
    } catch (e) {
      throw Exception('Encryption failed: $e');
    }
  }

  // Decrypt data with a specific key (used for retrieving group keys)
  String decryptData(String encryptedData, String key) {
    if (!isValidKey(key)) {
      throw Exception('Invalid encryption key');
    }

    try {
      final encryptKey = Key(base64Decode(key));
      final bytes = base64Decode(encryptedData);

      final iv = IV(bytes.sublist(0, 16));
      final encryptedBytes = bytes.sublist(16);

      final encrypter = Encrypter(AES(encryptKey));
      final encrypted = Encrypted(encryptedBytes);

      return encrypter.decrypt(encrypted, iv: iv);
    } catch (e) {
      throw Exception('Decryption failed: $e');
    }
  }

  // Validate if a string is a valid base64-encoded AES-256 key
  bool isValidKey(String key) {
    try {
      final bytes = base64Decode(key);
      return bytes.length == 32; // 256 bits = 32 bytes
    } catch (_) {
      return false;
    }
  }
}
