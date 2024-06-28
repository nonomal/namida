import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/pages/yt_channel_subpage.dart';
import 'package:namida/youtube/widgets/namida_read_more.dart';
import 'package:namida/youtube/widgets/yt_description_widget.dart';
import 'package:namida/youtube/widgets/yt_shimmer.dart';
import 'package:namida/youtube/widgets/yt_thumbnail.dart';
import 'package:youtipie/class/comments/comment_info_item.dart';

class YTCommentCard extends StatelessWidget {
  final EdgeInsetsGeometry? margin;
  final String? videoId;
  final CommentInfoItem? comment;
  const YTCommentCard({super.key, required this.videoId, required this.comment, required this.margin});

  @override
  Widget build(BuildContext context) {
    final uploaderAvatar = comment?.authorAvatarUrl ?? comment?.author?.avatarThumbnailUrl;
    final author = comment?.author?.displayName;
    final isArtist = comment?.author?.isArtist ?? false;
    final uploadedFrom = comment?.publishedTimeText;
    final commentContent = comment?.content;
    final likeCount = comment?.likesCount;
    final repliesCount = comment?.repliesCount;
    final isHearted = comment?.isHearted ?? false;
    final isPinned = comment?.isPinned ?? false;

    final containerColor = context.theme.cardColor.withAlpha(100);
    final readmoreColor = context.theme.colorScheme.primary.withAlpha(160);

    final authorTextColor = context.theme.colorScheme.onSurface.withAlpha(180);
    final authorTextStyle = context.textTheme.displaySmall?.copyWith(
      fontWeight: FontWeight.w400,
      color: authorTextColor,
    );

    return Stack(
      children: [
        Padding(
          padding: margin ?? EdgeInsets.zero,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: containerColor,
              borderRadius: BorderRadius.circular(12.0.multipliedRadius),
              boxShadow: [
                BoxShadow(
                  color: context.theme.secondaryHeaderColor.withAlpha(60),
                  blurRadius: 4.0,
                  spreadRadius: 1.5,
                  offset: const Offset(0.0, 1.0),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: SizedBox(
                width: context.width,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    NamidaDummyContainer(
                      width: 38.0,
                      height: 38.0,
                      isCircle: true,
                      shimmerEnabled: uploaderAvatar == null,
                      child: YoutubeThumbnail(
                        key: Key(uploaderAvatar ?? ''),
                        isImportantInCache: false,
                        customUrl: uploaderAvatar,
                        width: 38.0,
                        isCircle: true,
                      ),
                    ),
                    const SizedBox(width: 10.0),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 2.0),
                          if (isPinned) ...[
                            Row(
                              children: [
                                const Icon(
                                  Broken.path,
                                  size: 14.0,
                                ),
                                const SizedBox(width: 4.0),
                                Text(
                                  lang.PINNED,
                                  style: context.textTheme.displaySmall?.copyWith(
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2.0),
                          ],
                          NamidaDummyContainer(
                            width: context.width * 0.5,
                            height: 12.0,
                            borderRadius: 6.0,
                            shimmerEnabled: author == null,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      if (author != null)
                                        Flexible(
                                          child: Text(
                                            author,
                                            style: authorTextStyle,
                                          ),
                                        ),
                                      if (uploadedFrom != null)
                                        Text(
                                          " • $uploadedFrom",
                                          style: authorTextStyle,
                                        ),
                                      if (isArtist) ...[
                                        const SizedBox(width: 4.0),
                                        Icon(
                                          Broken.musicnote,
                                          size: 10.0,
                                          color: authorTextColor,
                                        ),
                                      ],
                                      if (isHearted) ...[
                                        const SizedBox(width: 4.0),
                                        const Icon(
                                          Broken.heart_tick,
                                          size: 14.0,
                                          color: Color.fromARGB(210, 233, 80, 112),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4.0),
                          AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: commentContent == null
                                  ? Column(
                                      children: [
                                        ...List.filled(
                                          (4 - 1).getRandomNumberBelow(1),
                                          const Padding(
                                            padding: EdgeInsets.only(top: 2.0),
                                            child: NamidaDummyContainer(
                                              width: null,
                                              height: 12.0,
                                              borderRadius: 4.0,
                                              shimmerEnabled: true,
                                              child: null,
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  : commentContent.rawText == null
                                      ? const SizedBox()
                                      : YoutubeDescriptionWidget(
                                          videoId: videoId,
                                          content: commentContent,
                                          linkColor: context.theme.colorScheme.primary.withAlpha(210),
                                          childBuilder: (span) {
                                            return NamidaReadMoreText(
                                              span: span,
                                              lines: 5,
                                              builder: (span, lines, isExpanded, exceededMaxLines, toggle) {
                                                return Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text.rich(
                                                      span,
                                                      maxLines: lines,
                                                    ),
                                                    if (exceededMaxLines)
                                                      Padding(
                                                        padding: const EdgeInsets.all(8.0),
                                                        child: TapDetector(
                                                          onTap: toggle,
                                                          child: Row(
                                                            mainAxisAlignment: MainAxisAlignment.end,
                                                            children: [
                                                              Text(
                                                                isExpanded ? '' : lang.SHOW_MORE,
                                                                style: context.textTheme.displaySmall?.copyWith(color: readmoreColor),
                                                              ),
                                                              const SizedBox(width: 8),
                                                              Icon(
                                                                isExpanded ? Broken.arrow_up_3 : Broken.arrow_down_2,
                                                                size: 18.0,
                                                                color: readmoreColor,
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                );
                                              },
                                            );
                                          },
                                        )),
                          const SizedBox(height: 8.0),
                          Row(
                            children: [
                              if (comment != null) const Icon(Broken.like_1, size: 16.0),
                              if (likeCount == null || likeCount > 0) ...[
                                const SizedBox(width: 4.0),
                                NamidaDummyContainer(
                                  width: 18.0,
                                  height: 8.0,
                                  borderRadius: 4.0,
                                  shimmerEnabled: likeCount == null,
                                  child: Text(
                                    likeCount?.formatDecimalShort() ?? '?',
                                    style: context.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w300),
                                  ),
                                ),
                              ],
                              const SizedBox(width: 12.0),
                              const Icon(Broken.dislike, size: 16.0),
                              const SizedBox(width: 16.0),
                              SizedBox(
                                height: 28.0,
                                child: TextButton.icon(
                                  style: TextButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    foregroundColor: context.theme.colorScheme.onSurface.withAlpha(200),
                                  ),
                                  onPressed: () {},
                                  icon: const Icon(Broken.document, size: 16.0),
                                  label: NamidaButtonText(
                                    [
                                      lang.REPLIES,
                                      if (repliesCount != null) repliesCount,
                                    ].join(' • '),
                                    style: context.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w300),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6.0 + 12.0), // right + iconWidth
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: NamidaPopupWrapper(
            childrenDefault: () => [
              NamidaPopupItem(
                icon: Broken.copy,
                title: lang.COPY,
                onTap: () {
                  final rawText = comment?.content.rawText;
                  if (rawText != null) {
                    Clipboard.setData(ClipboardData(text: rawText));
                  }
                },
              ),
              NamidaPopupItem(
                icon: Broken.user,
                title: lang.GO_TO_CHANNEL,
                onTap: () {
                  final channelId = comment?.author?.channelId;
                  if (channelId != null) {
                    NamidaNavigator.inst.navigateTo(YTChannelSubpage(channelID: channelId));
                  }
                },
              ),
            ],
            child: const Padding(
              padding: EdgeInsets.all(12.0 + 4.0),
              child: MoreIcon(),
            ),
          ),
        ),
      ],
    );
  }
}

class YTCommentCardCompact extends StatelessWidget {
  final CommentInfoItem? comment;
  const YTCommentCardCompact({super.key, required this.comment});

  @override
  Widget build(BuildContext context) {
    final uploaderAvatar = comment?.authorAvatarUrl ?? comment?.author?.avatarThumbnailUrl;
    final author = comment?.author?.displayName;
    final uploadedFrom = comment?.publishedTimeText;
    final commentTextParsed = comment?.content.rawText;
    final likeCount = comment?.likesCount;
    final repliesCount = comment?.repliesCount;
    final isHearted = comment?.isHearted ?? false;
    final isPinned = comment?.isPinned ?? false;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NamidaDummyContainer(
          width: 28.0,
          height: 28.0,
          isCircle: true,
          shimmerEnabled: uploaderAvatar == null,
          child: YoutubeThumbnail(
            key: Key(uploaderAvatar ?? ''),
            isImportantInCache: false,
            customUrl: uploaderAvatar,
            width: 28.0,
            isCircle: true,
          ),
        ),
        const SizedBox(width: 10.0),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 2.0),
              NamidaDummyContainer(
                width: context.width * 0.5,
                height: 8.0,
                borderRadius: 4.0,
                shimmerEnabled: author == null,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        [
                          author,
                          if (uploadedFrom != null) uploadedFrom,
                        ].join(' • '),
                        style: context.textTheme.displaySmall?.copyWith(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w400,
                          color: context.theme.colorScheme.onSurface.withAlpha(180),
                        ),
                      ),
                    ),
                    if (isPinned) ...[
                      const SizedBox(width: 4.0),
                      const Icon(
                        Broken.path,
                        size: 14.0,
                      ),
                    ],
                    if (isHearted) ...[
                      const SizedBox(width: 4.0),
                      const Icon(
                        Broken.heart_tick,
                        size: 14.0,
                        color: Color.fromARGB(200, 250, 90, 80),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 2.0),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: commentTextParsed == null
                    ? Column(
                        children: [
                          ...List.filled(
                            2,
                            const Padding(
                              padding: EdgeInsets.only(top: 2.0),
                              child: NamidaDummyContainer(
                                width: null,
                                height: 8.0,
                                borderRadius: 3.0,
                                shimmerEnabled: true,
                                child: null,
                              ),
                            ),
                          ),
                        ],
                      )
                    : Text(
                        commentTextParsed,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: context.textTheme.displaySmall?.copyWith(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: context.theme.colorScheme.onSurface.withAlpha(220),
                        ),
                      ),
              ),
              const SizedBox(height: 4.0),
              Row(
                children: [
                  const SizedBox(width: 4.0),
                  if (comment != null) const Icon(Broken.like_1, size: 12.0),
                  if (likeCount == null || likeCount > 0) ...[
                    const SizedBox(width: 4.0),
                    NamidaDummyContainer(
                      width: 18.0,
                      height: 6.0,
                      borderRadius: 4.0,
                      shimmerEnabled: likeCount == null,
                      child: Text(
                        likeCount?.formatDecimalShort() ?? '?',
                        style: context.textTheme.displaySmall?.copyWith(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                  if (repliesCount != null && repliesCount > 0) ...[
                    Text(
                      ' | ',
                      style: context.textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w300),
                    ),
                    Text(
                      [
                        lang.REPLIES,
                        repliesCount,
                      ].join(' • '),
                      style: context.textTheme.displaySmall?.copyWith(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
