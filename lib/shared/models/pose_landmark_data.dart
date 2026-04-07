class PoseLandmarkData {
  const PoseLandmarkData({
    required this.index,
    required this.x,
    required this.y,
    this.z = 0,
    this.likelihood = 1,
  });

  final int index;
  final double x;
  final double y;
  final double z;
  final double likelihood;
}
