import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:namida/core/utils.dart';
import 'package:on_audio_query/on_audio_query.dart';

import 'package:namida/class/faudiomodel.dart';
import 'package:namida/class/folder.dart';
import 'package:namida/class/library_item_map.dart';
import 'package:namida/class/split_config.dart';
import 'package:namida/class/track.dart';
import 'package:namida/class/video.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/folders_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/search_sort_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/tagger_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/ui/widgets/library/track_tile.dart';

class Indexer {
  static Indexer get inst => _instance;
  static final Indexer _instance = Indexer._internal();
  Indexer._internal();

  bool get _defaultUseMediaStore => settings.useMediaStore.value;

  final isIndexing = false.obs;

  final allAudioFiles = <String>{}.obs;
  final filteredForSizeDurationTracks = 0.obs;
  final duplicatedTracksLength = 0.obs;
  final tracksExcludedByNoMedia = 0.obs;

  final artworksInStorage = 0.obs;
  final colorPalettesInStorage = 0.obs;
  final videosInStorage = 0.obs;

  final artworksSizeInStorage = 0.obs;
  final videosSizeInStorage = 0.obs;

  final mainMapAlbums = LibraryItemMap();
  final mainMapArtists = LibraryItemMap();
  final mainMapAlbumArtists = LibraryItemMap();
  final mainMapComposer = LibraryItemMap();
  final mainMapGenres = LibraryItemMap();
  final mainMapFolders = <Folder, List<Track>>{}.obs;

  final RxList<Track> tracksInfoList = <Track>[].obs;

  /// tracks map used for lookup
  final allTracksMappedByPath = <Track, TrackExtended>{}.obs;
  final trackStatsMap = <Track, TrackStats>{}.obs;

  var allFolderCovers = <String, String>{}; // {directoryPath, imagePath}
  var allTracksMappedByYTID = <String, List<Track>>{};

  /// Used to prevent duplicated track (by filename).
  final Map<String, bool> _currentFileNamesMap = {};

  late final _audioQuery = OnAudioQuery();

  List<Track> get recentlyAddedTracks {
    final alltracks = List<Track>.from(tracksInfoList.value);
    alltracks.sortByReverseAlt((e) => e.dateModified, (e) => e.dateAdded);
    return alltracks;
  }

  Map<String, (Track, int)> get backupMediaStoreIDS => _backupMediaStoreIDS;

  bool imageObtainedBefore(String imagePath) => _artworksMap[imagePath] != null || _artworksMapFullRes[imagePath] != null;

  /// {imagePath: (TrackExtended, id)};
  final _backupMediaStoreIDS = <String, (Track, int)>{};
  final artworksMap = <String, Uint8List?>{};
  final _artworksMap = <String, Completer<void>>{};
  final _artworksMapFullRes = <String, Completer<void>>{};
  Future<(File?, Uint8List?)> getArtwork({
    required String imagePath,
    bool checkFileFirst = true,
    required bool compressed,
    int? size,
  }) async {
    if (compressed && _artworksMap[imagePath] != null) {
      await _artworksMap[imagePath]!.future;
      return (null, artworksMap[imagePath]);
    }

    if (checkFileFirst && await File(imagePath).exists()) {
      return (File(imagePath), null);
    } else {
      final info = _backupMediaStoreIDS[imagePath];
      if (info != null) {
        final id = info.$2;
        Uint8List? artwork;
        if (compressed) {
          _artworksMap[imagePath] = Completer<Uint8List?>();

          artwork = await _audioQuery.queryArtwork(
            id,
            ArtworkType.AUDIO,
            format: ArtworkFormat.JPEG,
            quality: null,
            size: size?.clamp(48, 360) ?? 360,
          );
          artworksMap[imagePath] = artwork;
          _artworksMap[imagePath]!.completeIfWasnt();
          await _artworksMap[imagePath]?.future;
          return (null, artworksMap[imagePath]);
        } else {
          _artworksMapFullRes[imagePath] = Completer<void>();
          // -- try extracting full res using taggers
          File? file;
          final res = await FAudioTaggerController.inst.extractMetadata(trackPath: info.$1.path);
          file = res.tags.artwork.file;
          if (file == null) {
            artwork = await _audioQuery.queryArtwork(
              id,
              ArtworkType.AUDIO,
              format: ArtworkFormat.PNG,
              quality: 100,
              size: 720,
            );
            if (artwork != null) {
              final f = File(imagePath);
              await FileImage(f).evict();
              await f.writeAsBytes(artwork);
              file = f;
            }
          }

          _artworksMapFullRes[imagePath]!.completeIfWasnt(); // to notify that the process was done, but we dont store full res bytes
          await _artworksMapFullRes[imagePath]?.future;
          return (file, null);
        }
      }
    }

    return (null, null);
  }

  Future<void> prepareTracksFile() async {
    _fetchMediaStoreTracks(); // to fill ids map

    /// Only awaits if the track file exists, otherwise it will get into normally and start indexing.
    if (await File(AppPaths.TRACKS).existsAndValid()) {
      await readTrackData();
      _afterIndexing();
    }

    /// doesnt exists
    else {
      await File(AppPaths.TRACKS).create();
      refreshLibraryAndCheckForDiff(forceReIndex: true, useMediaStore: _defaultUseMediaStore);
    }
  }

  Future<void> refreshLibraryAndCheckForDiff({
    Set<String>? currentFiles,
    bool forceReIndex = false,
    bool? useMediaStore,
    bool allowDeletion = true,
    bool showFinishedSnackbar = true,
  }) async {
    if (isIndexing.value) {
      snackyy(title: lang.NOTE, message: lang.ANOTHER_PROCESS_IS_RUNNING);
      return;
    }

    isIndexing.value = true;
    useMediaStore ??= _defaultUseMediaStore;

    if (forceReIndex || tracksInfoList.isEmpty) {
      await _fetchAllSongsAndWriteToFile(
        audioFiles: {},
        deletedPaths: {},
        forceReIndex: true,
        useMediaStore: useMediaStore,
      );
    } else {
      currentFiles ??= await getAudioFiles();
      await _fetchAllSongsAndWriteToFile(
        audioFiles: getNewFoundPaths(currentFiles),
        deletedPaths: allowDeletion ? getDeletedPaths(currentFiles) : {},
        forceReIndex: false,
        useMediaStore: useMediaStore,
      );
    }

    _afterIndexing();
    isIndexing.value = false;
    if (showFinishedSnackbar) snackyy(title: lang.DONE, message: lang.FINISHED_UPDATING_LIBRARY);
  }

  /// Adds all tracks inside [tracksInfoList] to their respective album, artist, etc..
  /// & sorts all media.
  void _afterIndexing() {
    this.mainMapAlbums.clear();
    this.mainMapArtists.clear();
    this.mainMapAlbumArtists.clear();
    this.mainMapComposer.clear();
    this.mainMapGenres.clear();
    this.mainMapFolders.clear();

    final mainMapAlbums = this.mainMapAlbums.value;
    final mainMapArtists = this.mainMapArtists.value;
    final mainMapAlbumArtists = this.mainMapAlbumArtists.value;
    final mainMapComposer = this.mainMapComposer.value;
    final mainMapGenres = this.mainMapGenres.value;
    final mainMapFolders = this.mainMapFolders.value;

    // --- Sorting All Sublists ---
    tracksInfoList.loop((tr) {
      final trExt = tr.toTrackExt();

      // -- Assigning Albums
      mainMapAlbums.addForce(trExt.albumIdentifier, tr);

      // -- Assigning Artists
      trExt.artistsList.loop((artist) {
        mainMapArtists.addForce(artist, tr);
      });

      // -- Assigning Album Artist
      mainMapAlbumArtists.addForce(trExt.albumArtist, tr);

      // -- Assigning Composer
      mainMapComposer.addForce(trExt.composer, tr);

      // -- Assigning Genres
      trExt.genresList.loop((genre) {
        mainMapGenres.addForce(genre, tr);
      });

      // -- Assigning Folders
      mainMapFolders.addForce(tr.folder, tr);
    });

    this.mainMapAlbums.refresh();
    this.mainMapArtists.refresh();
    this.mainMapAlbumArtists.refresh();
    this.mainMapComposer.refresh();
    this.mainMapGenres.refresh();
    this.mainMapFolders.refresh();

    Folders.inst.onMapChanged(mainMapFolders);
    _sortAll();
    sortMediaTracksSubLists(MediaType.values);
  }

  void sortMediaTracksSubLists(List<MediaType> medias) {
    medias.loop((e) {
      final sorters = SearchSortController.inst.getMediaTracksSortingComparables(e);
      void sortPls(Iterable<List<Track>> trs, MediaType type) {
        final reverse = settings.mediaItemsTrackSortingReverse.value[type] ?? false;
        if (reverse) {
          for (final e in trs) {
            e.sortByReverseAlts(sorters);
          }
        } else {
          for (final e in trs) {
            e.sortByAlts(sorters);
          }
        }
      }

      switch (e) {
        case MediaType.album:
          sortPls(mainMapAlbums.value.values, MediaType.album);
          mainMapAlbums.refresh();
          break;
        case MediaType.artist:
          sortPls(mainMapArtists.value.values, MediaType.artist);
          mainMapArtists.refresh();
          break;
        case MediaType.albumArtist:
          sortPls(mainMapAlbumArtists.value.values, MediaType.albumArtist);
          mainMapAlbumArtists.refresh();
          break;
        case MediaType.composer:
          sortPls(mainMapComposer.value.values, MediaType.composer);
          mainMapComposer.refresh();
          break;
        case MediaType.genre:
          sortPls(mainMapGenres.value.values, MediaType.genre);
          mainMapGenres.refresh();
          break;
        case MediaType.folder:
          sortPls(mainMapFolders.values, MediaType.folder);
          mainMapFolders.refresh();
          break;
        default:
          null;
      }
    });
  }

  /// re-sorts media subtracks that depend on history.
  void sortMediaTracksSubListsAfterHistoryPrepared() {
    final requiredToSort = <MediaType>[];
    for (final e in settings.mediaItemsTrackSorting.entries) {
      if (e.value.contains(SortType.mostPlayed)) {
        requiredToSort.add(e.key);
      }
    }
    sortMediaTracksSubLists(requiredToSort);
  }

  void _sortAll() => SearchSortController.inst.sortAll();

  /// Removes Specific tracks from their corresponding media, useful when updating track metadata or reindexing a track.
  void _removeThisTrackFromAlbumGenreArtistEtc(Track tr) {
    final trExt = tr.toTrackExt();
    mainMapAlbums.value[trExt.albumIdentifier]?.remove(tr);

    trExt.artistsList.loop((artist) {
      mainMapArtists.value[artist]?.remove(tr);
    });
    mainMapAlbumArtists.value[trExt.albumArtist]?.remove(tr);
    mainMapComposer.value[trExt.composer]?.remove(tr);
    trExt.genresList.loop((genre) {
      mainMapGenres.value[genre]?.remove(tr);
    });
    mainMapFolders[tr.folder]?.remove(tr);

    _currentFileNamesMap.remove(tr.filename);
  }

  void _addTheseTracksToAlbumGenreArtistEtc(List<Track> tracks) {
    final mainMapAlbums = this.mainMapAlbums.value;
    final mainMapArtists = this.mainMapArtists.value;
    final mainMapAlbumArtists = this.mainMapAlbumArtists.value;
    final mainMapComposer = this.mainMapComposer.value;
    final mainMapGenres = this.mainMapGenres.value;
    final mainMapFolders = this.mainMapFolders.value;

    final List<String> addedAlbums = [];
    final List<String> addedArtists = [];
    final List<String> addedAlbumArtists = [];
    final List<String> addedComposers = [];
    final List<String> addedGenres = [];
    final List<Folder> addedFolders = [];

    tracks.loop((tr) {
      final trExt = tr.toTrackExt();

      // -- Assigning Albums
      mainMapAlbums.addNoDuplicatesForce(trExt.albumIdentifier, tr);

      // -- Assigning Artists
      trExt.artistsList.loop((artist) {
        mainMapArtists.addNoDuplicatesForce(artist, tr);
      });
      mainMapAlbumArtists.addNoDuplicatesForce(trExt.albumArtist, tr);
      mainMapComposer.addNoDuplicatesForce(trExt.composer, tr);

      // -- Assigning Genres
      trExt.genresList.loop((genre) {
        mainMapGenres.addNoDuplicatesForce(genre, tr);
      });

      // -- Assigning Folders
      mainMapFolders.addNoDuplicatesForce(tr.folder, tr);

      // --- Adding media that was affected
      addedAlbums.add(trExt.albumIdentifier);
      addedArtists.addAll(trExt.artistsList);
      addedAlbumArtists.add(trExt.albumArtist);
      addedComposers.add(trExt.composer);
      addedGenres.addAll(trExt.artistsList);
      addedFolders.add(tr.folder);
    });

    final albumSorters = SearchSortController.inst.getMediaTracksSortingComparables(MediaType.album);
    final artistSorters = SearchSortController.inst.getMediaTracksSortingComparables(MediaType.artist);
    final genreSorters = SearchSortController.inst.getMediaTracksSortingComparables(MediaType.genre);
    final folderSorters = SearchSortController.inst.getMediaTracksSortingComparables(MediaType.folder);

    void cleanyLoopy<T, E>(MediaType type, List<E> added, Map<E, List<T>> map, List<Comparable<dynamic> Function(T tr)> sorters) {
      if (added.isEmpty) return;
      added.removeDuplicates();
      if (added.isEmpty) return;

      final reverse = settings.mediaItemsTrackSortingReverse.value[type] ?? false;
      if (reverse) {
        added.loop((e) => map[e]?.sortByReverseAlts(sorters));
      } else {
        added.loop((e) => map[e]?.sortByAlts(sorters));
      }
    }

    cleanyLoopy(MediaType.album, addedAlbums, mainMapAlbums, albumSorters);
    cleanyLoopy(MediaType.artist, addedArtists, mainMapArtists, artistSorters);
    cleanyLoopy(MediaType.albumArtist, addedAlbumArtists, mainMapAlbumArtists, artistSorters);
    cleanyLoopy(MediaType.composer, addedComposers, mainMapComposer, artistSorters);
    cleanyLoopy(MediaType.genre, addedGenres, mainMapGenres, genreSorters);
    cleanyLoopy(MediaType.folder, addedFolders, mainMapFolders, folderSorters);

    Folders.inst.onMapChanged(mainMapFolders);
    _sortAll();
  }

  TrackExtended? _convertTagToTrack({
    required String trackPath,
    required FAudioModel trackInfo,
    required bool tryExtractingFromFilename,
    int minDur = 0,
    int minSize = 0,
    required TrackExtended? Function() onMinDurTrigger,
    required TrackExtended? Function() onMinSizeTrigger,
    required TrackExtended? Function(String err) onError,
  }) {
    // -- most methods dont throw, except for timeout
    try {
      // -- returns null early depending on size [byte] or duration [seconds]
      FileStat? fileStat;
      try {
        fileStat = File(trackPath).statSync();
        if (minSize > 0 && fileStat.size < minSize) {
          return onMinSizeTrigger();
        }
      } catch (_) {}

      late TrackExtended finalTrackExtended;

      if (trackInfo.hasError && !tryExtractingFromFilename) return null;

      final initialTrack = TrackExtended(
        title: UnknownTags.TITLE,
        originalArtist: UnknownTags.ARTIST,
        artistsList: [UnknownTags.ARTIST],
        album: UnknownTags.ALBUM,
        albumArtist: UnknownTags.ALBUMARTIST,
        originalGenre: UnknownTags.GENRE,
        genresList: [UnknownTags.GENRE],
        composer: UnknownTags.COMPOSER,
        originalMood: UnknownTags.MOOD,
        moodList: [UnknownTags.MOOD],
        trackNo: 0,
        duration: 0,
        year: 0,
        size: fileStat?.size ?? 0,
        dateAdded: fileStat?.creationDate.millisecondsSinceEpoch ?? 0,
        dateModified: fileStat?.modified.millisecondsSinceEpoch ?? 0,
        path: trackPath,
        comment: '',
        bitrate: 0,
        sampleRate: 0,
        format: '',
        channels: '',
        discNo: 0,
        language: '',
        lyrics: '',
      );
      if (!trackInfo.hasError) {
        int durationInSeconds = trackInfo.length ?? 0;
        if (minDur != 0 && durationInSeconds != 0 && durationInSeconds < minDur) {
          return onMinDurTrigger();
        }

        final tags = trackInfo.tags;

        // -- Split Artists
        final artists = splitArtist(
          title: tags.title,
          originalArtist: tags.artist,
          config: ArtistsSplitConfig.settings(),
        );

        // -- Split Genres
        final genres = splitGenre(
          tags.genre,
          config: GenresSplitConfig.settings(),
        );

        // -- Split Moods (using same genre splitters)
        final moods = splitGenre(
          tags.mood,
          config: GenresSplitConfig.settings(),
        );

        String? trimOrNull(String? value) => value == null ? value : value.trimAll();
        String? nullifyEmpty(String? value) => value == '' ? null : value;
        String? doMagic(String? value) => nullifyEmpty(trimOrNull(value));

        finalTrackExtended = initialTrack.copyWith(
          title: doMagic(tags.title),
          originalArtist: doMagic(tags.artist),
          artistsList: artists,
          album: doMagic(tags.album),
          albumArtist: doMagic(tags.albumArtist),
          originalGenre: doMagic(tags.genre),
          genresList: genres,
          originalMood: doMagic(tags.mood),
          moodList: moods,
          composer: doMagic(tags.composer),
          trackNo: trackInfo.tags.trackNumber.getIntValue(),
          duration: durationInSeconds,
          year: TrackExtended.enforceYearFormat(tags.year),
          comment: tags.comment,
          bitrate: trackInfo.bitRate,
          sampleRate: trackInfo.sampleRate,
          format: trackInfo.format,
          channels: trackInfo.channels,
          discNo: tags.discNumber.getIntValue(),
          language: tags.language,
          lyrics: tags.lyrics,
        );

        // ----- if the title || artist weren't found in the tag fields
        final isTitleEmpty = finalTrackExtended.title == UnknownTags.TITLE;
        final isArtistEmpty = finalTrackExtended.originalArtist == UnknownTags.ARTIST;
        if (isTitleEmpty || isArtistEmpty) {
          final extractedName = getTitleAndArtistFromFilename(trackPath.getFilenameWOExt);
          final newTitle = isTitleEmpty ? extractedName.$1 : null;
          final newArtists = isArtistEmpty ? [extractedName.$2] : null;
          finalTrackExtended = finalTrackExtended.copyWith(
            title: newTitle,
            originalArtist: newArtists?.first,
            artistsList: newArtists,
          );
        }
      } else {
        // --- Adding dummy track with info extracted from filename.
        final titleAndArtist = getTitleAndArtistFromFilename(trackPath.getFilenameWOExt);
        final title = titleAndArtist.$1;
        final artist = titleAndArtist.$2;
        finalTrackExtended = initialTrack.copyWith(
          title: title,
          originalArtist: artist,
          artistsList: [artist],
        );
      }

      return finalTrackExtended;
    } catch (e) {
      return onError(e.toString());
    }
  }

  Future<TrackExtended?> extractTrackInfo({
    required String trackPath,
    int minDur = 0,
    int minSize = 0,
    required TrackExtended? Function() onMinDurTrigger,
    required TrackExtended? Function() onMinSizeTrigger,
    bool deleteOldArtwork = false,
    bool checkForDuplicates = true,
    bool tryExtractingFromFilename = true,
  }) async {
    final res = await FAudioTaggerController.inst.extractMetadata(
      trackPath: trackPath,
      overrideArtwork: deleteOldArtwork,
    );
    if (res.hasError) return null;
    return _convertTagToTrack(
      trackPath: trackPath,
      trackInfo: res,
      tryExtractingFromFilename: tryExtractingFromFilename,
      minDur: minDur,
      minSize: minSize,
      onMinDurTrigger: onMinDurTrigger,
      onMinSizeTrigger: onMinSizeTrigger,
      onError: (_) => null,
    );
  }

  Future<void> extractTracksInfo({
    required List<String> tracksPath,
    int minDur = 0,
    int minSize = 0,
    required TrackExtended? Function() onMinDurTrigger,
    required TrackExtended? Function() onMinSizeTrigger,
    bool deleteOldArtwork = false,
    bool checkForDuplicates = true,
    bool tryExtractingFromFilename = true,
  }) async {
    TrackExtended? extractFunction(FAudioModel item) => _convertTagToTrack(
          trackPath: item.tags.path,
          trackInfo: item,
          tryExtractingFromFilename: tryExtractingFromFilename,
          minDur: minDur,
          minSize: minSize,
          onMinDurTrigger: onMinDurTrigger,
          onMinSizeTrigger: onMinSizeTrigger,
          onError: (_) => null,
        );

    final stream = await FAudioTaggerController.inst.extractMetadataAsStream(
      paths: tracksPath,
      overrideArtwork: deleteOldArtwork,
    );

    await for (final item in stream) {
      final trext = extractFunction(item);
      if (trext != null) _addTrackToLists(trext, checkForDuplicates, item.tags.artwork);
    }
  }

  void _addTrackToLists(TrackExtended trackExt, bool checkForDuplicates, FArtwork? artwork) {
    final tr = trackExt.toTrack();
    allTracksMappedByPath[tr] = trackExt;
    allTracksMappedByYTID.addForce(trackExt.youtubeID, tr);
    _currentFileNamesMap[trackExt.path.getFilename] = true;
    if (checkForDuplicates) {
      tracksInfoList.addNoDuplicates(tr);
      SearchSortController.inst.trackSearchList.addNoDuplicates(tr);
    } else {
      tracksInfoList.add(tr);
      SearchSortController.inst.trackSearchList.add(tr);
    }
    if (artwork != null && artwork.hasArtwork) {
      artworksInStorage.value++;
      if (artwork.size != null) artworksSizeInStorage.value += artwork.size!;
    }
  }

  Future<void> reindexTracks({
    required List<Track> tracks,
    bool updateArtwork = false,
    required void Function(bool didExtract) onProgress,
    required void Function(int tracksLength) onFinish,
    bool tryExtractingFromFilename = true,
  }) async {
    final tracksReal = <Track>[];
    final tracksRealPaths = <String>[];
    final tracksMissing = <Track>[];
    tracks.loop((tr) {
      bool exists = false;
      try {
        exists = File(tr.path).existsSync();
      } catch (_) {}
      if (exists) {
        tracksReal.add(tr);
        tracksRealPaths.add(tr.path);
      } else {
        tracksMissing.add(tr);
      }
    });

    if (updateArtwork) {
      imageCache.clear();
      imageCache.clearLiveImages();
      AudioService.evictArtworkCache();
    }

    tracksMissing.loop((e) => onProgress(false));

    final stream = await FAudioTaggerController.inst.extractMetadataAsStream(
      paths: tracksRealPaths,
      overrideArtwork: updateArtwork,
    );
    await for (final item in stream) {
      final path = item.tags.path;
      final trext = _convertTagToTrack(
        trackPath: path,
        trackInfo: item,
        tryExtractingFromFilename: tryExtractingFromFilename,
        onMinDurTrigger: () => null,
        onMinSizeTrigger: () => null,
        onError: (_) => null,
      );
      if (item.hasError) {
        onProgress(false);
      } else {
        final tr = Track(path);
        allTracksMappedByYTID.remove(tr.youtubeID);
        _currentFileNamesMap.remove(path.getFilename);
        _removeThisTrackFromAlbumGenreArtistEtc(tr);
        if (trext != null) _addTrackToLists(trext, true, item.tags.artwork);
        onProgress(true);
      }
    }

    final finalTrack = <Track>[];
    tracksReal.loop((p) {
      final tr = p.path.toTrackOrNull();
      if (tr != null) finalTrack.add(tr);
    });
    _addTheseTracksToAlbumGenreArtistEtc(finalTrack);
    Player.inst.refreshNotification();
    await _sortAndSaveTracks();
    onFinish(finalTrack.length);
  }

  Future<void> updateTrackMetadata({
    required Map<Track, TrackExtended> tracksMap,
    String newArtworkPath = '',
  }) async {
    final oldTracks = <Track>[];
    final newTracks = <Track>[];

    if (newArtworkPath != '') {
      imageCache.clear();
      imageCache.clearLiveImages();
      AudioService.evictArtworkCache();
    }

    for (final e in tracksMap.entries) {
      final ot = e.key;
      final nt = e.value.toTrack();
      oldTracks.add(ot);
      newTracks.add(nt);
      allTracksMappedByPath[ot] = e.value;
      allTracksMappedByYTID.addForce(e.value.youtubeID, ot);
      _currentFileNamesMap.remove(ot.filename);
      _currentFileNamesMap[nt.filename] = true;

      if (newArtworkPath != '') {
        // await extractTracksArtworks(
        //   [ot.path],
        //   forceReExtract: true,
        //   artworkPaths: {ot.path: newArtworkPath},
        //   albumIdendifiers: {ot.path: e.value.albumIdentifier},
        // );
        CurrentColor.inst.reExtractTrackColorPalette(track: ot, newNC: null, imagePath: ot.pathToImage);
      }
    }
    oldTracks.loop((tr) => _removeThisTrackFromAlbumGenreArtistEtc(tr));
    _addTheseTracksToAlbumGenreArtistEtc(newTracks);
    await _sortAndSaveTracks();
  }

  Future<List<Track>> convertPathToTrack(Iterable<String> tracksPathPre) async {
    final List<Track> finalTracks = <Track>[];
    final tracksToExtract = <String>[];

    final orderLookup = <String, int>{};
    int index = 0;
    for (final path in tracksPathPre) {
      final trInLib = path.toTrackOrNull();
      if (trInLib != null) {
        finalTracks.add(trInLib);
      } else {
        tracksToExtract.add(path);
      }
      orderLookup[path] = index;
      index++;
    }

    if (tracksToExtract.isNotEmpty) {
      TrackExtended? extractFunction(FAudioModel item) => _convertTagToTrack(
            trackPath: item.tags.path,
            trackInfo: item,
            tryExtractingFromFilename: true,
            onMinDurTrigger: () => null,
            onMinSizeTrigger: () => null,
            onError: (_) => null,
          );

      final stream = await FAudioTaggerController.inst.extractMetadataAsStream(paths: tracksToExtract);
      await for (final item in stream) {
        finalTracks.add(Track(item.tags.path));
        final trext = extractFunction(item);
        if (trext != null) _addTrackToLists(trext, true, item.tags.artwork);
      }
    }

    _addTheseTracksToAlbumGenreArtistEtc(finalTracks);
    await _sortAndSaveTracks();

    finalTracks.sortBy((e) => orderLookup[e.path] ?? 0);
    return finalTracks;
  }

  Future<void> _sortAndSaveTracks() async {
    Player.inst.refreshRxVariables();
    Player.inst.refreshNotification();
    SearchSortController.inst.searchAll(ScrollSearchController.inst.searchTextEditingController.text);
    SearchSortController.inst.sortMedia(MediaType.track);
    await _saveTrackFileToStorage();
    await _createDefaultNamidaArtwork();
  }

  void _clearLists() {
    artworksInStorage.value = 0;
    artworksSizeInStorage.value = 0;
    tracksInfoList.clear();
    allTracksMappedByPath.clear();
    allTracksMappedByYTID.clear();
    _currentFileNamesMap.clear();
    SearchSortController.inst.sortMedia(MediaType.track);
  }

  void _resetCounters() {
    filteredForSizeDurationTracks.value = 0;
    duplicatedTracksLength.value = 0;
    tracksExcludedByNoMedia.value = 0;
  }

  /// Removes [deletedPaths] and fetches [audioFiles].
  ///
  /// [bypassAllChecks] will bypass `duration`, `size` & similar filenames checks.
  ///
  /// Setting [forceReIndex] to `true` will require u to call [_afterIndexing],
  /// otherwise use [_addTheseTracksToAlbumGenreArtistEtc] with changed tracks only.
  Future<void> _fetchAllSongsAndWriteToFile({
    required Set<String> audioFiles,
    required Set<String> deletedPaths,
    required bool forceReIndex,
    required bool useMediaStore,
  }) async {
    _resetCounters();

    if (forceReIndex) {
      _clearLists();
      if (!useMediaStore) audioFiles = await getAudioFiles();
    }

    printy("Audio Files New: ${audioFiles.length}");
    printy("Audio Files Deleted: ${deletedPaths.length}");

    if (deletedPaths.isNotEmpty) {
      tracksInfoList.removeWhere((tr) => deletedPaths.contains(tr.path));
    }

    final minDur = settings.indexMinDurationInSec.value; // Seconds
    final minSize = settings.indexMinFileSizeInB.value; // bytes
    final prevDuplicated = settings.preventDuplicatedTracks.value;
    if (useMediaStore) {
      final trs = await _fetchMediaStoreTracks();
      tracksInfoList.clear();
      allTracksMappedByPath.clear();
      allTracksMappedByYTID.clear();
      _currentFileNamesMap.clear();
      trs.loop((e) => _addTrackToLists(e.$1, false, null));
    } else {
      FAudioTaggerController.inst.currentPathsBeingExtracted.clear();
      final audioFilesWithoutDuplicates = <String>[];
      if (prevDuplicated) {
        /// skip duplicated tracks according to filename
        for (final trackPath in audioFiles) {
          if (_currentFileNamesMap.keyExists(trackPath.getFilename)) {
            duplicatedTracksLength.value++;
          } else {
            audioFilesWithoutDuplicates.add(trackPath);
          }
        }
      }

      final finalAudios = prevDuplicated ? audioFilesWithoutDuplicates : audioFiles.toList();
      final listParts = (Platform.numberOfProcessors ~/ 2).withMinimum(1);
      final audioFilesParts = finalAudios.split(listParts);
      final audioFilesCompleters = List.generate(audioFilesParts.length, (_) => Completer<void>());

      Future<void> extractFunction(List<String> chunkList) async {
        if (chunkList.isEmpty) return;
        await extractTracksInfo(
          tracksPath: chunkList,
          minDur: minDur,
          minSize: minSize,
          onMinDurTrigger: () {
            filteredForSizeDurationTracks.value++;
            return null;
          },
          onMinSizeTrigger: () {
            filteredForSizeDurationTracks.value++;
            return null;
          },
          checkForDuplicates: false,
        );
      }

      audioFilesParts.loopAdv((part, partIndex) {
        extractFunction(part).then((value) => audioFilesCompleters[partIndex].complete());
      });
      await Future.wait(audioFilesCompleters.map((e) => e.future).toList());
    }

    /// doing some checks to remove unqualified tracks.
    /// removes tracks after changing `duration` or `size`.
    tracksInfoList.removeWhere((tr) => (tr.duration != 0 && tr.duration < minDur) || tr.size < minSize);

    /// removes duplicated tracks after a refresh
    if (prevDuplicated) {
      final removedNumber = tracksInfoList.removeDuplicates((element) => element.filename);
      duplicatedTracksLength.value = removedNumber;
    }

    printy("FINAL: ${tracksInfoList.length}");

    await _sortAndSaveTracks();
  }

  Future<void> _saveTrackFileToStorage() async {
    TrackTileManager.onTrackItemPropChange();
    await File(AppPaths.TRACKS).writeAsJson(tracksInfoList.value.map((key) => allTracksMappedByPath[key]?.toJson()).toList());
  }

  Future<void> updateTrackDuration(Track track, Duration? dur) async {
    final durInSeconds = dur?.inSeconds ?? 0;
    if (durInSeconds > 0 && track.duration != durInSeconds) {
      track.duration = durInSeconds;
      await _saveTrackFileToStorage();
    }
  }

  /// Returns new [TrackStats].
  Future<TrackStats> updateTrackStats(
    Track track, {
    int? rating,
    List<String>? tags,
    List<String>? moods,
    int? lastPositionInMs,
  }) async {
    rating ??= track.stats.rating;
    tags ??= track.stats.tags;
    moods ??= track.stats.moods;
    lastPositionInMs ??= track.stats.lastPositionInMs;
    final newStats = TrackStats(track, rating.clamp(0, 100), tags, moods, lastPositionInMs);
    trackStatsMap[track] = newStats;

    await _saveTrackStatsFileToStorage();
    return newStats;
  }

  Future<void> _saveTrackStatsFileToStorage() async {
    TrackTileManager.onTrackItemPropChange();
    await File(AppPaths.TRACKS_STATS).writeAsJson(trackStatsMap.values.map((e) => e.toJson()).toList());
  }

  Future<void> readTrackData() async {
    // reading stats file containing track rating etc.
    final statsResult = await _readTracksStatsCompute.thready(AppPaths.TRACKS_STATS);
    trackStatsMap.value = statsResult;

    tracksInfoList.clear(); // clearing for cases which refreshing library is required (like after changing separators)

    /// Reading actual track file.
    final splitconfig = _SplitArtistGenreConfig(
      path: AppPaths.TRACKS,
      artistsConfig: ArtistsSplitConfig.settings(),
      genresConfig: GenresSplitConfig.settings(),
    );
    final tracksResult = await _readTracksFileCompute.thready(splitconfig);
    allTracksMappedByPath.value = tracksResult.$1;
    allTracksMappedByYTID = tracksResult.$2;
    tracksInfoList.value = tracksResult.$3;

    printy("All Tracks Length From File: ${tracksInfoList.length}");
  }

  static Future<Map<Track, TrackStats>> _readTracksStatsCompute(String path) async {
    final map = <Track, TrackStats>{};
    final list = File(path).readAsJsonSync() as List?;
    if (list != null) {
      for (int i = 0; i < list.length; i++) {
        try {
          final item = list[i];
          final trst = TrackStats.fromJson(item);
          map[trst.track] = trst;
        } catch (e) {
          continue;
        }
      }
    }
    return map;
  }

  static (Map<Track, TrackExtended>, Map<String, List<Track>>, List<Track>) _readTracksFileCompute(_SplitArtistGenreConfig config) {
    final map = <Track, TrackExtended>{};
    final idsMap = <String, List<Track>>{};
    final allTracks = <Track>[];
    final list = File(config.path).readAsJsonSync() as List?;
    if (list != null) {
      for (int i = 0; i < list.length; i++) {
        try {
          final item = list[i];
          final trExt = TrackExtended.fromJson(
            item,
            artistsSplitConfig: config.artistsConfig,
            genresSplitConfig: config.genresConfig,
          );
          final track = trExt.toTrack();
          map[track] = trExt;
          allTracks.add(track);
          idsMap.addForce(trExt.youtubeID, track);
        } catch (e) {
          continue;
        }
      }
    }
    return (map, idsMap, allTracks);
  }

  /// [addArtistsFromTitle] extracts feat artists.
  /// Defaults to [settings.extractFeatArtistFromTitle]
  static List<String> splitArtist({
    required String? title,
    required String? originalArtist,
    required ArtistsSplitConfig config,
  }) {
    final allArtists = <String>[];

    final artistsOrg = config.splitText(originalArtist, fallback: UnknownTags.ARTIST);
    allArtists.addAll(artistsOrg);

    if (config.addFeatArtist) {
      final List<String>? moreArtists = title?.split(RegExp(r'\(ft\. |\[ft\. |\(feat\. |\[feat\. \]', caseSensitive: false));
      if (moreArtists != null && moreArtists.length > 1) {
        final extractedFeatArtists = moreArtists[1].split(RegExp(r'\)|\]')).first;
        allArtists.addAll(
          config.splitText(extractedFeatArtists, fallback: ''),
        );
      }
    }
    return allArtists;
  }

  static List<String> splitGenre(
    String? originalGenre, {
    required GenresSplitConfig config,
  }) {
    return config.splitText(
      originalGenre,
      fallback: UnknownTags.GENRE,
    );
  }

  /// (title, artist)
  static (String, String) getTitleAndArtistFromFilename(String filename) {
    final filenameWOEx = filename.replaceAll('_', ' ');
    final titleAndArtist = <String>[];

    /// preferring to split by [' - '], since there are artists that has '-' in their name.
    titleAndArtist.addAll(filenameWOEx.split(' - '));
    if (titleAndArtist.length == 1) {
      titleAndArtist.addAll(filenameWOEx.split('-'));
    }

    /// in case splitting produced 2 entries or more, it means its high likely to be [artist - title]
    /// otherwise [title] will be the [filename] and [artist] will be [Unknown]
    final title = titleAndArtist.length >= 2 ? titleAndArtist[1].trimAll() : filenameWOEx;
    final artist = titleAndArtist.length >= 2 ? titleAndArtist[0].trimAll() : UnknownTags.ARTIST;

    // TODO: split by ( and ) too, but retain Remixes and feat.
    final cleanedUpTitle = title.splitFirst('[').trimAll();
    final cleanedUpArtist = artist.splitLast(']').trimAll();

    return (cleanedUpTitle, cleanedUpArtist);
  }

  Set<String> getNewFoundPaths(Set<String> currentFiles) => currentFiles.difference(Set.of(tracksInfoList.value.map((t) => t.path)));
  Set<String> getDeletedPaths(Set<String> currentFiles) => Set.of(tracksInfoList.value.map((t) => t.path)).difference(currentFiles);

  /// [strictNoMedia] forces all subdirectories to follow the same result of the parent.
  ///
  /// ex: if (.nomedia) was found in [/storage/0/Music/],
  /// then subdirectories [/storage/0/Music/folder1/], [/storage/0/Music/folder2/] & [/storage/0/Music/folder2/subfolder/] will be excluded too.
  Future<Set<String>> getAudioFiles({bool strictNoMedia = true}) async {
    tracksExcludedByNoMedia.value = 0;
    final allAvailableDirectories = await getAvailableDirectories(forceReCheck: true, strictNoMedia: strictNoMedia);

    final parameters = {
      'allAvailableDirectories': allAvailableDirectories,
      'directoriesToExclude': settings.directoriesToExclude.value,
      'extensions': kAudioFileExtensions,
      'imageExtensions': kImageFilesExtensions,
    };

    final mapResult = await getFilesTypeIsolate.thready(parameters);

    final allPaths = mapResult['allPaths'] as Set<String>;
    final excludedByNoMedia = mapResult['pathsExcludedByNoMedia'] as Set<String>;
    final folderCovers = mapResult['folderCovers'] as Map<String, String>;

    tracksExcludedByNoMedia.value += excludedByNoMedia.length;

    // ignore: invalid_use_of_protected_member
    allAudioFiles.value = allPaths;

    allFolderCovers = folderCovers;

    printy("Paths Found: ${allPaths.length}");
    return allPaths;
  }

  Completer<Map<Directory, bool>>? _lastAvailableDirectories;
  Future<Map<Directory, bool>> getAvailableDirectories({bool forceReCheck = true, bool strictNoMedia = true}) async {
    if (forceReCheck == false && _lastAvailableDirectories != null) {
      return await _lastAvailableDirectories!.future;
    }

    _lastAvailableDirectories = null; // for when forceReCheck enabled.
    _lastAvailableDirectories = Completer<Map<Directory, bool>>();
    final parameters = {
      'directoriesToScan': settings.directoriesToScan.value,
      'respectNoMedia': settings.respectNoMedia.value,
      'strictNoMedia': strictNoMedia, // TODO: expose [strictNoMedia] in settings?
    };
    final dirs = await _getAvailableDirectoriesIsolate.thready(parameters);
    _lastAvailableDirectories?.completeIfWasnt(dirs);
    return dirs;
  }

  static Map<Directory, bool> _getAvailableDirectoriesIsolate(Map parameters) {
    final directoriesToScan = parameters['directoriesToScan'] as List<String>;
    final respectNoMedia = parameters['respectNoMedia'] as bool;
    final strictNoMedia = parameters['strictNoMedia'] as bool;

    final allAvailableDirectories = <Directory, bool>{};

    for (final dirPath in directoriesToScan) {
      final directory = Directory(dirPath);

      if (directory.existsSync()) {
        allAvailableDirectories[directory] = false;
        for (final file in directory.listSyncSafe(recursive: true, followLinks: true)) {
          if (file is Directory) {
            allAvailableDirectories[file] = false;
          }
        }
      }
    }

    /// Assigning directories and sub-subdirectories that has .nomedia.
    if (respectNoMedia) {
      for (final d in allAvailableDirectories.keys) {
        final hasNoMedia = File("${d.path}/.nomedia").existsSync();
        if (hasNoMedia) {
          if (strictNoMedia) {
            // strictly applies bool to all subdirectories.
            allAvailableDirectories.forEach((key, value) {
              if (key.path.startsWith(d.path)) {
                allAvailableDirectories[key] = true;
              }
            });
          } else {
            allAvailableDirectories[d] = true;
          }
        }
      }
    }
    return allAvailableDirectories;
  }

  Future<List<(TrackExtended, int)>> _fetchMediaStoreTracks() async {
    final allMusic = await _audioQuery.querySongs();
    // -- folders selected will be ignored when [settings.useMediaStore.value] is enabled.
    allMusic.retainWhere((element) =>
        settings.directoriesToExclude.value.every((dir) => !element.data.startsWith(dir)) /* && settings.directoriesToScan.any((dir) => element.data.startsWith(dir)) */);
    final tracks = <(TrackExtended, int)>[];
    final artistsSplitConfig = ArtistsSplitConfig.settings();
    final genresSplitConfig = GenresSplitConfig.settings();
    allMusic.loop((e) {
      final map = e.getMap;
      final artist = e.artist;
      final artists = artist == null
          ? <String>[]
          : Indexer.splitArtist(
              title: e.title,
              originalArtist: artist,
              config: artistsSplitConfig,
            );
      final genre = e.genre;
      final genres = genre == null
          ? <String>[]
          : Indexer.splitGenre(
              genre,
              config: genresSplitConfig,
            );
      final mood = map['mood'];
      final moods = mood == null
          ? <String>[]
          : Indexer.splitGenre(
              mood,
              config: genresSplitConfig,
            );
      final bitrate = map['bitrate'] as int?;
      final disc = map['disc_number'] as int?;
      final yearString = map['year'] as String?;
      final trext = TrackExtended(
        title: e.title,
        originalArtist: e.artist ?? UnknownTags.ARTIST,
        artistsList: artists,
        album: e.album ?? UnknownTags.ALBUM,
        albumArtist: map['album_artist'] ?? UnknownTags.ALBUMARTIST,
        originalGenre: e.genre ?? UnknownTags.GENRE,
        genresList: genres,
        originalMood: mood ?? '',
        moodList: moods,
        composer: e.composer ?? '',
        trackNo: e.track ?? 0,
        duration: e.duration == null ? 0 : e.duration! ~/ 1000,
        year: TrackExtended.enforceYearFormat(yearString) ?? 0,
        size: e.size,
        dateAdded: e.dateAdded ?? 0,
        dateModified: e.dateModified ?? 0,
        path: e.data,
        comment: '',
        bitrate: bitrate == null ? 0 : bitrate ~/ 1000,
        sampleRate: 0,
        format: '',
        channels: '',
        discNo: disc ?? 0,
        language: '',
        lyrics: '',
      );
      tracks.add((trext, e.id));
      _backupMediaStoreIDS[trext.pathToImage] = (trext.toTrack(), e.id);
    });
    return tracks;
  }

  void updateImageSizesInStorage({required int removedCount, required int removedSize}) {
    artworksInStorage.value -= removedCount;
    artworksSizeInStorage.value -= removedSize;
  }

  Future<void> calculateAllImageSizesInStorage() async {
    final stats = await updateImageSizeInStorageIsolate.thready({
      "dirPath": AppDirs.ARTWORKS,
      "token": RootIsolateToken.instance,
    });
    artworksInStorage.value = stats.$1;
    artworksSizeInStorage.value = stats.$2;
  }

  static (int, int) updateImageSizeInStorageIsolate(Map p) {
    final dirPath = p["dirPath"] as String;
    final token = p["token"] as RootIsolateToken;
    BackgroundIsolateBinaryMessenger.ensureInitialized(token);

    int totalCount = 0;
    int totalSize = 0;
    final dir = Directory(dirPath);

    for (final f in dir.listSyncSafe()) {
      try {
        totalSize += (f as File).lengthSync();
        totalCount++;
      } catch (_) {}
    }

    return (totalCount, totalSize);
  }

  Future<void> updateColorPalettesSizeInStorage({String? newPalettePath}) async {
    if (newPalettePath != null) {
      colorPalettesInStorage.value++;
      return;
    }
    await _updateDirectoryStats(AppDirs.PALETTES, colorPalettesInStorage, null);
  }

  Future<void> updateVideosSizeInStorage() async {
    await _updateDirectoryStats(AppDirs.VIDEOS_CACHE, videosInStorage, videosSizeInStorage);
  }

  Future<void> _updateDirectoryStats(String dirPath, Rx<int>? filesCountVariable, Rx<int>? filesSizeVariable) async {
    // resets values
    filesCountVariable?.value = 0;
    filesSizeVariable?.value = 0;

    final dir = Directory(dirPath);

    await for (final f in dir.list()) {
      if (f is File) {
        filesCountVariable?.value++;
        final st = await f.stat();
        filesSizeVariable?.value += st.size;
      }
    }
  }

  Future<void> clearImageCache() async {
    await Directory(AppDirs.ARTWORKS).delete(recursive: true);
    await Directory(AppDirs.ARTWORKS).create();
    await _createDefaultNamidaArtwork();
    calculateAllImageSizesInStorage();
  }

  /// Deletes specific videos or the whole cache.
  Future<void> clearVideoCache([List<NamidaVideo>? videosToDelete]) async {
    if (videosToDelete != null) {
      for (final v in videosToDelete) {
        final deleted = await File(v.path).tryDeleting();
        if (deleted) {
          videosInStorage.value--;
          videosSizeInStorage.value -= v.sizeInBytes;
        }
      }
    } else {
      await Directory(AppDirs.VIDEOS_CACHE).delete(recursive: true);
      await Directory(AppDirs.VIDEOS_CACHE).create();
      videosInStorage.value = 0;
      videosSizeInStorage.value = 0;
    }
  }

  Future<void> _createDefaultNamidaArtwork() async {
    if (!await File(AppPaths.NAMIDA_LOGO).exists()) {
      final byteData = await rootBundle.load('assets/namida_icon.png');
      final file = await File(AppPaths.NAMIDA_LOGO).create(recursive: true);
      await file.writeAsBytes(byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
    }
  }
}

class _SplitArtistGenreConfig {
  final String path;
  final ArtistsSplitConfig artistsConfig;
  final GenresSplitConfig genresConfig;

  const _SplitArtistGenreConfig({
    required this.path,
    required this.artistsConfig,
    required this.genresConfig,
  });
}
