/// Feature-first domain models for the plan invite loop.
///
/// Re-exports the Freezed Plan and PlanMember from the shared layer so
/// feature code can import from a single canonical path without duplicating
/// generated Freezed files.
library plan_models;

export '../../../shared/models/models.dart' show Plan, PlanMember;
