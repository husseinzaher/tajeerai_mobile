import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/bootstrap/dependencies.dart';
import '../../../../failures/app_failure.dart';
import '../../domain/entities/customer.dart';
import '../../domain/repositories/customer_repository.dart';
import '../../domain/value_objects/phone_digits.dart';

/// Why a contact could not be saved -- a reason, not a sentence.
///
/// The screen words it in the reader's language. A controller that held
/// sentences would put English on an Arabic screen.
enum CustomerFormError {
  /// The number was typed without its country code.
  phoneNeedsCountryCode,

  /// Adding a contact is online-only, and there was no connection.
  needsConnection,

  /// The server already holds this contact.
  alreadyExists,

  /// Anything else.
  saveFailed,
}

/// How a save ended, for the screen to act on.
sealed class CustomerFormOutcome {
  const CustomerFormOutcome();
}

/// A contact was created.
final class CustomerSaved extends CustomerFormOutcome {
  const CustomerSaved(this.customerId);

  final String customerId;
}

/// The number already belonged to somebody; nothing was created.
final class CustomerAlreadyExisted extends CustomerFormOutcome {
  const CustomerAlreadyExisted(this.customerId);

  final String customerId;
}

/// Nothing was saved, for the reason the state now carries.
final class CustomerSaveRefused extends CustomerFormOutcome {
  const CustomerSaveRefused(this.error);

  final CustomerFormError error;
}

/// The contact form's state. It holds no field text -- that lives in the
/// screen's controllers and is handed to [CustomerFormController.save].
final class CustomerFormState {
  const CustomerFormState({this.isSaving = false, this.error});

  final bool isSaving;
  final CustomerFormError? error;

  CustomerFormState copyWith({
    bool? isSaving,
    CustomerFormError? error,
    bool clearError = false,
  }) {
    return CustomerFormState(
      isSaving: isSaving ?? this.isSaving,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CustomerFormState &&
      other.isSaving == isSaving &&
      other.error == error;

  @override
  int get hashCode => Object.hash(isSaving, error);
}

/// Auto-disposed, so the next contact starts from a clean form.
final NotifierProvider<CustomerFormController, CustomerFormState>
customerFormControllerProvider =
    NotifierProvider.autoDispose<CustomerFormController, CustomerFormState>(
      CustomerFormController.new,
    );

/// Owns adding a contact.
///
/// **Online only.** The record needs a server id before anything else can
/// point at it, and a contact created offline would be a second person the
/// moment somebody else added the same number.
///
/// Before it creates one it looks for the number among the contacts this
/// device already holds -- so the common case, a number that is already
/// somebody, opens them instead of quietly making a duplicate. The check is
/// local because that is where the caller card's own answer comes from: if
/// this device thinks the number is new, the card thought so too.
///
/// A controller rather than code in the screen, so the sequence -- validate,
/// look up, create -- runs where it can be tested without a widget tree, and
/// so the widget holds no repository.
class CustomerFormController extends Notifier<CustomerFormState> {
  /// The workspace's home market, and the same default the web's phone control
  /// opens on -- the two have to agree, or a number typed in one place is a
  /// different number in the other.
  ///
  /// A number typed without one is the mistake the field invites: the API
  /// refuses it, and `0501234567` is Saudi Arabia's number to a Saudi reader
  /// and somebody else's to everybody else. Starting the field at `+966` makes
  /// the right answer the easy one, and it is still editable for a contact
  /// abroad.
  static const String defaultCallingCode = '+966';

  @override
  CustomerFormState build() => const CustomerFormState();

  /// Saves the contact, or says why not.
  ///
  /// Returns null when there was nothing to do -- no name, or a save already
  /// in flight. Navigation is the screen's: this reports where the contact is
  /// and the screen decides how to get there.
  Future<CustomerFormOutcome?> save({
    required String name,
    required String phone,
    required String email,
  }) async {
    final String trimmedName = name.trim();

    if (trimmedName.isEmpty || state.isSaving) return null;

    state = const CustomerFormState(isSaving: true);

    final String number = phone.trim();

    // The bare calling code is nobody's number.
    final bool hasNumber = number.isNotEmpty && number != defaultCallingCode;

    // Refused here as well as by the API, so somebody learns what is wrong
    // while the keyboard is still open rather than after a round trip.
    if (hasNumber && !PhoneDigits.isInternational(number)) {
      return _refuse(CustomerFormError.phoneNeedsCountryCode);
    }

    final CustomerRepository customers = ref.read(customerRepositoryProvider);

    try {
      // The duplicate check, before the write rather than after it: a contact
      // created and then found to exist is two rows somebody has to merge.
      if (hasNumber && PhoneDigits.bare(number).isNotEmpty) {
        final Customer? existing = await customers.findByPhone(number);

        if (existing != null) {
          state = state.copyWith(isSaving: false);

          return CustomerAlreadyExisted(existing.id);
        }
      }

      final String trimmedEmail = email.trim();

      final Customer created = await customers.create(
        name: trimmedName,
        // Sent as typed. The server normalises to E.164 with the phone
        // metadata this app deliberately does not carry -- see `PhoneDigits`.
        phone: hasNumber ? number : null,
        email: trimmedEmail.isEmpty ? null : trimmedEmail,
      );

      state = state.copyWith(isSaving: false);

      return CustomerSaved(created.id);
    } on AppFailure catch (failure) {
      return _refuse(switch (failure) {
        TransportFailure(isOffline: true) => CustomerFormError.needsConnection,
        ConflictFailure() => CustomerFormError.alreadyExists,
        _ => CustomerFormError.saveFailed,
      });
    }
  }

  /// Clears the error as the member edits, so a stale message does not sit
  /// under a field they are fixing.
  void clearError() {
    if (state.error == null) return;

    state = state.copyWith(clearError: true);
  }

  CustomerSaveRefused _refuse(CustomerFormError error) {
    state = CustomerFormState(error: error);

    return CustomerSaveRefused(error);
  }
}
