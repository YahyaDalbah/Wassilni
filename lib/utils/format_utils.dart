extension DistanceFormatter on double {
  String formatDistance() {
    if (this < 100) {
      return '${(this).round()} m';
    }
    return '${(this / 1000).toStringAsFixed(1)} km';
  }

  String formatDuration() {
    if (this < 60) {
      return '${this.round()} sec';
    } else if (this < 3600) {
      return '${(this / 60).toInt()}:${(this % 60).toInt().toString().padLeft(2, '0')} min';
    } else {
      return '${(this / 3600).toInt()}:${((this / 60) % 60).toInt().toString().padLeft(2, '0')}:${(this % 60).toInt().toString().padLeft(2, '0')}';
    }
  }
}
