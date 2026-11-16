import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gym_tracker/core/theme/app_colors.dart';

import '../../data/motivation_artwork_processor.dart';

/// Preview exactly the normalized alignment used by the private PNG encoder.
/// Cancel never changes an existing cover; no input is uploaded anywhere.
class MotivationCoverCropSheet {
  const MotivationCoverCropSheet._();

  static Future<MotivationCoverFocus?> show(
    BuildContext context,
    String filePath,
  ) => showModalBottomSheet<MotivationCoverFocus>(
    context:context,
    useSafeArea:true,
    isScrollControlled:true,
    showDragHandle:true,
    builder:(ctx)=>_CropBody(filePath:filePath),
  );
}

class _CropBody extends StatefulWidget {
  const _CropBody({required this.filePath});
  final String filePath;

  @override
  State<_CropBody> createState()=>_CropBodyState();
}

class _CropBodyState extends State<_CropBody> {
  double horizontal=0;
  double vertical=0;

  @override
  Widget build(BuildContext context) {
    final colors=AppColors.of(context);
    final focus=Alignment(horizontal,vertical);
    return Padding(
      padding:EdgeInsets.fromLTRB(
        18,6,18,18+MediaQuery.viewInsetsOf(context).bottom),
      child:SingleChildScrollView(
        child:Column(mainAxisSize:MainAxisSize.min,
          crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('Ajustar portada',style:AppTypography.headlineMedium),
          const SizedBox(height:6),
          Text('Mueve el encuadre antes de guardar. '
            'La imagen queda privada en tu dispositivo.',
            style:AppTypography.bodySmall.copyWith(
              color:colors.textSecondary)),
          const SizedBox(height:14),
          Center(child:ConstrainedBox(
            constraints:const BoxConstraints(maxWidth:260),
            child:AspectRatio(aspectRatio:1,child:ClipRRect(
              borderRadius:AppRadius.md_,
              child:Image.file(
                File(widget.filePath),
                key:const ValueKey('motivation_crop_preview'),
                fit:BoxFit.cover,
                alignment:focus,
                cacheWidth:1024,
                cacheHeight:1024,
                errorBuilder:(_,__,___)=>ColoredBox(
                  color:colors.primaryFaded,
                  child:Center(child:Icon(Icons.broken_image_outlined,
                    size:48,color:colors.primary)),
                ),
              ),
            )),
          )),
          const SizedBox(height:10),
          Text('Encuadre horizontal',style:AppTypography.bodyMedium),
          Slider(
            key:const ValueKey('motivation_crop_horizontal'),
            min:-1,max:1,divisions:20,value:horizontal,
            label:horizontal.toStringAsFixed(1),
            onChanged:(v)=>setState(()=>horizontal=v),
          ),
          Text('Encuadre vertical',style:AppTypography.bodyMedium),
          Slider(
            key:const ValueKey('motivation_crop_vertical'),
            min:-1,max:1,divisions:20,value:vertical,
            label:vertical.toStringAsFixed(1),
            onChanged:(v)=>setState(()=>vertical=v),
          ),
          // Wrapping action targets avoids horizontal overflow at 320dp
          // and with 200% accessibility text. Cancel remains reachable.
          Wrap(
            key:const ValueKey('motivation_crop_responsive_actions'),
            alignment:WrapAlignment.end,
            crossAxisAlignment:WrapCrossAlignment.center,
            spacing:AppSpacing.xs,
            runSpacing:AppSpacing.xs,
            children:[
              TextButton.icon(
                onPressed:()=>setState((){
                  horizontal=0;
                  vertical=0;
                }),
                icon:const Icon(Icons.center_focus_strong_outlined),
                label:const Text('Centrar'),
              ),
              TextButton(
                onPressed:()=>Navigator.pop(context),
                child:const Text('Cancelar'),
              ),
              FilledButton(
                key:const ValueKey('motivation_crop_apply'),
                onPressed:()=>Navigator.pop(context,
                  MotivationCoverFocus(x:horizontal,y:vertical)),
                child:const Text('Guardar'),
              ),
            ],
          ),
        ]),
      ),
    );
  }
}
