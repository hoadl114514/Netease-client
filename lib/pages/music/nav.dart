import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../shell/player_bar.dart';
import 'album_page.dart';
import 'artist_page.dart';

/// 二级页面统一外壳：标题栏 + 内容 + 底部迷你播放条。
class SubPage extends StatelessWidget {
  const SubPage({super.key, required this.title, required this.body, this.actions});

  final String title;
  final Widget body;
  final List<Widget>? actions;

  static Future<void> push(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: body,
      bottomNavigationBar: const SafeArea(top: false, child: PlayerBar()),
    );
  }
}

Future<void> openArtist(BuildContext context, ArtistRef artist) =>
    SubPage.push(context, ArtistPage(artist: artist));

Future<void> openAlbum(BuildContext context, String albumId, {String? name}) =>
    SubPage.push(context, AlbumPage(albumId: albumId, name: name));

/// 一首歌有多位歌手时先选一位。
Future<void> openSongArtist(BuildContext context, Song song) async {
  final artists = song.artists;
  if (artists.isEmpty) return;
  if (artists.length == 1) return openArtist(context, artists.first);
  final picked = await showModalBottomSheet<ArtistRef>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final a in artists)
            ListTile(
              leading: const Icon(Icons.person_outline_rounded),
              title: Text(a.name),
              onTap: () => Navigator.of(context).pop(a),
            ),
        ],
      ),
    ),
  );
  if (picked != null && context.mounted) await openArtist(context, picked);
}
