import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:namida/controller/current_color.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/main.dart';
import 'package:namida/ui/dialogs/edit_tags_dialog.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/youtube/class/youtube_item_download_config.dart';
import 'package:namida/youtube/controller/youtube_controller.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';
import 'package:namida/youtube/functions/video_download_options.dart';
import 'package:namida/youtube/widgets/yt_shimmer.dart';
import 'package:namida/youtube/widgets/yt_thumbnail.dart';
import 'package:namida/youtube/yt_utils.dart';
import 'package:youtipie/class/streams/audio_stream.dart';
import 'package:youtipie/class/streams/video_stream.dart';
import 'package:youtipie/class/streams/video_stream_info.dart';
import 'package:youtipie/class/streams/video_streams_result.dart';
import 'package:youtipie/core/extensions.dart' hide ListUtils;

/// [onConfirmButtonTap] should return wether to pop sheet or not.
Future<void> showDownloadVideoBottomSheet({
  BuildContext? ctx,
  required String videoId,
  Color? colorScheme,
  String confirmButtonText = '',
  bool Function(String groupName, YoutubeItemDownloadConfig config)? onConfirmButtonTap,
  bool showSpecificFileOptionsInEditTagDialog = true,
  YoutubeItemDownloadConfig? initialItemConfig,
}) async {
  colorScheme ??= CurrentColor.inst.color;
  final context = ctx ?? rootContext;

  final showAudioWebm = false.obs;
  final showVideoWebm = false.obs;
  final streamResult = Rxn<VideoStreamsResult>();
  final selectedAudioOnlyStream = Rxn<AudioStream>();
  final selectedVideoOnlyStream = Rxn<VideoStream>();
  final videoInfo = Rxn<VideoStreamInfo>();
  final videoOutputFilenameController = TextEditingController();
  final videoThumbnail = Rxn<File>();
  DateTime? videoDateTime;

  final formKey = GlobalKey<FormState>();
  final filenameExists = false.obs;

  String groupName = '';

  final tagsMap = <String, String?>{};
  void updateTagsMap(Map<String, String?> map) {
    for (final e in map.entries) {
      tagsMap[e.key] = e.value;
    }
  }

  void updatefilenameOutput({String customName = ''}) {
    if (customName != '') {
      videoOutputFilenameController.text = customName;
      return;
    }
    if (initialItemConfig != null) return; // cuz already set.

    final videoTitle = videoInfo.value?.title ?? videoId;
    if (selectedAudioOnlyStream.value == null && selectedVideoOnlyStream.value == null) {
      videoOutputFilenameController.text = videoTitle;
    } else {
      final audioOnly = selectedAudioOnlyStream.value != null && selectedVideoOnlyStream.value == null;
      if (audioOnly) {
        final filenameRealAudio = videoTitle;
        videoOutputFilenameController.text = filenameRealAudio;
      } else {
        final filenameRealVideo = "${videoTitle}_${selectedVideoOnlyStream.value?.qualityLabel}";
        videoOutputFilenameController.text = filenameRealVideo;
      }
    }
  }

  if (initialItemConfig != null) {
    updatefilenameOutput(customName: initialItemConfig.filename);
    updateTagsMap(initialItemConfig.ffmpegTags);
  }

  void onStreamsObtained(VideoStreamsResult? streams) {
    streamResult.value = streams;
    if (streams?.info != null) videoInfo.value = streams!.info!;

    selectedAudioOnlyStream.value = streamResult.value?.audioStreams.firstNonWebm();
    if (selectedAudioOnlyStream.value == null) {
      selectedAudioOnlyStream.value = streams?.audioStreams.firstOrNull;
      if (selectedAudioOnlyStream.value?.isWebm == true) {
        showAudioWebm.value = true;
      }
    }
    selectedVideoOnlyStream.value = streams?.videoStreams.firstWhereEff(
          (e) {
            final cached = e.getCachedFile(videoId);
            if (cached != null) return true;
            final strQualityLabel = e.qualityLabel.videoLabelToSettingLabel();
            return !e.isWebm && settings.youtubeVideoQualities.contains(strQualityLabel);
          },
        ) ??
        streams?.videoStreams.firstWhereEff((e) => !e.isWebm);

    updatefilenameOutput();
    videoDateTime = videoInfo.value?.publishedAt.date;
    final meta = YTUtils.getMetadataInitialMap(videoId, videoInfo.value, autoExtract: settings.ytAutoExtractVideoTagsFromInfo.value);
    if (initialItemConfig == null) updateTagsMap(meta);
  }

  final streamsInCache = YoutubeInfoController.video.fetchVideoStreamsSync(videoId);
  if (streamsInCache != null) {
    final expired = streamsInCache.hasExpired();
    if (expired == true || expired == null || streamsInCache.audioStreams.isEmpty) {
      YoutubeInfoController.video.fetchVideoStreams(videoId).then(onStreamsObtained);
    } else {
      onStreamsObtained(streamsInCache);
    }
  } else {
    YoutubeInfoController.video.fetchVideoStreams(videoId).then(onStreamsObtained);
  }

  Widget getQualityChipBase({
    required final Color? selectedColor,
    final double verticalPadding = 8.0,
    required void Function() onTap,
    required Widget? child,
  }) {
    return NamidaInkWell(
      decoration: selectedColor != null
          ? BoxDecoration(
              border: Border.all(
                color: selectedColor,
              ),
            )
          : const BoxDecoration(),
      animationDurationMS: 100,
      margin: const EdgeInsets.symmetric(horizontal: 3.0, vertical: 4.0),
      padding: EdgeInsets.symmetric(vertical: verticalPadding),
      onTap: onTap,
      borderRadius: 8.0,
      bgColor: selectedColor != null ? Color.alphaBlend(selectedColor.withAlpha(40), context.theme.cardTheme.color!) : context.theme.cardTheme.color,
      child: child,
    );
  }

  Widget getDummyQualityChip({double width = 112.0}) {
    return getQualityChipBase(
      verticalPadding: 0.0,
      selectedColor: null,
      onTap: () {},
      child: NamidaDummyContainer(
        width: width,
        height: 38.0,
        shimmerEnabled: true,
        borderRadius: 0.0,
        child: const SizedBox(),
      ),
    );
  }

  Widget getQualityButton({
    required final String title,
    final String subtitle = '',
    required final bool cacheExists,
    required final bool selected,
    final double horizontalPadding = 8.0,
    final double verticalPadding = 8.0,
    required void Function() onTap,
  }) {
    final selectedColor = colorScheme!;
    return getQualityChipBase(
      selectedColor: selected ? selectedColor : null,
      verticalPadding: verticalPadding,
      onTap: () {
        onTap();
        updatefilenameOutput();
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: horizontalPadding),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: context.textTheme.displayMedium?.copyWith(
                  fontSize: 12.0,
                ),
              ),
              if (subtitle != '')
                Text(
                  subtitle,
                  style: context.textTheme.displaySmall?.copyWith(
                    fontSize: 12.0,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 6.0),
          Icon(cacheExists ? Broken.tick_circle : Broken.import, size: 18.0),
          SizedBox(width: horizontalPadding),
        ],
      ),
    );
  }

  Widget getTextWidget({
    required final String title,
    required final String? subtitle,
    final IconData? icon,
    final Widget? leading,
    final TextStyle? style,
    required final void Function()? onSussyIconTap,
    required final void Function() onCloseIconTap,
  }) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          leading ?? Icon(icon),
          const SizedBox(width: 8.0),
          Text(
            title,
            style: style ?? context.textTheme.displayMedium,
          ),
          if (subtitle != null) ...[
            const SizedBox(width: 8.0),
            Expanded(
              child: Text(
                '• $subtitle',
                style: style ?? context.textTheme.displaySmall,
              ),
            ),
          ],
          const Spacer(),
          NamidaIconButton(
            tooltip: () => lang.SHOW_WEBM,
            horizontalPadding: 0.0,
            iconSize: 20.0,
            icon: Broken.video_octagon,
            onPressed: onSussyIconTap,
          ),
          const SizedBox(width: 12.0),
          NamidaIconButton(
            horizontalPadding: 0.0,
            iconSize: 20.0,
            icon: Broken.close_circle,
            onPressed: () {
              onCloseIconTap();
              updatefilenameOutput();
            },
          ),
          const SizedBox(width: 12.0),
        ],
      ),
    );
  }

  Widget getDivider() => const NamidaContainerDivider(margin: EdgeInsets.symmetric(vertical: 8.0));

  Widget getPopupItem<T>({required List<T> items, required Widget Function(T item) itemBuilder}) {
    return Wrap(children: items.map((element) => itemBuilder(element)).toList());
  }

  await Future.delayed(Duration.zero); // delay bcz sometimes doesnt show
  await showModalBottomSheet(
    isScrollControlled: true,
    // ignore: use_build_context_synchronously
    context: context,
    builder: (context) {
      final bottomPadding = MediaQuery.viewInsetsOf(context).bottom + MediaQuery.paddingOf(context).bottom;
      return SizedBox(
        height: context.height * 0.7 + bottomPadding,
        width: context.width,
        child: Padding(
          padding: const EdgeInsets.all(18.0).add(EdgeInsets.only(bottom: bottomPadding)),
          child: ObxO(
            rx: videoInfo,
            builder: (videoInfo) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        YoutubeThumbnail(
                          key: Key(videoId),
                          isImportantInCache: true,
                          borderRadius: 10.0,
                          videoId: videoId,
                          width: context.width * 0.2,
                          height: context.width * 0.2 * 9 / 16,
                          onImageReady: (imageFile) {
                            if (imageFile != null) videoThumbnail.value = imageFile;
                          },
                        ),
                        const SizedBox(width: 12.0),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ShimmerWrapper(
                                shimmerEnabled: videoInfo == null,
                                child: NamidaDummyContainer(
                                  borderRadius: 6.0,
                                  width: context.width,
                                  height: 18.0,
                                  shimmerEnabled: videoInfo == null,
                                  child: Text(
                                    videoInfo?.title ?? videoId,
                                    style: context.textTheme.displayMedium,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2.0),
                              ShimmerWrapper(
                                shimmerEnabled: videoInfo == null,
                                child: NamidaDummyContainer(
                                  borderRadius: 4.0,
                                  width: context.width - 24.0,
                                  height: 12.0,
                                  shimmerEnabled: videoInfo == null,
                                  child: () {
                                    final dateFormatted = videoInfo?.publishedAt.date?.millisecondsSinceEpoch.dateFormattedOriginal;
                                    return Text(
                                      [
                                        videoInfo?.durSeconds?.secondsLabel ?? "00:00",
                                        if (dateFormatted != null) dateFormatted,
                                      ].join(' - '),
                                      style: context.textTheme.displaySmall,
                                    );
                                  }(),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6.0),
                        ObxO(
                          rx: selectedVideoOnlyStream,
                          builder: (selectedVideo) => ObxO(
                            rx: selectedAudioOnlyStream,
                            builder: (selectedAudio) {
                              if (selectedAudio == null && selectedVideo == null) return const SizedBox();
                              final isWEBM = (selectedAudio?.isWebm == true || selectedVideo?.isWebm == true);
                              return Stack(
                                alignment: Alignment.bottomRight,
                                children: [
                                  NamidaIconButton(
                                    horizontalPadding: 0.0,
                                    icon: Broken.edit,
                                    onPressed: () {
                                      if (videoInfo == null && tagsMap.isEmpty) return;

                                      // webm doesnt support tag editing
                                      if (isWEBM) {
                                        snackyy(
                                          title: lang.ERROR,
                                          message: lang.WEBM_NO_EDIT_TAGS_SUPPORT,
                                          leftBarIndicatorColor: Colors.red,
                                          margin: EdgeInsets.zero,
                                          borderRadius: 0,
                                          top: false,
                                        );
                                      }

                                      showVideoDownloadOptionsSheet(
                                        context: context,
                                        videoTitle: videoInfo?.title,
                                        videoUploader: videoInfo?.channelName,
                                        tagMaps: tagsMap,
                                        supportTagging: !isWEBM,
                                        showSpecificFileOptions: showSpecificFileOptionsInEditTagDialog,
                                        onDownloadGroupNameChanged: (newGroupName) {
                                          groupName = newGroupName;
                                          formKey.currentState?.validate();
                                        },
                                      );
                                    },
                                  ),
                                  if (isWEBM)
                                    IgnorePointer(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(6),
                                          boxShadow: [
                                            BoxShadow(
                                              color: context.theme.scaffoldBackgroundColor,
                                              spreadRadius: 0,
                                              blurRadius: 3.0,
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Broken.info_circle,
                                          color: Colors.red,
                                          size: 16.0,
                                        ),
                                      ),
                                    )
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        Obx(
                          () {
                            final e = selectedAudioOnlyStream.valueR;
                            final subtitle = e == null ? null : "${e.bitrateText()} • ${e.codecInfo.container} • ${e.sizeInBytes.fileSizeFormatted}";
                            return getTextWidget(
                              title: lang.AUDIO,
                              subtitle: subtitle,
                              icon: Broken.audio_square,
                              onCloseIconTap: () => selectedAudioOnlyStream.value = null,
                              onSussyIconTap: () {
                                showAudioWebm.toggle();
                                if (showAudioWebm.value == false && selectedAudioOnlyStream.value?.isWebm == true) {
                                  selectedAudioOnlyStream.value = streamResult.value?.audioStreams.firstOrNull;
                                }
                              },
                            );
                          },
                        ),
                        Obx(
                          () => streamResult.valueR?.audioStreams == null
                              ? Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: ShimmerWrapper(
                                    shimmerEnabled: true,
                                    child: getPopupItem(
                                      items: List.filled(2, null),
                                      itemBuilder: (item) => getDummyQualityChip(width: 164.0),
                                    ),
                                  ),
                                )
                              : getPopupItem(
                                  items: showAudioWebm.valueR ? streamResult.valueR!.audioStreams : streamResult.valueR!.audioStreams.where((element) => !element.isWebm).toList(),
                                  itemBuilder: (element) {
                                    return Obx(
                                      () {
                                        final cacheFile = element.getCachedFile(videoId);
                                        return getQualityButton(
                                          selected: selectedAudioOnlyStream.valueR == element,
                                          cacheExists: cacheFile != null,
                                          title: "${element.codecInfo.codec} • ${element.sizeInBytes.fileSizeFormatted}",
                                          subtitle: "${element.codecInfo.container} • ${element.bitrateText()}",
                                          onTap: () => selectedAudioOnlyStream.value = element,
                                        );
                                      },
                                    );
                                  },
                                ),
                        ),
                        getDivider(),
                        ObxO(
                          rx: selectedVideoOnlyStream,
                          builder: (vostream) {
                            final subtitle = vostream == null ? null : "${vostream.qualityLabel} • ${vostream.sizeInBytes.fileSizeFormatted}";
                            return getTextWidget(
                              title: lang.VIDEO,
                              subtitle: subtitle,
                              icon: Broken.video_square,
                              onCloseIconTap: () => selectedVideoOnlyStream.value = null,
                              onSussyIconTap: () {
                                showVideoWebm.toggle();
                                if (showVideoWebm.value == false && selectedVideoOnlyStream.value?.isWebm == true) {
                                  selectedVideoOnlyStream.value = streamResult.value?.videoStreams.firstOrNull;
                                }
                              },
                            );
                          },
                        ),
                        Obx(
                          () => streamResult.valueR?.videoStreams == null
                              ? Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: ShimmerWrapper(
                                    shimmerEnabled: true,
                                    child: getPopupItem(
                                      items: List.filled(8, null),
                                      itemBuilder: (item) => getDummyQualityChip(),
                                    ),
                                  ),
                                )
                              : getPopupItem(
                                  items: showVideoWebm.valueR ? streamResult.valueR!.videoStreams : streamResult.valueR!.videoStreams.where((element) => !element.isWebm).toList(),
                                  itemBuilder: (element) {
                                    return Obx(
                                      () {
                                        final cacheFile = element.getCachedFile(videoId);
                                        return getQualityButton(
                                          selected: selectedVideoOnlyStream.valueR == element,
                                          cacheExists: cacheFile != null,
                                          title: "${element.qualityLabel} • ${element.sizeInBytes.fileSizeFormatted}",
                                          subtitle: "${element.codecInfo.container} • ${element.bitrateText()}",
                                          onTap: () => selectedVideoOnlyStream.value = element,
                                        );
                                      },
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12.0),
                  Obx(() {
                    final videoOnly = selectedVideoOnlyStream.valueR != null && selectedAudioOnlyStream.valueR == null ? lang.VIDEO_ONLY : null;
                    final audioOnly = selectedVideoOnlyStream.valueR == null && selectedAudioOnlyStream.valueR != null ? lang.AUDIO_ONLY : null;
                    final audioAndVideo = selectedVideoOnlyStream.valueR != null && selectedAudioOnlyStream.valueR != null ? "${lang.VIDEO} + ${lang.AUDIO}" : null;

                    return Text.rich(
                      TextSpan(
                        text: "${lang.OUTPUT}: ",
                        style: context.textTheme.displaySmall,
                        children: [
                          TextSpan(
                            text: videoOnly ?? audioOnly ?? audioAndVideo ?? lang.NONE,
                            style: context.textTheme.displayMedium?.copyWith(color: videoOnly != null ? Colors.red : null),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 18.0),
                  Form(
                    key: formKey,
                    child: CustomTagTextField(
                      controller: videoOutputFilenameController,
                      hintText: videoOutputFilenameController.text,
                      labelText: lang.FILE_NAME,
                      validatorMode: AutovalidateMode.always,
                      validator: (value) {
                        if (value == null) return lang.PLEASE_ENTER_A_NAME;
                        final file = File("${AppDirs.YOUTUBE_DOWNLOADS}$groupName$value");
                        void updateVal(bool exist) => WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
                              filenameExists.value = exist;
                            });
                        if (file.existsSync()) {
                          updateVal(true);
                          return "${lang.FILE_ALREADY_EXISTS}, ${lang.DOWNLOADING_WILL_OVERRIDE_IT} (${file.fileSizeFormatted() ?? 0})";
                        } else {
                          updateVal(false);
                        }

                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 12.0),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        flex: 1,
                        child: TextButton(
                          child: NamidaButtonText(lang.CANCEL),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(width: 12.0),
                      Expanded(
                        flex: 2,
                        child: Obx(
                          () {
                            final sizeSum = (selectedVideoOnlyStream.valueR?.sizeInBytes ?? 0) + (selectedAudioOnlyStream.valueR?.sizeInBytes ?? 0);
                            final enabled = sizeSum > 0;
                            final sizeText = enabled ? "(${sizeSum.fileSizeFormatted})" : '';
                            return IgnorePointer(
                              ignoring: !enabled,
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 200),
                                opacity: enabled ? 1.0 : 0.6,
                                child: NamidaInkWell(
                                  borderRadius: 12.0,
                                  padding: const EdgeInsets.all(12.0),
                                  height: 48.0,
                                  bgColor: colorScheme,
                                  decoration: filenameExists.valueR
                                      ? BoxDecoration(
                                          border: Border.all(
                                            width: 3.0,
                                            color: Colors.red.withAlpha(80),
                                          ),
                                        )
                                      : const BoxDecoration(),
                                  onTap: () async {
                                    final itemConfig = YoutubeItemDownloadConfig(
                                      id: videoId,
                                      filename: videoOutputFilenameController.text,
                                      ffmpegTags: tagsMap,
                                      fileDate: videoDateTime,
                                      videoStream: selectedVideoOnlyStream.value,
                                      audioStream: selectedAudioOnlyStream.value,
                                      prefferedVideoQualityID: selectedVideoOnlyStream.value?.itag.toString(),
                                      prefferedAudioQualityID: selectedAudioOnlyStream.value?.itag.toString(),
                                    );
                                    if (onConfirmButtonTap != null) {
                                      final accept = onConfirmButtonTap(groupName, itemConfig);
                                      if (accept) context.safePop();
                                    } else {
                                      if (!await requestManageStoragePermission()) return;
                                      requestIgnoreBatteryOptimizations();
                                      if (context.mounted) context.safePop();
                                      YoutubeController.inst.downloadYoutubeVideos(
                                        useCachedVersionsIfAvailable: true,
                                        autoExtractTitleAndArtist: settings.ytAutoExtractVideoTagsFromInfo.value,
                                        keepCachedVersionsIfDownloaded: settings.downloadFilesKeepCachedVersions.value,
                                        downloadFilesWriteUploadDate: settings.downloadFilesWriteUploadDate.value,
                                        groupName: groupName,
                                        itemsConfig: [itemConfig],
                                      );
                                    }
                                  },
                                  child: Center(
                                    child: Text(
                                      '${confirmButtonText == '' ? lang.DOWNLOAD : confirmButtonText} $sizeText',
                                      style: context.textTheme.displayMedium?.copyWith(color: Colors.white.withOpacity(0.9)),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  )
                ],
              );
            },
          ),
        ),
      );
    },
  );

  void closeStreams() {
    showAudioWebm.close();
    showVideoWebm.close();
    streamResult.close();
    selectedAudioOnlyStream.close();
    selectedVideoOnlyStream.close();
    videoInfo.close();
    videoOutputFilenameController.dispose();
    videoThumbnail.close();
    filenameExists.close();
  }

  closeStreams.executeAfterDelay();
}
