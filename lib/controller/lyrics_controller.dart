/// copyright: google search request is originally from [@netlob](https://github.com/netlob/dart-lyrics), edited to fit Namida.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:lrc/lrc.dart';

import 'package:namida/base/ports_provider.dart';
import 'package:namida/class/http_response_wrapper.dart';
import 'package:namida/class/lyrics.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/lyrics_search_utils/lrc_search_details.dart';
import 'package:namida/controller/lyrics_search_utils/lrc_search_utils_base.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/wakelock_controller.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/packages/lyrics_lrc_parsed_view.dart';
import 'package:namida/youtube/class/youtube_id.dart';

class Lyrics {
  static Lyrics get inst => _instance;
  static final Lyrics _instance = Lyrics._internal();
  Lyrics._internal();

  final textScrollController = ScrollController(keepScrollOffset: true);

  GlobalKey<LyricsLRCParsedViewState>? lrcViewKey;
  final lrcViewKeyFullscreen = GlobalKey<LyricsLRCParsedViewState>();

  final currentLyricsText = ''.obs;
  final currentLyricsLRC = Rxn<Lrc>();
  final lyricsCanBeAvailable = true.obs;

  Playable? _currentItem;

  bool get _lyricsEnabled => settings.enableLyrics.value;
  bool get _canDisplayLRCForYoutubeID => settings.youtubeStyleMiniplayer.value == false;
  bool get _lyricsPrioritizeEmbedded => settings.prioritizeEmbeddedLyrics.value;
  LyricsSource get _lyricsSource => settings.lyricsSource.value;

  final _lrcSearchManager = _LRCSearchManager();

  void _updateWidgets(Lrc? lrc) {
    WakelockController.inst.updateLRCStatus(lrc != null);
    lrcViewKey?.currentState?.fillLists(lrc);
    lrcViewKeyFullscreen.currentState?.fillLists(lrc);
  }

  void resetLyrics() {
    _currentItem = null;
    currentLyricsText.value = '';
    currentLyricsLRC.value = null;
    _updateWidgets(null);
  }

  Future<void> updateLyrics(Playable item) async {
    resetLyrics();
    _currentItem = item;
    bool checkInterrupted() => _currentItem != item;

    try {
      textScrollController.jumpTo(0);
    } catch (_) {}
    lrcViewKey = GlobalKey<LyricsLRCParsedViewState>();

    lyricsCanBeAvailable.value = true;
    if (!_lyricsEnabled) return;
    if (item is YoutubeID && !_canDisplayLRCForYoutubeID) return;

    final LrcSearchUtils? lrcUtils = LrcSearchUtils.fromPlayable(item);

    if (lrcUtils == null) return;

    final embedded = lrcUtils.embeddedLyrics;
    if (_lyricsPrioritizeEmbedded && embedded != '') {
      final lrc = embedded.parseLRC();
      if (lrc != null && lrc.lyrics.isNotEmpty) {
        currentLyricsLRC.value = lrc;
        _updateWidgets(lrc);
      } else {
        currentLyricsText.value = embedded;
      }
      return;
    }

    /// 1. device lrc
    /// 2. cached lrc
    /// 3. track embedded lrc
    /// 4. database.
    final lrcLyrics = await _fetchLRCBasedLyrics(lrcUtils, embedded, _lyricsSource);

    if (checkInterrupted()) return;

    if (lrcLyrics.$1 != null) {
      currentLyricsLRC.value = lrcLyrics.$1;
      _updateWidgets(lrcLyrics.$1);
      return;
    } else if (lrcLyrics.$2 != null) {
      currentLyricsText.value = lrcLyrics.$2 ?? '';
      _updateWidgets(null);
      return;
    }

    if (checkInterrupted()) return;

    /// 1. cached txt lyrics
    /// 2. track embedded txt
    /// 3. google search
    final textLyrics = await _fetchTextBasedLyrics(lrcUtils, embedded, _lyricsSource);

    if (checkInterrupted()) return;

    if (textLyrics != '') {
      currentLyricsText.value = textLyrics;
    } else {
      lyricsCanBeAvailable.value = false;
    }
  }

  Future<List<LyricsModel>> searchLRCLyricsFromInternet({required LrcSearchUtils lrcUtils, String? customQuery}) async {
    final searchTries = lrcUtils.searchDetailsQueries();
    if (searchTries.isEmpty && (customQuery == null || customQuery == '')) return [];

    return await _lrcSearchManager.search(
      queries: searchTries,
      customQuery: customQuery,
    );
  }

  Future<(Lrc?, String?)> _fetchLRCBasedLyrics(LrcSearchUtils lrcUtils, String trackLyrics, LyricsSource source) async {
    String? lrcContent;

    /// 1. device lrc
    /// 2. cached lrc
    /// 3. track embedded
    if (source != LyricsSource.internet) {
      final lyricsFilesLocal = lrcUtils.deviceLRCFiles;
      for (final lf in lyricsFilesLocal) {
        if (await lf.existsAndValid()) {
          lrcContent = await lf.readAsString();
          break;
        }
      }
      if (lrcContent == null) {
        final syncedInCache = lrcUtils.cachedLRCFile;
        if (await syncedInCache.existsAndValid()) {
          lrcContent = await syncedInCache.readAsString();
        } else if (trackLyrics != '') {
          lrcContent = trackLyrics;
        }
      }
    }

    /// 4. if still null, fetch from database.
    if (source != LyricsSource.local && lrcContent == null) {
      final lyrics = await searchLRCLyricsFromInternet(lrcUtils: lrcUtils);
      final lyricsModelToUse = lyrics.firstOrNull;
      if (lyricsModelToUse != null && lyricsModelToUse.lyrics.isNotEmpty == true) {
        final parsedLrc = lyricsModelToUse.synced ? lyricsModelToUse.lyrics.parseLRC() : null;
        if (parsedLrc != null) {
          final syncedInCache = lrcUtils.cachedLRCFile;
          await syncedInCache.writeAsString(lyricsModelToUse.lyrics);
          return (parsedLrc, null);
        } else {
          final plainInCache = lrcUtils.cachedTxtFile;
          await plainInCache.writeAsString(lyricsModelToUse.lyrics);
          return (null, lyricsModelToUse.lyrics);
        }
      }
    }

    final lrc = lrcContent?.parseLRC();
    if (lrc != null && lrc.lyrics.isNotEmpty) {
      return (lrc, null);
    } else {
      return (null, lrcContent);
    }
  }

  Future<String> _fetchTextBasedLyrics(LrcSearchUtils lrcUtils, String trackLyrics, LyricsSource source) async {
    final lyricsFile = lrcUtils.cachedTxtFile;

    /// get from storage
    if (source != LyricsSource.internet && await lyricsFile.existsAndValid()) {
      return await lyricsFile.readAsString();
    } else if (source != LyricsSource.internet && trackLyrics != '') {
      return trackLyrics;
    }

    /// download lyrics
    else if (source != LyricsSource.local) {
      final lyrics = await _fetchLyricsGoogle(lrcUtils.searchQueriesGoogle());
      final regex = RegExp(r'<[^>]*>');
      if (lyrics != '') {
        final formattedText = lyrics.replaceAll(regex, '');
        await lyricsFile.writeAsString(formattedText);
        return formattedText;
      }
    }
    return '';
  }

  Future<String> _fetchLyricsGoogle(List<String> possibleQueries) async {
    if (possibleQueries.isEmpty) return '';
    return await _fetchLyricsGoogleIsolate.thready(possibleQueries);
  }

  static Future<String> _fetchLyricsGoogleIsolate(List<String> searches) async {
    const url = "https://www.google.com/search?client=safari&rls=en&ie=UTF-8&oe=UTF-8&q=";
    const delimiter1 = '</div></div></div></div><div class="hwc"><div class="BNeawe tAd8D AP7Wnd"><div><div class="BNeawe tAd8D AP7Wnd">';
    const delimiter2 = '</div></div></div></div></div><div><span class="hwc"><div class="BNeawe uEec3 AP7Wnd">';

    Future<String> requestQuery(String searchText) async {
      try {
        final res = await http.get(Uri.parse(Uri.encodeFull("$url$searchText"))).timeout(const Duration(seconds: 10));
        final body = res.body;
        final lyricsRes = body.substring(body.indexOf(delimiter1) + delimiter1.length, body.lastIndexOf(delimiter2));
        if (lyricsRes.contains('<meta charset="UTF-8">')) return '';
        if (lyricsRes.contains('please enable javascript on your web browser')) return '';
        if (lyricsRes.contains('Error 500 (Server Error)')) return '';
        if (lyricsRes.contains('systems have detected unusual traffic from your computer network')) return '';
        return lyricsRes;
      } catch (_) {
        return '';
      }
    }

    String lyrics = '';

    for (final q in searches) {
      lyrics = await requestQuery(q);
      if (lyrics != '') break;
    }

    // final List<String> split = lyrics.split('\n');
    // String result = '';
    // for (int i = 0; i < split.length; i++) {
    //   result = '$result${split[i]}\n';
    // }
    // return result.trim();
    return lyrics;
  }
}

class _LRCSearchManager with PortsProvider<SendPort> {
  _LRCSearchManager();

  Completer<List<LyricsModel>>? _completer;

  Future<List<LyricsModel>> search({
    required List<LRCSearchDetails> queries,
    String? customQuery,
  }) async {
    _completer?.completeIfWasnt([]);
    _completer = Completer<List<LyricsModel>>();

    await initialize();
    final p = customQuery != null && customQuery.isNotEmpty ? customQuery : queries;
    await sendPort(p);
    final res = await _completer?.future ?? [];
    _completer = null;
    return res;
  }

  @override
  void onResult(dynamic result) {
    _completer?.completeIfWasnt(result as List<LyricsModel>);
    _completer = null;
  }

  @override
  IsolateFunctionReturnBuild<SendPort> isolateFunction(SendPort port) {
    return IsolateFunctionReturnBuild(_prepareResourcesAndSearch, port);
  }

  static void _prepareResourcesAndSearch(SendPort sendPort) async {
    final recievePort = ReceivePort();
    sendPort.send(recievePort.sendPort);

    HttpClientWrapper? mainRequester;

    String substringArtist(String artist) {
      int maxIndex = -1;
      maxIndex = artist.indexOf('(');
      if (maxIndex <= 0) maxIndex = artist.indexOf('[');
      return maxIndex <= 0 ? artist : artist.substring(0, maxIndex);
    }

    Future<List<LyricsModel>> fetchLRCBasedLyricsFromInternet({
      LRCSearchDetails? details,
      String customQuery = '',
      required HttpClientWrapper requester,
    }) async {
      if (customQuery == '' && details == null) return [];
      String formatTime(int seconds) {
        final duration = Duration(seconds: seconds);
        final min = duration.inMinutes.remainder(60);
        final sec = duration.inSeconds.remainder(60);
        final ms = duration.inMilliseconds.remainder(1000);
        String pad(int n) => n.toString().padLeft(2, '0');
        final formattedTime = '${pad(min)}:${pad(sec)}.${pad(ms)}';
        return formattedTime;
      }

      String tail = '';
      if (customQuery != '') {
        tail = 'q=$customQuery';
      } else if (details != null) {
        final params = [
          if (details.title != '') 'track_name=${details.title}',
          if (details.artist != '') 'artist_name=${substringArtist(details.artist)}',
          if (details.album != '') 'album_name=${details.album}',
        ].join('&');
        tail = params;
      }

      if (tail != '') {
        final urlPre = "https://lrclib.net/api/search?$tail";
        final url = Uri.parse(Uri.encodeFull(urlPre));

        try {
          final response = await requester.getUrl(url);
          final responseBody = await utf8.decodeStream(response.asBroadcastStream());
          final fetched = <LyricsModel>[];
          final jsonLists = (jsonDecode(responseBody) as List<dynamic>?) ?? [];
          for (final jsonRes in jsonLists) {
            final syncedLyrics = jsonRes?["syncedLyrics"] as String? ?? '';
            final plain = jsonRes?["plainLyrics"] as String? ?? '';
            if (syncedLyrics != '') {
              // lrc
              final lines = <String>[];
              final artist = jsonRes['artistName'] ?? details?.artist ?? '';
              final album = jsonRes['albumName'] ?? details?.album ?? '';
              final title = jsonRes['trackName'] ?? details?.title ?? '';
              final dur = (jsonRes['duration'] as num?)?.toInt() ?? details?.durationSeconds ?? 0;

              if (artist != '') lines.add('[ar:$artist]');
              if (album != '') lines.add('[al:$album]');
              if (title != '') lines.add('[ti:$title]');
              if (dur > 0) lines.add('[length:${formatTime(dur)}]');
              for (final l in syncedLyrics.split('\n')) {
                lines.add(l);
              }
              final resultedLRC = lines.join('\n');
              fetched.add(LyricsModel(
                lyrics: resultedLRC,
                isInCache: false,
                fromInternet: true,
                synced: true,
                file: null,
                isEmbedded: false,
              ));
            } else if (plain != '') {
              // txt
              fetched.add(LyricsModel(
                lyrics: plain,
                isInCache: false,
                fromInternet: true,
                synced: false,
                file: null,
                isEmbedded: false,
              ));
            }
          }
          fetched.removeDuplicates();
          return fetched;
        } catch (_) {}
      }
      return [];
    }

    // -- start listening
    StreamSubscription? streamSub;
    streamSub = recievePort.listen((p) async {
      if (PortsProvider.isDisposeMessage(p)) {
        recievePort.close();
        streamSub?.cancel();
        return;
      }
      mainRequester?.close();
      mainRequester = HttpClientWrapper();
      final c = mainRequester!; // instance so it can be closed

      var lyrics = <LyricsModel>[];
      if (p is List<LRCSearchDetails>) {
        for (final details in p) {
          lyrics = await fetchLRCBasedLyricsFromInternet(
            details: details,
            requester: c,
          );
          if (lyrics.isNotEmpty) break;
        }
      } else if (p is String) {
        lyrics = await fetchLRCBasedLyricsFromInternet(
          details: null,
          customQuery: p,
          requester: c,
        );
      }
      sendPort.send(lyrics);
    });

    sendPort.send(null); // prepared
  }
}
