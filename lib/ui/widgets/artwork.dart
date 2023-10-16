// ignore_for_file: unused_element

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:namida/class/track.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/icon_fonts/broken_icons.dart';
import 'package:namida/packages/drop_shadow.dart';
import 'package:namida/ui/widgets/custom_widgets.dart';

class ArtworkWidget extends StatefulWidget {
  /// path of image file.
  final String? path;
  final Uint8List? bytes;
  final double thumbnailSize;
  final bool forceSquared;
  final bool staggered;
  final bool compressed;
  final int fadeMilliSeconds;
  final int cacheHeight;
  final double? width;
  final double? height;
  final double? iconSize;
  final double borderRadius;
  final double blur;
  final bool useTrackTileCacheHeight;
  final bool forceDummyArtwork;
  final Color? bgcolor;
  final Widget? child;
  final List<Widget> onTopWidgets;
  final List<BoxShadow>? boxShadow;
  final bool forceEnableGlow;
  final bool displayIcon;
  final IconData icon;
  final bool isCircle;

  const ArtworkWidget({
    super.key,
    this.bytes,
    this.compressed = true,
    this.fadeMilliSeconds = 300,
    required this.thumbnailSize,
    this.forceSquared = false,
    this.child,
    this.borderRadius = 8.0,
    this.blur = 1.5,
    this.width,
    this.height,
    this.cacheHeight = 100,
    this.useTrackTileCacheHeight = false,
    this.forceDummyArtwork = false,
    this.bgcolor,
    this.iconSize,
    this.staggered = false,
    this.boxShadow,
    this.onTopWidgets = const <Widget>[],
    this.path,
    this.forceEnableGlow = false,
    this.displayIcon = true,
    this.icon = Broken.musicnote,
    this.isCircle = false,
  });

  @override
  State<ArtworkWidget> createState() => _ArtworkWidgetState();
}

class _ArtworkWidgetState extends State<ArtworkWidget> {
  @override
  Widget build(BuildContext context) {
    final imagePath = widget.path;
    final realWidthAndHeight = widget.forceSquared ? context.width : null;

    int? finalCache;
    if (widget.compressed) {
      final pixelRatio = context.mediaQuery.devicePixelRatio;
      final cacheMultiplier = (pixelRatio * settings.artworkCacheHeightMultiplier.value).round();
      finalCache = widget.useTrackTileCacheHeight ? 60 * cacheMultiplier : widget.cacheHeight * cacheMultiplier;
    }

    final c = DisposableBuildContext<_ArtworkWidgetState>(this);

    final borderR = widget.isCircle || settings.borderRadiusMultiplier.value == 0 ? null : BorderRadius.circular(widget.borderRadius.multipliedRadius);
    final shape = widget.isCircle ? BoxShape.circle : BoxShape.rectangle;

    final boxWidth = widget.width ?? widget.thumbnailSize;
    final boxHeight = widget.height ?? widget.thumbnailSize;

    Widget getStockWidget({
      final Color? bgc,
      required final bool stackWithOnTopWidgets,
    }) {
      final icon = Icon(
        widget.displayIcon ? widget.icon : null,
        size: widget.iconSize ?? widget.thumbnailSize / 2,
      );
      return Container(
        width: boxWidth,
        height: boxHeight,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: widget.bgcolor ?? Color.alphaBlend(context.theme.cardColor.withAlpha(100), context.theme.scaffoldBackgroundColor),
          borderRadius: borderR,
          shape: shape,
          boxShadow: widget.boxShadow,
        ),
        child: stackWithOnTopWidgets
            ? Stack(
                alignment: Alignment.center,
                children: [
                  icon,
                  ...widget.onTopWidgets,
                ],
              )
            : icon,
      );
    }

    final bytes = widget.bytes;
    return imagePath == null || widget.forceDummyArtwork
        ? getStockWidget(
            stackWithOnTopWidgets: true,
            bgc: widget.bgcolor ?? Color.alphaBlend(context.theme.cardColor.withAlpha(100), context.theme.scaffoldBackgroundColor),
          )
        : SizedBox(
            width: widget.staggered ? null : boxWidth,
            height: widget.staggered ? null : boxHeight,
            child: Align(
              child: _DropShadowWrapper(
                enabled: widget.forceEnableGlow || (settings.enableGlowEffect.value && widget.blur != 0.0),
                borderRadius: widget.borderRadius.multipliedRadius,
                blur: widget.blur,
                child: Container(
                  clipBehavior: Clip.hardEdge,
                  decoration: BoxDecoration(
                    borderRadius: borderR,
                    shape: shape,
                    boxShadow: widget.boxShadow,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Image(
                        image: ScrollAwareImageProvider(
                          context: c,
                          imageProvider: ResizeImage.resizeIfNeeded(
                            null,
                            finalCache,
                            (bytes != null && bytes.isNotEmpty ? MemoryImage(bytes) : FileImage(File(imagePath))) as ImageProvider,
                          ),
                        ),
                        gaplessPlayback: true,
                        fit: BoxFit.cover,
                        filterQuality: widget.compressed ? FilterQuality.low : FilterQuality.high,
                        width: realWidthAndHeight,
                        height: realWidthAndHeight,
                        frameBuilder: ((context, child, frame, wasSynchronouslyLoaded) {
                          if (wasSynchronouslyLoaded) return child;
                          return AnimatedSwitcher(
                            duration: Duration(milliseconds: widget.fadeMilliSeconds),
                            child: frame != null ? child : const SizedBox(),
                          );
                        }),
                        errorBuilder: (context, error, stackTrace) {
                          return getStockWidget(
                            stackWithOnTopWidgets: false,
                          );
                        },
                      ),
                      ...widget.onTopWidgets
                    ],
                  ),
                ),
              ),
            ),
          );
  }
}

class _DropShadowWrapper extends StatelessWidget {
  final bool enabled;
  final Widget child;
  final double blur;
  final Offset offset;
  final double borderRadius;

  const _DropShadowWrapper({
    required this.enabled,
    required this.child,
    this.offset = const Offset(0, 1),
    this.borderRadius = 0,
    this.blur = 4.0,
  });

  @override
  Widget build(BuildContext context) {
    return enabled
        ? DropShadow(
            borderRadius: borderRadius,
            blurRadius: blur,
            spread: 0.8,
            offset: const Offset(0, 1),
            child: child,
          )
        : child;
  }
}

class MultiArtworks extends StatelessWidget {
  final List<String> paths;
  final double thumbnailSize;
  final Color? bgcolor;
  final double borderRadius;
  final Object heroTag;
  final bool disableHero;
  final double iconSize;

  const MultiArtworks({
    super.key,
    required this.paths,
    required this.thumbnailSize,
    this.bgcolor,
    this.borderRadius = 8.0,
    required this.heroTag,
    this.disableHero = false,
    this.iconSize = 29.0,
  });

  @override
  Widget build(BuildContext context) {
    return NamidaHero(
      tag: heroTag,
      enabled: !disableHero,
      child: Container(
        height: thumbnailSize,
        width: thumbnailSize,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(borderRadius.multipliedRadius)),
        child: LayoutBuilder(
          builder: (context, c) {
            return paths.isEmpty
                ? ArtworkWidget(
                    key: UniqueKey(),
                    thumbnailSize: thumbnailSize,
                    path: allTracksInLibrary.firstOrNull?.pathToImage,
                    forceSquared: true,
                    blur: 0,
                    forceDummyArtwork: true,
                    bgcolor: bgcolor,
                    borderRadius: borderRadius,
                    iconSize: iconSize,
                    width: c.maxWidth,
                    height: c.maxHeight,
                  )
                : paths.length == 1
                    ? ArtworkWidget(
                        key: UniqueKey(),
                        thumbnailSize: thumbnailSize,
                        path: paths.elementAt(0),
                        forceSquared: true,
                        blur: 0,
                        borderRadius: 0,
                        compressed: false,
                        width: c.maxWidth,
                        height: c.maxHeight,
                      )
                    : paths.length == 2
                        ? Row(
                            children: [
                              ArtworkWidget(
                                key: UniqueKey(),
                                thumbnailSize: thumbnailSize / 2,
                                path: paths.elementAt(0),
                                forceSquared: true,
                                blur: 0,
                                borderRadius: 0,
                                iconSize: iconSize - 2.0,
                                width: c.maxWidth / 2,
                                height: c.maxHeight,
                              ),
                              ArtworkWidget(
                                key: UniqueKey(),
                                thumbnailSize: thumbnailSize / 2,
                                path: paths.elementAt(1),
                                forceSquared: true,
                                blur: 0,
                                borderRadius: 0,
                                iconSize: iconSize - 2.0,
                                width: c.maxWidth / 2,
                                height: c.maxHeight,
                              ),
                            ],
                          )
                        : paths.length == 3
                            ? Row(
                                children: [
                                  Column(
                                    children: [
                                      ArtworkWidget(
                                        key: UniqueKey(),
                                        thumbnailSize: thumbnailSize / 2,
                                        path: paths.elementAt(0),
                                        forceSquared: true,
                                        blur: 0,
                                        borderRadius: 0,
                                        iconSize: iconSize - 2.0,
                                        width: c.maxWidth / 2,
                                        height: c.maxHeight / 2,
                                      ),
                                      ArtworkWidget(
                                        key: UniqueKey(),
                                        thumbnailSize: thumbnailSize / 2,
                                        path: paths.elementAt(1),
                                        forceSquared: true,
                                        blur: 0,
                                        borderRadius: 0,
                                        iconSize: iconSize - 2.0,
                                        width: c.maxWidth / 2,
                                        height: c.maxHeight / 2,
                                      ),
                                    ],
                                  ),
                                  Column(
                                    children: [
                                      ArtworkWidget(
                                        key: UniqueKey(),
                                        thumbnailSize: thumbnailSize / 2,
                                        path: paths.elementAt(2),
                                        forceSquared: true,
                                        blur: 0,
                                        borderRadius: 0,
                                        iconSize: iconSize,
                                        width: c.maxWidth / 2,
                                        height: c.maxHeight,
                                      ),
                                    ],
                                  ),
                                ],
                              )
                            : Column(
                                children: [
                                  Row(
                                    children: [
                                      ArtworkWidget(
                                        key: UniqueKey(),
                                        thumbnailSize: thumbnailSize / 2,
                                        path: paths.elementAt(0),
                                        forceSquared: true,
                                        blur: 0,
                                        borderRadius: 0,
                                        iconSize: iconSize - 3.0,
                                        width: c.maxWidth / 2,
                                        height: c.maxHeight / 2,
                                      ),
                                      ArtworkWidget(
                                        key: UniqueKey(),
                                        thumbnailSize: thumbnailSize / 2,
                                        path: paths.elementAt(1),
                                        forceSquared: true,
                                        blur: 0,
                                        borderRadius: 0,
                                        iconSize: iconSize - 3.0,
                                        width: c.maxWidth / 2,
                                        height: c.maxHeight / 2,
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      ArtworkWidget(
                                        key: UniqueKey(),
                                        thumbnailSize: thumbnailSize / 2,
                                        path: paths.elementAt(2),
                                        forceSquared: true,
                                        blur: 0,
                                        borderRadius: 0,
                                        iconSize: iconSize - 3.0,
                                        width: c.maxWidth / 2,
                                        height: c.maxHeight / 2,
                                      ),
                                      ArtworkWidget(
                                        key: UniqueKey(),
                                        thumbnailSize: thumbnailSize / 2,
                                        path: paths.elementAt(3),
                                        forceSquared: true,
                                        blur: 0,
                                        borderRadius: 0,
                                        iconSize: iconSize - 3.0,
                                        width: c.maxWidth / 2,
                                        height: c.maxHeight / 2,
                                      ),
                                    ],
                                  ),
                                ],
                              );
          },
        ),
      ),
    );
  }
}
