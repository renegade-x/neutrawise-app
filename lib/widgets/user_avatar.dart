import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:neutrawise/widgets/theme/app_colors.dart';

class UserAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String name;
  final double radius;
  final VoidCallback? onTap;
  final bool showEditBadge;
  final Border? border;

  const UserAvatar({
    super.key,
    required this.name,
    this.avatarUrl,
    this.radius = 24,
    this.onTap,
    this.showEditBadge = false,
    this.border,
  });

  String _getInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'U';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      final first = parts.first.isNotEmpty ? parts.first[0] : '';
      final second = parts.last.isNotEmpty ? parts.last[0] : '';
      return '$first$second'.toUpperCase();
    }
    return trimmed.substring(0, trimmed.length >= 2 ? 2 : 1).toUpperCase();
  }

  Widget _buildAvatarContent(BuildContext context) {
    if (avatarUrl != null && avatarUrl!.trim().isNotEmpty) {
      final url = avatarUrl!.trim();

      // Base64 Data URL or Raw Base64
      if (url.startsWith('data:image') || url.startsWith('base64:')) {
        try {
          final base64Str = url.contains(',')
              ? url.split(',').last
              : (url.startsWith('base64:') ? url.substring(7) : url);
          final Uint8List bytes = base64Decode(base64Str);
          return ClipOval(
            child: Image.memory(
              bytes,
              width: radius * 2,
              height: radius * 2,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _buildFallback(context),
            ),
          );
        } catch (_) {
          return _buildFallback(context);
        }
      }

      // Preset Emoji Avatar
      if (url.startsWith('emoji:')) {
        final emoji = url.substring(6);
        return Container(
          width: radius * 2,
          height: radius * 2,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.primaryGradient,
          ),
          alignment: Alignment.center,
          child: Text(emoji, style: TextStyle(fontSize: radius * 1.05)),
        );
      }

      // Network Image
      if (url.startsWith('http://') || url.startsWith('https://')) {
        return ClipOval(
          child: Image.network(
            url,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _buildFallback(context),
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                width: radius * 2,
                height: radius * 2,
                color: AppColors.surfaceDark,
                child: const Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      }

      // Asset Image
      if (url.startsWith('assets/')) {
        return ClipOval(
          child: Image.asset(
            url,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _buildFallback(context),
          ),
        );
      }
    }

    return _buildFallback(context);
  }

  Widget _buildFallback(BuildContext context) {
    final initials = _getInitials(name);
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            AppColors.primaryGreen.withValues(alpha: 0.8),
            AppColors.primaryBlue.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.75,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final avatarWidget = Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border:
            border ??
            Border.all(
              color: AppColors.primaryGreen.withValues(alpha: 0.3),
              width: 1.5,
            ),
      ),
      child: _buildAvatarContent(context),
    );

    if (!showEditBadge && onTap == null) {
      return avatarWidget;
    }

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          avatarWidget,
          if (showEditBadge)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surfaceDark, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.camera_alt,
                  size: 16,
                  color: Colors.black,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
