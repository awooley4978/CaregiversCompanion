import '/components/button/button_widget.dart';
import '/components/emergency_contact_card/emergency_contact_card_widget.dart';
import '/components/medical_badge/medical_badge_widget.dart';
import '/components/nav_menu_directory/nav_menu_directory_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'i_emergency_information_widget.dart' show IEmergencyInformationWidget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class IEmergencyInformationModel
    extends FlutterFlowModel<IEmergencyInformationWidget> {
  ///  State fields for stateful widgets in this page.

  // Model for MedicalBadge.
  late MedicalBadgeModel medicalBadgeModel1;
  // Model for MedicalBadge.
  late MedicalBadgeModel medicalBadgeModel2;
  // Model for MedicalBadge.
  late MedicalBadgeModel medicalBadgeModel3;
  // Model for MedicalBadge.
  late MedicalBadgeModel medicalBadgeModel4;
  // Model for EmergencyContactCard.
  late EmergencyContactCardModel emergencyContactCardModel1;
  // Model for EmergencyContactCard.
  late EmergencyContactCardModel emergencyContactCardModel2;
  // Model for EmergencyContactCard.
  late EmergencyContactCardModel emergencyContactCardModel3;
  // Model for Button.
  late ButtonModel buttonModel1;
  // Model for Button.
  late ButtonModel buttonModel2;

  @override
  void initState(BuildContext context) {
    medicalBadgeModel1 = createModel(context, () => MedicalBadgeModel());
    medicalBadgeModel2 = createModel(context, () => MedicalBadgeModel());
    medicalBadgeModel3 = createModel(context, () => MedicalBadgeModel());
    medicalBadgeModel4 = createModel(context, () => MedicalBadgeModel());
    emergencyContactCardModel1 =
        createModel(context, () => EmergencyContactCardModel());
    emergencyContactCardModel2 =
        createModel(context, () => EmergencyContactCardModel());
    emergencyContactCardModel3 =
        createModel(context, () => EmergencyContactCardModel());
    buttonModel1 = createModel(context, () => ButtonModel());
    buttonModel2 = createModel(context, () => ButtonModel());
  }

  @override
  void dispose() {
    medicalBadgeModel1.dispose();
    medicalBadgeModel2.dispose();
    medicalBadgeModel3.dispose();
    medicalBadgeModel4.dispose();
    emergencyContactCardModel1.dispose();
    emergencyContactCardModel2.dispose();
    emergencyContactCardModel3.dispose();
    buttonModel1.dispose();
    buttonModel2.dispose();
  }
}
