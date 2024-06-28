import 'package:flutter/material.dart';
import 'package:youtipie/class/stream_info_item/stream_info_item.dart';

import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

enum YTVideosSorting {
  date,
  views,
  duration,
}

mixin YoutubeStreamsManager {
  List<StreamInfoItem>? get streamsList;
  ScrollController get scrollController;
  BuildContext get context;
  Color? get sortChipBGColor;
  void onSortChanged(void Function() fn);

  void disposeResources() {
    sorting.close();
    sortingByTop.close();
  }

  late final _defaultSorting = YTVideosSorting.date;
  late final _defaultSortingByTop = true;
  late final sorting = _defaultSorting.obs;
  late final sortingByTop = _defaultSortingByTop.obs;

  Widget get sortWidget => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            ...YTVideosSorting.values.map(
              (e) {
                final details = sortToTextAndIcon(e);
                return ObxO(
                  rx: sorting,
                  builder: (s) {
                    final enabled = s == e;
                    final itemsColor = enabled ? Colors.white.withOpacity(0.8) : null;
                    return NamidaInkWell(
                      animationDurationMS: 200,
                      borderRadius: 6.0,
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                      margin: const EdgeInsets.symmetric(horizontal: 3.0),
                      bgColor: enabled ? sortChipBGColor : context.theme.cardColor,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          enabled
                              ? ObxO(
                                  rx: sortingByTop,
                                  builder: (sortingByTop) => StackedIcon(
                                    baseIcon: details.$2,
                                    secondaryIcon: sortingByTop ? Broken.arrow_down_2 : Broken.arrow_up_3,
                                    iconSize: 20.0,
                                    secondaryIconSize: 10.0,
                                    blurRadius: 4.0,
                                    baseIconColor: itemsColor,
                                    // secondaryIconColor: enabled ? context.theme.colorScheme.surface : null,
                                  ),
                                )
                              : Icon(
                                  details.$2,
                                  size: 20.0,
                                  color: null,
                                ),
                          const SizedBox(width: 4.0),
                          Text(
                            details.$1,
                            style: context.textTheme.displayMedium?.copyWith(color: itemsColor),
                          ),
                        ],
                      ),
                      onTap: () => onSortChanged(
                        () => sortStreams(sort: e, sortingByTop: enabled ? !sortingByTop.value : null),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      );
  void trySortStreams() {
    if (sorting.value != _defaultSorting || sortingByTop.value != _defaultSortingByTop) {
      sortStreams(jumpToZero: false);
    }
  }

  void sortStreams({List<StreamInfoItem>? streams, YTVideosSorting? sort, bool? sortingByTop, bool jumpToZero = true}) {
    streams ??= streamsList;
    if (streams == null) return;
    sort ??= sorting.value;
    sortingByTop ??= this.sortingByTop.value;
    switch (sort) {
      case YTVideosSorting.date:
        sortingByTop ? streams.sortByReverse((e) => e.publishedAt.date ?? DateTime(0)) : streams.sortBy((e) => e.publishedAt.date ?? DateTime(0));
        break;

      case YTVideosSorting.views:
        sortingByTop ? streams.sortByReverse((e) => e.viewsCount ?? 0) : streams.sortBy((e) => e.viewsCount ?? 0);
        break;

      case YTVideosSorting.duration:
        sortingByTop ? streams.sortByReverse((e) => e.durSeconds ?? 0) : streams.sortBy((e) => e.durSeconds ?? 0);
        break;

      default:
        null;
    }
    sorting.value = sort;
    this.sortingByTop.value = sortingByTop;

    if (jumpToZero && scrollController.hasClients) {
      final scrolledFar = scrollController.offset > context.height * 0.7;
      if (scrolledFar) {
        scrollController.animateToEff(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.fastEaseInToSlowEaseOut,
        );
      }
    }
  }

  (String, IconData) sortToTextAndIcon(YTVideosSorting sort) {
    switch (sort) {
      case YTVideosSorting.date:
        return (lang.DATE, Broken.calendar);
      case YTVideosSorting.views:
        return (lang.VIEWS.capitalizeFirst(), Broken.eye);
      case YTVideosSorting.duration:
        return (lang.DURATION, Broken.timer_1);
    }
  }
}
