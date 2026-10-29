import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../home/presentation/home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  static const _pages = <_OnboardingPageData>[
    _OnboardingPageData(
      icon: Icons.explore_outlined,
      title: 'DRISHTI আপনার পকেট ন্যাভিগেটর',
      body:
          'চলাফেরার সময় গুরুত্বপূর্ণ সতর্কতা বুঝতে সাহায্য করার জন্য তৈরি একটি সহায়ক অ্যাপ।',
    ),
    _OnboardingPageData(
      icon: Icons.science_outlined,
      title: 'ডেমো মোডে আগে অনুশীলন করুন',
      body:
          'হার্ডওয়্যার ছাড়া সিমুলেটেড ইভেন্ট দেখে অ্যাপের কাজ বুঝুন। প্রতিটি ডেমো ইভেন্ট স্পষ্টভাবে চিহ্নিত থাকবে।',
    ),
    _OnboardingPageData(
      icon: Icons.accessibility_new,
      title: 'আপনার নিরাপত্তাই প্রথম',
      body:
          'DRISHTI রাস্তা পারাপারের নিরাপত্তার নিশ্চয়তা দেয় না। সাদা ছড়ি, গাইড ডগ বা প্রশিক্ষিত চলাচল-পদ্ধতি সবসময় ব্যবহার করুন।',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _pages.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            children: [
              Semantics(
                label: 'DRISHTI পরিচিতি, ধাপ ${_page + 1} এর মধ্যে ${_pages.length}',
                child: LinearProgressIndicator(
                  value: (_page + 1) / _pages.length,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 28),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _pages.length,
                  onPageChanged: (value) => setState(() => _page = value),
                  itemBuilder: (context, index) {
                    final page = _pages[index];
                    return _OnboardingPage(data: page);
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (index) => Semantics(
                    label: 'ধাপ ${index + 1}',
                    selected: index == _page,
                    child: Container(
                      width: index == _page ? 28 : 10,
                      height: 10,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: index == _page ? AppTheme.blue : const Color(0xFFB8C4D1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () {
                  if (isLast) {
                    _finish();
                  } else {
                    _controller.nextPage(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                    );
                  }
                },
                child: Text(isLast ? 'শুরু করুন' : 'পরবর্তী'),
              ),
              const SizedBox(height: 12),
              if (!isLast)
                TextButton(
                  onPressed: _finish,
                  style: TextButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('এখনই ড্যাশবোর্ডে যান'),
                )
              else
                const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingPageData {
  const _OnboardingPageData({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.data});

  final _OnboardingPageData data;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Semantics(
          label: 'চিত্র: ${data.title}',
          image: true,
          child: CircleAvatar(
            radius: 76,
            backgroundColor: AppTheme.sky,
            child: Icon(data.icon, size: 78, color: AppTheme.blue),
          ),
        ),
        const SizedBox(height: 40),
        Text(
          data.title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 20),
        Text(
          data.body,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    );
  }
}
