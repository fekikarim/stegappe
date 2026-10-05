import 'package:equatable/equatable.dart';

/// Backend-owned internship statuses (authoritative, AGENTS.md §4).
///
/// S1b: the legacy `planned` / `active` / `completed` values were removed and
/// replaced by the explicit chain APPROVED → IN_PROGRESS → REPORT_SUBMITTED →
/// UNDER_VALIDATION → VALIDATED → RECEIPT_ISSUED.
enum InternshipStatus {
  approved,
  inProgress,
  reportSubmitted,
  underValidation,
  validated,
  receiptIssued,
  cancelled,
  archived,
}

InternshipStatus internshipStatusFrom(String? raw) =>
    switch (raw?.toUpperCase()) {
      'IN_PROGRESS' => InternshipStatus.inProgress,
      'REPORT_SUBMITTED' => InternshipStatus.reportSubmitted,
      'UNDER_VALIDATION' => InternshipStatus.underValidation,
      'VALIDATED' => InternshipStatus.validated,
      'RECEIPT_ISSUED' => InternshipStatus.receiptIssued,
      'CANCELLED' => InternshipStatus.cancelled,
      'ARCHIVED' => InternshipStatus.archived,
      _ => InternshipStatus.approved,
    };

/// Backend-computed type. Displayed only — never derived on-device.
enum InternshipType { observation, perfectionnement, pfe }

InternshipType? internshipTypeFrom(String? raw) =>
    switch (raw?.toUpperCase()) {
      'OBSERVATION' => InternshipType.observation,
      'PERFECTIONNEMENT' => InternshipType.perfectionnement,
      'PFE' => InternshipType.pfe,
      _ => null,
    };

class Internship extends Equatable {
  const Internship({
    required this.id,
    required this.reference,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.type,
    required this.requirement,
    required this.paymentEligible,
    this.subject,
    this.candidateFullName,
  });

  final String id;
  final String reference;
  final DateTime startDate;
  final DateTime endDate;
  final InternshipStatus status;

  /// Backend-computed; null only if the contract ever sends unknown values.
  final InternshipType? type;
  final String requirement;
  final bool paymentEligible;
  final String? subject;
  final String? candidateFullName;

  /// Date-derived presentation facts (not business rules):
  /// elapsed/total calendar days from backend-provided dates.
  int get totalDays => endDate.difference(startDate).inDays + 1;
  int elapsedDays(DateTime now) {
    if (now.isBefore(startDate)) return 0;
    if (now.isAfter(endDate)) return totalDays;
    return now.difference(startDate).inDays + 1;
  }

  double timelineFraction(DateTime now) {
    if (totalDays <= 0) return 0;
    return (elapsedDays(now) / totalDays).clamp(0.0, 1.0);
  }

  @override
  List<Object?> get props => [
        id,
        reference,
        startDate,
        endDate,
        status,
        type,
        requirement,
        paymentEligible,
        subject,
        candidateFullName,
      ];
}

class InternshipAssignment extends Equatable {
  const InternshipAssignment({
    required this.id,
    required this.departmentName,
    required this.supervisorName,
    required this.status,
    this.startDate,
    this.endDate,
  });

  final String id;
  final String departmentName;
  final String supervisorName;
  final String status;
  final DateTime? startDate;
  final DateTime? endDate;

  /// Assignment status (NOT the internship status): an assignment is ACTIVE,
  /// ENDED, REASSIGNED… — a different enum from §4's internship chain.
  bool get isActive => status.toUpperCase() == 'ACTIVE';

  @override
  List<Object?> get props =>
      [id, departmentName, supervisorName, status, startDate, endDate];
}
