import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import 'package:namida/base/pull_to_refresh.dart';
import 'package:namida/class/route.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/queue_controller.dart';
import 'package:namida/controller/scroll_search_controller.dart';
import 'package:namida/controller/search_sort_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/dialogs/common_dialogs.dart';
import 'package:namida/ui/pages/queues_page.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/expandable_box.dart';
import 'package:namida/ui/widgets/library/multi_artwork_card.dart';
import 'package:namida/ui/widgets/library/playlist_tile.dart';
import 'package:namida/ui/widgets/sort_by_button.dart';

/// By Default, sending tracks to add (i.e: addToPlaylistDialog) will:
/// 1. Hide Default Playlists.
/// 2. Hide Grid Widget.
/// 3. Disable bottom padding.
/// 4. Disable Scroll Controller.
class PlaylistsPage extends StatefulWidget with NamidaRouteWidget {
  @override
  RouteType get route => RouteType.PAGE_playlists;

  final List<Track>? tracksToAdd;
  final int countPerRow;
  final bool animateTiles;
  final bool enableHero;

  const PlaylistsPage({
    super.key,
    this.tracksToAdd,
    required this.countPerRow,
    this.animateTiles = true,
    required this.enableHero,
  });

  @override
  State<PlaylistsPage> createState() => _PlaylistsPageState();
}

class _PlaylistsPageState extends State<PlaylistsPage> with TickerProviderStateMixin, PullToRefreshMixin {
  bool get _shouldAnimate => widget.animateTiles && LibraryTab.playlists.shouldAnimateTiles;

  @override
  Widget build(BuildContext context) {
    final tracksToAdd = widget.tracksToAdd;
    final isInsideDialog = tracksToAdd != null;
    final scrollController = isInsideDialog ? null : LibraryTab.playlists.scrollController;
    final defaultCardHorizontalPadding = context.width * 0.045;
    final defaultCardHorizontalPaddingCenter = context.width * 0.035;
    final cardDimensions = Dimensions.inst.getMultiCardDimensions(widget.countPerRow);

    return BackgroundWrapper(
      child: Listener(
        onPointerMove: (event) {
          final c = scrollController;
          if (c != null) onPointerMove(c, event);
        },
        onPointerUp: (event) async {
          onRefresh(() async {
            await PlaylistController.inst.prepareM3UPlaylists();
            PlaylistController.inst.sortPlaylists();
          });
        },
        onPointerCancel: (event) => onVerticalDragFinish(),
        child: NamidaScrollbar(
          controller: scrollController,
          child: AnimationLimiter(
            child: Column(
              children: [
                Obx(
                  () => ExpandableBox(
                    enableHero: widget.enableHero,
                    gridWidget: isInsideDialog
                        ? null
                        : ChangeGridCountWidget(
                            currentCount: settings.playlistGridCount.valueR,
                            onTap: () {
                              final newCount = ScrollSearchController.inst.animateChangingGridSize(LibraryTab.playlists, widget.countPerRow);
                              settings.save(playlistGridCount: newCount);
                            },
                          ),
                    isBarVisible: LibraryTab.playlists.isBarVisible.valueR,
                    showSearchBox: LibraryTab.playlists.isSearchBoxVisible.valueR,
                    leftText: SearchSortController.inst.playlistSearchList.length.displayPlaylistKeyword,
                    onFilterIconTap: () => ScrollSearchController.inst.switchSearchBoxVisibilty(LibraryTab.playlists),
                    onCloseButtonPressed: () => ScrollSearchController.inst.clearSearchTextField(LibraryTab.playlists),
                    sortByMenuWidget: SortByMenu(
                      title: settings.playlistSort.valueR.toText(),
                      popupMenuChild: () => const SortByMenuPlaylist(),
                      isCurrentlyReversed: settings.playlistSortReversed.valueR,
                      onReverseIconTap: () => SearchSortController.inst.sortMedia(MediaType.playlist, reverse: !settings.playlistSortReversed.value),
                    ),
                    textField: () => CustomTextFiled(
                      textFieldController: LibraryTab.playlists.textSearchController,
                      textFieldHintText: lang.FILTER_PLAYLISTS,
                      onTextFieldValueChanged: (value) => SearchSortController.inst.searchMedia(value, MediaType.playlist),
                    ),
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      Obx(
                        () => CustomScrollView(
                          controller: scrollController,
                          slivers: [
                            if (!isInsideDialog)
                              SliverToBoxAdapter(
                                child: NamidaHero(
                                  tag: 'PlaylistPage_TopRow',
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.start,
                                      children: [
                                        const SizedBox(width: 12.0),
                                        Text(
                                          PlaylistController.inst.playlistsMap.length.displayPlaylistKeyword,
                                          style: context.textTheme.displayLarge,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(width: 12.0),
                                        const Expanded(
                                          child: GeneratePlaylistButton(),
                                        ),
                                        const SizedBox(width: 8.0),
                                        const Expanded(
                                          child: CreatePlaylistButton(),
                                        ),
                                        const SizedBox(width: 8.0),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            const SliverPadding(padding: EdgeInsets.only(top: 6.0)),

                            /// Default Playlists.
                            if (!isInsideDialog)
                              SliverToBoxAdapter(
                                child: SizedBox(
                                  width: context.width,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(height: defaultCardHorizontalPadding * 0.5),
                                      Row(
                                        children: [
                                          SizedBox(width: defaultCardHorizontalPadding),
                                          Expanded(
                                            child: NamidaHero(
                                              tag: 'DPC_history',
                                              child: ObxO(
                                                rx: HistoryController.inst.totalHistoryItemsCount,
                                                builder: (count) => DefaultPlaylistCard(
                                                  colorScheme: Colors.grey,
                                                  icon: Broken.refresh,
                                                  title: lang.HISTORY,
                                                  displayLoadingIndicator: count == -1,
                                                  text: count.formatDecimal(),
                                                  onTap: NamidaOnTaps.inst.onHistoryPlaylistTap,
                                                ),
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: defaultCardHorizontalPaddingCenter),
                                          Expanded(
                                            child: NamidaHero(
                                              tag: 'DPC_mostplayed',
                                              child: Obx(
                                                () => DefaultPlaylistCard(
                                                  colorScheme: Colors.green,
                                                  icon: Broken.award,
                                                  title: lang.MOST_PLAYED,
                                                  displayLoadingIndicator: HistoryController.inst.isLoadingHistoryR,
                                                  text: HistoryController.inst.topTracksMapListens.length.formatDecimal(),
                                                  onTap: () => NamidaOnTaps.inst.onMostPlayedPlaylistTap(),
                                                ),
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: defaultCardHorizontalPadding),
                                        ],
                                      ),
                                      SizedBox(height: defaultCardHorizontalPaddingCenter),
                                      Row(
                                        children: [
                                          SizedBox(width: defaultCardHorizontalPadding),
                                          Expanded(
                                            child: NamidaHero(
                                              tag: 'DPC_favs',
                                              child: Obx(
                                                () => DefaultPlaylistCard(
                                                  colorScheme: Colors.red,
                                                  icon: Broken.heart,
                                                  title: lang.FAVOURITES,
                                                  text: PlaylistController.inst.favouritesPlaylist.valueR.tracks.length.formatDecimal(),
                                                  onTap: () => NamidaOnTaps.inst.onNormalPlaylistTap(k_PLAYLIST_NAME_FAV),
                                                ),
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: defaultCardHorizontalPaddingCenter),
                                          Expanded(
                                            child: NamidaHero(
                                              tag: 'DPC_queues',
                                              child: Obx(
                                                () => DefaultPlaylistCard(
                                                  colorScheme: Colors.blue,
                                                  icon: Broken.driver,
                                                  title: lang.QUEUES,
                                                  displayLoadingIndicator: QueueController.inst.isLoadingQueues,
                                                  text: QueueController.inst.queuesMap.valueR.length.formatDecimal(),
                                                  onTap: () => NamidaNavigator.inst.navigateTo(const QueuesPage()),
                                                ),
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: defaultCardHorizontalPadding),
                                        ],
                                      ),
                                      SizedBox(height: defaultCardHorizontalPadding * 0.5),
                                    ],
                                  ),
                                ),
                              ),
                            const SliverPadding(padding: EdgeInsets.only(top: 10.0)),
                            if (isInsideDialog)
                              SliverToBoxAdapter(
                                child: PlaylistTile(
                                  playlistName: k_PLAYLIST_NAME_FAV,
                                  onTap: () => PlaylistController.inst.addTracksToPlaylist(
                                    PlaylistController.inst.favouritesPlaylist.value,
                                    tracksToAdd,
                                    duplicationActions: [
                                      PlaylistAddDuplicateAction.addAllAndRemoveOldOnes,
                                      PlaylistAddDuplicateAction.addOnlyMissing,
                                    ],
                                  ),
                                ),
                              ),
                            if (isInsideDialog)
                              const SliverToBoxAdapter(
                                child: NamidaContainerDivider(margin: EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0)),
                              ),
                            if (widget.countPerRow == 1)
                              SliverFixedExtentList.builder(
                                itemCount: SearchSortController.inst.playlistSearchList.length,
                                itemExtent: Dimensions.playlistTileItemExtent,
                                itemBuilder: (context, i) {
                                  final key = SearchSortController.inst.playlistSearchList[i];
                                  final playlist = PlaylistController.inst.playlistsMap[key]!;
                                  return AnimatingTile(
                                    position: i,
                                    shouldAnimate: _shouldAnimate,
                                    child: PlaylistTile(
                                      playlistName: key,
                                      onTap: tracksToAdd != null
                                          ? () => PlaylistController.inst.addTracksToPlaylist(playlist, tracksToAdd)
                                          : () => NamidaOnTaps.inst.onNormalPlaylistTap(key),
                                    ),
                                  );
                                },
                              )
                            else if (widget.countPerRow > 1)
                              SliverGrid.builder(
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: widget.countPerRow,
                                  childAspectRatio: 0.8,
                                  mainAxisSpacing: 8.0,
                                ),
                                itemCount: SearchSortController.inst.playlistSearchList.length,
                                itemBuilder: (context, i) {
                                  final key = SearchSortController.inst.playlistSearchList[i];
                                  final playlist = PlaylistController.inst.playlistsMap[key]!;
                                  return AnimatingGrid(
                                    columnCount: SearchSortController.inst.playlistSearchList.length,
                                    position: i,
                                    shouldAnimate: _shouldAnimate,
                                    child: MultiArtworkCard(
                                      dimensions: cardDimensions,
                                      heroTag: 'playlist_${playlist.name}',
                                      tracks: playlist.tracks.toTracks(),
                                      name: playlist.name.translatePlaylistName(),
                                      gridCount: widget.countPerRow,
                                      showMenuFunction: () => NamidaDialogs.inst.showPlaylistDialog(key),
                                      onTap: () => NamidaOnTaps.inst.onNormalPlaylistTap(key),
                                      widgetsInStack: [
                                        if (playlist.m3uPath != null)
                                          Positioned(
                                            bottom: 8.0,
                                            right: 8.0,
                                            child: NamidaTooltip(
                                              message: () => "${lang.M3U_PLAYLIST}\n${playlist.m3uPath?.formatPath()}",
                                              child: const Icon(Broken.music_filter, size: 18.0),
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            if (!isInsideDialog) kBottomPaddingWidgetSliver,
                          ],
                        ),
                      ),
                      pullToRefreshWidget,
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
