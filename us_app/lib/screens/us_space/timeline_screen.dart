import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../models/timeline_event_model.dart';
import '../../providers/timeline_provider.dart';
import '../../widgets/v2/space_header.dart';
import '../../widgets/v2/timeline_tile.dart';

class TimelineScreen extends ConsumerWidget {
  const TimelineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupedAsync = ref.watch(groupedTimelineProvider);
    final allAsync = ref.watch(timelineProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF1A0A0F),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1A0A0F), Color(0xFF3D1525)],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                SpaceSubHeader(
                  title: 'Our Timeline',
                  gradientColors: const [Color(0xFF1A0A0F), Color(0xFF3D1525)],
                  onBack: () => context.pop(),
                ),
                Expanded(
                  child: groupedAsync.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFE91E8C),
                      ),
                    ),
                    error: (e, _) => _buildError(e.toString()),
                    data: (grouped) {
                      if (grouped.isEmpty) {
                        return _buildEmptyState();
                      }

                      final totalEvents = allAsync.whenOrNull(
                            data: (events) => events.length,
                          ) ??
                          0;

                      return CustomScrollView(
                        slivers: [
                          // Event count header
                          SliverToBoxAdapter(
                            child: _buildEventCountHeader(totalEvents),
                          ),

                          // Grouped timeline
                          // Grouped timeline
                          ...grouped.asMap().entries.map(
                                (entry) {
                              final groupIndex = entry.key;
                              final group = entry.value;
                              final monthLabel = group.label;
                              final events = group.events;

                              return SliverList(
                                delegate: SliverChildListDelegate([
                                  _buildMonthHeader(monthLabel, groupIndex),
                                  ...events.asMap().entries.map((evEntry) {
                                    final i = evEntry.key;
                                    final event = evEntry.value;
                                    return TimelineTile(
                                      event: event,
                                      isFirst: i == 0,
                                      isLast: i == events.length - 1,
                                    )
                                        .animate()
                                        .fadeIn(
                                          delay: Duration(
                                            milliseconds:
                                                groupIndex * 100 + i * 60,
                                          ),
                                          duration: const Duration(
                                              milliseconds: 400),
                                        )
                                        .slideX(
                                          begin: -0.05,
                                          end: 0,
                                          delay: Duration(
                                            milliseconds:
                                                groupIndex * 100 + i * 60,
                                          ),
                                          duration: const Duration(
                                              milliseconds: 400),
                                          curve: Curves.easeOut,
                                        );
                                  }),
                                  const SizedBox(height: 8),
                                ]),
                              );
                            },
                          ),

                          // Bottom padding
                          const SliverToBoxAdapter(
                            child: SizedBox(height: 40),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCountHeader(int count) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            const Color(0xFFE91E8C).withOpacity(0.15),
            const Color(0xFFE91E8C).withOpacity(0.05),
          ],
        ),
        border: Border.all(
          color: const Color(0xFFE91E8C).withOpacity(0.25),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const Text('💫', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$count ',
                  style: GoogleFonts.dmMono(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    fontStyle: FontStyle.normal,
                  ),
                ),
                TextSpan(
                  text: count == 1 ? 'moment together' : 'moments together',
                  style: GoogleFonts.dmSans(
                    color: Colors.white70,
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    fontStyle: FontStyle.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: const Duration(milliseconds: 500))
        .slideY(begin: -0.1, end: 0, duration: const Duration(milliseconds: 400));
  }

  Widget _buildMonthHeader(String displayText, int groupIndex) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Row(
        children: [
          Text(
            displayText,
            style: GoogleFonts.playfairDisplay(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              fontStyle: FontStyle.normal,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFE91E8C).withOpacity(0.5),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(
          delay: Duration(milliseconds: groupIndex * 100),
          duration: const Duration(milliseconds: 400),
        )
        .slideX(
          begin: -0.05,
          end: 0,
          delay: Duration(milliseconds: groupIndex * 100),
          duration: const Duration(milliseconds: 400),
        );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '💫',
            style: TextStyle(fontSize: 48),
          )
              .animate()
              .scale(
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut,
              )
              .then()
              .shimmer(
                duration: const Duration(milliseconds: 1500),
                color: Colors.white24,
              ),
          const SizedBox(height: 20),
          Text(
            'Your story begins here',
            style: GoogleFonts.playfairDisplay(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              fontStyle: FontStyle.normal,
            ),
          ).animate().fadeIn(delay: const Duration(milliseconds: 300)),
          const SizedBox(height: 10),
          Text(
            'Moments you share will appear here',
            style: GoogleFonts.dmSans(
              color: Colors.white38,
              fontSize: 14,
              fontStyle: FontStyle.normal,
            ),
          ).animate().fadeIn(delay: const Duration(milliseconds: 450)),
        ],
      ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.redAccent,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'Couldn\'t load timeline',
              style: GoogleFonts.playfairDisplay(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                fontStyle: FontStyle.normal,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: GoogleFonts.dmSans(
                color: Colors.white38,
                fontSize: 13,
                fontStyle: FontStyle.normal,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
