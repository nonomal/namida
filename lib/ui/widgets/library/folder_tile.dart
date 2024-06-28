import 'package:flutter/material.dart';

import 'package:namida/core/utils.dart';

import 'package:namida/class/folder.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/functions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/ui/dialogs/common_dialogs.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

class FolderTile extends StatelessWidget {
  final Folder folder;
  final List<Track>? dummyTracks;
  final String? subtitle;

  const FolderTile({
    super.key,
    required this.folder,
    this.dummyTracks,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final dirInside = folder.getDirectoriesInside();
    final tracks = dummyTracks ?? folder.tracks();
    final double iconSize = (settings.trackThumbnailSizeinList.value / 1.35).clamp(0, settings.trackListTileHeight.value);
    final double thumbSize = (settings.trackThumbnailSizeinList.value / 2.6).clamp(0, settings.trackListTileHeight.value * 0.5);
    return Padding(
      padding: const EdgeInsets.only(bottom: Dimensions.tileBottomMargin, right: Dimensions.tileBottomMargin, left: Dimensions.tileBottomMargin),
      child: NamidaInkWell(
        bgColor: context.theme.cardColor,
        borderRadius: 10.0,
        onTap: () => NamidaOnTaps.inst.onFolderTap(folder),
        onLongPress: () => NamidaDialogs.inst.showFolderDialog(folder: folder, recursiveTracks: true),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Dimensions.tileVerticalPadding),
          child: Row(
            children: [
              const SizedBox(width: 12.0),
              Stack(
                children: [
                  SizedBox(
                    width: settings.trackThumbnailSizeinList.value.withMinimum(12.0),
                    height: (Dimensions.inst.trackTileItemExtent - Dimensions.totalVerticalDistance).withMinimum(12.0),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          Broken.folder,
                          size: iconSize,
                        ),
                        Positioned(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: tracks.isEmpty && dirInside.isNotEmpty
                                ? Icon(
                                    Broken.folder_open,
                                    size: thumbSize,
                                  )
                                : ArtworkWidget(
                                    key: ValueKey(tracks.firstOrNull),
                                    track: tracks.firstOrNull,
                                    blur: 0,
                                    borderRadius: 6,
                                    thumbnailSize: thumbSize,
                                    path: tracks.firstOrNull?.pathToImage,
                                    forceSquared: true,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12.0),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      folder.folderName,
                      style: context.textTheme.displayMedium!,
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: context.textTheme.displaySmall!,
                      ),
                    Text(
                      [
                        tracks.displayTrackKeyword,
                        if (dirInside.isNotEmpty) dirInside.length.displayFolderKeyword,
                      ].join(' - '),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: context.textTheme.displaySmall!,
                    ),
                  ],
                ),
              ),
              const SizedBox(
                width: 2.0,
              ),
              MoreIcon(
                padding: 6.0,
                onPressed: () => NamidaDialogs.inst.showFolderDialog(folder: folder, recursiveTracks: tracks.isEmpty ? true : false),
                onLongPress: () => NamidaDialogs.inst.showFolderDialog(folder: folder, recursiveTracks: true),
              ),
              const SizedBox(
                width: 4.0,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
