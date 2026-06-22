//
//  story_viewer_view.dart
//
//  Full-screen story player ("动态" / Stories). Black canvas with segmented
//  progress bars, a compact header (avatar + name + close), the current story's
//  media (photo, or a video thumbnail with a play overlay), and an optional
//  caption. Left third taps go back, right two-thirds advance; running off
//  either end dismisses. Port of the Swift `StoryViewerView`.
//

import 'package:flutter/material.dart';

import '../components/photo_avatar.dart';
import '../components/sf_symbols.dart';
import '../tdlib/json_helpers.dart';
import '../tdlib/td_client.dart';
import '../tdlib/td_models.dart';

class _StoryMedia {
  _StoryMedia(this.imageFile, this.caption, this.isVideo);
  final TdFileRef? imageFile;
  final String caption;
  final bool isVideo;
}

class StoryViewerView extends StatefulWidget {
  const StoryViewerView({
    super.key,
    required this.chatId,
    required this.storyIds,
  });
  final int chatId;
  final List<int> storyIds;

  @override
  State<StoryViewerView> createState() => _StoryViewerViewState();
}

class _StoryViewerViewState extends State<StoryViewerView> {
  int _index = 0;
  String _senderName = '动态';
  TdFileRef? _senderPhoto;
  _StoryMedia? _current;

  @override
  void initState() {
    super.initState();
    _resolveSender();
    _load(0);
  }

  Future<void> _resolveSender() async {
    try {
      final chat = await TdClient.shared.query({
        '@type': 'getChat',
        'chat_id': widget.chatId,
      });
      if (!mounted) return;
      setState(() {
        final t = chat.str('title');
        if (t != null && t.isNotEmpty) _senderName = t;
        _senderPhoto = TDParse.smallPhoto(chat.obj('photo'));
      });
    } catch (_) {}
  }

  Future<void> _load(int index) async {
    if (index < 0 || index >= widget.storyIds.length) return;
    final sid = widget.storyIds[index];
    setState(() => _current = null);

    // Mark the story as viewed (best-effort).
    TdClient.shared.send({
      '@type': 'openStory',
      'story_sender_chat_id': widget.chatId,
      'story_id': sid,
    });

    try {
      final story = await TdClient.shared.query({
        '@type': 'getStory',
        'story_sender_chat_id': widget.chatId,
        'story_id': sid,
        'only_local': false,
      });
      final content = story.obj('content');
      final caption = story.obj('caption')?.str('text') ?? '';
      TdFileRef? imageFile;
      var isVideo = false;
      switch (content?.type) {
        case 'storyContentPhoto':
          final photo = content?.obj('photo');
          final sizes = photo?.objects('sizes');
          final best = (sizes != null && sizes.isNotEmpty)
              ? sizes.reduce(
                  (a, b) =>
                      (a.integer('width') ?? 0) >= (b.integer('width') ?? 0)
                      ? a
                      : b,
                )
              : null;
          imageFile = TDParse.fileRef(
            best?.obj('photo'),
            miniThumb: TDParse.decodeMiniThumb(photo?.obj('minithumbnail')),
          );
        case 'storyContentVideo':
          final video = content?.obj('video');
          imageFile = TDParse.fileRef(video?.obj('thumbnail')?.obj('file'));
          isVideo = true;
      }
      if (!mounted || _index != index) return;
      setState(() => _current = _StoryMedia(imageFile, caption, isVideo));
    } catch (_) {}
  }

  void _goPrevious() {
    if (_index > 0) {
      setState(() => _index--);
      _load(_index);
    } else {
      Navigator.of(context).pop();
    }
  }

  void _goNext() {
    if (_index < widget.storyIds.length - 1) {
      setState(() => _index++);
      _load(_index);
    } else {
      Navigator.of(context).pop();
    }
  }

  double _fill(int i) => i < _index ? 1 : (i == _index ? 0.7 : 0);

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Column(
            children: [
              SizedBox(height: top + 12),
              // Progress bars
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  children: [
                    for (var i = 0; i < widget.storyIds.length; i++)
                      Expanded(
                        child: Container(
                          height: 2.5,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: _fill(i),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                child: Row(
                  children: [
                    PhotoAvatar(
                      title: _senderName,
                      photo: _senderPhoto,
                      size: 34,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _senderName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: const SizedBox(
                        width: 36,
                        height: 36,
                        child: Icon(Icons.close, size: 22, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              _media(),
              const Spacer(),
              if (_current != null && _current!.caption.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _current!.caption,
                      style: const TextStyle(fontSize: 15, color: Colors.white),
                    ),
                  ),
                ),
              SizedBox(height: MediaQuery.of(context).padding.bottom),
            ],
          ),
          // Tap zones: left third = prev, right two-thirds = next.
          Positioned.fill(
            top: top + 96,
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _goPrevious,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: _goNext,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _media() {
    final story = _current;
    if (story?.imageFile == null) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation(Colors.white),
        ),
      );
    }
    return Stack(
      alignment: Alignment.center,
      children: [
        TDImage(photo: story!.imageFile, cornerRadius: 0, fit: BoxFit.contain),
        if (story.isVideo)
          Container(
            width: 70,
            height: 70,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              shape: BoxShape.circle,
            ),
            child: Icon(sfIcon('play.fill'), size: 30, color: Colors.white),
          ),
      ],
    );
  }
}
