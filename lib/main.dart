import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:on_audio_query_pluse/on_audio_query.dart';
import 'package:shared_preferences/shared_preferences.dart';

const purple = Color(0xFFB57BFF);
const surface = Color(0xFF171022);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'org.opensic.player.audio',
    androidNotificationChannelName: 'Opensic playback',
    androidNotificationOngoing: true,
  );
  runApp(const OpensicApp());
}

class Track {
  final String id, title, artist, uri;
  final int? localId;
  const Track(this.id, this.title, this.artist, this.uri, {this.localId});
  bool get isLocal => localId != null;
  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'artist': artist, 'uri': uri, 'localId': localId};
  factory Track.fromJson(Map<String, dynamic> j) => Track(j['id'] as String, j['title'] as String,
      j['artist'] as String, j['uri'] as String, localId: j['localId'] as int?);
}

class OpensicApp extends StatelessWidget {
  const OpensicApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Opensic', debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0D0913),
      colorScheme: ColorScheme.fromSeed(seedColor: purple, brightness: Brightness.dark),
      appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent)),
    home: const HomePage(),
  );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final query = OnAudioQuery();
  final player = AudioPlayer();
  final search = TextEditingController();
  final streamUrl = TextEditingController();
  final streamTitle = TextEditingController();
  List<Track> local = [], online = [], queue = [];
  Map<String, List<String>> playlists = {};
  Set<String> liked = {};
  int tab = 0;
  bool loading = true;
  String? error;
  Track? current;
  int currentIndex = 0;
  bool shuffleEnabled = false;
  LoopMode repeatMode = LoopMode.off;

  @override
  void initState() {
    super.initState();
    search.addListener(_refresh);
    player.currentIndexStream.listen((index) {
      if (!mounted || index == null || index >= queue.length) return;
      setState(() { currentIndex = index; current = queue[index]; });
    });
    load();
  }

  void _refresh() { if (mounted) setState(() {}); }
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final allowed = await query.permissionsStatus() || await query.permissionsRequest();
      final songs = allowed ? await query.querySongs(sortType: SongSortType.TITLE,
        orderType: OrderType.ASC_OR_SMALLER, uriType: UriType.EXTERNAL) : <SongModel>[];
      if (!mounted) return;
      setState(() {
        local = songs.where((s) => s.uri != null).map((s) => Track('local:${s.id}', s.title,
          s.artist ?? 'Unknown artist', s.uri!, localId: s.id)).toList();
        liked = (prefs.getStringList('liked') ?? []).toSet();
        online = (prefs.getStringList('streams') ?? []).map((s) => Track.fromJson(jsonDecode(s) as Map<String, dynamic>)).toList();
        final saved = prefs.getString('playlists');
        if (saved != null) {
          final decoded = jsonDecode(saved) as Map<String, dynamic>;
          playlists = decoded.map((k, v) => MapEntry(k, List<String>.from(v as List)));
        }
        loading = false;
        error = allowed ? null : 'Music permission denied. Enable audio access in Android settings.';
      });
    } catch (e) { if (mounted) setState(() { loading = false; error = '$e'; }); }
  }

  Future<void> persist() async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList('liked', liked.toList());
    await p.setStringList('streams', online.map((t) => jsonEncode(t.toJson())).toList());
    await p.setString('playlists', jsonEncode(playlists));
  }

  List<Track> get all => [...local, ...online];
  Track? byId(String id) { for (final t in all) { if (t.id == id) return t; } return null; }
  AudioSource source(Track t) => AudioSource.uri(Uri.parse(t.uri), tag: MediaItem(
    id: t.id, title: t.title, artist: t.artist, album: t.isLocal ? 'On device' : 'Online stream'));

  Future<void> playTracks(List<Track> tracks, [int index = 0]) async {
    if (tracks.isEmpty || index < 0 || index >= tracks.length) return;
    try {
      setState(() { queue = List.of(tracks); currentIndex = index; current = tracks[index]; });
      await player.setAudioSource(ConcatenatingAudioSource(children: tracks.map(source).toList()), initialIndex: index);
      unawaited(player.play());
    } catch (e) { notify('Playback error: $e'); }
  }

  void notify(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  void toggleLike(Track t) { setState(() { if (!liked.add(t.id)) liked.remove(t.id); }); persist(); }

  Future<void> addStream() async {
    final uri = Uri.tryParse(streamUrl.text.trim());
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) { notify('Enter a valid HTTPS audio URL'); return; }
    final t = Track('stream:${DateTime.now().microsecondsSinceEpoch}',
      streamTitle.text.trim().isEmpty ? uri.host : streamTitle.text.trim(), 'Online audio', uri.toString());
    setState(() => online.add(t));
    await persist();
    streamTitle.clear(); streamUrl.clear();
    if (mounted) Navigator.pop(context);
    notify('Stream saved to your library');
  }

  Future<void> newPlaylist() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(context: context, builder: (c) => AlertDialog(
      title: const Text('New playlist'), content: TextField(controller: controller, autofocus: true,
        decoration: const InputDecoration(hintText: 'Playlist name')),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(c, controller.text.trim()), child: const Text('Create'))]));
    if (name == null || name.isEmpty) return;
    if (playlists.containsKey(name)) { notify('Playlist already exists'); return; }
    setState(() => playlists[name] = []);
    await persist();
  }

  Future<void> choosePlaylist(Track t) async {
    if (playlists.isEmpty) { notify('Create a playlist first'); return; }
    final name = await showModalBottomSheet<String>(context: context, builder: (c) => SafeArea(
      child: ListView(shrinkWrap: true, children: [const ListTile(title: Text('Add to playlist')),
        ...playlists.keys.map((name) => ListTile(title: Text(name), onTap: () => Navigator.pop(c, name)))])));
    if (name == null) return;
    setState(() { if (!playlists[name]!.contains(t.id)) playlists[name]!.add(t.id); });
    await persist(); notify('Added to $name');
  }

  void openStreamDialog() => showDialog(context: context, builder: (c) => AlertDialog(
    title: const Text('Add authorized stream'),
    content: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: streamTitle, decoration: const InputDecoration(labelText: 'Title')),
      TextField(controller: streamUrl, keyboardType: TextInputType.url,
        decoration: const InputDecoration(labelText: 'HTTPS audio URL')),
      const SizedBox(height: 10),
      const Text('Only add streams you have permission to access.', style: TextStyle(fontSize: 12, color: Colors.white54)),
    ]), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
      FilledButton(onPressed: addStream, child: const Text('Save'))]));

  Widget artwork(Track t, {double size = 52}) => ClipRRect(borderRadius: BorderRadius.circular(12),
    child: SizedBox(width: size, height: size, child: t.localId == null
      ? Container(color: const Color(0xFF35204C), child: const Icon(Icons.wifi_tethering, color: purple))
      : QueryArtworkWidget(id: t.localId!, type: ArtworkType.AUDIO, artworkFit: BoxFit.cover,
        nullArtworkWidget: Container(color: const Color(0xFF35204C), child: const Icon(Icons.music_note, color: purple)))));

  Widget trackTile(Track t, {List<Track>? contextQueue}) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
    leading: artwork(t), title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
    subtitle: Text(t.artist, maxLines: 1, overflow: TextOverflow.ellipsis,
      style: const TextStyle(color: Colors.white54)),
    onTap: () => playTracks(contextQueue ?? all, (contextQueue ?? all).indexWhere((x) => x.id == t.id)),
    trailing: PopupMenuButton<String>(icon: const Icon(Icons.more_vert), onSelected: (action) async {
      if (action == 'like') toggleLike(t);
      if (action == 'playlist') await choosePlaylist(t);
      if (action == 'queue') await enqueue(t);
    }, itemBuilder: (_) => [
      PopupMenuItem(value: 'like', child: Text(liked.contains(t.id) ? 'Unlike' : 'Like')),
      const PopupMenuItem(value: 'playlist', child: Text('Add to playlist')),
      const PopupMenuItem(value: 'queue', child: Text('Add to queue')),
    ]),
  );

  Future<void> enqueue(Track t) async {
    if (queue.isEmpty) { await playTracks([t]); return; }
    try {
      final updated = [...queue, t];
      final keepIndex = player.currentIndex ?? currentIndex;
      final position = player.position;
      final wasPlaying = player.playing;
      await player.setAudioSource(ConcatenatingAudioSource(children: updated.map(source).toList()), initialIndex: keepIndex, initialPosition: position);
      setState(() => queue = updated);
      if (wasPlaying) unawaited(player.play());
      notify('Added to queue');
    } catch (e) { notify('Unable to add to queue: $e'); }
  }

  Widget sectionTitle(String s) => Padding(padding: const EdgeInsets.fromLTRB(18, 22, 18, 10),
    child: Text(s, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold)));

  Widget homeView() => ListView(children: [
    Padding(padding: const EdgeInsets.fromLTRB(18, 12, 18, 4), child: Container(
      padding: const EdgeInsets.all(22), decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF62369B), Color(0xFF21132F)]),
        borderRadius: BorderRadius.circular(24)),
      child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.graphic_eq, size: 36, color: Colors.white), SizedBox(height: 12),
        Text('Your music. Your rules.', style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
        SizedBox(height: 6), Text('Local tracks + your authorized online streams', style: TextStyle(color: Colors.white70)),
      ]))),
    sectionTitle('Recently added'),
    if (all.isEmpty) const ListTile(title: Text('Your library is empty'), subtitle: Text('Add music files or an authorized stream.')),
    ...all.reversed.take(12).map((t) => trackTile(t)),
  ]);

  Widget libraryView() {
    final q = search.text.toLowerCase();
    final tracks = all.where((t) => '${t.title} ${t.artist}'.toLowerCase().contains(q)).toList();
    return Column(children: [
      Padding(padding: const EdgeInsets.all(14), child: TextField(controller: search,
        decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: 'Search your music',
          filled: true, fillColor: surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none)))),
      Expanded(child: ListView(children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 18), child: Text('${tracks.length} tracks', style: const TextStyle(color: Colors.white54))),
        ...tracks.map((t) => trackTile(t, contextQueue: tracks)),
      ])),
    ]);
  }

  Widget playlistView() => ListView(children: [
    ListTile(leading: const Icon(Icons.add_circle_outline, color: purple), title: const Text('Create playlist'), onTap: newPlaylist),
    ...playlists.entries.map((e) => ListTile(leading: const Icon(Icons.queue_music, color: purple),
      title: Text(e.key), subtitle: Text('${e.value.length} songs'),
      trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () async {
        setState(() => playlists.remove(e.key)); await persist();
      }), onTap: () {
        final tracks = e.value.map(byId).whereType<Track>().toList();
        Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
          appBar: AppBar(title: Text(e.key)), body: ListView(children: [
            ListTile(title: Text('${tracks.length} available tracks'),
              trailing: FilledButton(onPressed: tracks.isEmpty ? null : () => playTracks(tracks), child: const Text('Play all'))),
            ...tracks.map((t) => trackTile(t, contextQueue: tracks)),
          ]))));
      })),
  ]);

  Widget likedView() {
    final tracks = all.where((t) => liked.contains(t.id)).toList();
    return ListView(children: [sectionTitle('Liked songs'), ...tracks.map((t) => trackTile(t, contextQueue: tracks))]);
  }

  Widget miniPlayer() {
    final t = current;
    if (t == null) return const SizedBox.shrink();
    return Container(margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: const Color(0xFF39244F), borderRadius: BorderRadius.circular(17)),
      child: ListTile(onTap: () => openNowPlaying(), leading: artwork(t, size: 42),
        title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(t.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: StreamBuilder<PlayerState>(stream: player.playerStateStream, builder: (_, snapshot) => IconButton(
          onPressed: () => player.playing ? player.pause() : player.play(),
          icon: Icon(player.playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 30)))));
  }

  Future<void> toggleShuffle() async {
    final enabled = !shuffleEnabled;
    await player.setShuffleModeEnabled(enabled);
    if (enabled) await player.shuffle();
    if (mounted) setState(() => shuffleEnabled = enabled);
  }

  Future<void> cycleRepeat() async {
    final next = repeatMode == LoopMode.off ? LoopMode.all : repeatMode == LoopMode.all ? LoopMode.one : LoopMode.off;
    await player.setLoopMode(next);
    if (mounted) setState(() => repeatMode = next);
  }

  void openQueue() => showModalBottomSheet(context: context, isScrollControlled: true,
    builder: (_) => SafeArea(child: SizedBox(height: MediaQuery.sizeOf(context).height * .65,
      child: Column(children: [const ListTile(title: Text('Up next', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
        Expanded(child: ListView.builder(itemCount: queue.length, itemBuilder: (c, i) => ListTile(
          leading: Icon(i == currentIndex ? Icons.equalizer : Icons.music_note, color: purple),
          title: Text(queue[i].title), subtitle: Text(queue[i].artist),
          onTap: () async { Navigator.pop(c); await player.seek(Duration.zero, index: i); })))]))));

  void openNowPlaying() => Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
    appBar: AppBar(title: const Text('NOW PLAYING'), centerTitle: true,
      actions: [IconButton(onPressed: openQueue, icon: const Icon(Icons.queue_music))]),
    body: StreamBuilder<int?>(stream: player.currentIndexStream, builder: (_, __) {
      final t = current;
      if (t == null) return const Center(child: Text('Nothing playing'));
      return SafeArea(child: Padding(padding: const EdgeInsets.all(24), child: Column(children: [
        const Spacer(), Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 320),
          child: AspectRatio(aspectRatio: 1, child: ClipRRect(borderRadius: BorderRadius.circular(28),
            child: t.localId == null ? Container(color: const Color(0xFF3E235C),
              child: const Icon(Icons.album, size: 120, color: purple))
              : QueryArtworkWidget(id: t.localId!, type: ArtworkType.AUDIO, artworkFit: BoxFit.cover,
                nullArtworkWidget: Container(color: const Color(0xFF3E235C),
                  child: const Icon(Icons.album, size: 120, color: purple))))))),
        const Spacer(), Align(alignment: Alignment.centerLeft, child: Text(t.title,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis)),
        Align(alignment: Alignment.centerLeft, child: Text(t.artist, style: const TextStyle(color: Colors.white60, fontSize: 16))),
        const SizedBox(height: 20),
        StreamBuilder<Duration>(stream: player.positionStream, builder: (_, snap) {
          final duration = player.duration ?? Duration.zero;
          final pos = snap.data ?? Duration.zero;
          final max = duration.inMilliseconds.toDouble();
          final value = pos.inMilliseconds.toDouble().clamp(0.0, max > 0 ? max : 0.0);
          return Column(children: [Slider(value: value, max: max > 0 ? max : 1,
            onChanged: max <= 0 ? null : (v) => player.seek(Duration(milliseconds: v.round()))),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(format(pos)), Text(max > 0 ? format(duration) : 'LIVE'),
            ])]);
        }),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          IconButton(tooltip: 'Shuffle', onPressed: toggleShuffle, icon: Icon(Icons.shuffle, color: shuffleEnabled ? purple : Colors.white70)),
          IconButton(onPressed: player.hasPrevious ? () => player.seekToPrevious() : null,
            icon: const Icon(Icons.skip_previous, size: 36)),
          StreamBuilder<PlayerState>(stream: player.playerStateStream, builder: (_, __) => IconButton.filled(
            onPressed: () => player.playing ? player.pause() : player.play(),
            icon: Icon(player.playing ? Icons.pause : Icons.play_arrow, size: 42))),
          IconButton(onPressed: player.hasNext ? () => player.seekToNext() : null,
            icon: const Icon(Icons.skip_next, size: 36)),
          IconButton(tooltip: 'Repeat', onPressed: cycleRepeat, icon: Icon(repeatMode == LoopMode.one ? Icons.repeat_one : Icons.repeat, color: repeatMode == LoopMode.off ? Colors.white70 : purple)),
        ]),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          TextButton.icon(onPressed: () => toggleLike(t), icon: Icon(liked.contains(t.id) ? Icons.favorite : Icons.favorite_border), label: const Text('Like')),
          TextButton.icon(onPressed: openQueue, icon: const Icon(Icons.queue_music), label: const Text('Queue')),
        ]), const Spacer(),
      ])));
    }))));

  String format(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('opensic', style: TextStyle(fontSize: 29, fontWeight: FontWeight.w900,
      letterSpacing: -1)), actions: [
        IconButton(tooltip: 'Refresh library', onPressed: load, icon: const Icon(Icons.refresh)),
        IconButton(tooltip: 'Add online stream', onPressed: openStreamDialog, icon: const Icon(Icons.add_link)),
      ]),
    body: Column(children: [
      if (loading) const LinearProgressIndicator(),
      if (error != null) Padding(padding: const EdgeInsets.all(10), child: Text(error!, style: const TextStyle(color: Colors.orangeAccent))),
      Expanded(child: IndexedStack(index: tab, children: [homeView(), libraryView(), playlistView(), likedView()])),
      miniPlayer(),
    ]),
    bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: (i) => setState(() => tab = i),
      destinations: const [NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
        NavigationDestination(icon: Icon(Icons.library_music_outlined), label: 'Library'),
        NavigationDestination(icon: Icon(Icons.queue_music), label: 'Playlists'),
        NavigationDestination(icon: Icon(Icons.favorite_border), label: 'Liked')]),
  );

  @override
  void dispose() { player.dispose(); search.dispose(); streamUrl.dispose(); streamTitle.dispose(); super.dispose(); }
}
