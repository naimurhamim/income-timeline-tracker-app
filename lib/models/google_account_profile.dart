import 'package:flutter/foundation.dart';

/// Cached Google account identity and Drive backup metadata stored on-device.
@immutable
class GoogleAccountProfile {
  const GoogleAccountProfile({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.driveFileId,
    this.lastSyncedAt,
    this.migratedFromFirebase = false,
  });

  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final String? driveFileId;
  final DateTime? lastSyncedAt;
  final bool migratedFromFirebase;

  GoogleAccountProfile copyWith({
    String? id,
    String? email,
    String? displayName,
    String? photoUrl,
    String? driveFileId,
    DateTime? lastSyncedAt,
    bool? migratedFromFirebase,
    bool clearLastSyncedAt = false,
  }) {
    return GoogleAccountProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      driveFileId: driveFileId ?? this.driveFileId,
      lastSyncedAt:
          clearLastSyncedAt ? null : (lastSyncedAt ?? this.lastSyncedAt),
      migratedFromFirebase:
          migratedFromFirebase ?? this.migratedFromFirebase,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'driveFileId': driveFileId,
        'lastSyncedAt': lastSyncedAt?.toIso8601String(),
        'migratedFromFirebase': migratedFromFirebase,
      };

  factory GoogleAccountProfile.fromJson(Map<String, dynamic> json) {
    return GoogleAccountProfile(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      displayName: json['displayName']?.toString(),
      photoUrl: json['photoUrl']?.toString(),
      driveFileId: json['driveFileId']?.toString(),
      lastSyncedAt: DateTime.tryParse(json['lastSyncedAt']?.toString() ?? ''),
      migratedFromFirebase: json['migratedFromFirebase'] == true,
    );
  }
}
