import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../providers/drops_provider.dart';
import '../../widgets/v2/drop_card.dart';
import '../../widgets/v2/space_header.dart';

class DropsScreen extends ConsumerStatefulWidget {
  const DropsScreen({super.key});

  @override
  ConsumerState<DropsScreen> createState() => _DropsScreenState();
}

class _DropsScreenState extends ConsumerState<DropsScreen> {
  String? _myId;

  @override
  void initState() {
    super.initState();
    _myId = Supabase.instance.client.auth.currentUser?.id;
  }

  Future<void> _confirmDelete(BuildContext context, String dropId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A1020),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Remove Drop?',
          style: GoogleFonts.playfairDisplay(
            color: Colors.white,
            fontStyle: FontStyle.normal,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'This moment will be gone forever.',
          style: GoogleFonts.dmSans(
            color: Colors.white70,
            fontStyle: FontStyle.normal,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Keep it',
              style: GoogleFonts.dmSans(
                color: Colors.white54,
                fontStyle: FontStyle.normal,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Remove',
              style: GoogleFonts.dmSans(
                color: const Color(0xFFE57373),
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.normal,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(dropsProvider.notifier).deleteDrop(dropId);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Could not remove drop. Try again.',
                style: GoogleFonts.dmSans(fontStyle: FontStyle.normal),
              ),
              backgroundColor: Colors.red.shade800,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dropsAsync = ref.watch(dropsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF1A0A0F),
      body: Stack(
        children: [
          // Background gradient
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
                  title: 'Drops',
                  gradientColors: const [Color(0xFF1A0A0F), Color(0xFF3D1525)],
                  onBack: () => context.pop(),
                ),
                Expanded(
                  child: dropsAsync.when(
                    loading: () => _buildShimmerLoading(),
                    error: (e, _) => _buildError(e.toString()),
                    data: (drops) {
                      if (drops.isEmpty) {
                        return _buildEmptyState(context);
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        itemCount: drops.length,
                        itemBuilder: (context, index) {
                          final drop = drops[index];
                          final isMyDrop = drop.addedBy == _myId;
                          return GestureDetector(
                            onLongPress: isMyDrop
                                ? () => _confirmDelete(context, drop.id)
                                : null,
                            child: DropCard(
                              drop: drop,
                              isMyDrop: isMyDrop,
                              index: index,
                            )
                                .animate()
                                .fadeIn(
                                  delay: Duration(milliseconds: index * 80),
                                  duration: const Duration(milliseconds: 400),
                                )
                                .slideY(
                                  begin: 0.15,
                                  end: 0,
                                  delay: Duration(milliseconds: index * 80),
                                  duration: const Duration(milliseconds: 400),
                                  curve: Curves.easeOut,
                                ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/us-space/drops/add'),
        backgroundColor: const Color(0xFFE91E8C),
        elevation: 8,
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      )
          .animate()
          .scale(
            delay: const Duration(milliseconds: 300),
            duration: const Duration(milliseconds: 400),
            curve: Curves.elasticOut,
          ),
    );
  }

  Widget _buildShimmerLoading() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          height: 280,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white.withOpacity(0.05),
          ),
        )
            .animate(onPlay: (c) => c.repeat())
            .shimmer(
              duration: const Duration(milliseconds: 1200),
              color: Colors.white.withOpacity(0.1),
            );
      },
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
          const SizedBox(height: 16),
          Text(
            'Something went wrong',
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
              color: Colors.white54,
              fontSize: 13,
              fontStyle: FontStyle.normal,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            '📸',
            style: TextStyle(fontSize: 48),
          ).animate().scale(
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut,
              ),
          const SizedBox(height: 20),
          Text(
            'Drop a moment',
            style: GoogleFonts.playfairDisplay(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              fontStyle: FontStyle.normal,
            ),
          ).animate().fadeIn(delay: const Duration(milliseconds: 200)),
          const SizedBox(height: 10),
          Text(
            'Share photos and music with each other',
            style: GoogleFonts.dmSans(
              color: Colors.white54,
              fontSize: 14,
              fontStyle: FontStyle.normal,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: const Duration(milliseconds: 350)),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => context.go('/us-space/drops/add'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE91E8C),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              elevation: 8,
              shadowColor: const Color(0xFFE91E8C).withOpacity(0.4),
            ),
            child: Text(
              'Add Drop',
              style: GoogleFonts.dmSans(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                fontStyle: FontStyle.normal,
              ),
            ),
          ).animate().fadeIn(delay: const Duration(milliseconds: 500)).slideY(
                begin: 0.2,
                end: 0,
                delay: const Duration(milliseconds: 500),
              ),
        ],
      ),
    );
  }
}
