import '/backend/backend.dart';
import '/backend/org/org_service.dart';
import '/components/button/button_widget.dart';
import '/components/condition_chip/condition_chip_widget.dart';
import '/components/module_toggle/module_toggle_widget.dart';
import '/components/nav_menu_directory/nav_menu_directory_widget.dart';
import '/components/text_field/text_field_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/index.dart';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'b_care_profile_setup_model.dart';
export 'b_care_profile_setup_model.dart';

/// The built-in condition chips on this page, in the order they are laid out in
/// the condition Wrap below. The chips are fed from this list, so the names the
/// page saves can never drift from the labels the caregiver sees.
const kCareProfileConditionChipLabels = <String>[
  'Diabetes',
  'Hypertension',
  'Heart Failure',
  'Dementia',
  'Limited Mobility',
  'Fall Risk',
  'Wound Care',
];

/// Collects the conditions to save for a care profile: every selected built-in
/// chip, plus the free-text 'Other / Add Your Own' entry when the caregiver
/// typed one (owner-approved 2026-09-23 — the chips used to be static
/// decoration, and nothing the caregiver picked was written to the recipient's
/// Conditions field).
///
/// Each chip's selection is read off that chip's own widget model, the same
/// pattern the Tracking Modules use via `switchModel.switchValue`, so the page
/// keeps no second copy of the selection state. Top-level so its contract can
/// be pinned in a test without rendering the whole page.
///
/// Owner amendment 2026-11-16: conditions are NEVER comma-split. When the
/// 'Other' text is exactly what was loaded from the record, the stored entries
/// are written back unchanged — so two distinct stored conditions can never be
/// merged into one string by loading and re-saving.
List<String> careProfileConditionsToSave(
  List<ConditionChipModel> chipModels, {
  String? otherCondition,
  List<String> loadedOtherConditions = const [],
}) {
  assert(
    chipModels.length == kCareProfileConditionChipLabels.length,
    'one ConditionChipModel per built-in condition chip',
  );

  final conditions = <String>[
    for (var i = 0; i < chipModels.length; i++)
      if (valueOrDefault<bool>(chipModels[i].selectedValue, false))
        kCareProfileConditionChipLabels[i],
  ];

  final other = otherCondition?.trim() ?? '';
  if (other.isEmpty) {
    return conditions;
  }

  final unchanged = loadedOtherConditions.isNotEmpty &&
      other == loadedOtherConditions.join(', ').trim();
  final toAdd = unchanged ? loadedOtherConditions : <String>[other];
  for (final condition in toAdd) {
    if (condition.isNotEmpty && !conditions.contains(condition)) {
      conditions.add(condition);
    }
  }

  return conditions;
}

/// The stored conditions, split into the built-in chips they select and the
/// custom entries that belong in the 'Other / Add Your Own' field.
class CareProfileConditionSelection {
  const CareProfileConditionSelection({
    required this.chipLabels,
    required this.otherConditions,
  });

  /// The built-in chip labels the stored record selects, in chip order.
  final List<String> chipLabels;

  /// The stored conditions that no chip covers, in stored order (untouched —
  /// they are written back verbatim when the caregiver leaves the field as-is).
  final List<String> otherConditions;

  String get otherText => otherConditions.join(', ');
}

/// Reads a stored `Conditions` list back into the form (owner-approved
/// 2026-11-16: the page used to never load them, so saving a profile blanked
/// the recipient's conditions).
CareProfileConditionSelection careProfileConditionsFromRecord(
  List<String> stored,
) {
  final chips = <String>[];
  final other = <String>[];
  for (final condition in stored) {
    if (condition.trim().isEmpty) {
      continue;
    }
    if (kCareProfileConditionChipLabels.contains(condition)) {
      if (!chips.contains(condition)) {
        chips.add(condition);
      }
    } else {
      other.add(condition);
    }
  }
  chips.sort((a, b) => kCareProfileConditionChipLabels
      .indexOf(a)
      .compareTo(kCareProfileConditionChipLabels.indexOf(b)));
  return CareProfileConditionSelection(
    chipLabels: chips,
    otherConditions: other,
  );
}

/// Parses the comma-separated Allergies field into the stored `Allergies` list.
///
/// A value that is unchanged from what was loaded is written back exactly as
/// stored (so legacy allergy entries are never re-split); a value the caregiver
/// typed is split on commas, trimmed, and empty entries dropped.
List<String> careProfileAllergiesToSave(
  String? allergies, {
  List<String> loadedAllergies = const [],
}) {
  final text = allergies?.trim() ?? '';
  if (text.isEmpty) {
    return const [];
  }
  if (loadedAllergies.isNotEmpty &&
      text == loadedAllergies.join(', ').trim()) {
    return List<String>.from(loadedAllergies);
  }
  return [
    for (final allergy in text.split(','))
      if (allergy.trim().isNotEmpty) allergy.trim(),
  ];
}

/// The Advance Directives options, in the order the chips are laid out.
const kCareProfileAdvanceDirectivesLabels = <String>[
  'On file',
  'Not on file',
  'Unknown',
];
const kCareProfileAdvanceDirectivesValues = <String>[
  kAdvanceDirectivesOnFile,
  kAdvanceDirectivesNotOnFile,
  kAdvanceDirectivesUnknown,
];

/// The caregiver-facing label for a stored Advance Directives status.
String careProfileAdvanceDirectivesLabel(String status) {
  final index = kCareProfileAdvanceDirectivesValues.indexOf(status);
  return index == -1
      ? kCareProfileAdvanceDirectivesLabels.last
      : kCareProfileAdvanceDirectivesLabels[index];
}

/// Date formats the Date of Birth input accepts. Existing records store display
/// strings ("14 Mar 1948"), so a stored value is ALWAYS saveable: a value that
/// is unchanged from what was loaded is accepted verbatim and never rewritten
/// (owner amendment 2026-11-16).
const kCareProfileDateOfBirthFormats = <String>[
  'MM/dd/yyyy',
  'M/d/yyyy',
  'yyyy-MM-dd',
  'd MMM yyyy',
  'd MMMM yyyy',
  'MMM d, yyyy',
  'MMMM d, yyyy',
];

/// Validates the Date of Birth input. Returns null when the value is acceptable
/// (empty, unchanged from the loaded value, or a real calendar date in one of
/// [kCareProfileDateOfBirthFormats]) and the message to show otherwise.
///
/// The value is only validated, never normalised: what the caregiver typed (or
/// what was already stored) is saved exactly as-is.
String? careProfileDateOfBirthError(String? value, {String? loadedValue}) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) {
    return null;
  }
  if (text == (loadedValue?.trim() ?? '')) {
    return null;
  }
  for (final format in kCareProfileDateOfBirthFormats) {
    try {
      final parsed = DateFormat(format, 'en_US').parseStrict(text);
      // A real calendar date round-trips through the same format; '02/30/1948'
      // parses but formats back as '03/01/1948', so it is rejected.
      if (DateFormat(format, 'en_US').format(parsed) == text) {
        return null;
      }
    } on FormatException {
      // Try the next accepted format.
    }
  }
  return 'Enter the date of birth as MM/DD/YYYY (for example 03/14/1948).';
}

class BCareProfileSetupWidget extends StatefulWidget {
  const BCareProfileSetupWidget({
    super.key,
    this.careRecipients,
  });

  /// The care recipient being edited (owner-approved 2026-11-14).
  ///
  /// Present  -> edit that recipient: the form loads it and Save updates it.
  /// Absent   -> today's create behaviour, unchanged. Every existing push site
  ///             (nav menu, share menu, directory "add" card) passes nothing,
  ///             so adding a second care recipient still works.
  final DocumentReference? careRecipients;

  static String routeName = 'BCareProfileSetup';
  static String routePath = '/bCareProfileSetup';

  @override
  State<BCareProfileSetupWidget> createState() =>
      _BCareProfileSetupWidgetState();
}

class _BCareProfileSetupWidgetState extends State<BCareProfileSetupWidget> {
  late BCareProfileSetupModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  /// Edit mode (owner-approved 2026-11-14): true while the recipient being
  /// edited is loading, and the reason it could not be loaded. While either is
  /// in play Save stays disabled — an unloaded form must never be savable, or
  /// it would write blanks over a real profile.
  bool _loadingExisting = false;
  String? _loadError;

  /// The Date of Birth validation message, shown under the field and blocking
  /// the save until the value is a real date (owner amendment 2026-11-16).
  String? _dateOfBirthError;

  bool get _isEditing => widget.careRecipients != null;
  bool get _saveBlocked =>
      _isEditing && (_loadingExisting || _loadError != null);

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => BCareProfileSetupModel());

    if (_isEditing) {
      _loadExisting();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  /// Loads the recipient being edited and prefills the form.
  ///
  /// The text controllers are set directly: TextFieldWidget seeds its
  /// controller from `value:` only once, in its own initState, so a later
  /// rebuild cannot prefill it.
  Future<void> _loadExisting() async {
    final recipientRef = widget.careRecipients;
    if (recipientRef == null) {
      return;
    }
    safeSetState(() {
      _loadingExisting = true;
      _loadError = null;
    });
    try {
      final recipient =
          await CareRecipientsRecord.getDocumentOnce(recipientRef);
      if (!mounted) {
        return;
      }
      final conditions = careProfileConditionsFromRecord(recipient.conditions);
      safeSetState(() {
        _loadingExisting = false;
        _loadError = null;

        _model.loadedDateOfBirth = recipient.dateOfBirth;
        _model.loadedAllergies = List<String>.from(recipient.allergies);
        _model.loadedOtherConditions =
            List<String>.from(conditions.otherConditions);
        _model.advanceDirectivesStatus = recipient.advanceDirectivesStatus;

        _setText(_model.textFieldNameModel, recipient.name);
        _setText(
            _model.textFieldDateOfBirthModel, recipient.dateOfBirth);
        _setText(
            _model.textFieldPrimaryModel, recipient.primaryCondition);
        _setText(_model.textFieldAddConditionModel, conditions.otherText);
        _setText(_model.textFieldAllergiesModel,
            recipient.allergies.join(', '));
        _setText(_model.textFieldPrimaryContactModel,
            recipient.primaryCarePhysicianName);
        _setText(_model.textFieldPrimaryPhoneModel,
            recipient.primaryCarePhysicianPhone);
        _setText(
            _model.textFieldEmergencyModel, recipient.emergencyContactName);
        _setText(
            _model.textFieldEmergencyPhoneModel, recipient.emergencyContactPhone);
        _setText(_model.textFieldAdvanceDirectivesNotesModel,
            recipient.advanceDirectivesNotes);

        for (var i = 0; i < kCareProfileConditionChipLabels.length; i++) {
          _conditionChipModels[i].selectedValue =
              conditions.chipLabels.contains(kCareProfileConditionChipLabels[i]);
        }
        _applyAdvanceDirectivesStatus(_model.advanceDirectivesStatus);

        _model.moduleToggleModel1.switchModel.switchValue =
            recipient.trackVitals;
        _model.moduleToggleModel2.switchModel.switchValue =
            recipient.trackGlucose;
        _model.moduleToggleModel3.switchModel.switchValue =
            recipient.trackMedication;
        _model.moduleToggleModel4.switchModel.switchValue =
            recipient.trackSymptoms;
        _model.moduleToggleModel5.switchModel.switchValue =
            recipient.tracksMealsHydration;
      });
    } catch (_) {
      if (mounted) {
        safeSetState(() {
          _loadingExisting = false;
          _loadError = 'Could not load this care profile. Please check your '
              'connection and try again.';
        });
      }
    }
  }

  /// Puts [text] in [field]'s controller, cursor at the end.
  void _setText(TextFieldModel field, String text) {
    final controller =
        field.inputTextController ??= TextEditingController();
    controller.text = text;
    controller.selection =
        TextSelection.collapsed(offset: controller.text.length);
  }

  /// The seven built-in condition chips, in layout order.
  List<ConditionChipModel> get _conditionChipModels => [
        _model.conditionChipModel1,
        _model.conditionChipModel2,
        _model.conditionChipModel3,
        _model.conditionChipModel4,
        _model.conditionChipModel5,
        _model.conditionChipModel6,
        _model.conditionChipModel7,
      ];

  /// The three Advance Directives chips, in layout order.
  List<ConditionChipModel> get _advanceDirectivesChipModels => [
        _model.conditionChipAdvanceDirectivesModel1,
        _model.conditionChipAdvanceDirectivesModel2,
        _model.conditionChipAdvanceDirectivesModel3,
      ];

  /// Selects [status] and nothing else — the three Advance Directives chips are
  /// a mutually exclusive group.
  void _applyAdvanceDirectivesStatus(String status) {
    final selected = kCareProfileAdvanceDirectivesValues.contains(status)
        ? status
        : kAdvanceDirectivesUnknown;
    _model.advanceDirectivesStatus = selected;
    final chips = _advanceDirectivesChipModels;
    for (var i = 0; i < chips.length; i++) {
      chips[i].selectedValue =
          kCareProfileAdvanceDirectivesValues[i] == selected;
    }
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  /// The Date of Birth to store: what was typed, except that an UNCHANGED
  /// legacy value is written back exactly as it was stored (never rewritten).
  String _dateOfBirthToSave() {
    final typed = (_model.textFieldDateOfBirthModel.inputTextController?.text ??
            '')
        .trim();
    final loaded = _model.loadedDateOfBirth?.trim() ?? '';
    if (_isEditing && typed == loaded) {
      return _model.loadedDateOfBirth ?? '';
    }
    return typed;
  }

  /// Saves the form: creates a new care recipient when the page was opened
  /// without a recipient, updates the one it was opened with otherwise
  /// (owner-approved 2026-11-14 — the same editor, never a second one).
  Future<void> _save() async {
    if (_saveBlocked) {
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to save a care recipient.')),
      );
      return;
    }

    // Date of Birth is validated before anything is written (owner amendment
    // 2026-11-16): an invalid date blocks the save and nothing is stored.
    final dateOfBirthError = careProfileDateOfBirthError(
      _model.textFieldDateOfBirthModel.inputTextController?.text,
      loadedValue: _model.loadedDateOfBirth,
    );
    safeSetState(() => _dateOfBirthError = dateOfBirthError);
    if (dateOfBirthError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(dateOfBirthError)),
      );
      return;
    }

    final data = createCareRecipientsRecordData(
      name: _model.textFieldNameModel.inputTextController.text,
      dateOfBirth: _dateOfBirthToSave(),
      conditions: careProfileConditionsToSave(
        _conditionChipModels,
        otherCondition: _model.textFieldAddConditionModel.inputTextController?.text,
        loadedOtherConditions: _model.loadedOtherConditions,
      ),
      allergies: careProfileAllergiesToSave(
        _model.textFieldAllergiesModel.inputTextController?.text,
        loadedAllergies: _model.loadedAllergies,
      ),
      primaryCondition: _model.textFieldPrimaryModel.inputTextController.text,
      primaryCarePhysicianName:
          _model.textFieldPrimaryContactModel.inputTextController.text,
      primaryCarePhysicianPhone:
          _model.textFieldPrimaryPhoneModel.inputTextController.text,
      emergencyContactName:
          _model.textFieldEmergencyModel.inputTextController.text,
      emergencyContactPhone:
          _model.textFieldEmergencyPhoneModel.inputTextController.text,
      trackVitals: _model.moduleToggleModel1.switchModel.switchValue,
      trackGlucose: _model.moduleToggleModel2.switchModel.switchValue,
      trackMedication: _model.moduleToggleModel3.switchModel.switchValue,
      trackSymptoms: _model.moduleToggleModel4.switchModel.switchValue,
      tracksMealsHydration: _model.moduleToggleModel5.switchModel.switchValue,
      advanceDirectivesStatus: _model.advanceDirectivesStatus,
      advanceDirectivesNotes: (_model
                  .textFieldAdvanceDirectivesNotesModel
                  .inputTextController
                  ?.text ??
              '')
          .trim(),
      // The update stamps UpdatedAt; a create keeps its previous payload
      // (CreatedAt is written by the create helper's caller path as before).
      updatedAt: _isEditing ? DateTime.now() : null,
    );

    try {
      if (_isEditing) {
        // Only the fields this form owns are sent; the merged update leaves
        // orgId, migrationStatus, CreatedAt and every other stored field alone.
        await updateCareRecipientForActiveGroup(
          user: user,
          recipientRef: widget.careRecipients!,
          data: data,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Care Profile saved successfully.'),
            ),
          );
          // Back to wherever the editor was opened from (the Emergency Info
          // screen), which reloads and shows the saved values.
          context.pop();
        }
        return;
      }

      final createdRef = await createCareRecipientForActiveGroup(
        user: user,
        data: data,
      );
      // Make this the active care card so the rest of the app (dashboard,
      // notes, etc.) shows the profile we just saved.
      FFAppState().selectedCareRecipient = createdRef;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Care Profile saved successfully.'),
          ),
        );
        // Navigate to the newly created recipient's Daily Dashboard (same
        // destination/pattern as the nav menu's "Daily Care" and the Client
        // Directory card tap). selectedCareRecipient was set above so the
        // dashboard opens for the new recipient, not a stale one.
        context.pushNamed(CDailyDashboardWidget.routeName);
      }
    } on OrgAccessDeniedException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } on SaveStepException catch (e) {
      // A SaveStepException carries the exact step label + Firestore code +
      // message, so the owner can read WHICH operation was denied straight
      // from the snackbar, no devtools.
      print('CareProfileSetup: save failed (step $e)');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save at step ${e.step}: $e'),
        ),
      );
    } catch (e) {
      // A failed save must never destroy the entered form data: the text
      // fields retain their controllers, and we only surface a clear message
      // instead of wiping the form. But the failure must NOT be silent: log
      // the real exception (Firestore code + message) so a non-membership
      // failure (permission-denied, unavailable, invalid-argument, ...) is
      // diagnosable instead of opaque.
      print(
        'CareProfileSetup: save failed (non-membership): '
        '${e is FirebaseException ? '${e.code}: ${e.message}' : e.toString()}',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Could not save: '
              '${e is FirebaseException ? e.code : e.runtimeType} — '
              '${e.toString().length > 80 ? e.toString().substring(0, 80) : e.toString()}'),
        ),
      );
    }
  }

  /// Edit-mode status line (loading / could-not-load) above the form.
  Widget _editModeBanner(BuildContext context, String message) => Container(
        decoration: BoxDecoration(
          color: FlutterFlowTheme.of(context).info10,
          borderRadius: BorderRadius.circular(20.0),
          shape: BoxShape.rectangle,
          border: Border.all(
            color: FlutterFlowTheme.of(context).info20,
            width: 1.0,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: FlutterFlowTheme.of(context).onSurface,
                size: 20.0,
              ),
              Expanded(
                flex: 1,
                child: Text(
                  message,
                  style: FlutterFlowTheme.of(context).bodySmall.override(
                        font: GoogleFonts.nunito(
                          fontWeight:
                              FlutterFlowTheme.of(context).bodySmall.fontWeight,
                          fontStyle:
                              FlutterFlowTheme.of(context).bodySmall.fontStyle,
                        ),
                        color: FlutterFlowTheme.of(context).onSurface,
                        letterSpacing: 0.0,
                        fontWeight:
                            FlutterFlowTheme.of(context).bodySmall.fontWeight,
                        fontStyle:
                            FlutterFlowTheme.of(context).bodySmall.fontStyle,
                        lineHeight: 1.5,
                      ),
                ),
              ),
            ].divide(SizedBox(width: 16.0)),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        body: Stack(
          children: [
            Align(
              alignment: AlignmentDirectional(0.0, 0.0),
              child: Padding(
                padding: EdgeInsetsDirectional.fromSTEB(0.0, 50.0, 0.0, 0.0),
                child: SingleChildScrollView(
                  primary: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color:
                              FlutterFlowTheme.of(context).secondaryBackground,
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(10.0),
                            bottomRight: Radius.circular(10.0),
                          ),
                          shape: BoxShape.rectangle,
                        ),
                        alignment: AlignmentDirectional(0.0, 0.0),
                      ),
                      Container(
                        width: 100.0,
                        height: 117.43,
                        decoration: BoxDecoration(
                          color:
                              FlutterFlowTheme.of(context).secondaryBackground,
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color:
                                FlutterFlowTheme.of(context).primaryBackground,
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(10.0),
                              bottomRight: Radius.circular(10.0),
                            ),
                            shape: BoxShape.rectangle,
                          ),
                          alignment: AlignmentDirectional(-1.0, 0.0),
                          child: Stack(
                            children: [
                              Align(
                                alignment: AlignmentDirectional(1.0, 0.0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: EdgeInsetsDirectional.fromSTEB(
                                          24.0, 32.0, 24.0, 32.0),
                                      child: Container(
                                        child: Align(
                                          alignment:
                                              AlignmentDirectional(-1.0, 0.0),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            mainAxisAlignment:
                                                MainAxisAlignment.start,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisSize: MainAxisSize.max,
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.center,
                                                children: [
                                                  Align(
                                                    alignment:
                                                        AlignmentDirectional(
                                                            1.0, -1.0),
                                                    child: Padding(
                                                      padding:
                                                          EdgeInsetsDirectional
                                                              .fromSTEB(
                                                                  20.0,
                                                                  0.0,
                                                                  0.0,
                                                                  0.0),
                                                      child:
                                                          FlutterFlowIconButton(
                                                        borderRadius: 28.0,
                                                        buttonSize: 40.0,
                                                        fillColor: FlutterFlowTheme
                                                                .of(context)
                                                            .secondaryBackground,
                                                        icon: Icon(
                                                          Icons.menu,
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .secondaryText,
                                                          size: 24.0,
                                                        ),
                                                        onPressed: () async {
                                                          await showModalBottomSheet(
                                                            isScrollControlled:
                                                                true,
                                                            backgroundColor:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .primaryBackground,
                                                            enableDrag: false,
                                                            context: context,
                                                            builder: (context) {
                                                              return GestureDetector(
                                                                onTap: () {
                                                                  FocusScope.of(
                                                                          context)
                                                                      .unfocus();
                                                                  FocusManager
                                                                      .instance
                                                                      .primaryFocus
                                                                      ?.unfocus();
                                                                },
                                                                child: Padding(
                                                                  padding: MediaQuery
                                                                      .viewInsetsOf(
                                                                          context),
                                                                  child:
                                                                      NavMenuDirectoryWidget(),
                                                                ),
                                                              );
                                                            },
                                                          ).then((value) =>
                                                              safeSetState(
                                                                  () {}));
                                                        },
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Column(
                                                mainAxisSize: MainAxisSize.min,
                                                mainAxisAlignment:
                                                    MainAxisAlignment.start,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: <Widget>[].divide(
                                                    SizedBox(height: 4.0)),
                                              ),
                                            ].divide(SizedBox(height: 1.0)),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Align(
                                alignment: AlignmentDirectional(-1.0, 0.0),
                                child: Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      30.0, 0.0, 7.0, 0.0),
                                  child: Text(
                                    'Care Profile Setup',
                                    textAlign: TextAlign.start,
                                    style: FlutterFlowTheme.of(context)
                                        .headlineMedium
                                        .override(
                                          font: GoogleFonts.dmSans(
                                            fontWeight: FontWeight.bold,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .headlineMedium
                                                    .fontStyle,
                                          ),
                                          color: FlutterFlowTheme.of(context)
                                              .primaryText,
                                          letterSpacing: 0.0,
                                          fontWeight: FontWeight.bold,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .headlineMedium
                                                  .fontStyle,
                                          lineHeight: 1.3,
                                        ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Edit mode only: the profile is loading, or it
                            // could not be loaded and Save stays disabled.
                            if (_loadingExisting)
                              _editModeBanner(
                                  context, 'Loading this care profile...'),
                            if (_loadError != null)
                              _editModeBanner(context, _loadError!),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Client Information',
                                  style: FlutterFlowTheme.of(context)
                                      .titleMedium
                                      .override(
                                        font: GoogleFonts.dmSans(
                                          fontWeight: FontWeight.bold,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .titleMedium
                                                  .fontStyle,
                                        ),
                                        letterSpacing: 0.0,
                                        fontWeight: FontWeight.bold,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .titleMedium
                                            .fontStyle,
                                        lineHeight: 1.45,
                                      ),
                                ),
                                wrapWithModel(
                                  model: _model.textFieldNameModel,
                                  updateCallback: () => safeSetState(() {}),
                                  child: TextFieldWidget(
                                    label: 'Full Name',
                                    labelPresent: true,
                                    helper: '',
                                    helperPresent: false,
                                    leadingIcon: Icon(
                                      Icons.person_outline_rounded,
                                      color: FlutterFlowTheme.of(context)
                                          .primaryText,
                                      size: 24.0,
                                    ),
                                    leadingIconPresent: true,
                                    trailingIconPresent: false,
                                    hint: 'e.g. Margaret Smith',
                                    value: '',
                                    onChange: '',
                                    onSubmit: '',
                                    variant: 'outlined',
                                    error: false,
                                  ),
                                ),
                                // Date of Birth (owner-approved 2026-11-14):
                                // a validated date input on the existing
                                // DateOfBirth field. Existing stored values are
                                // loaded verbatim and saved verbatim.
                                wrapWithModel(
                                  model: _model.textFieldDateOfBirthModel,
                                  updateCallback: () => safeSetState(() {}),
                                  child: TextFieldWidget(
                                    label: 'Date of Birth',
                                    labelPresent: true,
                                    helper: _dateOfBirthError ?? '',
                                    helperPresent: _dateOfBirthError != null,
                                    leadingIcon: Icon(
                                      Icons.cake_outlined,
                                      color: FlutterFlowTheme.of(context)
                                          .primaryText,
                                      size: 24.0,
                                    ),
                                    leadingIconPresent: true,
                                    trailingIconPresent: false,
                                    hint: 'MM/DD/YYYY',
                                    value: '',
                                    onChange: '',
                                    onSubmit: '',
                                    variant: 'outlined',
                                    error: _dateOfBirthError != null,
                                  ),
                                ),
                                wrapWithModel(
                                  model: _model.textFieldPrimaryModel,
                                  updateCallback: () => safeSetState(() {}),
                                  child: TextFieldWidget(
                                    label: 'Primary Condition',
                                    labelPresent: true,
                                    helper: '',
                                    helperPresent: false,
                                    leadingIcon: Icon(
                                      Icons.medical_services_outlined,
                                      color: FlutterFlowTheme.of(context)
                                          .primaryText,
                                      size: 24.0,
                                    ),
                                    leadingIconPresent: true,
                                    trailingIconPresent: false,
                                    hint: 'e.g. Stroke Recovery',
                                    value: '',
                                    onChange: '',
                                    onSubmit: '',
                                    variant: 'outlined',
                                    error: false,
                                  ),
                                ),
                              ].divide(SizedBox(height: 16.0)),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.max,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Care Conditions',
                                      style: FlutterFlowTheme.of(context)
                                          .titleMedium
                                          .override(
                                            font: GoogleFonts.dmSans(
                                              fontWeight: FontWeight.bold,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .titleMedium
                                                      .fontStyle,
                                            ),
                                            letterSpacing: 0.0,
                                            fontWeight: FontWeight.bold,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .titleMedium
                                                    .fontStyle,
                                            lineHeight: 1.45,
                                          ),
                                    ),
                                    Text(
                                      'Select All That Apply',
                                      style: FlutterFlowTheme.of(context)
                                          .labelSmall
                                          .override(
                                            font: GoogleFonts.nunito(
                                              fontWeight:
                                                  FlutterFlowTheme.of(context)
                                                      .labelSmall
                                                      .fontWeight,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .labelSmall
                                                      .fontStyle,
                                            ),
                                            color: FlutterFlowTheme.of(context)
                                                .onBackground,
                                            letterSpacing: 0.0,
                                            fontWeight:
                                                FlutterFlowTheme.of(context)
                                                    .labelSmall
                                                    .fontWeight,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .labelSmall
                                                    .fontStyle,
                                            lineHeight: 1.3,
                                          ),
                                    ),
                                  ],
                                ),
                                Wrap(
                                  spacing: 8.0,
                                  runSpacing: 8.0,
                                  alignment: WrapAlignment.start,
                                  crossAxisAlignment: WrapCrossAlignment.start,
                                  direction: Axis.horizontal,
                                  runAlignment: WrapAlignment.start,
                                  verticalDirection: VerticalDirection.down,
                                  clipBehavior: Clip.none,
                                  children: [
                                    wrapWithModel(
                                      model: _model.conditionChipModel1,
                                      updateCallback: () => safeSetState(() {}),
                                      child: ConditionChipWidget(
                                        label:
                                            kCareProfileConditionChipLabels[0],
                                        selected: true,
                                      ),
                                    ),
                                    wrapWithModel(
                                      model: _model.conditionChipModel2,
                                      updateCallback: () => safeSetState(() {}),
                                      child: ConditionChipWidget(
                                        label:
                                            kCareProfileConditionChipLabels[1],
                                        selected: true,
                                      ),
                                    ),
                                    wrapWithModel(
                                      model: _model.conditionChipModel3,
                                      updateCallback: () => safeSetState(() {}),
                                      child: ConditionChipWidget(
                                        label:
                                            kCareProfileConditionChipLabels[2],
                                        selected: false,
                                      ),
                                    ),
                                    wrapWithModel(
                                      model: _model.conditionChipModel4,
                                      updateCallback: () => safeSetState(() {}),
                                      child: ConditionChipWidget(
                                        label:
                                            kCareProfileConditionChipLabels[3],
                                        selected: false,
                                      ),
                                    ),
                                    wrapWithModel(
                                      model: _model.conditionChipModel5,
                                      updateCallback: () => safeSetState(() {}),
                                      child: ConditionChipWidget(
                                        label:
                                            kCareProfileConditionChipLabels[4],
                                        selected: true,
                                      ),
                                    ),
                                    wrapWithModel(
                                      model: _model.conditionChipModel6,
                                      updateCallback: () => safeSetState(() {}),
                                      child: ConditionChipWidget(
                                        label:
                                            kCareProfileConditionChipLabels[5],
                                        selected: true,
                                      ),
                                    ),
                                    wrapWithModel(
                                      model: _model.conditionChipModel7,
                                      updateCallback: () => safeSetState(() {}),
                                      child: ConditionChipWidget(
                                        label:
                                            kCareProfileConditionChipLabels[6],
                                        selected: false,
                                      ),
                                    ),
                                  ],
                                ),
                                wrapWithModel(
                                  model: _model.textFieldAddConditionModel,
                                  updateCallback: () => safeSetState(() {}),
                                  child: TextFieldWidget(
                                    label: 'Other / Add Your Own',
                                    labelPresent: true,
                                    helper: '',
                                    helperPresent: false,
                                    leadingIconPresent: false,
                                    trailingIconPresent: false,
                                    hint: 'Type a condition...',
                                    value: '',
                                    onChange: '',
                                    onSubmit: '',
                                    variant: 'ghost',
                                    error: false,
                                  ),
                                ),
                                // Allergies (owner-approved 2026-11-14): the
                                // create helper could not write this field at
                                // all, so the Emergency Info allergy badges had
                                // no way to be filled in.
                                wrapWithModel(
                                  model: _model.textFieldAllergiesModel,
                                  updateCallback: () => safeSetState(() {}),
                                  child: TextFieldWidget(
                                    label: 'Allergies',
                                    labelPresent: true,
                                    helper: 'Separate each allergy with a comma',
                                    helperPresent: true,
                                    leadingIcon: Icon(
                                      Icons.warning_amber_rounded,
                                      color: FlutterFlowTheme.of(context)
                                          .primaryText,
                                      size: 24.0,
                                    ),
                                    leadingIconPresent: true,
                                    trailingIconPresent: false,
                                    hint: 'e.g. Penicillin, Latex',
                                    value: '',
                                    onChange: '',
                                    onSubmit: '',
                                    variant: 'outlined',
                                    error: false,
                                  ),
                                ),
                              ].divide(SizedBox(height: 16.0)),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Tracking Modules',
                                  style: FlutterFlowTheme.of(context)
                                      .titleMedium
                                      .override(
                                        font: GoogleFonts.dmSans(
                                          fontWeight: FontWeight.bold,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .titleMedium
                                                  .fontStyle,
                                        ),
                                        letterSpacing: 0.0,
                                        fontWeight: FontWeight.bold,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .titleMedium
                                            .fontStyle,
                                        lineHeight: 1.45,
                                      ),
                                ),
                                wrapWithModel(
                                  model: _model.moduleToggleModel1,
                                  updateCallback: () => safeSetState(() {}),
                                  child: ModuleToggleWidget(
                                    icon: Icon(
                                      Icons.favorite_border_rounded,
                                      color:
                                          FlutterFlowTheme.of(context).primary,
                                      size: 20.0,
                                    ),
                                    subtitle:
                                        'Blood pressure, heart rate, weight',
                                    title: 'Vitals Tracker',
                                    active: true,
                                  ),
                                ),
                                wrapWithModel(
                                  model: _model.moduleToggleModel2,
                                  updateCallback: () => safeSetState(() {}),
                                  child: ModuleToggleWidget(
                                    icon: Icon(
                                      Icons.water_drop_rounded,
                                      color:
                                          FlutterFlowTheme.of(context).primary,
                                      size: 20.0,
                                    ),
                                    subtitle: 'Blood sugar & insulin logs',
                                    title: 'Glucose Tracker',
                                    active: true,
                                  ),
                                ),
                                wrapWithModel(
                                  model: _model.moduleToggleModel3,
                                  updateCallback: () => safeSetState(() {}),
                                  child: ModuleToggleWidget(
                                    icon: Icon(
                                      Icons.medication_outlined,
                                      color:
                                          FlutterFlowTheme.of(context).primary,
                                      size: 20.0,
                                    ),
                                    subtitle: 'Schedules & refill reminders',
                                    title: 'Medication Tracker',
                                    active: true,
                                  ),
                                ),
                                wrapWithModel(
                                  model: _model.moduleToggleModel4,
                                  updateCallback: () => safeSetState(() {}),
                                  child: ModuleToggleWidget(
                                    icon: Icon(
                                      Icons.psychology_rounded,
                                      color: FlutterFlowTheme.of(context)
                                          .secondaryText,
                                      size: 20.0,
                                    ),
                                    subtitle: 'Falls, mood, pain, appetite',
                                    title: 'Symptoms Log',
                                    active: false,
                                  ),
                                ),
                                wrapWithModel(
                                  model: _model.moduleToggleModel5,
                                  updateCallback: () => safeSetState(() {}),
                                  child: ModuleToggleWidget(
                                    icon: Icon(
                                      Icons.restaurant_rounded,
                                      color:
                                          FlutterFlowTheme.of(context).primary,
                                      size: 20.0,
                                    ),
                                    subtitle: 'Nutrition and fluid intake',
                                    title: 'Meals & Hydration',
                                    active: true,
                                  ),
                                ),
                              ].divide(SizedBox(height: 16.0)),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Primary Physician',
                                  style: FlutterFlowTheme.of(context)
                                      .titleMedium
                                      .override(
                                        font: GoogleFonts.dmSans(
                                          fontWeight: FontWeight.bold,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .titleMedium
                                                  .fontStyle,
                                        ),
                                        letterSpacing: 0.0,
                                        fontWeight: FontWeight.bold,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .titleMedium
                                            .fontStyle,
                                        lineHeight: 1.45,
                                      ),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryBackground,
                                    borderRadius: BorderRadius.circular(28.0),
                                    shape: BoxShape.rectangle,
                                    border: Border.all(
                                      color: FlutterFlowTheme.of(context)
                                          .alternate,
                                      width: 1.0,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.all(24.0),
                                    child: Container(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          wrapWithModel(
                                            model: _model
                                                .textFieldPrimaryContactModel,
                                            updateCallback: () =>
                                                safeSetState(() {}),
                                            child: TextFieldWidget(
                                              label: 'Primary Physician',
                                              labelPresent: true,
                                              helper: '',
                                              helperPresent: false,
                                              leadingIcon: Icon(
                                                Icons.local_hospital_outlined,
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .primaryText,
                                                size: 24.0,
                                              ),
                                              leadingIconPresent: true,
                                              trailingIconPresent: false,
                                              hint: 'Dr. Smith',
                                              value: '',
                                              onChange: '',
                                              onSubmit: '',
                                              variant: 'outlined',
                                              error: false,
                                            ),
                                          ),
                                          wrapWithModel(
                                            model: _model
                                                .textFieldPrimaryPhoneModel,
                                            updateCallback: () =>
                                                safeSetState(() {}),
                                            child: TextFieldWidget(
                                              label: 'Primary Physician Phone',
                                              labelPresent: true,
                                              helper: '',
                                              helperPresent: false,
                                              leadingIcon: Icon(
                                                Icons.phone_outlined,
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .primaryText,
                                                size: 24.0,
                                              ),
                                              leadingIconPresent: true,
                                              trailingIconPresent: false,
                                              hint: '555-555-0123',
                                              value: '',
                                              onChange: '',
                                              onSubmit: '',
                                              variant: 'outlined',
                                              error: false,
                                            ),
                                          ),
                                        ].divide(SizedBox(height: 16.0)),
                                      ),
                                    ),
                                  ),
                                ),
                              ].divide(SizedBox(height: 16.0)),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Emergency Contacts',
                                  style: FlutterFlowTheme.of(context)
                                      .titleMedium
                                      .override(
                                        font: GoogleFonts.dmSans(
                                          fontWeight: FontWeight.bold,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .titleMedium
                                                  .fontStyle,
                                        ),
                                        letterSpacing: 0.0,
                                        fontWeight: FontWeight.bold,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .titleMedium
                                            .fontStyle,
                                        lineHeight: 1.45,
                                      ),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryBackground,
                                    borderRadius: BorderRadius.circular(28.0),
                                    shape: BoxShape.rectangle,
                                    border: Border.all(
                                      color: FlutterFlowTheme.of(context)
                                          .alternate,
                                      width: 1.0,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.all(24.0),
                                    child: Container(
                                      decoration: BoxDecoration(),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          wrapWithModel(
                                            model:
                                                _model.textFieldEmergencyModel,
                                            updateCallback: () =>
                                                safeSetState(() {}),
                                            child: TextFieldWidget(
                                              label: 'Emergency Contact',
                                              labelPresent: true,
                                              helper: '',
                                              helperPresent: false,
                                              leadingIcon: Icon(
                                                Icons.local_hospital_outlined,
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .primaryText,
                                                size: 24.0,
                                              ),
                                              leadingIconPresent: true,
                                              trailingIconPresent: false,
                                              hint: 'Dr. Smith',
                                              value: '',
                                              onChange: '',
                                              onSubmit: '',
                                              variant: 'outlined',
                                              error: false,
                                            ),
                                          ),
                                          wrapWithModel(
                                            model: _model
                                                .textFieldEmergencyPhoneModel,
                                            updateCallback: () =>
                                                safeSetState(() {}),
                                            child: TextFieldWidget(
                                              label: 'Emergency Contact Phone',
                                              labelPresent: true,
                                              helper: '',
                                              helperPresent: false,
                                              leadingIcon: Icon(
                                                Icons.phone_outlined,
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .primaryText,
                                                size: 24.0,
                                              ),
                                              leadingIconPresent: true,
                                              trailingIconPresent: false,
                                              hint: '555-555-0123',
                                              value: '',
                                              onChange: '',
                                              onSubmit: '',
                                              variant: 'outlined',
                                              error: false,
                                            ),
                                          ),
                                        ].divide(SizedBox(height: 16.0)),
                                      ),
                                    ),
                                  ),
                                ),
                              ].divide(SizedBox(height: 16.0)),
                            ),
                            // Advance Directives (owner-approved 2026-11-14): an
                            // optional three-value status plus optional notes,
                            // on the new AdvanceDirectivesStatus /
                            // AdvanceDirectivesNotes fields. A record with no
                            // status reads as 'Unknown'.
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Advance Directives',
                                  style: FlutterFlowTheme.of(context)
                                      .titleMedium
                                      .override(
                                        font: GoogleFonts.dmSans(
                                          fontWeight: FontWeight.bold,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .titleMedium
                                                  .fontStyle,
                                        ),
                                        letterSpacing: 0.0,
                                        fontWeight: FontWeight.bold,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .titleMedium
                                            .fontStyle,
                                        lineHeight: 1.45,
                                      ),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryBackground,
                                    borderRadius: BorderRadius.circular(28.0),
                                    shape: BoxShape.rectangle,
                                    border: Border.all(
                                      color: FlutterFlowTheme.of(context)
                                          .alternate,
                                      width: 1.0,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.all(24.0),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Wrap(
                                          spacing: 8.0,
                                          runSpacing: 8.0,
                                          alignment: WrapAlignment.start,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.start,
                                          direction: Axis.horizontal,
                                          runAlignment: WrapAlignment.start,
                                          verticalDirection:
                                              VerticalDirection.down,
                                          clipBehavior: Clip.none,
                                          children: [
                                            wrapWithModel(
                                              model: _model
                                                  .conditionChipAdvanceDirectivesModel1,
                                              updateCallback: () =>
                                                  safeSetState(() {}),
                                              child: ConditionChipWidget(
                                                label:
                                                    kCareProfileAdvanceDirectivesLabels[
                                                        0],
                                                selected: _model
                                                        .advanceDirectivesStatus ==
                                                    kCareProfileAdvanceDirectivesValues[
                                                        0],
                                                onTap: () => safeSetState(() =>
                                                    _applyAdvanceDirectivesStatus(
                                                        kCareProfileAdvanceDirectivesValues[
                                                            0])),
                                              ),
                                            ),
                                            wrapWithModel(
                                              model: _model
                                                  .conditionChipAdvanceDirectivesModel2,
                                              updateCallback: () =>
                                                  safeSetState(() {}),
                                              child: ConditionChipWidget(
                                                label:
                                                    kCareProfileAdvanceDirectivesLabels[
                                                        1],
                                                selected: _model
                                                        .advanceDirectivesStatus ==
                                                    kCareProfileAdvanceDirectivesValues[
                                                        1],
                                                onTap: () => safeSetState(() =>
                                                    _applyAdvanceDirectivesStatus(
                                                        kCareProfileAdvanceDirectivesValues[
                                                            1])),
                                              ),
                                            ),
                                            wrapWithModel(
                                              model: _model
                                                  .conditionChipAdvanceDirectivesModel3,
                                              updateCallback: () =>
                                                  safeSetState(() {}),
                                              child: ConditionChipWidget(
                                                label:
                                                    kCareProfileAdvanceDirectivesLabels[
                                                        2],
                                                selected: _model
                                                        .advanceDirectivesStatus ==
                                                    kCareProfileAdvanceDirectivesValues[
                                                        2],
                                                onTap: () => safeSetState(() =>
                                                    _applyAdvanceDirectivesStatus(
                                                        kCareProfileAdvanceDirectivesValues[
                                                            2])),
                                              ),
                                            ),
                                          ],
                                        ),
                                        wrapWithModel(
                                          model: _model
                                              .textFieldAdvanceDirectivesNotesModel,
                                          updateCallback: () =>
                                              safeSetState(() {}),
                                          child: TextFieldWidget(
                                            label: 'Advance Directives Notes',
                                            labelPresent: true,
                                            helper:
                                                'Optional — e.g. DNR or POLST details',
                                            helperPresent: true,
                                            leadingIcon: Icon(
                                              Icons.description_outlined,
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .primaryText,
                                              size: 24.0,
                                            ),
                                            leadingIconPresent: true,
                                            trailingIconPresent: false,
                                            hint: 'Add a note',
                                            value: '',
                                            onChange: '',
                                            onSubmit: '',
                                            variant: 'outlined',
                                            error: false,
                                          ),
                                        ),
                                      ].divide(SizedBox(height: 16.0)),
                                    ),
                                  ),
                                ),
                              ].divide(SizedBox(height: 16.0)),
                            ),
                            InkWell(
                              splashColor: Colors.transparent,
                              focusColor: Colors.transparent,
                              hoverColor: Colors.transparent,
                              highlightColor: Colors.transparent,
                              // Save is blocked while an existing profile is
                              // loading (or failed to load) so an unloaded form
                              // can never write blanks over a real profile.
                              onTap: _saveBlocked ? null : _save,
                              child: wrapWithModel(
                                model: _model.buttonModel,
                                updateCallback: () => safeSetState(() {}),
                                child: ButtonWidget(
                                  iconPresent: false,
                                  iconEndPresent: false,
                                  content: 'Save Profile',
                                  variant: 'primary',
                                  size: 'small',
                                  fullWidth: false,
                                  loading: false,
                                  disabled: _saveBlocked,
                                ),
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: FlutterFlowTheme.of(context).info10,
                                borderRadius: BorderRadius.circular(20.0),
                                shape: BoxShape.rectangle,
                                border: Border.all(
                                  color: FlutterFlowTheme.of(context).info20,
                                  width: 1.0,
                                ),
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Container(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.max,
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.info_outline_rounded,
                                        color: FlutterFlowTheme.of(context)
                                            .onSurface,
                                        size: 20.0,
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: Text(
                                          'This profile is for organizational purposes only and does not constitute medical advice.',
                                          style: FlutterFlowTheme.of(context)
                                              .bodySmall
                                              .override(
                                                font: GoogleFonts.nunito(
                                                  fontWeight:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .bodySmall
                                                          .fontWeight,
                                                  fontStyle:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .bodySmall
                                                          .fontStyle,
                                                ),
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .onSurface,
                                                letterSpacing: 0.0,
                                                fontWeight:
                                                    FlutterFlowTheme.of(context)
                                                        .bodySmall
                                                        .fontWeight,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .bodySmall
                                                        .fontStyle,
                                                lineHeight: 1.5,
                                              ),
                                        ),
                                      ),
                                    ].divide(SizedBox(width: 16.0)),
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              height: 48.0,
                            ),
                          ].divide(SizedBox(height: 24.0)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
