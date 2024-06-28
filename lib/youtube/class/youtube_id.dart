import 'dart:async';
import 'dart:io';

import 'package:history_manager/history_manager.dart';
import 'package:playlist_manager/module/playlist_id.dart';
import 'package:share_plus/share_plus.dart';
import 'package:youtipie/core/url_utils.dart';

import 'package:namida/class/track.dart';
import 'package:namida/class/video.dart';
import 'package:namida/controller/thumbnail_manager.dart';
import 'package:namida/core/extensions.dart';

class YoutubeID implements Playable, ItemWithDate {
  final String id;
  final YTWatch? watchNull;
  final PlaylistID? playlistID;

  @override
  DateTime get dateTimeAdded => _date;

  DateTime get _date => watch.date;

  YTWatch get watch => watchNull ?? const YTWatch(dateNull: null, isYTMusic: false);

  const YoutubeID({
    required this.id,
    this.watchNull,
    required this.playlistID,
  });

  factory YoutubeID.fromJson(Map<String, dynamic> json) {
    return YoutubeID(
      id: json['id'] ?? '',
      watchNull: YTWatch.fromJson(json['watch']),
      playlistID: json['playlistID'] == null ? null : PlaylistID.fromJson(json['playlistID']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "watch": watch.toJson(),
      "playlistID": playlistID?.toJson(),
    };
  }

  @override
  bool operator ==(other) {
    if (other is YoutubeID) {
      return id == other.id && _date.millisecondsSinceEpoch == other._date.millisecondsSinceEpoch;
    }
    return false;
  }

  @override
  int get hashCode => "${id}_${_date.millisecondsSinceEpoch}".hashCode;

  @override
  String toString() => "YoutubeID(id: $id, addedDate: $_date, playlistID: $playlistID)";
}

extension YoutubeIDUtils on YoutubeID {
  File? getThumbnailSync() {
    return ThumbnailManager.inst.getYoutubeThumbnailFromCacheSync(id: id);
  }
}

extension YoutubeIDSUtils on List<YoutubeID> {
  Future<void> shareVideos() async {
    await Share.share(map((e) => "${YTUrlUtils.buildVideoUrl(e.id)} - ${e.dateTimeAdded.millisecondsSinceEpoch.dateAndClockFormattedOriginal}\n").join());
  }
}
