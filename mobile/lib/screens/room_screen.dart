import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../core/app_theme.dart';
import '../models/room.dart';
import '../services/media_service.dart';
import '../services/room_socket.dart';
import '../services/subtitle_service.dart';
import '../widgets/syncroom_logo.dart';

class RoomScreen extends StatefulWidget {
  final Room room;
  final String userId;
  final String displayName;
  final bool isHost;
  final String? localSource;

  const RoomScreen({
    super.key,
    required this.room,
    required this.userId,
    required this.displayName,
    required this.isHost,
    this.localSource,
  });

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  final socket = RoomSocket();
  final media = MediaService();
  final subtitleService = SubtitleService();
  final chat = TextEditingController();
  final chatFocus = FocusNode();
  final List<Map<String, dynamic>> messages = [];
  final List<Map<String, dynamic>> members = [];

  YoutubePlayerController? yt;
  VideoPlayerController? local;
  MediaStream? broadcastStream;
  final RTCVideoRenderer localScreenRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  final Map<String, RTCPeerConnection> peers = {};
  final Map<String, List<RTCIceCandidate>> pendingIce = {};
  StreamSubscription? eventSub;

  bool broadcasting = false;
  bool remoteConnected = false;
  bool micEnabled = true;
  SubtitleTrack? subtitleTrack;
  bool subtitlesEnabled = true;

  bool get isRealtimeMedia =>
      widget.room.sourceType == MediaSourceType.local ||
      widget.room.sourceType == MediaSourceType.screenShare;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    await localScreenRenderer.initialize();
    await remoteRenderer.initialize();
    await _initPlayer();
    if (!mounted) return;
    eventSub = socket.events.listen(_onEvent);
    await socket.connect(
      code: widget.room.code,
      userId: widget.userId,
      name: widget.displayName,
      isHost: widget.isHost,
    );
  }

  String? _youtubeId(String? raw) {
    if (raw == null) return null;
    return YoutubePlayerController.convertUrlToId(raw);
  }

  Future<void> _initPlayer() async {
    if (widget.room.sourceType == MediaSourceType.youtube) {
      final id = _youtubeId(widget.room.sourceValue);
      if (id != null) {
        yt = YoutubePlayerController.fromVideoId(
          videoId: id,
          autoPlay: false,
          params: const YoutubePlayerParams(
            showControls: true,
            showFullscreenButton: true,
            enableCaption: true,
            privacyEnhancedMode: true,
          ),
        );
        if (mounted) setState(() {});
      }
      return;
    }

    if (widget.room.sourceType == MediaSourceType.local &&
        widget.isHost &&
        widget.localSource != null) {
      try {
        local = await media.openLocalSource(widget.localSource!);
        local!.addListener(() {
          if (mounted) setState(() {});
        });
        if (mounted) setState(() {});
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Local video ochilmadi: $e')),
          );
        }
      }
    }
  }

  Future<double> _position() async {
    if (yt != null) return yt!.currentTime;
    return (local?.value.position.inMilliseconds ?? 0) / 1000;
  }

  Future<void> _onEvent(Map<String, dynamic> event) async {
    final type = event['type'];
    final payload =
        (event['payload'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};

    if (type == 'members.snapshot') {
      if (mounted) {
        setState(() {
          members
            ..clear()
            ..addAll(
              (payload['members'] as List? ?? [])
                  .map((v) => (v as Map).cast<String, dynamic>()),
            );
        });
      }
      if (!widget.isHost && isRealtimeMedia) {
        socket.send('rtc.viewer.ready', {'targetUserId': widget.room.hostUserId});
      }
      if (widget.isHost && broadcasting) {
        for (final member in members) {
          final id = member['userId'] as String?;
          final isHost = member['isHost'] == true;
          if (id != null && !isHost) _createHostOffer(id);
        }
      }
      return;
    }

    if (type == 'member.left') {
      final userId = payload['userId'] as String?;
      final pc = userId == null ? null : peers.remove(userId);
      await pc?.close();
      pendingIce.remove(userId);
      return;
    }

    if (type == 'chat.message') {
      if (mounted) setState(() => messages.add(payload));
      return;
    }

    if (type == 'reaction') {
      if (!mounted) return;
      final emoji = payload['emoji'] ?? '❤️';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${payload['name'] ?? 'Someone'}  $emoji'),
          duration: const Duration(milliseconds: 900),
        ),
      );
      return;
    }

    if (!widget.isHost &&
        (type == 'sync.play' ||
            type == 'sync.pause' ||
            type == 'sync.seek' ||
            type == 'state.snapshot')) {
      final state = type == 'state.snapshot'
          ? ((payload['playback'] as Map?)?.cast<String, dynamic>() ?? payload)
          : payload;
      final pos = (state['position'] as num?)?.toDouble() ?? 0;
      if (yt != null) {
        await yt!.seekTo(seconds: pos, allowSeekAhead: true);
        if (type == 'sync.play' || state['playing'] == true) {
          await yt!.playVideo();
        } else if (type == 'sync.pause' || state['playing'] == false) {
          await yt!.pauseVideo();
        }
      }
      return;
    }

    if (type == 'screen.started' && !widget.isHost && isRealtimeMedia) {
      socket.send('rtc.viewer.ready', {'targetUserId': widget.room.hostUserId});
      return;
    }

    if (type == 'rtc.viewer.ready' && widget.isHost && broadcasting) {
      final viewerId = payload['fromUserId'] as String?;
      if (viewerId != null) await _createHostOffer(viewerId);
      return;
    }

    if (type == 'rtc.offer' && !widget.isHost) {
      await _acceptOffer(payload);
      return;
    }

    if (type == 'rtc.answer' && widget.isHost) {
      await _acceptAnswer(payload);
      return;
    }

    if (type == 'rtc.ice') {
      await _acceptIce(payload);
      return;
    }
  }

  Future<RTCPeerConnection> _newPeer(String remoteUserId, {required bool sender}) async {
    final existing = peers[remoteUserId];
    if (existing != null) return existing;

    final pc = await createPeerConnection({
      'iceServers': [
        {
          'urls': ['stun:stun.l.google.com:19302'],
        },
      ],
      'sdpSemantics': 'unified-plan',
    });

    pc.onIceCandidate = (candidate) {
      if (candidate.candidate == null) return;
      socket.send('rtc.ice', {
        'targetUserId': remoteUserId,
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    };

    pc.onConnectionState = (state) {
      if (!mounted) return;
      if (!sender) {
        setState(() => remoteConnected =
            state == RTCPeerConnectionState.RTCPeerConnectionStateConnected);
      }
    };

    if (sender && broadcastStream != null) {
      for (final track in broadcastStream!.getTracks()) {
        await pc.addTrack(track, broadcastStream!);
      }
    } else {
      pc.onTrack = (event) {
        if (event.streams.isNotEmpty) {
          remoteRenderer.srcObject = event.streams.first;
          if (mounted) setState(() => remoteConnected = true);
        }
      };
    }

    peers[remoteUserId] = pc;
    return pc;
  }

  Future<void> _flushIce(String remoteUserId, RTCPeerConnection pc) async {
    final queued = pendingIce.remove(remoteUserId) ?? <RTCIceCandidate>[];
    for (final candidate in queued) {
      try {
        await pc.addCandidate(candidate);
      } catch (_) {
        (pendingIce[remoteUserId] ??= []).add(candidate);
      }
    }
  }

  Future<void> _createHostOffer(String viewerId) async {
    if (!widget.isHost || broadcastStream == null) return;
    if (peers.containsKey(viewerId)) return;
    final pc = await _newPeer(viewerId, sender: true);
    final offer = await pc.createOffer();
    await pc.setLocalDescription(offer);
    socket.send('rtc.offer', {
      'targetUserId': viewerId,
      'sdp': offer.sdp,
      'descriptionType': offer.type,
    });
  }

  Future<void> _acceptOffer(Map<String, dynamic> payload) async {
    final hostId = payload['fromUserId'] as String? ?? widget.room.hostUserId;
    final sdp = payload['sdp'] as String?;
    final descriptionType = payload['descriptionType'] as String?;
    if (sdp == null || descriptionType == null) return;

    final old = peers.remove(hostId);
    await old?.close();
    final pc = await _newPeer(hostId, sender: false);
    await pc.setRemoteDescription(RTCSessionDescription(sdp, descriptionType));
    await _flushIce(hostId, pc);
    final answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);
    socket.send('rtc.answer', {
      'targetUserId': hostId,
      'sdp': answer.sdp,
      'descriptionType': answer.type,
    });
  }

  Future<void> _acceptAnswer(Map<String, dynamic> payload) async {
    final viewerId = payload['fromUserId'] as String?;
    final sdp = payload['sdp'] as String?;
    final descriptionType = payload['descriptionType'] as String?;
    if (viewerId == null || sdp == null || descriptionType == null) return;
    final pc = peers[viewerId];
    if (pc == null) return;
    await pc.setRemoteDescription(RTCSessionDescription(sdp, descriptionType));
    await _flushIce(viewerId, pc);
  }

  Future<void> _acceptIce(Map<String, dynamic> payload) async {
    final fromUserId = payload['fromUserId'] as String?;
    final candidateText = payload['candidate'] as String?;
    if (fromUserId == null || candidateText == null) return;
    final candidate = RTCIceCandidate(
      candidateText,
      payload['sdpMid'] as String?,
      (payload['sdpMLineIndex'] as num?)?.toInt(),
    );
    final pc = peers[fromUserId];
    if (pc == null) {
      (pendingIce[fromUserId] ??= []).add(candidate);
      return;
    }
    try {
      await pc.addCandidate(candidate);
    } catch (_) {
      (pendingIce[fromUserId] ??= []).add(candidate);
    }
  }

  Future<void> _togglePlay() async {
    if (!widget.isHost) return;
    final pos = await _position();
    if (yt != null) {
      final state = await yt!.playerState;
      final playing = state == PlayerState.playing;
      if (playing) {
        await yt!.pauseVideo();
        socket.pause(pos);
      } else {
        await yt!.playVideo();
        socket.play(pos);
      }
    } else if (local != null) {
      if (local!.value.isPlaying) {
        await local!.pause();
        socket.pause(pos);
      } else {
        await local!.play();
        socket.play(pos);
      }
    }
  }

  Future<void> _seekBy(int seconds) async {
    if (!widget.isHost) return;
    final current = await _position();
    final next = (current + seconds).clamp(0, 999999).toDouble();
    if (yt != null) {
      await yt!.seekTo(seconds: next, allowSeekAhead: true);
    }
    if (local != null) {
      await local!.seekTo(Duration(milliseconds: (next * 1000).round()));
    }
    socket.seek(next);
  }

  Future<void> _startBroadcast() async {
    if (!widget.isHost || broadcasting) return;
    try {
      broadcastStream = await media.startScreenShare();
      localScreenRenderer.srcObject = broadcastStream;
      setState(() => broadcasting = true);
      socket.send('screen.started', {});
      for (final member in members) {
        final id = member['userId'] as String?;
        if (id != null && member['isHost'] != true) {
          await _createHostOffer(id);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Broadcast boshlanmadi: $e')),
        );
      }
    }
  }

  Future<void> _stopBroadcast() async {
    for (final pc in peers.values) {
      await pc.close();
    }
    peers.clear();
    for (final track in broadcastStream?.getTracks() ?? <MediaStreamTrack>[]) {
      await track.stop();
    }
    broadcastStream = null;
    localScreenRenderer.srcObject = null;
    await media.stopScreenShare();
    if (mounted) setState(() => broadcasting = false);
  }

  void _toggleMic() {
    final tracks = broadcastStream?.getAudioTracks() ?? const <MediaStreamTrack>[];
    if (tracks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Current broadcast has no audio track.')),
      );
      return;
    }
    setState(() => micEnabled = !micEnabled);
    for (final track in tracks) {
      track.enabled = micEnabled;
    }
  }

  void _sendChat() {
    final text = chat.text.trim();
    if (text.isEmpty) return;
    socket.chat(text);
    chat.clear();
  }

  @override
  void dispose() {
    eventSub?.cancel();
    socket.close();
    chat.dispose();
    chatFocus.dispose();
    yt?.close();
    local?.dispose();
    for (final pc in peers.values) {
      pc.close();
    }
    for (final track in broadcastStream?.getTracks() ?? <MediaStreamTrack>[]) {
      track.stop();
    }
    media.stopScreenShare();
    localScreenRenderer.dispose();
    remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
              child: Row(
                children: [
                  const SyncRoomLogo(size: 42, showText: true),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      widget.room.code,
                      style: const TextStyle(
                        letterSpacing: 2.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            _player(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.room.name,
                              style: const TextStyle(
                                fontSize: 27,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '${members.isEmpty ? 1 : members.length} watching  •  Host: ${widget.room.hostName}',
                              style: const TextStyle(color: AppColors.muted),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: widget.room.code));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Room code copied')),
                          );
                        },
                        icon: const Icon(Icons.link_rounded),
                        label: const Text('Invite'),
                      ),
                    ],
                  ),
                  if (widget.isHost && isRealtimeMedia) ...[
                    const SizedBox(height: 14),
                    _BroadcastStatus(
                      broadcasting: broadcasting,
                      onStart: _startBroadcast,
                      onStop: _stopBroadcast,
                    ),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 76,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemBuilder: (_, i) {
                        final m = members.isEmpty
                            ? {'name': widget.displayName, 'isHost': widget.isHost}
                            : members[i];
                        return Column(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: const Color(0xFF172448),
                              child: Text(
                                _initial(m['name'] as String? ?? '?'),
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              m['name'] as String? ?? '?',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        );
                      },
                      separatorBuilder: (_, __) => const SizedBox(width: 14),
                      itemCount: members.isEmpty ? 1 : members.length,
                    ),
                  ),
                  const Divider(color: AppColors.border, height: 26),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _Action(
                        icon: Icons.chat_bubble_outline_rounded,
                        label: 'Chat',
                        onTap: () => chatFocus.requestFocus(),
                      ),
                      _Action(
                        icon: Icons.favorite_border_rounded,
                        label: 'Reaction',
                        onTap: _reactionSheet,
                      ),
                      _Action(
                        icon: micEnabled ? Icons.mic_none_rounded : Icons.mic_off_rounded,
                        label: 'Mic',
                        onTap: _toggleMic,
                      ),
                      _Action(
                        icon: Icons.closed_caption_rounded,
                        label: 'Subtitles',
                        onTap: _subtitleInfo,
                      ),
                      _Action(
                        icon: Icons.more_horiz_rounded,
                        label: 'More',
                        onTap: _moreSheet,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _chatPanel(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _player() {
    Widget content;
    if (!widget.isHost && isRealtimeMedia && remoteRenderer.srcObject != null) {
      content = RTCVideoView(
        remoteRenderer,
        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
      );
    } else if (widget.room.sourceType == MediaSourceType.screenShare &&
        widget.isHost &&
        broadcasting) {
      content = RTCVideoView(
        localScreenRenderer,
        mirror: false,
        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
      );
    } else if (yt != null) {
      content = YoutubePlayer(controller: yt!, aspectRatio: 16 / 9);
    } else if (local != null && local!.value.isInitialized) {
      final subtitle = subtitlesEnabled && subtitleTrack != null
          ? subtitleTrack!.textAt(local!.value.position)
          : '';
      content = AspectRatio(
        aspectRatio: local!.value.aspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            VideoPlayer(local!),
            if (subtitle.isNotEmpty)
              Align(
                alignment: const Alignment(0, 0.86),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 22),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.72), borderRadius: BorderRadius.circular(8)),
                  child: Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, shadows: [Shadow(blurRadius: 3, color: Colors.black)])),
                ),
              ),
          ],
        ),
      );
    } else {
      content = Container(
        color: const Color(0xFF071020),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.room.sourceType == MediaSourceType.local
                    ? Icons.movie_rounded
                    : Icons.screen_share_rounded,
                size: 48,
                color: AppColors.indigo,
              ),
              const SizedBox(height: 10),
              Text(
                widget.isHost
                    ? 'Preparing media…'
                    : remoteConnected
                        ? 'Connected'
                        : 'Waiting for host broadcast…',
                style: const TextStyle(color: AppColors.muted),
              ),
            ],
          ),
        ),
      );
    }

    final showPlaybackControls =
        widget.room.sourceType == MediaSourceType.youtube ||
        (widget.room.sourceType == MediaSourceType.local && widget.isHost);

    return Column(
      children: [
        AspectRatio(aspectRatio: 16 / 9, child: content),
        Container(
          color: const Color(0xFF050A15),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: Row(
            children: [
              IconButton(
                onPressed: widget.isHost && showPlaybackControls ? _togglePlay : null,
                icon: Icon(
                  local?.value.isPlaying == true ? Icons.pause_rounded : Icons.play_arrow_rounded,
                ),
              ),
              if (isRealtimeMedia)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 4,
                        backgroundColor: remoteConnected || broadcasting
                            ? AppColors.success
                            : AppColors.muted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        widget.isHost
                            ? (broadcasting ? 'Broadcasting' : 'Not broadcasting')
                            : (remoteConnected ? 'Live' : 'Connecting'),
                        style: const TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              const Spacer(),
              IconButton(
                onPressed: widget.isHost && showPlaybackControls
                    ? () => _seekBy(-10)
                    : null,
                icon: const Icon(Icons.replay_10_rounded),
              ),
              IconButton(
                onPressed: widget.isHost && showPlaybackControls
                    ? () => _seekBy(10)
                    : null,
                icon: const Icon(Icons.forward_10_rounded),
              ),
              IconButton(
                onPressed: yt != null ? () => yt!.toggleFullScreen() : null,
                icon: const Icon(Icons.fullscreen_rounded),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _chatPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Live Chat',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 8),
              const CircleAvatar(radius: 4, backgroundColor: AppColors.success),
              const SizedBox(width: 5),
              Text(
                '${members.isEmpty ? 1 : members.length} watching',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (messages.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Room chat is ready. Say hello 👋',
                style: TextStyle(color: AppColors.muted),
              ),
            ),
          ...messages.take(8).map(
                (m) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: const Color(0xFF1A2850),
                        child: Text(_initial(m['name'] as String? ?? '?')),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.card2,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(m['text'] as String? ?? ''),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: chat,
                  focusNode: chatFocus,
                  onSubmitted: (_) => _sendChat(),
                  decoration: const InputDecoration(
                    hintText: 'Type a message...',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _sendChat,
                icon: const Icon(Icons.send_rounded),
                style: IconButton.styleFrom(backgroundColor: AppColors.indigo),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _reactionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['❤️', '😂', '😱', '🔥', '👏']
                .map(
                  (emoji) => InkWell(
                    onTap: () {
                      socket.reaction(emoji);
                      Navigator.pop(context);
                    },
                    child: Text(emoji, style: const TextStyle(fontSize: 36)),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  void _subtitleInfo() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            const ListTile(
              leading: Icon(Icons.closed_caption_rounded, color: AppColors.indigo),
              title: Text('Subtitles', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
            if (widget.room.sourceType == MediaSourceType.youtube)
              const ListTile(
                leading: Icon(Icons.smart_display_rounded),
                title: Text('YouTube captions'),
                subtitle: Text('Use the CC control inside the YouTube player.'),
              ),
            if (widget.room.sourceType == MediaSourceType.local && widget.isHost) ...[
              ListTile(
                leading: const Icon(Icons.subtitles_rounded),
                title: Text(subtitleTrack == null ? 'Choose .srt file' : subtitleTrack!.name),
                subtitle: Text(subtitleTrack == null ? 'Load a local SRT subtitle track' : '${subtitleTrack!.cues.length} subtitle cues loaded'),
                onTap: () async {
                  final track = await subtitleService.pickSrt();
                  if (track != null && mounted) setState(() { subtitleTrack = track; subtitlesEnabled = true; });
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                },
              ),
              if (subtitleTrack != null)
                SwitchListTile(
                  secondary: const Icon(Icons.visibility_rounded),
                  title: const Text('Show subtitles'),
                  value: subtitlesEnabled,
                  onChanged: (value) { setState(() => subtitlesEnabled = value); Navigator.pop(sheetContext); },
                ),
            ],
            if (widget.room.sourceType == MediaSourceType.local && !widget.isHost)
              const ListTile(
                leading: Icon(Icons.info_outline_rounded),
                title: Text('Host subtitles'),
                subtitle: Text('Local subtitles are rendered by the host and appear inside the shared movie stream.'),
              ),
            if (widget.room.sourceType == MediaSourceType.screenShare)
              const ListTile(
                leading: Icon(Icons.info_outline_rounded),
                title: Text('Shared-screen subtitles'),
                subtitle: Text('Any subtitles visible on the host screen are included in the shared view.'),
              ),
          ],
        ),
      ),
    );
  }

  void _moreSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('Copy room code'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: widget.room.code));
                Navigator.pop(context);
              },
            ),
            if (widget.isHost && isRealtimeMedia)
              ListTile(
                leading: Icon(broadcasting ? Icons.stop_circle_outlined : Icons.cast_rounded),
                title: Text(broadcasting ? 'Stop broadcast' : 'Start broadcast'),
                onTap: () {
                  Navigator.pop(context);
                  broadcasting ? _stopBroadcast() : _startBroadcast();
                },
              ),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: AppColors.danger),
              title: const Text('Leave room'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _BroadcastStatus extends StatelessWidget {
  final bool broadcasting;
  final VoidCallback onStart;
  final VoidCallback onStop;

  const _BroadcastStatus({
    required this.broadcasting,
    required this.onStart,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 6,
            backgroundColor: broadcasting ? AppColors.success : AppColors.muted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  broadcasting ? 'Live broadcast is active' : 'Ready to broadcast',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  broadcasting
                      ? 'Remote members receive your shared app/screen over WebRTC.'
                      : 'Start once to share this local movie/app screen with the room.',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filledTonal(
            onPressed: broadcasting ? onStop : onStart,
            icon: Icon(broadcasting ? Icons.stop_rounded : Icons.cast_rounded),
          ),
        ],
      ),
    );
  }
}

String _initial(String value) {
  final v = value.trim();
  return v.isEmpty ? '?' : v.substring(0, 1).toUpperCase();
}

class _Action extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _Action({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(7),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.card,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(icon, color: AppColors.muted),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}
