import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/services/initialization_service.dart';
import '../../../../core/theme/app_theme.dart';

/// Loading screen shown during initialization
class LoadingScreen extends ConsumerStatefulWidget {
  const LoadingScreen({super.key});

  @override
  ConsumerState<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends ConsumerState<LoadingScreen> {
  @override
  void initState() {
    super.initState();
    // Start initialization
    Future.microtask(() {
      ref.read(initializationProvider.notifier).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(initializationProvider);

    // Navigate when ready
    ref.listen<InitStatus>(initializationProvider, (previous, next) {
      if (next.state == InitState.ready) {
        // TODO: Check if onboarding completed
        context.go(AppRoutes.onboarding);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo/Icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.auto_stories,
                  size: 50,
                  color: AppColors.primaryLight,
                ),
              ),

              const SizedBox(height: 32),

              // App name
              Text(
                'Hamorah',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryLight,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'The Teacher',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondaryLight,
                ),
              ),

              const SizedBox(height: 48),

              // Status-specific content
              _buildStatusContent(status),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusContent(InitStatus status) {
    switch (status.state) {
      case InitState.initializing:
      case InitState.importing:
        return _buildProgressContent(status);

      case InitState.needsImport:
        return _buildImportPrompt();

      case InitState.error:
        return _buildErrorContent(status);

      case InitState.ready:
        return const CircularProgressIndicator();
    }
  }

  Widget _buildProgressContent(InitStatus status) {
    return Column(
      children: [
        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: status.progress,
            backgroundColor: AppColors.primaryLight.withOpacity(0.2),
            color: AppColors.primaryLight,
            minHeight: 8,
          ),
        ),

        const SizedBox(height: 16),

        Text(
          status.message,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondaryLight,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 24),

        SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primaryLight,
          ),
        ),
      ],
    );
  }

  Widget _buildImportPrompt() {
    return Column(
      children: [
        Icon(
          Icons.download_outlined,
          size: 48,
          color: AppColors.primaryLight,
        ),

        const SizedBox(height: 16),

        Text(
          'Download Bible',
          style: Theme.of(context).textTheme.titleLarge,
        ),

        const SizedBox(height: 8),

        Text(
          'Hamorah needs to download the King James Bible.\nThis only happens once (~5MB).',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondaryLight,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              ref.read(initializationProvider.notifier).importBible();
            },
            child: const Text('Download KJV Bible'),
          ),
        ),

        const SizedBox(height: 12),

        TextButton(
          onPressed: () {
            ref.read(initializationProvider.notifier).useSampleData();
          },
          child: Text(
            'Use sample data (offline)',
            style: TextStyle(color: AppColors.textSecondaryLight),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorContent(InitStatus status) {
    return Column(
      children: [
        Icon(
          Icons.error_outline,
          size: 48,
          color: Colors.red.shade400,
        ),

        const SizedBox(height: 16),

        Text(
          'Something went wrong',
          style: Theme.of(context).textTheme.titleLarge,
        ),

        const SizedBox(height: 8),

        Text(
          status.error ?? 'Unknown error',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondaryLight,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 24),

        ElevatedButton(
          onPressed: () {
            ref.read(initializationProvider.notifier).retry();
          },
          child: const Text('Try Again'),
        ),

        const SizedBox(height: 12),

        TextButton(
          onPressed: () {
            ref.read(initializationProvider.notifier).useSampleData();
          },
          child: const Text('Continue with sample data'),
        ),
      ],
    );
  }
}
