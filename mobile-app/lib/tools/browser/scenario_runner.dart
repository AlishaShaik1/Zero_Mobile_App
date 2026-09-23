import 'package:flutter/foundation.dart';
import '../../services/model_service.dart';
import 'browser_ui_automator.dart';

/// ── SCENARIO RUNNER ────────────────────────────────────────────────────────
/// Implements §6.3: A single interpreter that walks the SDL list and
/// dispatches each entry to the matching primitive.

class ScenarioRunner {
  final BrowserUIAutomator _uiAutomator = BrowserUIAutomator();

  Future<String> run({
    required String scenarioId,
    required String goal,
    required String url,
    required ModelService model,
    required List<Map<String, dynamic>> steps,
  }) async {
    debugPrint(
      '[ScenarioRunner] Starting scenario $scenarioId for goal: $goal',
    );

    int maxSteps = 500; // Hard deadline per task
    int stepCount = 0;

    // Evaluate steps sequentially
    for (final step in steps) {
      if (stepCount >= maxSteps) {
        return 'Error: Exceeded max steps ($maxSteps) for scenario $scenarioId';
      }
      stepCount++;

      final actionType = step.keys.first;
      final params = step[actionType] as Map<String, dynamic>? ?? {};

      debugPrint(
        '[ScenarioRunner] Executing step $stepCount: $actionType -> $params',
      );

      try {
        await _dispatchPrimitive(actionType, params, goal, url, model);
      } catch (e) {
        debugPrint('[ScenarioRunner] Error in step $actionType: $e');
        return 'Error during execution of $actionType: $e';
      }
    }

    return 'Success: Scenario $scenarioId completed.';
  }

  Future<void> _dispatchPrimitive(
    String actionType,
    Map<String, dynamic> params,
    String goal,
    String url,
    ModelService model,
  ) async {
    // Implement the ~20 primitives from §6.2
    switch (actionType) {
      case 'launchApp':
        final package = _resolveParam(params['package'], url, goal);
        // Delegate to Android Accessibility Bridge
        debugPrint('[ScenarioRunner] Action: launchApp $package');
        // In real app: await methodChannel.invokeMethod('launch_app', {'package': package});
        await Future.delayed(const Duration(seconds: 1));
        break;

      case 'openBrowser':
        final targetUrl = _resolveParam(params['url'], url, goal);
        debugPrint('[ScenarioRunner] Action: openBrowser $targetUrl');
        // In real app: await methodChannel.invokeMethod('open_browser', {'url': targetUrl});
        await Future.delayed(const Duration(seconds: 1));
        break;

      case 'wait':
        final seconds = params['seconds'] as int? ?? 1;
        debugPrint('[ScenarioRunner] Action: wait $seconds seconds');
        await Future.delayed(Duration(seconds: seconds));
        break;

      case 'classifyScreen':
        debugPrint('[ScenarioRunner] Action: classifyScreen');
        await _uiAutomator.classifyScreen(model, goal);
        break;

      case 'findFieldByLabel':
        final label = _resolveParam(params['label'], url, goal);
        debugPrint('[ScenarioRunner] Action: findFieldByLabel $label');
        // Determine the best candidate deterministically
        break;

      case 'tapElement':
        final candidates = params['candidates'];
        debugPrint('[ScenarioRunner] Action: tapElement $candidates');
        // Action: methodChannel.invokeMethod('ui_automate_perform_action', {'action': 'tap(...) '});
        break;

      case 'typeText':
        final field = params['field'];
        final value = _resolveParam(params['value'], url, goal);
        debugPrint('[ScenarioRunner] Action: typeText $value into $field');
        break;

      case 'verifyCondition':
        final condition = params['condition'];
        debugPrint('[ScenarioRunner] Action: verifyCondition $condition');
        // Call model with verify condition (Yes/No/Maybe)
        break;

      case 'extractText':
        final region = params['region'];
        debugPrint('[ScenarioRunner] Action: extractText from $region');
        break;

      case 'waitUntil':
        final condition = params['condition'];
        final maxIterations = params['maxIterations'] ?? 10;
        debugPrint(
          '[ScenarioRunner] Action: waitUntil $condition (max $maxIterations)',
        );
        break;

      default:
        debugPrint('[ScenarioRunner] Unknown primitive: $actionType');
        break;
    }
  }

  String _resolveParam(dynamic param, String url, String goal) {
    if (param == null) return '';
    String str = param.toString();
    str = str.replaceAll('{url}', url);
    str = str.replaceAll('{query}', goal);
    str = str.replaceAll(
      '{package}',
      goal.replaceAll(RegExp(r'[^a-zA-Z]'), ''),
    ); // naive fallback
    return str;
  }
}
