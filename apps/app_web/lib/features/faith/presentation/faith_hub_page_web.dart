import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import 'ai_chat_page_web.dart';
import 'bible_reader_page_web.dart';
import 'daily_verse_page_web.dart';

class FaithHubPageWeb extends StatelessWidget {
  const FaithHubPageWeb({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          elevation: 0,
          title: Text('Fe', style: AppTypography.headlineMedium),
          centerTitle: true,
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.menu_book_outlined), text: 'Biblia'),
              Tab(icon: Icon(Icons.wb_sunny_outlined), text: 'Reflexión'),
              Tab(icon: Icon(Icons.auto_awesome_outlined), text: 'Haven Faith'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            BibleReaderPageWeb(embedded: true),
            DailyVersePageWeb(embedded: true),
            AiChatPageWeb(embedded: true),
          ],
        ),
      ),
    );
  }
}
