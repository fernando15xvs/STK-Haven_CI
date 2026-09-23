import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';
import 'package:gym_tracker/core/theme/components/primary_button.dart';
import 'package:core/core/constants/preset_programs.dart';
import 'package:core/domain/models/preset_program.dart';
import 'package:core/features/onboarding/application/program_service.dart';
import 'package:gym_tracker/features/onboarding/presentation/widgets/program_preview_modal.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  String? _selectedGoal;
  String? _selectedExperience;
  int? _selectedDays;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentIndex < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  PresetProgram? _getRecommendedProgram() {
    if (_selectedDays == null) return null;

    if (_selectedDays! <= 2) {
      return presetPrograms.firstWhere((p) => p.id == 'prog_fullbody_2', orElse: () => presetPrograms.first);
    }

    if (_selectedDays == 3) {
      if (_selectedExperience == 'Principiante' || _selectedGoal == 'Mantenerme activo') {
        return presetPrograms.firstWhere((p) => p.id == 'prog_fullbody_3', orElse: () => presetPrograms.first);
      }
      return presetPrograms.firstWhere((p) => p.id == 'prog_ppl_3', orElse: () => presetPrograms.first);
    }

    if (_selectedDays == 4 || _selectedDays == 5) {
      return presetPrograms.firstWhere((p) => p.id == 'prog_upper_lower_4', orElse: () => presetPrograms.first);
    }

    if (_selectedDays == 6) {
      if (_selectedExperience == 'Principiante') {
        // Principiantes no deberían hacer 6 días, bajar a 4
        return presetPrograms.firstWhere((p) => p.id == 'prog_upper_lower_4', orElse: () => presetPrograms.first);
      }
      return presetPrograms.firstWhere((p) => p.id == 'prog_ppl_6', orElse: () => presetPrograms.first);
    }

    return presetPrograms.first;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Progress Indicator
            if (_currentIndex > 0)
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: AppColors.textSecondary),
                      onPressed: _previousPage,
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (_currentIndex) / 3,
                          backgroundColor: AppColors.surface,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                          minHeight: 8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Page Content
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) => setState(() => _currentIndex = index),
                children: [
                  _buildWelcomeStep(),
                  _buildExperienceGoalStep(),
                  _buildDaysStep(),
                  _buildRecommendationStep(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeStep() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.fitness_center, size: 80, color: AppColors.primary),
          const SizedBox(height: AppSpacing.xl),
          const Text(
            'Lleva tu progreso\nal siguiente nivel',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.textPrimary, height: 1.2),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text(
            'Diseñamos un programa basado en tu experiencia y disponibilidad.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity, 
            child: PrimaryButton(
              label: 'Comenzar',
              onPressed: _nextPage, 
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExperienceGoalStep() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('¿Qué quieres conseguir?', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: AppSpacing.lg),
          _buildSelectionChip('Ganar masa muscular', _selectedGoal, (v) => setState(() => _selectedGoal = v)),
          _buildSelectionChip('Ganar fuerza', _selectedGoal, (v) => setState(() => _selectedGoal = v)),
          _buildSelectionChip('Mantenerme activo', _selectedGoal, (v) => setState(() => _selectedGoal = v)),

          const SizedBox(height: AppSpacing.xl * 1.5),

          const Text('¿Cuál es tu experiencia?', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: AppSpacing.lg),
          _buildSelectionChip('Principiante', _selectedExperience, (v) => setState(() => _selectedExperience = v)),
          _buildSelectionChip('Intermedio', _selectedExperience, (v) => setState(() => _selectedExperience = v)),
          _buildSelectionChip('Avanzado', _selectedExperience, (v) => setState(() => _selectedExperience = v)),

          const Spacer(),
          SizedBox(
            width: double.infinity, 
            child: PrimaryButton(
              label: 'Siguiente',
              onPressed: (_selectedGoal != null && _selectedExperience != null) ? _nextPage : null, 
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }

  Widget _buildDaysStep() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('¿Cuántos días puedes entrenar?', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: AppSpacing.sm),
          const Text('A la semana', style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.xl),
          
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [2, 3, 4, 5, 6].map((days) {
              final isSelected = _selectedDays == days;
              return GestureDetector(
                onTap: () => setState(() => _selectedDays = days),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 60,
                  height: 60,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.surfaceBorder,
                      width: 2,
                    ),
                  ),
                  child: Text(
                    '$days',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.black : AppColors.textPrimary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const Spacer(),
          SizedBox(
            width: double.infinity, 
            child: PrimaryButton(
              label: 'Siguiente',
              onPressed: _selectedDays != null ? _nextPage : null, 
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }

  Widget _buildRecommendationStep() {
    final recommendedProgram = _getRecommendedProgram();
    if (recommendedProgram == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Recomendado para ti', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: AppSpacing.xl),
          
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withAlpha(100), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.star, color: AppColors.primary, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    Text('Mejor opción', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(recommendedProgram.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(height: AppSpacing.sm),
                Text('${recommendedProgram.daysPerWeek} días / semana • ${recommendedProgram.level}', style: const TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: AppSpacing.md),
                Text(recommendedProgram.description, style: const TextStyle(color: AppColors.textPrimary, height: 1.4)),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  
                  child: OutlinedButton(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (ctx) => ProgramPreviewModal(program: recommendedProgram),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Ver rutinas', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
          
          const Spacer(),
          SizedBox(
            width: double.infinity, 
            child: PrimaryButton(
              label: 'Usar este programa',
              onPressed: () async {
                await ref.read(programServiceProvider).installProgram(recommendedProgram);
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextButton(
            onPressed: () async {
              await ref.read(programServiceProvider).completeOnboardingFromScratch();
            },
            child: const Text('Crear mis propias rutinas →', style: TextStyle(color: AppColors.textSecondary)),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }

  Widget _buildSelectionChip(String text, String? selectedValue, ValueChanged<String> onSelect) {
    final isSelected = text == selectedValue;
    return GestureDetector(
      onTap: () => onSelect(text),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: AppSpacing.lg),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withAlpha(30) : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.surfaceBorder,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              text,
              style: TextStyle(
                fontSize: 16,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
