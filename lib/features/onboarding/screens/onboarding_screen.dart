import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController pageController = PageController();
  int currentPage = 0;

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<_OnboardingPageData> pages = [
      const _OnboardingPageData(Icons.fitness_center_outlined, 'Exercise Mode', 'Track reps, posture, and progress with live pose feedback.'),
      const _OnboardingPageData(Icons.self_improvement_outlined, 'Yoga Mode', 'Classify poses, monitor stability, and hold better alignment.'),
      const _OnboardingPageData(Icons.menu_book_outlined, 'Study Focus', 'Use Pomodoro sessions, focus scoring, and distraction insights.'),
    ];

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: pageController,
                  onPageChanged: (int index) => setState(() => currentPage = index),
                  itemCount: pages.length,
                  itemBuilder: (context, index) {
                    final _OnboardingPageData page = pages[index];
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(page.icon, size: 96),
                        const SizedBox(height: 24),
                        Text(page.title, style: Theme.of(context).textTheme.headlineMedium),
                        const SizedBox(height: 12),
                        Text(page.subtitle, textAlign: TextAlign.center),
                      ],
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  pages.length,
                  (int index) => Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: index == currentPage ? Theme.of(context).colorScheme.primary : Colors.white24,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () {
                  if (currentPage == pages.length - 1) {
                    context.go('/auth');
                  } else {
                    pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
                  }
                },
                child: Text(currentPage == pages.length - 1 ? 'Get started' : 'Next'),
              ),
              TextButton(
                onPressed: () => context.go('/auth'),
                child: const Text('Skip'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingPageData {
  const _OnboardingPageData(this.icon, this.title, this.subtitle);

  final IconData icon;
  final String title;
  final String subtitle;
}
