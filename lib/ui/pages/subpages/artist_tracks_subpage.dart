import 'package:flutter/material.dart';

import 'package:namida/class/route.dart';
import 'package:namida/class/track.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/core/dimensions.dart';
import 'package:namida/core/enums.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/core/namida_converter_ext.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/core/utils.dart';
import 'package:namida/ui/widgets/artwork.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';
import 'package:namida/ui/widgets/library/album_card.dart';

class ArtistTracksPage extends StatelessWidget with NamidaRouteWidget {
  @override
  RouteType get route {
    return type == MediaType.albumArtist
        ? RouteType.SUBPAGE_albumArtistTracks
        : type == MediaType.composer
            ? RouteType.SUBPAGE_composerTracks
            : RouteType.SUBPAGE_artistTracks;
  }

  @override
  final String name;

  final List<Track> tracks;
  final Set<String> albumIdentifiers;
  final MediaType type;

  const ArtistTracksPage({
    super.key,
    required this.name,
    required this.tracks,
    required this.albumIdentifiers,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    final albumDimensions = Dimensions.inst.getAlbumCardDimensions(Dimensions.albumInsideArtistGridCount);
    return BackgroundWrapper(
      child: Obx(
        () {
          // to update after sorting
          type == MediaType.artist
              ? Indexer.inst.mainMapArtists.valueR
              : type == MediaType.albumArtist
                  ? Indexer.inst.mainMapAlbumArtists.valueR
                  : type == MediaType.composer
                      ? Indexer.inst.mainMapComposer.valueR
                      : null;
          return NamidaTracksList(
            queueSource: QueueSource.artist,
            queueLength: tracks.length,
            queue: tracks,
            paddingAfterHeader: const EdgeInsets.only(bottom: 12.0),
            header: Column(
              children: [
                SubpagesTopContainer(
                  topPadding: 8.0,
                  bottomPadding: 8.0,
                  title: name,
                  source: QueueSource.artist,
                  subtitle: [
                    tracks.displayTrackKeyword,
                    if (tracks.year != 0) tracks.year.yearFormatted,
                  ].join(' - '),
                  heroTag: 'artist_$name',
                  imageWidget: NamidaHero(
                    tag: 'artist_$name',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 0.0, horizontal: 2),
                      child: ContainerWithBorder(
                        child: ArtworkWidget(
                          key: Key(tracks.pathToImage),
                          track: tracks.trackOfImage,
                          thumbnailSize: namida.width * 0.35,
                          path: tracks.pathToImage,
                          forceSquared: true,
                          blur: 0,
                          iconSize: 32.0,
                        ),
                      ),
                    ),
                  ),
                  tracksFn: () => tracks,
                ),
                NamidaExpansionTile(
                  icon: Broken.music_dashboard,
                  titleText: "${lang.ALBUMS} ${albumIdentifiers.length}",
                  initiallyExpanded: albumIdentifiers.isNotEmpty,
                  children: [
                    SizedBox(
                      height: 130.0 + 28.0,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 14.0),
                        scrollDirection: Axis.horizontal,
                        itemExtent: 100.0,
                        itemCount: albumIdentifiers.length,
                        itemBuilder: (context, i) {
                          final albumId = albumIdentifiers.elementAt(i);
                          return Container(
                            width: 100.0,
                            margin: const EdgeInsets.only(left: 2.0),
                            child: AlbumCard(
                              dimensions: albumDimensions,
                              identifier: albumId,
                              album: albumId.getAlbumTracks(),
                              staggered: false,
                              compact: true,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
