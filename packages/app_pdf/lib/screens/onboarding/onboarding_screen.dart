import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../components/dk_button.dart';
import '../../components/dk_icon.dart';
import '../../components/dk_illustration.dart';
import '../../components/dk_tappable.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/onboarding_providers.dart';
import '../../routes/routes.dart';
import '../../theme/dk_tokens.dart';

/// Onboarding (DK-0238; UI spec §14.2), at `/welcome`, shown once: O1 and O2
/// tell what Dokulo is, O3 asks what to do first. Skip, Next and swipe move
/// through it; Skip and every O3 card mark it seen. No account, no paywall,
/// no rating prompt.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _count = 3;
  final _pages = PageController();
  var _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _finish(String location) {
    ref.read(onboardingDoneProvider.notifier).complete();
    context.go(location);
  }

  void _next() {
    final motion = context.tokens.motion;
    if (context.reduceMotion) {
      _pages.jumpToPage(_page + 1);
    } else {
      _pages.nextPage(duration: motion.standard, curve: motion.standardCurve);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    final last = _page == _count - 1;
    return Scaffold(
      backgroundColor: t.color.background,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 44,
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: t.space.s),
                  child: DkButton(
                    label: l.common_skip,
                    variant: DkButtonVariant.tertiary,
                    onPressed: () => _finish(Routes.home),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pages,
                onPageChanged: (page) => setState(() => _page = page),
                children: [
                  _Intro(
                    illustration: DkIllustrations.onboarding1,
                    title: l.onb_1_title,
                    body: l.onb_1_body,
                  ),
                  _Intro(
                    illustration: DkIllustrations.onboarding2,
                    title: l.onb_2_title,
                    body: l.onb_2_body,
                  ),
                  _StartWith(onChoose: _finish),
                ],
              ),
            ),
            _Dots(count: _count, active: _page),
            if (last)
              SizedBox(height: t.space.xxxl + t.space.l)
            else
              Padding(
                padding: EdgeInsets.fromLTRB(
                  t.space.l,
                  t.space.xxl,
                  t.space.l,
                  t.space.l,
                ),
                child: DkButton(
                  label: l.common_next,
                  size: DkButtonSize.large,
                  expand: true,
                  onPressed: _next,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The top edge of the illustration sits at 22 % of the screen's height.
double _illustrationTop(BuildContext context) {
  final mq = MediaQuery.of(context);
  return (mq.size.height * 0.22 - mq.padding.top - 44).clamp(16, 400);
}

/// O1 and O2: the illustration, the headline and the body, centred.
class _Intro extends StatelessWidget {
  const _Intro({
    required this.illustration,
    required this.title,
    required this.body,
  });

  final DkIllustrations illustration;
  final String title, body;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        t.space.xxl,
        _illustrationTop(context),
        t.space.xxl,
        t.space.l,
      ),
      child: Column(
        children: [
          DkIllustration(illustration),
          SizedBox(height: t.space.xl),
          Text(
            title,
            textAlign: TextAlign.center,
            style: t.text.display.copyWith(color: t.color.textPrimary),
          ),
          SizedBox(height: t.space.m),
          Text(
            body,
            textAlign: TextAlign.center,
            style: t.text.bodyL.copyWith(color: t.color.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// O3: what to do first. Each card marks onboarding seen and goes there.
class _StartWith extends StatelessWidget {
  const _StartWith({required this.onChoose});

  final void Function(String location) onChoose;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final l = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(t.space.l, t.space.l, t.space.l, t.space.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: DkIllustration(DkIllustrations.onboarding3)),
          SizedBox(height: t.space.xl),
          Text(
            l.onb_3_title,
            textAlign: TextAlign.center,
            style: t.text.display.copyWith(color: t.color.textPrimary),
          ),
          SizedBox(height: t.space.xl),
          _StartCard(
            icon: DkIcons.scan,
            title: l.onb_scan_title,
            sub: l.onb_scan_sub,
            onTap: () => onChoose(Routes.scan),
          ),
          SizedBox(height: t.space.m),
          _StartCard(
            icon: DkIcons.folderOpen,
            title: l.onb_open_title,
            sub: l.onb_open_sub,
            // ponytail: the Files tab until the system picker lands (DK-0241)
            onTap: () => onChoose(Routes.files),
          ),
          SizedBox(height: t.space.m),
          _StartCard(
            icon: DkIcons.toolsTab,
            title: l.onb_look_title,
            sub: l.onb_look_sub,
            onTap: () => onChoose(Routes.home),
          ),
        ],
      ),
    );
  }
}

/// A start-with card: 72 tall, `radius.m`, outline, a 40 dp tonal icon, the
/// title and the sub line, a chevron; one button for screen readers.
class _StartCard extends StatelessWidget {
  const _StartCard({
    required this.icon,
    required this.title,
    required this.sub,
    required this.onTap,
  });

  final IconData icon;
  final String title, sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.color;
    return Semantics(
      button: true,
      label: [title, sub].join('\n'),
      excludeSemantics: true,
      onTap: onTap,
      child: DkTappable(
        onTap: onTap,
        radius: t.radius.m,
        builder: (context, pressed) => Container(
          constraints: const BoxConstraints(minHeight: 72),
          padding: EdgeInsets.symmetric(
            horizontal: t.space.l,
            vertical: t.space.s,
          ),
          decoration: BoxDecoration(
            color: pressed ? t.state.pressed : c.surface,
            borderRadius: BorderRadius.circular(t.radius.m),
            border: Border.all(color: c.outline),
          ),
          child: Row(
            spacing: t.space.l,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: c.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: DkIcon(icon, color: c.onPrimaryContainer),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: t.text.titleS.copyWith(color: c.textPrimary),
                    ),
                    Text(
                      sub,
                      style: t.text.caption.copyWith(color: c.textSecondary),
                    ),
                  ],
                ),
              ),
              DkIcon(DkIcons.chevronRight, color: c.iconSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// The page dots: 8 dp, the active one a 24 × 8 `color.primary` pill.
/// Screen readers hear "Page 2 of 3".
class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.active});

  final int count, active;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      label: AppLocalizations.of(context).progress_page(active + 1, count),
      excludeSemantics: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: t.space.s,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: t.motion.fast,
              width: i == active ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: i == active ? t.color.primary : t.color.outlineStrong,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
        ],
      ),
    );
  }
}
