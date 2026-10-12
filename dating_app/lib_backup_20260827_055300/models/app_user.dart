class AppUser {
  final String uid;
  final String name;
  final String email;
  final String dateOfBirth;
  final String gender;
  final String interestedIn;
  final String bio;
  final double? latitude;
  final double? longitude;
  final bool isOnline;
  final String photoUrl;

  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.dateOfBirth,
    required this.gender,
    required this.interestedIn,
    required this.bio,
    this.latitude,
    this.longitude,
    required this.isOnline,
    required this.photoUrl,
  });

  factory AppUser.fromMap(String id, Map<String, dynamic> data) {
    return AppUser(
      uid: id,
      name: data['name']?.toString() ?? 'LoveMatch User',
      email: data['email']?.toString() ?? '',
      dateOfBirth: data['dateOfBirth']?.toString() ?? '',
      gender: data['gender']?.toString() ?? '',
      interestedIn: data['interestedIn']?.toString() ?? '',
      bio: data['bio']?.toString() ?? '',
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      isOnline: data['isOnline'] == true,
      photoUrl: data['photoUrl']?.toString() ?? '',
    );
  }
}
