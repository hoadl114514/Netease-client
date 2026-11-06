import 'package:flutter/material.dart';

import '../../data/models.dart';
import '../../shell/player_bar.dart';
import 'playlist_view.dart';

class PlaylistPage extends StatelessWidget {
  const PlaylistPage({super.key, required this.playlist});

  final Playlist playlist;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('歌单')),
      body: PlaylistView(playlist: playlist),
      extendBody: true,
      bottomNavigationBar: const FloatingBottomBar(),
    );
  }
}
