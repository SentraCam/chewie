import 'package:chewie/src/chewie_player.dart';
import 'package:chewie/src/helpers/adaptive_controls.dart';
import 'package:chewie/src/notifiers/index.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

class PlayerWithControls extends StatefulWidget {
  const PlayerWithControls({super.key, this.overlayBuilder});
  final Widget Function(BuildContext context, Size? size)? overlayBuilder;

  @override
  State<PlayerWithControls> createState() => _PlayerWithControlsState();
}

class _PlayerWithControlsState extends State<PlayerWithControls> {
  final GlobalKey _videoKey = GlobalKey();
  bool _isFullScreen = false;
  bool _isPlaying = false;
  ChewieController? _chewieController;
  final ValueNotifier<Size> notifier = ValueNotifier(const Size(0, 0));

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _chewieController = ChewieController.of(context);
      _chewieController!.addListener(_rebuild);
      _rebuild();
    });
    super.initState();
  }

  @override
  void dispose() {
    _chewieController?.removeListener(_rebuild);
    super.dispose();
  }

  _rebuild() {
    if (!mounted || _chewieController == null) return;
    _isPlaying = _chewieController!.videoPlayerController.value.isPlaying;

    if (_chewieController!.isFullScreen != _isFullScreen) {
      _isFullScreen = _chewieController!.isFullScreen;

      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {});
        }
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (_isPlaying) {
            _chewieController!.play();
          }
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ChewieController chewieController = ChewieController.of(context);

    double calculateAspectRatio(BuildContext context) {
      final size = MediaQuery.of(context).size;
      final width = size.width;
      final height = size.height;

      return width > height ? width / height : height / width;
    }

    Widget buildOverlay(BuildContext context) {
      if (widget.overlayBuilder != null) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) {
            notifier.value =
                (_videoKey.currentContext!.findRenderObject() as RenderBox)
                    .size;
          },
        );

        return ValueListenableBuilder(
          valueListenable: notifier,
          builder: (context, value, child) {
            return widget.overlayBuilder!(context, value);
          },
        );
      } else if (chewieController.overlay != null) {
        return chewieController.overlay!;
      }
      return const SizedBox.shrink();
    }

    Widget buildControls(
      BuildContext context,
      ChewieController chewieController,
    ) {
      return chewieController.showControls
          ? chewieController.customControls ?? const AdaptiveControls()
          : const SizedBox();
    }

    Widget buildPlayerWithControls(
        ChewieController chewieController, BuildContext context) {
      return Stack(
        children: <Widget>[
          if (chewieController.placeholder != null)
            chewieController.placeholder!,
          InteractiveViewer(
            transformationController: chewieController.transformationController,
            maxScale: chewieController.maxScale,
            panEnabled: chewieController.zoomAndPan,
            scaleEnabled: chewieController.zoomAndPan,
            child: Center(
              child: AspectRatio(
                aspectRatio: chewieController.aspectRatio ??
                    chewieController.videoPlayerController.value.aspectRatio,
                child: VideoPlayer(
                  chewieController.videoPlayerController,
                  key: _videoKey,
                ),
              ),
            ),
          ),
          Center(child: buildOverlay(context)),
          if (Theme.of(context).platform != TargetPlatform.iOS)
            Consumer<PlayerNotifier>(
              builder: (
                BuildContext context,
                PlayerNotifier notifier,
                Widget? widget,
              ) =>
                  Visibility(
                visible: !notifier.hideStuff,
                child: AnimatedOpacity(
                  opacity: notifier.hideStuff ? 0.0 : 0.8,
                  duration: const Duration(
                    milliseconds: 250,
                  ),
                  child: const DecoratedBox(
                    decoration: BoxDecoration(color: Colors.black54),
                    child: SizedBox.expand(),
                  ),
                ),
              ),
            ),
          if (!chewieController.isFullScreen)
            buildControls(context, chewieController)
          else
            SafeArea(
              bottom: false,
              child: buildControls(context, chewieController),
            ),
        ],
      );
    }

    return LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
      return Center(
        child: SizedBox(
          height: constraints.maxHeight,
          width: constraints.maxWidth,
          child: AspectRatio(
            aspectRatio: calculateAspectRatio(context),
            child: buildPlayerWithControls(chewieController, context),
          ),
        ),
      );
    });
  }
}
