/// Video information extracted from a URL.
class VideoInfo {
  final String? title;
  final String? thumbnail;
  final int? duration;
  final String? uploader;
  final String? webpageUrl;
  final String? extractor;
  final List<VideoFormat> formats;

  VideoInfo({
    this.title,
    this.thumbnail,
    this.duration,
    this.uploader,
    this.webpageUrl,
    this.extractor,
    this.formats = const [],
  });

  factory VideoInfo.fromJson(Map<String, dynamic> json) {
    return VideoInfo(
      title: json['title'],
      thumbnail: json['thumbnail'],
      duration: json['duration'],
      uploader: json['uploader'],
      webpageUrl: json['webpage_url'],
      extractor: json['extractor'],
      formats: (json['formats'] as List? ?? [])
          .map((f) => VideoFormat.fromJson(f))
          .toList(),
    );
  }

  String get durationText {
    if (duration == null) return '--:--';
    final m = duration! ~/ 60;
    final s = duration! % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

/// A single format option for a video.
class VideoFormat {
  final String? formatId;
  final String? ext;
  final String? resolution;
  final int? fps;
  final int? filesize;
  final String? vcodec;
  final String? acodec;
  final double? abr;
  final String? formatNote;

  VideoFormat({
    this.formatId,
    this.ext,
    this.resolution,
    this.fps,
    this.filesize,
    this.vcodec,
    this.acodec,
    this.abr,
    this.formatNote,
  });

  factory VideoFormat.fromJson(Map<String, dynamic> json) {
    return VideoFormat(
      formatId: json['format_id'],
      ext: json['ext'],
      resolution: json['resolution'],
      fps: (json['fps'] as num?)?.toInt(),
      filesize: (json['filesize'] as num?)?.toInt(),
      vcodec: json['vcodec'],
      acodec: json['acodec'],
      abr: (json['abr'] as num?)?.toDouble(),
      formatNote: json['format_note'],
    );
  }

  bool get isVideoOnly =>
      (vcodec != null && vcodec != 'none') &&
      (acodec == null || acodec == 'none');

  bool get isAudioOnly =>
      (acodec != null && acodec != 'none') &&
      (vcodec == null || vcodec == 'none');

  bool get hasBothCodecs =>
      !isVideoOnly &&
      !isAudioOnly &&
      vcodec != null &&
      vcodec != 'none' &&
      acodec != null &&
      acodec != 'none';

  String get fileSizeMb {
    if (filesize == null || filesize == 0) return '—';
    return '${(filesize! / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  String get fileSizeKb {
    if (filesize == null || filesize == 0) return '—';
    if (filesize! < 1024 * 1024)
      return '${(filesize! / 1024).toStringAsFixed(0)} KB';
    return fileSizeMb;
  }

  /// Short video codec name (e.g. "AV1", "H264", "VP9")
  String get vcodecLabel {
    if (vcodec == null || vcodec == 'none') return '';
    final lc = vcodec!.toLowerCase();
    if (lc.contains('av01')) return 'AV1';
    if (lc.contains('avc') || lc.contains('h264')) return 'H264';
    if (lc.contains('vp9')) return 'VP9';
    if (lc.contains('vp09')) return 'VP9';
    if (lc.contains('hevc') || lc.contains('h265')) return 'HEVC';
    if (lc.contains('av1')) return 'AV1';
    return vcodec!.toUpperCase();
  }

  /// Short audio codec name (e.g. "AAC", "OPUS", "MP3")
  String get acodecLabel {
    if (acodec == null || acodec == 'none') return '';
    final lc = acodec!.toLowerCase();
    if (lc.contains('mp4a') || lc.contains('aac')) return 'AAC';
    if (lc.contains('opus')) return 'OPUS';
    if (lc.contains('mp3') || lc.contains('mpga')) return 'MP3';
    if (lc.contains('vorbis')) return 'VORBIS';
    if (lc.contains('flac')) return 'FLAC';
    return acodec!.toUpperCase();
  }

  String get label {
    final parts = <String>[
      if (resolution != null && resolution != 'audio only') resolution!,
      if (ext != null) ext!.toUpperCase(),
      if (fps != null && fps! > 30) '${fps}fps',
    ];
    return parts.join(' · ');
  }
}

/// A download record from the backend.
class DownloadRecord {
  final int id;
  final String? fileName;
  final String? filePath;
  final int? fileSize;
  final DateTime? createdAt;

  DownloadRecord({
    this.id = 0,
    this.fileName,
    this.filePath,
    this.fileSize,
    this.createdAt,
  });

  factory DownloadRecord.fromJson(Map<String, dynamic> json) {
    return DownloadRecord(
      id: (json['id'] as num?)?.toInt() ??
          (json['file_name']?.hashCode ?? 0),
      fileName: json['file_name'],
      filePath: json['file_path'],
      fileSize: (json['file_size'] as num?)?.toInt(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ??
              DateTime.fromMillisecondsSinceEpoch(
                  (json['created_at'] as num).toInt() * 1000,
                  isUtc: true)
          : null,
    );
  }

  String get fileSizeMb {
    if (fileSize == null || fileSize == 0) return '—';
    return '${(fileSize! / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  String get title => fileName ?? 'Video';
}
