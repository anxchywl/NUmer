import 'package:flutter/material.dart';

import 'habits_clearances.dart';
import 'ios_liquid_action_pill.dart';

const createNewHabitLabel = 'Create new';

class HabitsCreateButton extends StatelessWidget {
  const HabitsCreateButton({
    super.key,
    required this.visible,
    required this.shown,
    required this.onPressed,
  });

  final bool visible;
  final bool shown;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Visibility(
      visible: visible,
      maintainState: true,
      maintainAnimation: false,
      maintainSize: false,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutQuart,
        offset: shown ? Offset.zero : const Offset(0, 0.22),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutQuart,
          opacity: shown ? 1 : 0,
          child: IgnorePointer(
            ignoring: !shown,
            child: isIos(context)
                ? Padding(
                    padding: EdgeInsets.only(bottom: iosFabBottomLift(context)),
                    child: IosLiquidActionPill(
                      icon: Icons.add,
                      label: createNewHabitLabel,
                      onPressed: onPressed,
                    ),
                  )
                : FloatingActionButton(
                    onPressed: onPressed,
                    child: const Icon(Icons.add),
                  ),
          ),
        ),
      ),
    );
  }
}
