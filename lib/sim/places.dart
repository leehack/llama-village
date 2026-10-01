const List<String> publicPlaces = ['pond', 'berry bushes', 'bakery', 'hilltop'];
const Set<String> outdoorPlaces = {'pond', 'berry bushes', 'hilltop'};

String hutOf(String name) => "$name's hut";
bool isHut(String place) => place.endsWith("'s hut");

/// "the pond", but "Pip's hut".
String theP(String place) => isHut(place) ? place : 'the $place';
bool isIndoor(String place) => !outdoorPlaces.contains(place);
bool hasFood(String place, String home) => place == 'bakery' || place == 'berry bushes' || place == home;

/// Where each place sits in the 3D village, in metres on the ground plane
/// (x east, z south). The bakery is the village square.
const Map<String, (double, double)> placeCoordinates = {
  'pond': (-19, 13),
  'berry bushes': (16, 16),
  'bakery': (0, 0),
  'hilltop': (6, -34),
  "Pip's hut": (-12, -4),
  "Mo's hut": (10, -6),
  "June's hut": (21, 2),
  "Bramble's hut": (-6, -20),
  "Clover's hut": (-21, -11),
};

/// Every place, huts included.
List<String> get allPlaces => placeCoordinates.keys.toList();
