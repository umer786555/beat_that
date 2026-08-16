/// Formats a view count into a human-readable string.
/// 
/// Examples:
/// - 1,000 views → "1.0K"
/// - 1,500,000 views → "1.5M"
/// - 42 views → "42"
String formatViewCount(int count) {
  if (count >= 1000000) {
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }
  if (count >= 1000) {
    return '${(count / 1000).toStringAsFixed(1)}K';
  }
  return count.toString();
}
