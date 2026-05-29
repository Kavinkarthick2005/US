import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_colors.dart';
import '../../models/drop_model.dart';

/// Polaroid scrapbook-style photo card for the Drops/Moments feed.
/// Features jagged washi tape overlays, tilted angles, pushpins, and hand-written style text.
class DropCard extends StatefulWidget {
  final DropModel drop;
  final bool isMyDrop;
  final VoidCallback? onLongPress;
  final int index;

  const DropCard({
    super.key,
    required this.drop,
    required this.isMyDrop,
    this.onLongPress,
    this.index = 0,
  });

  @override
  State<DropCard> createState() => _DropCardState();
}

class _DropCardState extends State<DropCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _heartController;
  bool _showHeart = false;

  @override
  void initState() {
    super.initState();
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _heartController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _showHeart = false);
        _heartController.reset();
      }
    });
  }

  @override
  void dispose() {
    _heartController.dispose();
    super.dispose();
  }

  void _onDoubleTap() {
    setState(() => _showHeart = true);
    _heartController.forward();
  }

  void _showSongOptions(String songText) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFFFDFBF7),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Open in...', style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF3E2D2F), fontStyle: FontStyle.normal)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Text('🟢', style: TextStyle(fontSize: 24)),
              title: Text('Spotify', style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, color: const Color(0xFF3E2D2F), fontStyle: FontStyle.normal)),
              onTap: () {
                Navigator.pop(ctx);
                final query = Uri.encodeComponent(songText.replaceAll('🎵 ', ''));
                launchUrl(Uri.parse('https://open.spotify.com/search/$query'), mode: LaunchMode.externalApplication);
              },
            ),
            ListTile(
              leading: const Text('▶️', style: TextStyle(fontSize: 24)),
              title: Text('YouTube', style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, color: const Color(0xFF3E2D2F), fontStyle: FontStyle.normal)),
              onTap: () {
                Navigator.pop(ctx);
                final query = Uri.encodeComponent(songText.replaceAll('🎵 ', ''));
                launchUrl(Uri.parse('https://www.youtube.com/results?search_query=$query'), mode: LaunchMode.externalApplication);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Deterministic scrapbook rotation angle to make photos look casually placed
    final double rotationAngle = (((widget.index * 3) % 7) - 3) * 0.012;

    // Pick a cute tape color based on the index
    final List<Color> tapeColors = [
      const Color(0xFFF9C5D1), // Pastel Rose
      const Color(0xFFD3C5F9), // Pastel Lavender
      const Color(0xFFC5F9E6), // Pastel Mint
      const Color(0xFFF9E7C5), // Soft Peach
    ];
    final tapeColor = tapeColors[widget.index % tapeColors.length].withValues(alpha: 0.65);

    return Transform.rotate(
      angle: rotationAngle,
      child: GestureDetector(
        onDoubleTap: _onDoubleTap,
        onLongPress: widget.onLongPress,
        child: Container(
          margin: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // ── Main Polaroid Frame ─────────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFDFBF7), // Cozy cream/off-white scrapbook paper
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFEADBCE), // Aged paper border
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: const Color(0xFF9E7C60).withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Inner Photo Container ─────────────────────────────────
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Stack(
                          children: [
                            AspectRatio(
                              aspectRatio: 1.0, // Classic square Polaroid photo
                              child: CachedNetworkImage(
                                imageUrl: widget.drop.photoUrl,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(
                                  color: const Color(0xFFF7F4EB),
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      color: AppColors.rose,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                                errorWidget: (_, __, ___) => Container(
                                  color: const Color(0xFFF7F4EB),
                                  child: const Icon(
                                    Icons.broken_image_rounded,
                                    color: AppColors.muted,
                                    size: 48,
                                  ),
                                ),
                              ),
                            ),
                            
                            // Double tap animated heart overlay
                            if (_showHeart)
                              Positioned.fill(
                                child: Center(
                                  child: AnimatedBuilder(
                                    animation: _heartController,
                                    builder: (_, __) => Opacity(
                                      opacity: (1 - _heartController.value).clamp(0.0, 1.0),
                                      child: Transform.scale(
                                        scale: 0.5 + (_heartController.value * 1.2),
                                        child: const Text(
                                          '❤️',
                                          style: TextStyle(fontSize: 80),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Caption (Handwritten Editorial Look) ──────────────────
                    if (widget.drop.caption != null &&
                        widget.drop.caption!.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          widget.drop.caption!,
                          style: GoogleFonts.caveat(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF3E2D2F), // Muted dark coffee text
                            height: 1.15,
                            fontStyle: FontStyle.normal,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── Moment Context Chips (AI Generated) ──────────────────
                    if (widget.drop.momentContext.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: widget.drop.momentContext.map((chip) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFECEF),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFFFC0CB),
                                  width: 0.5,
                                ),
                              ),
                              child: Text(
                                chip,
                                style: GoogleFonts.dmSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF8B4F58),
                                  fontStyle: FontStyle.normal,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── Bottom Details Row ────────────────────────────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Left Column: Owner & Music Link
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Handwritten style owner name
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: widget.isMyDrop
                                          ? const Color(0xFFE8607A)
                                          : const Color(0xFFC97B93),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    widget.isMyDrop ? 'me' : 'my love',
                                    style: GoogleFonts.caveat(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF7A6466),
                                      fontStyle: FontStyle.normal,
                                    ),
                                  ),
                                ],
                              ),
                              if (widget.drop.songInfo != null || widget.drop.songTitle != null) ...[
                                const SizedBox(height: 10),
                                // Vintage vinyl-record music chip
                                GestureDetector(
                                  onTap: () {
                                    final text = widget.drop.songInfo ?? (widget.drop.songArtist != null ? '${widget.drop.songTitle} · ${widget.drop.songArtist}' : widget.drop.songTitle!);
                                    _showSongOptions(text);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFECEF),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: const Color(0xFFFFC0CB),
                                        width: 1.0,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Text('🎵',
                                            style: TextStyle(fontSize: 11)),
                                        const SizedBox(width: 5),
                                        Flexible(
                                          child: Text(
                                            widget.drop.songInfo != null ? widget.drop.songInfo!.replaceAll('🎵 ', '') : (widget.drop.songArtist != null
                                                ? '${widget.drop.songTitle} · ${widget.drop.songArtist}'
                                                : widget.drop.songTitle!),
                                            style: GoogleFonts.dmSans(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xFF8B4F58),
                                              fontStyle: FontStyle.normal,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        
                        // Right Column: Date Stamp (Vintage ink stamp style)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: const Color(0xFFE8607A).withValues(alpha: 0.55),
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          transform: Matrix4.rotationZ(-0.06), // Tilted date stamp
                          child: Text(
                            DateFormat('dd.MM.yy').format(widget.drop.createdAt),
                            style: GoogleFonts.dmMono(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFE8607A),
                              fontStyle: FontStyle.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Decorative Washi Tape (Overlapping top edge) ───────────────
              Positioned(
                top: -12,
                left: widget.index % 2 == 0 ? 32 : null,
                right: widget.index % 2 != 0 ? 32 : null,
                child: Transform.rotate(
                  angle: widget.index % 2 == 0 ? -0.06 : 0.08,
                  child: _WashiTapeWidget(
                    color: tapeColor,
                    width: 90,
                    height: 26,
                  ),
                ),
              ),

              // ── Decorative Stickers ─────────────────────────────────────────
              // Sparkle stamp at bottom-right
              Positioned(
                bottom: -8,
                right: 8,
                child: Transform.rotate(
                  angle: 0.12,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.yellow.shade100,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 3,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Text('✨', style: TextStyle(fontSize: 14)),
                  ),
                ),
              ),

              // Pushpin at top center
              if (widget.index % 3 == 0)
                const Positioned(
                  top: -16,
                  left: 0,
                  right: 0,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Text(
                      '📌',
                      style: TextStyle(fontSize: 22),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Washi Tape Painter
// ─────────────────────────────────────────────────────────────────────────────

class _WashiTapeWidget extends StatelessWidget {
  final Color color;
  final double width;
  final double height;

  const _WashiTapeWidget({
    required this.color,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _WashiTapePainter(color: color),
    );
  }
}

class _WashiTapePainter extends CustomPainter {
  final Color color;

  const _WashiTapePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, 0);

    // Jagged left side
    double currentY = 0;
    const toothSize = 3.0;
    bool zig = true;

    while (currentY < size.height) {
      currentY += toothSize;
      if (currentY > size.height) currentY = size.height;
      path.lineTo(zig ? toothSize : 0, currentY);
      zig = !zig;
    }

    path.lineTo(size.width, size.height);

    // Jagged right side
    currentY = size.height;
    zig = true;

    while (currentY > 0) {
      currentY -= toothSize;
      if (currentY < 0) currentY = 0;
      path.lineTo(size.width - (zig ? toothSize : 0), currentY);
      zig = !zig;
    }

    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
