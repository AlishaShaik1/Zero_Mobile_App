// deep_search_events.dart

abstract class DeepSearchEvent {}

class SearchPlanningEvent extends DeepSearchEvent {
  final String query;
  SearchPlanningEvent(this.query);
}

class SearchPlanReadyEvent extends DeepSearchEvent {
  final List<String> steps;
  SearchPlanReadyEvent(this.steps);
}

class StepStartedEvent extends DeepSearchEvent {
  final int index;
  final int total;
  final String query;
  StepStartedEvent(this.index, this.total, this.query);
}

class StepSourcesFoundEvent extends DeepSearchEvent {
  final int index;
  final List<String> sources;
  StepSourcesFoundEvent(this.index, this.sources);
}

class StepSuccessEvent extends DeepSearchEvent {
  final int index;
  final String summary;
  final String? url;
  final String? title;
  StepSuccessEvent(this.index, this.summary, {this.url, this.title});
}

class StepFailedEvent extends DeepSearchEvent {
  final int index;
  final String error;
  StepFailedEvent(this.index, this.error);
}

class FinalizingReportEvent extends DeepSearchEvent {}

class SearchCompleteEvent extends DeepSearchEvent {
  final String filePath;
  SearchCompleteEvent(this.filePath);
}

class SearchErrorEvent extends DeepSearchEvent {
  final String error;
  SearchErrorEvent(this.error);
}
