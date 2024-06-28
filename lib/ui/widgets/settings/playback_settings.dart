import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import 'package:namida/base/setting_subpage_provider.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/player_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/video_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/settings_card.dart';

enum _PlaybackSettingsKeys {
  enableVideoPlayback,
  videoSource,
  videoQuality,
  localVideoMatching,
  keepScreenAwake,
  displayFavButtonInNotif,
  displayArtworkOnLockscreen,
  killPlayerAfterDismissing,
  onNotificationTap,
  dismissibleMiniplayer,
  skipSilence,
  crossfade,
  fadeEffectOnPlayPause,
  autoPlayOnNextPrev,
  infinityQueue,
  onVolume0,
  onInterruption,
  jumpToFirstTrackAfterFinishing,
  previousButtonReplays,
  seekDuration,
  minimumTrackDurToRestoreLastPosition,
  countListenAfter,
}

class PlaybackSettings extends SettingSubpageProvider {
  final bool isInDialog;
  const PlaybackSettings({super.key, super.initialItem, this.isInDialog = false});

  @override
  SettingSubpageEnum get settingPage => SettingSubpageEnum.playback;

  @override
  Map<Enum, List<String>> get lookupMap => {
        _PlaybackSettingsKeys.enableVideoPlayback: [lang.ENABLE_VIDEO_PLAYBACK],
        _PlaybackSettingsKeys.videoSource: [lang.VIDEO_PLAYBACK_SOURCE],
        _PlaybackSettingsKeys.videoQuality: [lang.VIDEO_QUALITY],
        _PlaybackSettingsKeys.localVideoMatching: [lang.LOCAL_VIDEO_MATCHING],
        _PlaybackSettingsKeys.keepScreenAwake: [lang.KEEP_SCREEN_AWAKE_WHEN],
        _PlaybackSettingsKeys.displayFavButtonInNotif: [lang.DISPLAY_FAV_BUTTON_IN_NOTIFICATION],
        _PlaybackSettingsKeys.displayArtworkOnLockscreen: [lang.DISPLAY_ARTWORK_ON_LOCKSCREEN],
        _PlaybackSettingsKeys.killPlayerAfterDismissing: [lang.KILL_PLAYER_AFTER_DISMISSING_APP],
        _PlaybackSettingsKeys.onNotificationTap: [lang.ON_NOTIFICATION_TAP],
        _PlaybackSettingsKeys.dismissibleMiniplayer: [lang.DISMISSIBLE_MINIPLAYER],
        _PlaybackSettingsKeys.skipSilence: [lang.SKIP_SILENCE],
        _PlaybackSettingsKeys.crossfade: [lang.ENABLE_CROSSFADE_EFFECT, lang.CROSSFADE_DURATION, lang.CROSSFADE_TRIGGER_SECONDS],
        _PlaybackSettingsKeys.fadeEffectOnPlayPause: [lang.ENABLE_FADE_EFFECT_ON_PLAY_PAUSE, lang.PLAY_FADE_DURATION, lang.PAUSE_FADE_DURATION],
        _PlaybackSettingsKeys.autoPlayOnNextPrev: [lang.PLAY_AFTER_NEXT_PREV],
        _PlaybackSettingsKeys.infinityQueue: [lang.INFINITY_QUEUE_ON_NEXT_PREV, lang.INFINITY_QUEUE_ON_NEXT_PREV_SUBTITLE],
        _PlaybackSettingsKeys.onVolume0: [lang.ON_VOLUME_ZERO],
        _PlaybackSettingsKeys.onInterruption: [lang.ON_INTERRUPTION],
        _PlaybackSettingsKeys.jumpToFirstTrackAfterFinishing: [lang.JUMP_TO_FIRST_TRACK_AFTER_QUEUE_FINISH],
        _PlaybackSettingsKeys.previousButtonReplays: [lang.PREVIOUS_BUTTON_REPLAYS, lang.PREVIOUS_BUTTON_REPLAYS_SUBTITLE],
        _PlaybackSettingsKeys.seekDuration: [lang.SEEK_DURATION, lang.SEEK_DURATION_INFO],
        _PlaybackSettingsKeys.minimumTrackDurToRestoreLastPosition: [lang.MIN_TRACK_DURATION_TO_RESTORE_LAST_POSITION],
        _PlaybackSettingsKeys.countListenAfter: [lang.MIN_VALUE_TO_COUNT_TRACK_LISTEN],
      };

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      getItemWrapper(
        key: _PlaybackSettingsKeys.enableVideoPlayback,
        child: Obx(
          () => CustomSwitchListTile(
            bgColor: getBgColor(_PlaybackSettingsKeys.enableVideoPlayback),
            title: lang.ENABLE_VIDEO_PLAYBACK,
            icon: Broken.video,
            value: settings.enableVideoPlayback.valueR,
            onChanged: (p0) async => await VideoController.inst.toggleVideoPlayback(),
          ),
        ),
      ),
      getItemWrapper(
        key: _PlaybackSettingsKeys.videoSource,
        child: Obx(
          () => CustomListTile(
            bgColor: getBgColor(_PlaybackSettingsKeys.videoSource),
            enabled: settings.enableVideoPlayback.valueR,
            title: lang.VIDEO_PLAYBACK_SOURCE,
            icon: Broken.scroll,
            trailingText: settings.videoPlaybackSource.valueR.toText(),
            onTap: () {
              bool isEnabled(VideoPlaybackSource val) => settings.videoPlaybackSource.value == val;
              void tileOnTap(VideoPlaybackSource val) => settings.save(videoPlaybackSource: val);
              NamidaNavigator.inst.navigateDialog(
                dialog: CustomBlurryDialog(
                  title: lang.VIDEO_PLAYBACK_SOURCE,
                  actions: [
                    IconButton(
                      onPressed: () => tileOnTap(VideoPlaybackSource.auto),
                      icon: const Icon(Broken.refresh),
                    ),
                    const DoneButton(),
                  ],
                  child: Obx(
                    () => ListView(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      children: [
                        ...VideoPlaybackSource.values.map(
                          (e) => Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: ListTileWithCheckMark(
                              active: isEnabled(e),
                              title: e.toText(),
                              subtitle: e.toSubtitle() ?? '',
                              onTap: () => tileOnTap(e),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
      getItemWrapper(
        key: _PlaybackSettingsKeys.videoQuality,
        child: Obx(
          () => CustomListTile(
            bgColor: getBgColor(_PlaybackSettingsKeys.videoQuality),
            enabled: settings.enableVideoPlayback.valueR,
            title: lang.VIDEO_QUALITY,
            icon: Broken.story,
            trailingText: settings.youtubeVideoQualities.valueR.first,
            onTap: () {
              bool isEnabled(String val) => settings.youtubeVideoQualities.contains(val);

              void tileOnTap(String val, int index) {
                if (isEnabled(val)) {
                  if (settings.youtubeVideoQualities.length == 1) {
                    showMinimumItemsSnack(1);
                  } else {
                    settings.removeFromList(youtubeVideoQualities1: val);
                  }
                } else {
                  settings.save(youtubeVideoQualities: [val]);
                }
                // sorts and saves dec
                settings.youtubeVideoQualities.sortByReverse((e) => kStockVideoQualities.indexOf(e));
                settings.save(youtubeVideoQualities: settings.youtubeVideoQualities.value);
              }

              NamidaNavigator.inst.navigateDialog(
                dialog: CustomBlurryDialog(
                  title: lang.VIDEO_QUALITY,
                  actions: const [
                    // IconButton(
                    //   onPressed: () => tileOnTap(0),
                    //   icon: const Icon(Broken.refresh),
                    // ),

                    DoneButton(),
                  ],
                  child: DefaultTextStyle(
                    style: context.textTheme.displaySmall!,
                    child: Obx(
                      () => Column(
                        children: [
                          Text(lang.VIDEO_QUALITY_SUBTITLE),
                          const SizedBox(
                            height: 12.0,
                          ),
                          Text("${lang.NOTE}: ${lang.VIDEO_QUALITY_SUBTITLE_NOTE}"),
                          const SizedBox(height: 18.0),
                          SizedBox(
                            width: namida.width,
                            height: namida.height * 0.4,
                            child: ListView(
                              padding: EdgeInsets.zero,
                              children: [
                                ...kStockVideoQualities.asMap().entries.map(
                                      (e) => Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                                        child: ListTileWithCheckMark(
                                          icon: Broken.story,
                                          active: isEnabled(e.value),
                                          title: e.value,
                                          onTap: () => tileOnTap(e.value, e.key),
                                        ),
                                      ),
                                    ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
      getItemWrapper(
        key: _PlaybackSettingsKeys.localVideoMatching,
        child: Obx(
          () => CustomListTile(
            bgColor: getBgColor(_PlaybackSettingsKeys.localVideoMatching),
            enabled: settings.enableVideoPlayback.valueR,
            icon: Broken.video_tick,
            title: lang.LOCAL_VIDEO_MATCHING,
            trailingText: settings.localVideoMatchingType.valueR.toText(),
            onTap: () {
              NamidaNavigator.inst.navigateDialog(
                dialog: CustomBlurryDialog(
                  title: lang.LOCAL_VIDEO_MATCHING,
                  actions: const [
                    DoneButton(),
                  ],
                  child: Column(
                    children: [
                      Obx(
                        () => CustomListTile(
                          icon: Broken.video_tick,
                          title: lang.MATCHING_TYPE,
                          trailingText: settings.localVideoMatchingType.valueR.toText(),
                          onTap: () {
                            final e = settings.localVideoMatchingType.value.nextElement(LocalVideoMatchingType.values);
                            settings.save(localVideoMatchingType: e);
                          },
                        ),
                      ),
                      Obx(
                        () => CustomSwitchListTile(
                          icon: Broken.folder,
                          title: lang.SAME_DIRECTORY_ONLY,
                          value: settings.localVideoMatchingCheckSameDir.valueR,
                          onChanged: (isTrue) => settings.save(localVideoMatchingCheckSameDir: !isTrue),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
      getItemWrapper(
        key: _PlaybackSettingsKeys.keepScreenAwake,
        child: Obx(
          () => CustomListTile(
            bgColor: getBgColor(_PlaybackSettingsKeys.keepScreenAwake),
            title: '${lang.KEEP_SCREEN_AWAKE_WHEN}:',
            subtitle: settings.wakelockMode.valueR.toText(),
            icon: Broken.external_drive,
            onTap: () {
              final e = settings.wakelockMode.value.nextElement(WakelockMode.values);
              settings.save(wakelockMode: e);
            },
          ),
        ),
      ),
      getItemWrapper(
        key: _PlaybackSettingsKeys.displayFavButtonInNotif,
        child: Obx(
          () => CustomSwitchListTile(
            bgColor: getBgColor(_PlaybackSettingsKeys.displayFavButtonInNotif),
            title: lang.DISPLAY_FAV_BUTTON_IN_NOTIFICATION,
            icon: Broken.heart_tick,
            value: settings.displayFavouriteButtonInNotification.valueR,
            onChanged: (val) {
              settings.save(displayFavouriteButtonInNotification: !val);
              Player.inst.refreshNotification();
              if (!val && NamidaDeviceInfo.sdkVersion < 31) {
                snackyy(title: lang.NOTE, message: lang.DISPLAY_FAV_BUTTON_IN_NOTIFICATION_SUBTITLE);
              }
            },
          ),
        ),
      ),
      if (NamidaDeviceInfo.sdkVersion < 33)
        getItemWrapper(
          key: _PlaybackSettingsKeys.displayArtworkOnLockscreen,
          child: Obx(
            () => CustomSwitchListTile(
              bgColor: getBgColor(_PlaybackSettingsKeys.displayArtworkOnLockscreen),
              title: lang.DISPLAY_ARTWORK_ON_LOCKSCREEN,
              leading: const StackedIcon(
                baseIcon: Broken.gallery,
                secondaryIcon: Broken.lock_circle,
              ),
              value: settings.player.lockscreenArtwork.valueR,
              onChanged: (val) {
                settings.player.save(lockscreenArtwork: !val);
                AudioService.setLockScreenArtwork(!val).then((_) => Player.inst.refreshNotification());
              },
            ),
          ),
        ),
      getItemWrapper(
        key: _PlaybackSettingsKeys.killPlayerAfterDismissing,
        child: Obx(
          () => CustomListTile(
            bgColor: getBgColor(_PlaybackSettingsKeys.killPlayerAfterDismissing),
            title: lang.KILL_PLAYER_AFTER_DISMISSING_APP,
            icon: Broken.forbidden_2,
            onTap: () {
              final element = settings.player.killAfterDismissingApp.value.nextElement(KillAppMode.values);
              settings.player.save(killAfterDismissingApp: element);
            },
            trailingText: settings.player.killAfterDismissingApp.valueR.toText(),
          ),
        ),
      ),
      getItemWrapper(
        key: _PlaybackSettingsKeys.onNotificationTap,
        child: Obx(
          () => CustomListTile(
            bgColor: getBgColor(_PlaybackSettingsKeys.onNotificationTap),
            title: lang.ON_NOTIFICATION_TAP,
            trailingText: settings.onNotificationTapAction.valueR.toText(),
            icon: Broken.card,
            onTap: () {
              final element = settings.onNotificationTapAction.value.nextElement(NotificationTapAction.values);
              settings.save(onNotificationTapAction: element);
            },
          ),
        ),
      ),
      getItemWrapper(
        key: _PlaybackSettingsKeys.dismissibleMiniplayer,
        child: Obx(
          () => CustomSwitchListTile(
            bgColor: getBgColor(_PlaybackSettingsKeys.dismissibleMiniplayer),
            icon: Broken.sidebar_bottom,
            title: lang.DISMISSIBLE_MINIPLAYER,
            onChanged: (value) => settings.save(dismissibleMiniplayer: !value),
            value: settings.dismissibleMiniplayer.valueR,
          ),
        ),
      ),
      getItemWrapper(
        key: _PlaybackSettingsKeys.skipSilence,
        child: Obx(
          () => CustomSwitchListTile(
            bgColor: getBgColor(_PlaybackSettingsKeys.skipSilence),
            icon: Broken.forward,
            title: lang.SKIP_SILENCE,
            onChanged: (value) async {
              final willBeTrue = !value;
              settings.player.save(skipSilenceEnabled: willBeTrue);
              await Player.inst.setSkipSilenceEnabled(willBeTrue);
            },
            value: settings.player.skipSilenceEnabled.valueR,
          ),
        ),
      ),
      // -- Crossfade
      getItemWrapper(
        key: _PlaybackSettingsKeys.crossfade,
        child: NamidaExpansionTile(
          bgColor: getBgColor(_PlaybackSettingsKeys.crossfade),
          normalRightPadding: true,
          initiallyExpanded: settings.player.enableCrossFade.value,
          leading: const StackedIcon(
            baseIcon: Broken.play,
            secondaryIcon: Broken.recovery_convert,
          ),
          childrenPadding: const EdgeInsets.symmetric(horizontal: 12.0),
          iconColor: context.defaultIconColor(),
          titleText: lang.ENABLE_CROSSFADE_EFFECT,
          onExpansionChanged: (wasCollapsed) {
            if (!wasCollapsed) return settings.player.save(enableCrossFade: false);
            SussyBaka.monetize(onEnable: () => settings.player.save(enableCrossFade: true));
          },
          trailing: Obx(() => CustomSwitch(active: settings.player.enableCrossFade.valueR)),
          children: [
            Obx(
              () {
                const stepper = 100;
                const minVal = 100;
                final enableCrossFade = settings.player.enableCrossFade.valueR;
                final crossFadeDurationMS = settings.player.crossFadeDurationMS.valueR;
                return CustomListTile(
                  enabled: enableCrossFade,
                  icon: Broken.blend_2,
                  title: lang.CROSSFADE_DURATION,
                  trailing: NamidaWheelSlider(
                    totalCount: (10000 - minVal) ~/ stepper,
                    initValue: crossFadeDurationMS ~/ stepper,
                    onValueChanged: (val) {
                      final v = (val * stepper + minVal);
                      settings.player.save(crossFadeDurationMS: v);
                    },
                    text: crossFadeDurationMS >= 1000 ? "${crossFadeDurationMS / 1000}s" : "${crossFadeDurationMS}ms",
                  ),
                );
              },
            ),
            Obx(
              () {
                final crossFadeAutoTriggerSeconds = settings.player.crossFadeAutoTriggerSeconds.valueR;
                return CustomListTile(
                  enabled: settings.player.enableCrossFade.valueR,
                  icon: Broken.blend,
                  title: crossFadeAutoTriggerSeconds == 0
                      ? lang.CROSSFADE_TRIGGER_SECONDS_DISABLED
                      : lang.CROSSFADE_TRIGGER_SECONDS.replaceFirst('_SECONDS_', "$crossFadeAutoTriggerSeconds"),
                  trailing: NamidaWheelSlider(
                    totalCount: 30,
                    initValue: crossFadeAutoTriggerSeconds,
                    onValueChanged: (val) {
                      settings.player.save(crossFadeAutoTriggerSeconds: val);
                    },
                    text: "${crossFadeAutoTriggerSeconds}s",
                  ),
                );
              },
            ),
          ],
        ),
      ),
      // -- Play/Pause Fade
      getItemWrapper(
        key: _PlaybackSettingsKeys.fadeEffectOnPlayPause,
        child: NamidaExpansionTile(
          bgColor: getBgColor(_PlaybackSettingsKeys.fadeEffectOnPlayPause),
          normalRightPadding: true,
          initiallyExpanded: settings.player.enableVolumeFadeOnPlayPause.value,
          leading: const StackedIcon(
            baseIcon: Broken.play,
            secondaryIcon: Broken.pause,
          ),
          childrenPadding: const EdgeInsets.symmetric(horizontal: 12.0),
          iconColor: context.defaultIconColor(),
          titleText: lang.ENABLE_FADE_EFFECT_ON_PLAY_PAUSE,
          onExpansionChanged: (value) {
            settings.player.save(enableVolumeFadeOnPlayPause: value);
            Player.inst.setVolume(settings.player.volume.value);
          },
          trailing: Obx(() => CustomSwitch(active: settings.player.enableVolumeFadeOnPlayPause.valueR)),
          children: [
            Obx(
              () => CustomListTile(
                enabled: settings.player.enableVolumeFadeOnPlayPause.valueR,
                icon: Broken.play,
                title: lang.PLAY_FADE_DURATION,
                trailing: NamidaWheelSlider(
                  totalCount: 1900 ~/ 50,
                  initValue: settings.player.playFadeDurInMilli.valueR ~/ 50,
                  onValueChanged: (val) {
                    final v = (val * 50 + 100);
                    settings.player.save(playFadeDurInMilli: v);
                  },
                  text: "${settings.player.playFadeDurInMilli.valueR}ms",
                ),
              ),
            ),
            Obx(
              () => CustomListTile(
                enabled: settings.player.enableVolumeFadeOnPlayPause.valueR,
                icon: Broken.pause,
                title: lang.PAUSE_FADE_DURATION,
                trailing: NamidaWheelSlider(
                  totalCount: 1900 ~/ 50,
                  initValue: settings.player.pauseFadeDurInMilli.valueR ~/ 50,
                  onValueChanged: (val) {
                    final v = (val * 50 + 100);
                    settings.player.save(pauseFadeDurInMilli: v);
                  },
                  text: "${settings.player.pauseFadeDurInMilli.valueR}ms",
                ),
              ),
            ),
          ],
        ),
      ),
      getItemWrapper(
        key: _PlaybackSettingsKeys.autoPlayOnNextPrev,
        child: Obx(
          () => CustomSwitchListTile(
            bgColor: getBgColor(_PlaybackSettingsKeys.autoPlayOnNextPrev),
            leading: const StackedIcon(
              baseIcon: Broken.play,
              secondaryIcon: Broken.record,
            ),
            title: lang.PLAY_AFTER_NEXT_PREV,
            onChanged: (value) => settings.player.save(playOnNextPrev: !value),
            value: settings.player.playOnNextPrev.valueR,
          ),
        ),
      ),
      getItemWrapper(
        key: _PlaybackSettingsKeys.infinityQueue,
        child: Obx(
          () => CustomSwitchListTile(
            bgColor: getBgColor(_PlaybackSettingsKeys.infinityQueue),
            icon: Broken.repeat,
            title: lang.INFINITY_QUEUE_ON_NEXT_PREV,
            subtitle: lang.INFINITY_QUEUE_ON_NEXT_PREV_SUBTITLE,
            onChanged: (value) => settings.player.save(infiniyQueueOnNextPrevious: !value),
            value: settings.player.infiniyQueueOnNextPrevious.valueR,
          ),
        ),
      ),
      getItemWrapper(
        key: _PlaybackSettingsKeys.onVolume0,
        child: NamidaExpansionTile(
          bgColor: getBgColor(_PlaybackSettingsKeys.onVolume0),
          childrenPadding: const EdgeInsets.symmetric(horizontal: 12.0),
          iconColor: context.defaultIconColor(),
          icon: Broken.volume_slash,
          titleText: lang.ON_VOLUME_ZERO,
          children: [
            Obx(
              () => CustomSwitchListTile(
                icon: Broken.pause_circle,
                title: lang.PAUSE_PLAYBACK,
                onChanged: (value) => settings.player.save(pauseOnVolume0: !value),
                value: settings.player.pauseOnVolume0.valueR,
              ),
            ),
            Obx(
              () {
                final valInSet = settings.player.volume0ResumeThresholdMin.valueR;
                final disabled = !settings.player.resumeAfterOnVolume0Pause.valueR;
                const max = 61;
                return CustomListTile(
                  icon: Broken.play_circle,
                  title: disabled
                      ? lang.DONT_RESUME
                      : valInSet == 0
                          ? lang.RESUME_IF_WAS_PAUSED_BY_VOLUME
                          : lang.RESUME_IF_WAS_PAUSED_FOR_LESS_THAN_N_MIN.replaceFirst('_NUM_', "${settings.player.volume0ResumeThresholdMin.valueR}"),
                  trailing: NamidaWheelSlider(
                    totalCount: max,
                    initValue: valInSet,
                    onValueChanged: (val) {
                      if (val == max) {
                        settings.player.save(resumeAfterOnVolume0Pause: false);
                      } else {
                        settings.player.save(resumeAfterOnVolume0Pause: true, volume0ResumeThresholdMin: val);
                      }
                    },
                    text: disabled
                        ? lang.NEVER
                        : valInSet == 0
                            ? lang.ALWAYS
                            : "${valInSet}m",
                  ),
                );
              },
            ),
          ],
        ),
      ),
      getItemWrapper(
        key: _PlaybackSettingsKeys.onInterruption,
        child: NamidaExpansionTile(
          bgColor: getBgColor(_PlaybackSettingsKeys.onInterruption),
          childrenPadding: const EdgeInsets.symmetric(horizontal: 12.0),
          iconColor: context.defaultIconColor(),
          icon: Broken.notification_bing,
          titleText: lang.ON_INTERRUPTION,
          children: [
            ...InterruptionType.values.map(
              (type) {
                return CustomListTile(
                  icon: type.toIcon(),
                  title: type.toText(),
                  subtitle: type.toSubtitle(),
                  trailing: PopupMenuButton<InterruptionAction>(
                    child: Obx(() {
                      final actionInSetting = settings.player.onInterrupted[type] ?? InterruptionAction.pause;
                      return Text(actionInSetting.toText());
                    }),
                    itemBuilder: (context) => <PopupMenuItem<InterruptionAction>>[
                      ...InterruptionAction.values.map(
                        (action) => PopupMenuItem(
                          value: action,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Icon(action.toIcon(), size: 22.0),
                              const SizedBox(width: 6.0),
                              Text(action.toText()),
                              const Spacer(),
                              Obx(
                                () {
                                  final actionInSetting = settings.player.onInterrupted[type] ?? InterruptionAction.pause;
                                  return NamidaCheckMark(
                                    size: 16.0,
                                    active: actionInSetting == action,
                                  );
                                },
                              ),
                              const SizedBox(width: 6.0),
                            ],
                          ),
                        ),
                      ),
                    ],
                    onSelected: (action) => settings.player.updatePlayerInterruption(type, action),
                  ),
                );
              },
            ),
            const NamidaContainerDivider(margin: EdgeInsets.symmetric(horizontal: 16.0)),
            const SizedBox(height: 6.0),
            Obx(
              () {
                final valInSet = settings.player.interruptionResumeThresholdMin.valueR;
                final disabled = !settings.player.resumeAfterWasInterrupted.valueR;
                const max = 61;
                return CustomListTile(
                  icon: Broken.play_circle,
                  title: disabled
                      ? lang.DONT_RESUME
                      : valInSet == 0
                          ? lang.RESUME_IF_WAS_INTERRUPTED
                          : lang.RESUME_IF_WAS_PAUSED_FOR_LESS_THAN_N_MIN.replaceFirst('_NUM_', "${settings.player.interruptionResumeThresholdMin.valueR}"),
                  trailing: NamidaWheelSlider(
                    totalCount: max,
                    initValue: valInSet,
                    onValueChanged: (val) {
                      if (val == max) {
                        settings.player.save(resumeAfterWasInterrupted: false);
                      } else {
                        settings.player.save(resumeAfterWasInterrupted: true, interruptionResumeThresholdMin: val);
                      }
                    },
                    text: disabled
                        ? lang.NEVER
                        : valInSet == 0
                            ? lang.ALWAYS
                            : "${valInSet}m",
                  ),
                );
              },
            ),
            const SizedBox(height: 6.0),
          ],
        ),
      ),
      getItemWrapper(
        key: _PlaybackSettingsKeys.jumpToFirstTrackAfterFinishing,
        child: Obx(
          () => CustomSwitchListTile(
            bgColor: getBgColor(_PlaybackSettingsKeys.jumpToFirstTrackAfterFinishing),
            icon: Broken.rotate_left,
            title: lang.JUMP_TO_FIRST_TRACK_AFTER_QUEUE_FINISH,
            onChanged: (value) => settings.player.save(jumpToFirstTrackAfterFinishingQueue: !value),
            value: settings.player.jumpToFirstTrackAfterFinishingQueue.valueR,
          ),
        ),
      ),
      getItemWrapper(
        key: _PlaybackSettingsKeys.previousButtonReplays,
        child: Obx(
          () => CustomSwitchListTile(
            bgColor: getBgColor(_PlaybackSettingsKeys.previousButtonReplays),
            leading: const StackedIcon(
              baseIcon: Broken.previous,
              secondaryIcon: Broken.rotate_left,
              secondaryIconSize: 12.0,
            ),
            title: lang.PREVIOUS_BUTTON_REPLAYS,
            subtitle: lang.PREVIOUS_BUTTON_REPLAYS_SUBTITLE,
            onChanged: (value) => settings.save(previousButtonReplays: !value),
            value: settings.previousButtonReplays.valueR,
          ),
        ),
      ),
      getItemWrapper(
        key: _PlaybackSettingsKeys.seekDuration,
        child: Obx(
          () => CustomListTile(
            bgColor: getBgColor(_PlaybackSettingsKeys.seekDuration),
            icon: Broken.forward_5_seconds,
            title: "${lang.SEEK_DURATION} (${settings.player.isSeekDurationPercentage.valueR ? lang.PERCENTAGE : lang.SECONDS})",
            subtitle: lang.SEEK_DURATION_INFO,
            onTap: () => settings.player.save(isSeekDurationPercentage: !settings.player.isSeekDurationPercentage.value),
            trailing: settings.player.isSeekDurationPercentage.valueR
                ? NamidaWheelSlider(
                    totalCount: 50,
                    initValue: settings.player.seekDurationInPercentage.valueR,
                    onValueChanged: (val) {
                      settings.player.save(seekDurationInPercentage: val);
                    },
                    text: "${settings.player.seekDurationInPercentage.valueR}%",
                  )
                : NamidaWheelSlider(
                    totalCount: 120,
                    initValue: settings.player.seekDurationInSeconds.valueR,
                    onValueChanged: (val) {
                      settings.player.save(seekDurationInSeconds: val);
                    },
                    text: "${settings.player.seekDurationInSeconds.valueR}s",
                  ),
          ),
        ),
      ),
      getItemWrapper(
        key: _PlaybackSettingsKeys.minimumTrackDurToRestoreLastPosition,
        child: Obx(
          () {
            final valInSet = settings.player.minTrackDurationToRestoreLastPosInMinutes.valueR;
            const max = 121;
            return CustomListTile(
              bgColor: getBgColor(_PlaybackSettingsKeys.minimumTrackDurToRestoreLastPosition),
              icon: Broken.refresh_left_square,
              title: lang.MIN_TRACK_DURATION_TO_RESTORE_LAST_POSITION,
              trailing: NamidaWheelSlider(
                totalCount: max,
                initValue: valInSet <= -1 ? max : valInSet,
                onValueChanged: (val) {
                  settings.player.save(minTrackDurationToRestoreLastPosInMinutes: val >= max ? -1 : val);
                },
                text: valInSet == 0
                    ? lang.ALWAYS_RESTORE
                    : valInSet <= -1
                        ? lang.DONT_RESTORE_POSITION
                        : "${valInSet}m",
              ),
            );
          },
        ),
      ),
      getItemWrapper(
        key: _PlaybackSettingsKeys.countListenAfter,
        child: Obx(
          () => CustomListTile(
            bgColor: getBgColor(_PlaybackSettingsKeys.countListenAfter),
            icon: Broken.timer,
            title: lang.MIN_VALUE_TO_COUNT_TRACK_LISTEN,
            onTap: () => NamidaNavigator.inst.navigateDialog(
              dialog: CustomBlurryDialog(
                title: lang.CHOOSE,
                child: Column(
                  children: [
                    Text(
                      lang.MIN_VALUE_TO_COUNT_TRACK_LISTEN,
                      style: context.textTheme.displayLarge,
                    ),
                    const SizedBox(
                      height: 32.0,
                    ),
                    Obx(
                      () => Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          NamidaWheelSlider(
                            totalCount: 160,
                            initValue: settings.isTrackPlayedSecondsCount.valueR - 20,
                            onValueChanged: (val) {
                              final v = (val + 20);
                              settings.save(isTrackPlayedSecondsCount: v);
                            },
                            text: "${settings.isTrackPlayedSecondsCount.valueR}s",
                            topText: lang.SECONDS.capitalizeFirst(),
                            textPadding: 8.0,
                          ),
                          Text(
                            lang.OR,
                            style: context.textTheme.displayMedium,
                          ),
                          NamidaWheelSlider(
                            totalCount: 80,
                            initValue: settings.isTrackPlayedPercentageCount.valueR - 20,
                            onValueChanged: (val) {
                              final v = (val + 20);
                              settings.save(isTrackPlayedPercentageCount: v);
                            },
                            text: "${settings.isTrackPlayedPercentageCount.valueR}%",
                            topText: lang.PERCENTAGE,
                            textPadding: 8.0,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            trailingText: "${settings.isTrackPlayedSecondsCount.valueR}s | ${settings.isTrackPlayedPercentageCount.valueR}%",
          ),
        ),
      ),
    ];
    return SettingsCard(
      title: lang.PLAYBACK_SETTING,
      subtitle: isInDialog ? null : lang.PLAYBACK_SETTING_SUBTITLE,
      icon: Broken.play_cricle,
      child: isInDialog
          ? SizedBox(
              height: context.height * 0.7,
              width: context.width,
              child: ListView(
                padding: EdgeInsets.zero,
                children: children,
              ),
            )
          : Column(
              children: children,
            ),
    );
  }
}
