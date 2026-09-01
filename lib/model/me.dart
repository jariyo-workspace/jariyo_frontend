class MeModel {
  final String id; //  "usr_3403ec971cc5",
  final String email; //  "test@example.com",
  final String displayName; //  "Seungju",
  final String phoneNumber; //  "010-5522-9480",
  // final String
  // customerProfile; // {"notificationConsent": true, "marketingConsent": true},
  // final String storeMemberships;

  MeModel({
    required this.id,
    required this.email,
    required this.displayName,
    required this.phoneNumber,
    // required this.customerProfile,
    // required this.storeMemberships,
  }); // []

  factory MeModel.fromJson(e) => MeModel(
    id: e['id'],
    email: e['email'],
    displayName: e['displayName'],
    phoneNumber: e['phoneNumber'],
    // customerProfile: e['customerProfile'],
    // storeMemberships: e['storeMemberships'],
  );
}
