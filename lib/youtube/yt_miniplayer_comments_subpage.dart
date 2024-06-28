import 'package:flutter/material.dart';
import 'package:youtipie/core/enum.dart';

import 'package:namida/base/pull_to_refresh.dart';
import 'package:namida/controller/connectivity.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/packages/scroll_physics_modified.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings/extra_settings.dart';
import 'package:namida/youtube/class/youtube_id.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';
import 'package:namida/youtube/controller/yt_miniplayer_ui_controller.dart';
import 'package:namida/youtube/widgets/yt_comment_card.dart';

class YTMiniplayerCommentsSubpage extends StatefulWidget {
  const YTMiniplayerCommentsSubpage({super.key});

  @override
  State<YTMiniplayerCommentsSubpage> createState() => _YTMiniplayerCommentsSubpageState();
}

class _YTMiniplayerCommentsSubpageState extends State<YTMiniplayerCommentsSubpage> {
  late final ScrollController sc;
  @override
  void initState() {
    super.initState();
    sc = ScrollController();
  }

  @override
  void dispose() {
    sc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BackgroundWrapper(
      child: ObxO(
        rx: Player.inst.currentItem,
        builder: (currentItem) {
          if (currentItem is! YoutubeID) return const SizedBox();
          final currentId = currentItem.id;
          return Column(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 12.0,
                      color: context.theme.secondaryHeaderColor.withOpacity(0.5),
                    )
                  ],
                ),
                child: const Column(
                  children: [
                    SizedBox(height: 12.0),
                    YoutubeCommentsHeader(
                      displayBackButton: true,
                    ),
                    SizedBox(height: 12.0),
                  ],
                ),
              ),
              Expanded(
                child: NamidaScrollbar(
                  controller: sc,
                  child: PullToRefresh(
                    maxDistance: 64.0,
                    controller: sc,
                    onRefresh: () async {
                      if (!ConnectivityController.inst.hasConnection) return;
                      try {
                        sc.jumpTo(0);
                      } catch (_) {}
                      await YoutubeInfoController.current.updateCurrentComments(
                        currentId,
                        newSortType: YoutubeMiniplayerUiController.inst.currentCommentSort.value,
                        initial: true,
                      );
                    },
                    child: LazyLoadListView(
                      onReachingEnd: () => YoutubeInfoController.current.updateCurrentComments(currentId),
                      extend: 400,
                      scrollController: sc,
                      listview: (controller) => CustomScrollView(
                        physics: const ClampingScrollPhysicsModified(),
                        controller: controller,
                        slivers: [
                          ObxO(
                            rx: YoutubeInfoController.current.isLoadingInitialComments,
                            builder: (loadingInitial) {
                              if (loadingInitial) {
                                return SliverToBoxAdapter(
                                  child: ShimmerWrapper(
                                    transparent: false,
                                    shimmerEnabled: true,
                                    child: ListView.builder(
                                      padding: EdgeInsets.zero,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: 10,
                                      shrinkWrap: true,
                                      itemBuilder: (context, index) {
                                        return const YTCommentCard(
                                          margin: EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                                          comment: null,
                                          videoId: null,
                                        );
                                      },
                                    ),
                                  ),
                                );
                              }
                              return ObxO(
                                rx: YoutubeInfoController.current.currentComments,
                                builder: (comments) {
                                  if (comments == null) return const SliverToBoxAdapter();
                                  return SliverList.builder(
                                    itemCount: comments.length,
                                    itemBuilder: (context, i) {
                                      final comment = comments[i];
                                      return ShimmerWrapper(
                                        transparent: false,
                                        shimmerDurationMS: 550,
                                        shimmerDelayMS: 250,
                                        shimmerEnabled: comment == null,
                                        child: YTCommentCard(
                                          key: Key("${comment == null}_${comment?.commentId}"),
                                          margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                                          comment: comment,
                                          videoId: currentId,
                                        ),
                                      );
                                    },
                                  );
                                },
                              );
                            },
                          ),
                          ObxO(
                            rx: YoutubeInfoController.current.isLoadingMoreComments,
                            builder: (isLoadingMoreComments) => isLoadingMoreComments
                                ? const SliverPadding(
                                    padding: EdgeInsets.all(12.0),
                                    sliver: SliverToBoxAdapter(
                                      child: Center(
                                        child: LoadingIndicator(),
                                      ),
                                    ),
                                  )
                                : const SliverToBoxAdapter(),
                          ),
                          const SliverPadding(padding: EdgeInsets.only(bottom: kYTQueueSheetMinHeight + 12.0))
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class YoutubeCommentsHeader extends StatelessWidget {
  final bool displayBackButton;
  const YoutubeCommentsHeader({super.key, required this.displayBackButton});

  @override
  Widget build(BuildContext context) {
    final commentsIconColor = context.theme.iconTheme.color;
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        if (displayBackButton) const SizedBox(width: 12.0),
        if (displayBackButton)
          NamidaIconButton(
            horizontalPadding: 0,
            icon: Broken.arrow_left_2,
            onPressed: NamidaNavigator.inst.popPage,
          ),
        const SizedBox(width: 12.0),
        ObxO(
          rx: YoutubeInfoController.current.isCurrentCommentsFromCache,
          builder: (isCurrentCommentsFromCache) => (isCurrentCommentsFromCache ?? false)
              ? StackedIcon(
                  baseIcon: Broken.document,
                  secondaryIcon: Broken.global,
                  iconSize: 22.0,
                  secondaryIconSize: 12.0,
                  baseIconColor: commentsIconColor,
                  secondaryIconColor: commentsIconColor,
                )
              : const Icon(
                  Broken.document,
                  size: 22.0,
                ),
        ),
        const SizedBox(width: 8.0),
        Expanded(
          child: ObxO(
            rx: YoutubeInfoController.current.currentComments,
            builder: (comments) {
              final count = comments?.commentsCount;
              return Text(
                [
                  lang.COMMENTS,
                  if (count != null) count.formatDecimalShort(),
                ].join(' • '),
                style: context.textTheme.displayMedium,
                textAlign: TextAlign.start,
              );
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const SizedBox(width: 8.0),
            ...CommentsSortType.values.map(
              (s) => ObxO(
                rx: YoutubeMiniplayerUiController.inst.currentCommentSort,
                builder: (currentCommentSort) => NamidaInkWell(
                  borderRadius: 8.0,
                  margin: const EdgeInsets.symmetric(horizontal: 4.0),
                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                  bgColor: currentCommentSort == s ? context.theme.colorScheme.secondaryContainer : context.theme.cardColor,
                  onTap: () async {
                    if (YoutubeMiniplayerUiController.inst.currentCommentSort.value == s) return;

                    final currentItem = Player.inst.currentItem.value;
                    if (currentItem is! YoutubeID) return;
                    final currentId = currentItem.id;

                    YoutubeMiniplayerUiController.inst.currentCommentSort.value = s;
                    await YoutubeInfoController.current.updateCurrentComments(
                      currentId,
                      newSortType: s,
                      initial: true,
                    );
                  },
                  child: Text(
                    s.toText(),
                    style: context.textTheme.displayMedium,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8.0),
          ],
        ),
        const SizedBox(width: 8.0),
      ],
    );
  }
}
