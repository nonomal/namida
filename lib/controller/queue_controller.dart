import 'dart:collection';
import 'dart:io';

import 'package:namida/core/utils.dart';

import 'package:namida/class/queue.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/youtube/class/youtube_id.dart';

class QueueController {
  static QueueController get inst => _instance;
  static final QueueController _instance = QueueController._internal();
  QueueController._internal();

  /// holds all queues mapped & sorted by [date] chronologically & reversly.
  final Rx<SplayTreeMap<int, Queue>> queuesMap = SplayTreeMap<int, Queue>((date1, date2) => date2.compareTo(date1)).obs;

  Queue? get _latestQueueInMap => queuesMap.value[_latestAddedQueueDate];

  /// faster way to access latest queue
  int _latestAddedQueueDate = 0;

  /// doesnt save queues with more than 2000 tracks.
  Future<void> addNewQueue({
    required QueueSource source,
    required HomePageItems? homePageItem,
    int? date,
    List<Track> tracks = const <Track>[],
  }) async {
    /// If there are more than 2000 tracks.
    if (tracks.length > 2000) {
      printy("UWAH QUEUE DEKKA", isError: true);
      return;
    }

    date ??= currentTimeMS;

    if (_isLoadingQueues) {
      // after queues full load, [addNewQueue] will be called to add Queues inside [_queuesToAddAfterAllQueuesLoad].
      _queuesToAddAfterAllQueuesLoad.add(Queue(source: source, homePageItem: homePageItem, date: date, isFav: false, tracks: tracks));
      printy("Queue adding suspended until queues full load");
      return;
    }

    // -- Prevents saving [allTracks] source over and over.
    final latestQueue = _latestQueueInMap;
    if (latestQueue != null) {
      if (source == QueueSource.allTracks && latestQueue.source == QueueSource.allTracks) {
        await removeQueue(latestQueue);
      }
    }

    final q = Queue(source: source, homePageItem: homePageItem, date: date, isFav: false, tracks: tracks);
    _updateMap(q);
    _latestAddedQueueDate = q.date;
    printy("Added New Queue");
    await _saveQueueToStorage(q);
  }

  Future<void> removeQueue(Queue queue) async {
    queuesMap.value.remove(queue.date);
    queuesMap.refresh();
    if (queue.date == _latestAddedQueueDate) _latestAddedQueueDate = 0;
    await _deleteQueueFromStorage(queue);
  }

  Future<void> removeQueues(List<int> queuesDates) async {
    bool hasLatestAdded = false;
    queuesDates.loop((date) {
      queuesMap.value.remove(date);
      if (date == _latestAddedQueueDate) hasLatestAdded = true;
    });
    queuesMap.refresh();
    if (hasLatestAdded) _latestAddedQueueDate = 0;
    await _deleteQueuesFromStorage(queuesDates);
  }

  Future<void> reAddQueue(Queue queue) async {
    _updateMap(queue);
    await _saveQueueToStorage(queue);
  }

  void _updateMap(Queue queue, [int? date]) {
    date ??= queue.date;
    queuesMap.value[date] = queue;
    queuesMap.refresh();
  }

  // void removeQueues(List<Queue> queues) async {
  //   queues.loop((q) => removeQueue(q));
  // }

  Future<void> toggleFavButton(Queue oldQueue) async {
    final newQueue = oldQueue.copyWith(isFav: !(queuesMap.value[oldQueue.date]?.isFav ?? false));
    queuesMap.value[oldQueue.date] = newQueue;
    _updateMap(newQueue);
    await _saveQueueToStorage(newQueue);
  }

  Future<void> updateQueue(Queue oldQueue, Queue newQueue) async {
    _updateMap(newQueue, oldQueue.date);
    await _saveQueueToStorage(newQueue);
  }

  Future<void> updateLatestQueue(List<Playable> items) async {
    await Future.wait([
      _saveLatestQueueToStorage(items),
      () async {
        // updating last queue inside queuesMap.
        final firstItem = items.firstOrNull;
        if (firstItem is Selectable) {
          final latestQueueInsideMap = _latestQueueInMap;
          final tracks = items.cast<Selectable>().tracks.toList();
          if (latestQueueInsideMap != null) {
            await updateQueue(latestQueueInsideMap, latestQueueInsideMap.copyWith(tracks: tracks));
          }
        }
      }(),
    ]);
  }

  Future<void> insertTracksQueue(Queue queue, List<Track> tracks, int index) async {
    queue.tracks.insertAllSafe(index, tracks);
    _updateMap(queue);
    await _saveQueueToStorage(queue);
  }

  Future<void> removeTrackFromQueue(Queue queue, int index) async {
    queue.tracks.removeAt(index);
    _updateMap(queue);
    await _saveQueueToStorage(queue);
  }

  /// Only use when updating missing track.
  Future<void> replaceTracksDirectoryInQueues(String oldDir, String newDir, {Iterable<String>? forThesePathsOnly, bool ensureNewFileExists = false}) async {
    String getNewPath(String old) => old.replaceFirst(oldDir, newDir);

    final queuesToSave = <Queue>{};
    queuesMap.value.entries.toList().loop((entry) {
      final q = entry.value;
      q.tracks.replaceWhere(
        (e) {
          final trackPath = e.path;
          if (ensureNewFileExists) {
            if (!File(getNewPath(trackPath)).existsSync()) return false;
          }
          final firstC = forThesePathsOnly != null ? forThesePathsOnly.contains(e.track.path) : true;
          final secondC = trackPath.startsWith(oldDir);
          return firstC && secondC;
        },
        (old) => Track(old.path.replaceFirst(oldDir, newDir)),
        onMatch: () => queuesToSave.add(q),
      );
    });
    for (final q in queuesToSave) {
      _updateMap(q);
      await _saveQueueToStorage(q);
    }
  }

  Future<void> replaceTrackInAllQueues(Map<Track, Track> oldNewTrack) async {
    final queuesToSave = <Queue>[];
    queuesMap.value.entries.toList().loop((entry) {
      final q = entry.value;
      for (final e in oldNewTrack.entries) {
        q.tracks.replaceItems(
          e.key,
          e.value,
          onMatch: () => queuesToSave.add(q),
        );
      }
    });
    for (final q in queuesToSave) {
      _updateMap(q);
      await _saveQueueToStorage(q);
    }
  }

  ///
  Future<void> prepareAllQueuesFile() async {
    final mapAndLatest = await _readQueueFilesCompute.thready(AppDirs.QUEUES);
    queuesMap.value = mapAndLatest.$1;
    _latestAddedQueueDate = mapAndLatest.$2;
    _isLoadingQueues = false;
    // Adding queues that were rejected by [addNewQueue] since Queues wasn't fully loaded.
    if (_queuesToAddAfterAllQueuesLoad.isNotEmpty) {
      for (final q in _queuesToAddAfterAllQueuesLoad) {
        await addNewQueue(source: q.source, homePageItem: q.homePageItem, date: q.date, tracks: q.tracks);
      }
      printy("Added ${_queuesToAddAfterAllQueuesLoad.length} queue that were suspended");
      _queuesToAddAfterAllQueuesLoad.clear();
    }
  }

  static (SplayTreeMap<int, Queue>, int) _readQueueFilesCompute(String path) {
    int newestQueueDate = 0;
    final map = SplayTreeMap<int, Queue>((date1, date2) => date1.compareTo(date2));
    for (final f in Directory(path).listSyncSafe()) {
      if (f is File) {
        try {
          final response = f.readAsJsonSync();
          final q = Queue.fromJson(response);
          map[q.date] = q;
          if (q.date > newestQueueDate) newestQueueDate = q.date;
        } catch (e) {
          continue;
        }
      }
    }
    return (map, newestQueueDate);
  }

  Future<void> emptyLatestQueue() async {
    await File(AppPaths.LATEST_QUEUE).tryDeleting();
  }

  /// Assigns the last queue to the [Player]
  Future<void> prepareLatestQueue() async {
    int index = 0;
    final latestQueue = <Playable>[];

    // -- Reading file.
    try {
      final res = await File(AppPaths.LATEST_QUEUE).readAsJson() as Map?;
      if (res != null) {
        final t = res['type'] as String? ?? LibraryCategory.localTracks;
        final items = res['items'] as List;
        index = settings.player.lastPlayedIndices[t] ?? 0;
        switch (t) {
          case LibraryCategory.localTracks:
            items.loop((e) => latestQueue.add(Track(e)));
            break;
          case LibraryCategory.youtube:
            items.loop((e) => latestQueue.add(YoutubeID.fromJson(e)));
            break;
          // case LibraryCategory.localVideos:
          // break;
        }
      }
    } catch (_) {}

    if (latestQueue.isEmpty) return;

    Player.inst.playOrPause(
      index > latestQueue.length - 1 ? 0 : index,
      latestQueue,
      QueueSource.playerQueue,
      startPlaying: false,
      updateQueue: false,
    );
  }

  Future<void> _saveQueueToStorage(Queue queue) async {
    await File('${AppDirs.QUEUES}${queue.date}.json').writeAsJson(queue.toJson());
  }

  Future<void> _saveLatestQueueToStorage(List<Playable> items) async {
    String type = '';
    final queue = <Object>[];
    switch (items.firstOrNull.runtimeType) {
      case const (Selectable):
      case const (Track):
      case const (TrackWithDate):
        type = LibraryCategory.localTracks;
        items.loop((e) => queue.add((e as Selectable).track.path));
        break;

      case const (YoutubeID):
        type = LibraryCategory.youtube;
        (items.cast<YoutubeID>()).loop((e) => queue.add(e.toJson()));
        break;
    }
    final map = {
      'type': type,
      'items': queue,
    };
    await File(AppPaths.LATEST_QUEUE).writeAsJson(map);
  }

  Future<void> _deleteQueueFromStorage(Queue queue) async {
    await File('${AppDirs.QUEUES}${queue.date}.json').tryDeleting();
  }

  Future<void> _deleteQueuesFromStorage(List<int> queuesDates) async {
    await _deleteQueuesFromStorageIsolate.thready((AppDirs.QUEUES, queuesDates));
  }

  static void _deleteQueuesFromStorageIsolate((String, List<int>) pathAndDates) async {
    pathAndDates.$2.loop((date) {
      try {
        File('${pathAndDates.$1}$date.json').deleteSync();
      } catch (_) {}
    });
  }

  /// Used to add Queues that were rejected by [addNewQueue] after full loading of queues.
  final List<Queue> _queuesToAddAfterAllQueuesLoad = <Queue>[];
  bool _isLoadingQueues = true;
  bool get isLoadingQueues => _isLoadingQueues;
}
