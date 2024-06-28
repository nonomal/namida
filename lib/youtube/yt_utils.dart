import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:history_manager/history_manager.dart';
import 'package:intl/intl.dart';
import 'package:playlist_manager/module/playlist_id.dart';
import 'package:share_plus/share_plus.dart';
import 'package:youtipie/class/streams/video_stream_info.dart';
import 'package:youtipie/core/url_utils.dart';

import 'package:namida/class/video.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/ffmpeg_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/miniplayer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/storage_cache_manager.dart';
import 'package:namida/controller/thumbnail_manager.dart';
import 'package:namida/controller/video_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_history_controller.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';
import 'package:namida/youtube/controller/youtube_playlist_controller.dart';
import 'package:namida/youtube/controller/yt_miniplayer_ui_controller.dart';
import 'package:namida/youtube/functions/add_to_playlist_sheet.dart';
import 'package:namida/youtube/functions/download_sheet.dart';
import 'package:namida/youtube/functions/video_listens_dialog.dart';
import 'package:namida/youtube/pages/yt_channel_subpage.dart';
import 'package:namida/youtube/pages/yt_history_page.dart';

class YTUtils {
  static void expandMiniplayer() {
    final st = MiniPlayerController.inst.ytMiniplayerKey.currentState;
    if (st != null) st.animateToState(true);

    // if the miniplayer wasnt already active, we wait till the queue get filled (i.e. miniplayer gets a state)
    // it would be better if we had a callback instead of waiting 300ms.
    // since awaiting [playOrPause] would take quite long.
    if (st == null) {
      Future.delayed(
        const Duration(milliseconds: 300),
        () => MiniPlayerController.inst.ytMiniplayerKey.currentState?.animateToState(true),
      );
    }

    YoutubeMiniplayerUiController.inst.resetGlowUnderVideo();
  }

  static List<Widget> getVideoCacheStatusIcons({
    required String videoId,
    required BuildContext context,
    Color? iconsColor,
    List<int> overrideListens = const [],
    bool displayCacheIcons = true,
  }) {
    iconsColor ??= context.theme.iconTheme.color;
    final listens = overrideListens.isNotEmpty ? overrideListens : YoutubeHistoryController.inst.topTracksMapListens[videoId] ?? [];
    return [
      if (listens.isNotEmpty)
        NamidaInkWell(
          borderRadius: 6.0,
          bgColor: context.theme.scaffoldBackgroundColor.withOpacity(0.5),
          onTap: () {
            showVideoListensDialog(videoId);
          },
          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 1.0),
          child: Text(
            listens.length.formatDecimal(),
            style: context.textTheme.displaySmall,
          ),
        ),
      if (displayCacheIcons) ...[
        const SizedBox(width: 4.0),
        Tooltip(
          message: lang.VIDEO_CACHE,
          child: Icon(
            Broken.video,
            size: 15.0,
            color: iconsColor?.withOpacity(
              VideoController.inst.getNVFromID(videoId).isNotEmpty ? 0.6 : 0.1,
            ),
          ),
        ),
        const SizedBox(width: 4.0),
        Tooltip(
          message: lang.AUDIO_CACHE,
          child: Icon(
            Broken.audio_square,
            size: 15.0,
            color: iconsColor?.withOpacity(
              Player.inst.audioCacheMap[videoId] != null || Indexer.inst.allTracksMappedByYTID[videoId] != null ? 0.6 : 0.1,
            ),
          ),
        ),
      ],
    ];
  }

  static List<NamidaPopupItem> getVideosMenuItems({
    required List<YoutubeID> videos,
    List<NamidaPopupItem> moreItems = const [],
    required String playlistName,
  }) {
    final playAfterVid = getPlayerAfterVideo();
    return [
      NamidaPopupItem(
        icon: Broken.music_library_2,
        title: lang.ADD_TO_PLAYLIST,
        onTap: () {
          showAddToPlaylistSheet(ids: videos.map((e) => e.id), idsNamesLookup: {});
        },
      ),
      NamidaPopupItem(
        icon: Broken.share,
        title: lang.SHARE,
        onTap: videos.shareVideos,
      ),
      NamidaPopupItem(
        icon: Broken.play,
        title: lang.PLAY,
        onTap: () => Player.inst.playOrPause(0, videos, QueueSource.others),
      ),
      NamidaPopupItem(
        icon: Broken.shuffle,
        title: lang.SHUFFLE,
        onTap: () => Player.inst.playOrPause(0, videos, QueueSource.others, shuffle: true),
      ),
      NamidaPopupItem(
        icon: Broken.next,
        title: lang.PLAY_NEXT,
        onTap: () => Player.inst.addToQueue(videos, insertNext: true),
      ),
      if (playAfterVid != null)
        NamidaPopupItem(
          icon: Broken.hierarchy_square,
          title: '${lang.PLAY_AFTER}: ${playAfterVid.diff.displayVideoKeyword}',
          subtitle: playAfterVid.name,
          oneLinedSub: true,
          onTap: () {
            Player.inst.addToQueue(videos, insertAfterLatest: true);
          },
        ),
      NamidaPopupItem(
        icon: Broken.play_cricle,
        title: lang.PLAY_LAST,
        onTap: () => Player.inst.addToQueue(videos, insertNext: false),
      ),
      if (playlistName != '')
        NamidaPopupItem(
          icon: Broken.trash,
          title: lang.DELETE,
          onTap: () => YTUtils.onRemoveVideosFromPlaylist(k_PLAYLIST_NAME_HISTORY, videos),
        ),
      ...moreItems,
    ];
  }

  static List<NamidaPopupItem> getVideoCardMenuItems({
    required String videoId,
    required String? url,
    required String? channelID,
    required PlaylistID? playlistID,
    required Map<String, String?> idsNamesLookup,
    String playlistName = '',
    YoutubeID? videoYTID,
    bool copyUrl = false,
  }) {
    final playAfterVid = getPlayerAfterVideo();
    final currentVideo = Player.inst.currentVideo;
    final isCurrentlyPlaying = currentVideo != null && videoId == currentVideo.id;
    return [
      NamidaPopupItem(
        icon: Broken.music_library_2,
        title: lang.ADD_TO_PLAYLIST,
        onTap: () {
          showAddToPlaylistSheet(ids: [videoId], idsNamesLookup: idsNamesLookup);
        },
      ),
      NamidaPopupItem(
        icon: Broken.import,
        title: lang.DOWNLOAD,
        onTap: () {
          showDownloadVideoBottomSheet(
            videoId: videoId,
          );
        },
      ),
      if (url != null && url != '')
        NamidaPopupItem(
          icon: Broken.share,
          title: lang.SHARE,
          onTap: () => Share.share(url),
        ),
      if (copyUrl)
        NamidaPopupItem(
          icon: Broken.copy,
          title: lang.COPY,
          onTap: () => YTUtils().copyCurrentVideoUrl(videoId),
        ),
      if (channelID != null && channelID != '')
        NamidaPopupItem(
          icon: Broken.user,
          title: lang.GO_TO_CHANNEL,
          onTap: () {
            NamidaNavigator.inst.navigateTo(YTChannelSubpage(channelID: channelID));
          },
        ),
      isCurrentlyPlaying
          ? NamidaPopupItem(
              icon: Broken.pause,
              title: lang.STOP_AFTER_THIS_VIDEO,
              enabled: Player.inst.sleepTimerConfig.value.sleepAfterItems != 1,
              onTap: () {
                Player.inst.updateSleepTimerValues(enableSleepAfterItems: true, sleepAfterItems: 1);
              },
            )
          : NamidaPopupItem(
              icon: Broken.play,
              title: lang.PLAY,
              onTap: () {
                Player.inst.playOrPause(0, [YoutubeID(id: videoId, playlistID: playlistID)], QueueSource.others);
              },
            ),
      NamidaPopupItem(
        icon: Broken.next,
        title: lang.PLAY_NEXT,
        onTap: () {
          Player.inst.addToQueue([YoutubeID(id: videoId, playlistID: playlistID)], insertNext: true, showSnackBar: false);
        },
      ),
      if (playAfterVid != null)
        NamidaPopupItem(
          icon: Broken.hierarchy_square,
          title: '${lang.PLAY_AFTER}: ${playAfterVid.diff.displayVideoKeyword}',
          subtitle: playAfterVid.name,
          oneLinedSub: true,
          onTap: () {
            Player.inst.addToQueue([YoutubeID(id: videoId, playlistID: playlistID)], insertAfterLatest: true, showSnackBar: false);
          },
        ),
      NamidaPopupItem(
        icon: Broken.play_cricle,
        title: lang.PLAY_LAST,
        onTap: () {
          Player.inst.addToQueue([YoutubeID(id: videoId, playlistID: playlistID)], insertNext: false, showSnackBar: false);
        },
      ),
      if (playlistName != '' && videoYTID != null)
        NamidaPopupItem(
          icon: Broken.box_remove,
          title: lang.REMOVE_FROM_PLAYLIST,
          subtitle: playlistName.translatePlaylistName(liked: true),
          onTap: () => YTUtils.onRemoveVideosFromPlaylist(playlistName, [videoYTID]),
        ),
    ];
  }

  static ({YoutubeID video, int diff, String name})? getPlayerAfterVideo() {
    final player = Player.inst;
    if (player.currentItem.value is YoutubeID && player.latestInsertedIndex != player.currentIndex.value) {
      try {
        final playAfterVideo = player.currentQueue.value[player.latestInsertedIndex] as YoutubeID;
        final diff = player.latestInsertedIndex - player.currentIndex.value;
        final name = YoutubeInfoController.utils.getVideoName(playAfterVideo.id) ?? '';
        return (video: playAfterVideo, diff: diff, name: name);
      } catch (_) {}
    }
    return null;
  }

  static Map<String, String?> getMetadataInitialMap(String id, VideoStreamInfo? info, {bool autoExtract = true}) {
    String removeTopic(String text) {
      const topic = '- Topic';
      final startIndex = (text.length - topic.length).withMinimum(0);
      return text.replaceFirst(topic, '', startIndex).trimAll();
    }

    final date = info?.publishedAt.date;
    final description = info?.availableDescription;
    String? title = info?.title;
    String? artist = info?.channelName;
    String? album;
    if (autoExtract) {
      final splitted = info?.title.splitArtistAndTitle();
      if (splitted != null && splitted.$1 != null && splitted.$2 != null) {
        title = splitted.$2;
        artist = splitted.$1;
      }
      final uploaderName = info?.channelName;
      if (uploaderName != null) album = removeTopic(uploaderName);
    }

    if (artist != null) artist = removeTopic(artist);

    return {
      FFMPEGTagField.title: title,
      FFMPEGTagField.artist: artist,
      FFMPEGTagField.album: album,
      FFMPEGTagField.comment: YTUrlUtils.buildVideoUrl(id),
      FFMPEGTagField.year: date == null ? null : DateFormat('yyyyMMdd').format(date),
      FFMPEGTagField.synopsis: description,
    };
  }

  static Future<bool> writeAudioMetadata({
    required String videoId,
    required File audioFile,
    required File? thumbnailFile,
    required Map<String, String?> tagsMap,
  }) async {
    final thumbnail = thumbnailFile ?? await ThumbnailManager.inst.getYoutubeThumbnailAndCache(id: videoId);
    if (thumbnail != null) {
      await NamidaFFMPEG.inst.editAudioThumbnail(audioPath: audioFile.path, thumbnailPath: thumbnail.path);
    }
    return await NamidaFFMPEG.inst.editMetadata(
      path: audioFile.path,
      tagsMap: tagsMap,
    );
  }

  static Future<void> onYoutubeHistoryPlaylistTap({
    required HistoryScrollInfo scrollInfo,
    required double initialScrollOffset,
  }) async {
    YoutubeHistoryController.inst.highlightedItem.value = scrollInfo;

    void jump() => YoutubeHistoryController.inst.scrollController.jumpTo(initialScrollOffset);

    NamidaNavigator.inst.hideStuff();

    if (YoutubeHistoryController.inst.scrollController.hasClients) {
      jump();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        jump();
      });
      await NamidaNavigator.inst.navigateTo(
        const YoutubeHistoryPage(),
      );
    }
  }

  static Future<void> onRemoveVideosFromPlaylist(String name, List<YoutubeID> videosToDelete) async {
    void showSnacky({required void Function() whatDoYouWant}) {
      snackyy(
        title: lang.UNDO_CHANGES,
        message: lang.UNDO_CHANGES_DELETED_TRACK,
        displaySeconds: 3,
        button: (lang.UNDO, whatDoYouWant),
      );
    }

    final bool isHistory = name == k_PLAYLIST_NAME_HISTORY;

    if (isHistory) {
      final tempList = List<YoutubeID>.from(videosToDelete);
      await YoutubeHistoryController.inst.removeTracksFromHistory(videosToDelete);
      showSnacky(
        whatDoYouWant: () async {
          await YoutubeHistoryController.inst.addTracksToHistory(tempList);
          YoutubeHistoryController.inst.sortHistoryTracks(tempList.mapped((e) => e.dateTimeAdded.toDaysSince1970()));
        },
      );
    } else {
      final playlist = YoutubePlaylistController.inst.getPlaylist(name);
      if (playlist == null) return;

      final Map<YoutubeID, int> twdAndIndexes = {};
      videosToDelete.loop((twd) {
        twdAndIndexes[twd] = playlist.tracks.indexOf(twd);
      });

      await YoutubePlaylistController.inst.removeTracksFromPlaylist(playlist, twdAndIndexes.values.toList());
      showSnacky(
        whatDoYouWant: () async {
          YoutubePlaylistController.inst.insertTracksInPlaylistWithEachIndex(
            playlist,
            twdAndIndexes,
          );
        },
      );
    }
  }

  void showVideoClearDialog(BuildContext context, String videoId, Color colorScheme) {
    final videosCached = VideoController.inst.getNVFromID(videoId);
    final audiosCached = Player.inst.audioCacheMap[videoId]?.where((element) => element.file.existsSync()).toList() ?? [];

    final fileSizeLookup = <String, int>{};
    final fileTypeLookup = <String, int>{};

    int videosSize = 0;
    int audiosSize = 0;

    audiosCached.loop((e) {
      final s = e.file.sizeInBytesSync();
      audiosSize += s;
      fileSizeLookup[e.file.path] = s;
      fileTypeLookup[e.file.path] = 0;
    });
    videosCached.loop((e) {
      final s = e.sizeInBytes;
      videosSize += s;
      fileSizeLookup[e.path] = s;
      fileTypeLookup[e.path] = 1;
    });

    final pathsToDelete = <String, bool>{}.obs;
    final allSelected = false.obs;
    final totalSizeToDelete = 0.obs;

    final deleteTempAudio = false.obs;
    final deleteTempVideo = false.obs;
    final tempFilesSizeAudio = <File, int>{}.obs;
    final tempFilesSizeVideo = <File, int>{}.obs;

    const cm = StorageCacheManager();
    cm.getTempAudiosForID(videoId).then((value) => tempFilesSizeAudio.value = value);
    cm.getTempVideosForID(videoId).then((value) => tempFilesSizeVideo.value = value);

    void reEvaluateTotalSize() {
      int newVal = 0;
      for (final k in pathsToDelete.keys) {
        if (pathsToDelete[k] == true) newVal += fileSizeLookup[k] ?? 0;
      }
      if (deleteTempAudio.value) {
        for (final v in tempFilesSizeAudio.values) {
          newVal += v;
        }
      }
      if (deleteTempVideo.value) {
        for (final v in tempFilesSizeVideo.values) {
          newVal += v;
        }
      }
      totalSizeToDelete.value = newVal;
    }

    Future<void> deleteItems(Iterable<String> paths) async {
      for (final path in paths) {
        await File(path).tryDeleting();

        final type = fileTypeLookup[path];
        if (type == 1) {
          VideoController.inst.removeNVFromCacheMap(videoId, path);
        } else if (type == 0) {
          Player.inst.audioCacheMap[videoId]?.removeWhere((element) => element.file.path == path);
        }
      }
    }

    Widget getExpansionTileWidget<T>({
      required String title,
      required String subtitle,
      required IconData icon,
      required List<T> items,
      required ({String title, String subtitle, String path}) Function(T item) itemBuilder,
      required int Function(T item) itemSize,
      required RxMap<File, int> tempFilesSize,
      required Rx<bool> tempFilesDelete,
    }) {
      return NamidaExpansionTile(
        initiallyExpanded: true,
        titleText: title,
        subtitleText: subtitle,
        icon: icon,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: context.theme.cardColor,
                borderRadius: BorderRadius.circular(6.0.multipliedRadius),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 3.0),
                child: Text("${items.length}"),
              ),
            ),
            const SizedBox(width: 6.0),
            const Icon(Broken.arrow_down_2, size: 20.0),
          ],
        ),
        childrenPadding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
        children: [
          ...items.map(
            (item) {
              final data = itemBuilder(item);
              return SmallListTile(
                borderRadius: 12.0,
                icon: Broken.arrow_right_3,
                iconSize: 20.0,
                color: context.theme.cardColor,
                visualDensity: const VisualDensity(horizontal: -3.0, vertical: -3.0),
                title: data.title,
                subtitle: data.subtitle,
                active: false,
                onTap: () {
                  final wasTrue = pathsToDelete[data.path] == true;
                  final willEnable = !wasTrue;
                  pathsToDelete[data.path] = willEnable;
                  if (willEnable) {
                    totalSizeToDelete.value += itemSize(item);
                  } else {
                    totalSizeToDelete.value -= itemSize(item);
                  }
                  allSelected.value = false;
                },
                trailing: Obx(
                  () => NamidaCheckMark(
                    size: 16.0,
                    active: pathsToDelete[data.path] == true,
                  ),
                ),
              );
            },
          ),
          Obx(
            () {
              final size = tempFilesSize.values.fold(0, (p, e) => p + e);
              if (size <= 0) return const SizedBox();
              return SmallListTile(
                borderRadius: 12.0,
                icon: Broken.broom,
                iconSize: 20.0,
                color: context.theme.cardColor,
                visualDensity: const VisualDensity(horizontal: -3.0, vertical: -3.0),
                title: lang.DELETE_TEMP_FILES,
                subtitle: size.fileSizeFormatted,
                active: false,
                onTap: () {
                  tempFilesDelete.value = !tempFilesDelete.value;
                  if (tempFilesDelete.value) {
                    totalSizeToDelete.value += size;
                  } else {
                    totalSizeToDelete.value -= size;
                  }
                },
                trailing: ObxO(
                  rx: tempFilesDelete,
                  builder: (deletetemp) => NamidaCheckMark(
                    size: 16.0,
                    active: deletetemp,
                  ),
                ),
              );
            },
          ),
        ],
      );
    }

    NamidaNavigator.inst.navigateDialog(
      onDisposing: () {
        pathsToDelete.close();
        allSelected.close();
        totalSizeToDelete.close();
        deleteTempAudio.close();
        deleteTempVideo.close();
        tempFilesSizeAudio.close();
        tempFilesSizeVideo.close();
      },
      dialogBuilder: (theme) => CustomBlurryDialog(
        theme: theme,
        normalTitleStyle: true,
        icon: Broken.trash,
        title: lang.CLEAR,
        trailingWidgets: [
          Obx(
            () => Checkbox.adaptive(
              splashRadius: 28.0,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4.0.multipliedRadius),
              ),
              value: allSelected.valueR,
              onChanged: (_) {
                final newVal = allSelected.toggle();
                if (newVal == true) {
                  audiosCached.loop((e) => pathsToDelete[e.file.path] = true);
                  videosCached.loop((e) => pathsToDelete[e.path] = true);
                  deleteTempAudio.value = true;
                  deleteTempVideo.value = true;
                } else {
                  pathsToDelete.clear();
                  deleteTempAudio.value = false;
                  deleteTempVideo.value = false;
                }
                reEvaluateTotalSize();
              },
            ),
          ),
        ],
        actions: [
          const CancelButton(),
          Obx(
            () => NamidaButton(
              enabled: deleteTempAudio.valueR || deleteTempVideo.valueR || pathsToDelete.values.any((element) => element),
              text: "${lang.DELETE} (${totalSizeToDelete.valueR.fileSizeFormatted})",
              onPressed: () async {
                await Future.wait([
                  deleteItems(pathsToDelete.keys.where((element) => pathsToDelete[element] == true)),
                  if (deleteTempAudio.value) deleteItems(tempFilesSizeAudio.keys.map((e) => e.path)),
                  if (deleteTempVideo.value) deleteItems(tempFilesSizeVideo.keys.map((e) => e.path)),
                ]);
                NamidaNavigator.inst.closeDialog();
              },
            ),
          ),
        ],
        child: Column(
          children: [
            getExpansionTileWidget(
              title: lang.VIDEO_CACHE,
              subtitle: videosSize.fileSizeFormatted,
              icon: Broken.video,
              items: videosCached,
              itemSize: (item) => item.sizeInBytes,
              tempFilesDelete: deleteTempVideo,
              tempFilesSize: tempFilesSizeVideo,
              itemBuilder: (v) {
                return (
                  title: "${v.resolution}p • ${v.framerate}fps ",
                  subtitle: v.sizeInBytes.fileSizeFormatted,
                  path: v.path,
                );
              },
            ),
            getExpansionTileWidget(
              title: lang.AUDIO_CACHE,
              subtitle: audiosSize.fileSizeFormatted,
              icon: Broken.musicnote,
              items: audiosCached,
              itemSize: (item) => fileSizeLookup[item.file.path] ?? item.file.sizeInBytesSync(),
              tempFilesDelete: deleteTempAudio,
              tempFilesSize: tempFilesSizeAudio,
              itemBuilder: (a) {
                final bitrateText = a.bitrate == null ? null : "${a.bitrate! ~/ 1000}kb/s";
                final langText = a.langaugeName == null ? '' : " • ${a.langaugeName}";
                return (
                  title: "${bitrateText ?? lang.AUDIO}$langText",
                  subtitle: a.file.fileSizeFormatted() ?? '',
                  path: a.file.path,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void copyCurrentVideoUrl(String videoId) {
    if (videoId != '') {
      final atSeconds = Player.inst.nowPlayingPosition.value ~/ 1000;
      final timeStamp = atSeconds > 0 ? '?t=$atSeconds' : '';
      final finalUrl = "https://www.youtube.com/watch?v=$videoId$timeStamp";
      Clipboard.setData(ClipboardData(text: finalUrl));
      snackyy(
        message: lang.COPIED_TO_CLIPBOARD,
        top: false,
        leftBarIndicatorColor: CurrentColor.inst.miniplayerColor,
      );
    }
  }
}
