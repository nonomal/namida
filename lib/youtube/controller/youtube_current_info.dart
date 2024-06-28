part of 'youtube_info_controller.dart';

class _YoutubeCurrentInfoController {
  _YoutubeCurrentInfoController._();

  RelatedVideosRequestParams get _relatedVideosParams => const RelatedVideosRequestParams.allowAll(); // -- from settings
  bool get _canShowComments => settings.youtubeStyleMiniplayer.value;

  RxBaseCore<YoutiPieVideoPageResult?> get currentVideoPage => _currentVideoPage;
  RxBaseCore<YoutiPieCommentResult?> get currentComments => _currentComments;
  RxBaseCore<bool> get isLoadingInitialComments => _isLoadingInitialComments;
  RxBaseCore<bool> get isLoadingMoreComments => _isLoadingMoreComments;
  RxBaseCore<YoutiPieFeedResult?> get currentFeed => _currentFeed;

  /// Used to keep track of current comments sources, mainly to
  /// prevent fetching next comments when cached version is loaded.
  RxBaseCore<bool?> get isCurrentCommentsFromCache => _isCurrentCommentsFromCache;

  /// Used as a backup in case of no connection.
  final currentCachedQualities = <NamidaVideo>[].obs;

  final _currentVideoPage = Rxn<YoutiPieVideoPageResult>();
  final _currentRelatedVideos = Rxn<YoutiPieRelatedVideosResult>();
  final _currentComments = Rxn<YoutiPieCommentResult>();
  final currentYTStreams = Rxn<VideoStreamsResult>();
  final _isLoadingInitialComments = false.obs;
  final _isLoadingMoreComments = false.obs;
  final _isCurrentCommentsFromCache = Rxn<bool>();

  final _currentFeed = Rxn<YoutiPieFeedResult>();

  String? _initialCommentsContinuation;

  /// Checks if the requested id is still playing, since most functions are async and will often
  /// take time to fetch from internet, and user may have played other vids, this covers such cases.
  bool _canSafelyModifyMetadata(String id) => Player.inst.currentVideo?.id == id;

  void Function()? onVideoPageReset;

  void resetAll() {
    currentCachedQualities.clear();
    _currentVideoPage.value = null;
    _currentRelatedVideos.value = null;
    _currentComments.value = null;
    currentYTStreams.value = null;
    _isLoadingInitialComments.value = false;
    _isLoadingMoreComments.value = false;
    _isCurrentCommentsFromCache.value = null;
  }

  Future<void> prepareFeed() async {
    final val = await YoutiPie.feed.fetchFeed();
    if (val != null) _currentFeed.value = val;
  }

  bool updateVideoPageSync(String videoId) {
    final vidcache = YoutiPie.cacheBuilder.forVideoPage(videoId: videoId);
    final vidPageCached = vidcache.read();
    _currentVideoPage.value = vidPageCached;
    final relatedcache = YoutiPie.cacheBuilder.forRelatedVideos(videoId: videoId);
    _currentRelatedVideos.value = relatedcache.read() ?? vidPageCached?.relatedVideosResult;
    return vidPageCached != null;
  }

  bool updateCurrentCommentsSync(String videoId) {
    final commcache = YoutiPie.cacheBuilder.forComments(videoId: videoId);
    final comms = commcache.read();
    _currentComments.value = comms;
    if (_currentComments.value != null) _isCurrentCommentsFromCache.value = true;
    return comms != null;
  }

  Future<void> updateVideoPage(String videoId, {required bool forceRequestPage, required bool forceRequestComments, CommentsSortType? commentsSort}) async {
    if (!ConnectivityController.inst.hasConnection) {
      snackyy(
        title: lang.ERROR,
        message: lang.NO_NETWORK_AVAILABLE_TO_FETCH_VIDEO_PAGE,
        isError: true,
        top: false,
      );
      return;
    }

    if (forceRequestPage) {
      if (onVideoPageReset != null) onVideoPageReset!(); // jumps miniplayer to top
      _currentVideoPage.value = null;
    }
    if (forceRequestComments) {
      _currentComments.value = null;
      _initialCommentsContinuation = null;
    }

    commentsSort ??= YoutubeMiniplayerUiController.inst.currentCommentSort.value;

    final page = await YoutubeInfoController.video.fetchVideoPage(videoId, details: forceRequestPage ? ExecuteDetails.forceRequest() : null);

    if (_canSafelyModifyMetadata(videoId)) {
      _currentVideoPage.value = page;
      if (forceRequestComments) {
        final commentsContinuation = page?.commentResult.continuation;
        if (commentsContinuation != null && _canShowComments) {
          _isLoadingInitialComments.value = true;
          final comm = await YoutubeInfoController.comment.fetchComments(
            videoId: videoId,
            continuationToken: commentsContinuation,
            details: ExecuteDetails.forceRequest(),
          );
          if (identical(page, _currentVideoPage.value)) {
            _isLoadingInitialComments.value = false;
            _currentVideoPage.refresh();
            _currentComments.value = comm;
            _isCurrentCommentsFromCache.value = false;
            _initialCommentsContinuation = comm?.continuation;
          }
        }
      }
    }
  }

  /// specify [sortType] to force refresh. otherwise fetches next
  Future<void> updateCurrentComments(String videoId, {CommentsSortType? newSortType, bool initial = false}) async {
    final commentRes = _currentComments.value;
    if (commentRes == null) return;
    if (initial == false && commentRes.canFetchNext == false) return;

    if (initial == false && commentRes.canFetchNext && newSortType == null) {
      _isLoadingMoreComments.value = true;
      final didFetch = await commentRes.fetchNext();
      if (didFetch) _currentComments.refresh();
      _isLoadingMoreComments.value = false;
    } else {
      // -- fetch initial.
      _isLoadingInitialComments.value = true;
      final initialContinuation = newSortType == null ? _initialCommentsContinuation : commentRes.sorters[newSortType] ?? _initialCommentsContinuation;
      if (initialContinuation != null) {
        final newRes = await YoutubeInfoController.comment.fetchComments(
          videoId: videoId,
          continuationToken: initialContinuation,
          details: ExecuteDetails.forceRequest(),
        );
        if (newRes != null && _canSafelyModifyMetadata(videoId)) {
          _currentComments.value = newRes;
          _isCurrentCommentsFromCache.value = false;
        }
      }
      _isLoadingInitialComments.value = false;
    }
  }
}
