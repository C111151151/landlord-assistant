import 'package:flutter_test/flutter_test.dart';
import 'package:landlord_assistant/database_service.dart';

void main() {
  group('leaseCoversMonth', () {
    test('includes the start and end months', () {
      expect(leaseCoversMonth('2026-01-15', '2026-04-14', DateTime(2026, 1)),
          isTrue);
      expect(leaseCoversMonth('2026-01-15', '2026-04-14', DateTime(2026, 4)),
          isTrue);
    });

    test('handles leases that cross into a new year', () {
      expect(leaseCoversMonth('2026-11-01', '2027-01-31', DateTime(2026, 12)),
          isTrue);
      expect(leaseCoversMonth('2026-11-01', '2027-01-31', DateTime(2027, 2)),
          isFalse);
    });

    test('rejects an end date before the move-in date', () {
      expect(
        () => leaseCoversMonth('2026-05-02', '2026-05-01', DateTime(2026, 5)),
        throwsArgumentError,
      );
    });
  });
}
