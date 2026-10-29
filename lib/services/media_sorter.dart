import 'dart:io';

import '../models/sort_options.dart';
import '../models/video.dart';

/// Provides pure sorting utilities for lists of Videos and video Files.
class MediaSorter {
  static List<Video> sortVideos(
    List<Video> videos,
    SortField field,
    SortDirection direction,
  ) {
    final sorted = List<Video>.from(videos);
    int cmp(Video a, Video b) {
      switch (field) {
        case SortField.dateAdded:
          return a.dateAdded.compareTo(b.dateAdded);
        case SortField.duration:
          return (a.durationSeconds ?? 0).compareTo(b.durationSeconds ?? 0);
        case SortField.name:
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        case SortField.size:
          return (a.fileSizeBytes ?? 0).compareTo(b.fileSizeBytes ?? 0);
      }
    }

    sorted.sort(cmp);
    if (direction == SortDirection.descending) {
      return sorted.reversed.toList();
    }
    return sorted;
  }

  static List<File> sortVideoFiles(
    List<File> files,
    SortField field,
    SortDirection direction,
  ) {
    final List<MapEntry<File, Object>> keyed = files.map((file) {
      Object key;
      switch (field) {
        case SortField.dateAdded:
          key = file.existsSync()
              ? file.lastModifiedSync()
              : DateTime.fromMillisecondsSinceEpoch(0);
          break;
        case SortField.duration:
        case SortField.name:
          key = file.path.toLowerCase();
          break;
        case SortField.size:
          key = file.existsSync() ? file.lengthSync() : 0;
          break;
      }
      return MapEntry(file, key);
    }).toList();

    keyed.sort((a, b) {
      final Object ka = a.value;
      final Object kb = b.value;
      if (ka is Comparable && kb is Comparable) {
        return ka.compareTo(kb);
      }
      return 0;
    });

    final List<File> sorted = keyed.map((e) => e.key).toList();
    if (direction == SortDirection.descending) {
      return sorted.reversed.toList();
    }
    return sorted;
  }
}
