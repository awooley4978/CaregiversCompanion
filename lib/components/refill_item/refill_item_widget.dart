import '/backend/pharmacy/pharmacy_service.dart';
import '/components/button/button_widget.dart';
import '/components/pharmacy_picker/pharmacy_picker.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'refill_item_model.dart';
export 'refill_item_model.dart';

class RefillItemWidget extends StatefulWidget {
  const RefillItemWidget({
    super.key,
    String? count,
    String? date,
    String? name,
  })  : this.count = count ?? '4 days',
        this.date = date ?? 'Oct 28',
        this.name = name ?? 'Lisinopril';

  final String count;
  final String date;
  final String name;

  @override
  State<RefillItemWidget> createState() => _RefillItemWidgetState();
}

class _RefillItemWidgetState extends State<RefillItemWidget> {
  late RefillItemModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => RefillItemModel());

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  /// Medication "Order"/"Reorder" handoff.
  ///
  ///  * No pharmacy set -> prompt the user to choose one (never do nothing).
  ///  * Pharmacy set -> hand OFF to that pharmacy's own refill/prescription
  ///    webpage in a new tab. The app does NOT place, and does not represent
  ///    itself as placing, a prescription order. No user/sensitive data is
  ///    sent to the page.
  Future<void> _handleOrder() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || !mounted) return;

    final service = PharmacyService();
    var pref = await service.getPreferredPharmacy(uid);

    if (pref.id == null || pref.id!.isEmpty) {
      // Owner req 4: prompt to choose rather than doing nothing.
      final choice = await showPreferredPharmacyPicker(context);
      if (choice == null || !mounted) {
        return; // User dismissed — no pharmacy chosen, no handoff.
      }
      await service.setPreferredPharmacy(
        uid,
        id: choice.id,
        label: choice.label,
      );
      pref = (id: choice.id, label: choice.label);
    }

    final url = pharmacyRefillUrl(pref.id, pref.label);
    if (!mounted) return;
    if (await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    )) {
      showSnackbar(
        context,
        'Opening ${pharmacyDisplayName(pref.id, pref.label)} to refill this '
        'prescription. ${pharmacyDisplayName(pref.id, pref.label)} handles '
        'your order — we never place it for you.',
      );
    } else {
      showSnackbar(context, 'Could not open the pharmacy page. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 8.0),
      child: Container(
        child: Container(
          decoration: BoxDecoration(
            color: Color(0xFFFFF9F2),
            borderRadius: BorderRadius.circular(28.0),
            shape: BoxShape.rectangle,
            border: Border.all(
              color: FlutterFlowTheme.of(context).warning,
              width: 1.0,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Container(
              child: Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inventory_2_rounded,
                    color: FlutterFlowTheme.of(context).tertiary,
                    size: 20.0,
                  ),
                  Expanded(
                    flex: 1,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          valueOrDefault<String>(
                            widget!.name,
                            'Lisinopril',
                          ),
                          style: FlutterFlowTheme.of(context)
                              .bodyMedium
                              .override(
                                font: GoogleFonts.nunito(
                                  fontWeight: FontWeight.w600,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .fontStyle,
                                ),
                                color: FlutterFlowTheme.of(context).primaryText,
                                letterSpacing: 0.0,
                                fontWeight: FontWeight.w600,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .fontStyle,
                                lineHeight: 1.6,
                              ),
                        ),
                        Text(
                          valueOrDefault<String>(
                            '${widget!.count} left • Refill by ${widget!.date}',
                            '4 days left • Refill by Oct 28',
                          ),
                          style: FlutterFlowTheme.of(context)
                              .bodySmall
                              .override(
                                font: GoogleFonts.nunito(
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .bodySmall
                                      .fontWeight,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .bodySmall
                                      .fontStyle,
                                ),
                                color:
                                    FlutterFlowTheme.of(context).secondaryText,
                                letterSpacing: 0.0,
                                fontWeight: FlutterFlowTheme.of(context)
                                    .bodySmall
                                    .fontWeight,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .bodySmall
                                    .fontStyle,
                                lineHeight: 1.5,
                              ),
                        ),
                      ],
                    ),
                  ),
                  wrapWithModel(
                    model: _model.buttonModel,
                    updateCallback: () => safeSetState(() {}),
                    child: ButtonWidget(
                      iconPresent: false,
                      iconEndPresent: false,
                      content: 'Order',
                      variant: 'secondary',
                      size: 'small',
                      fullWidth: false,
                      loading: false,
                      disabled: false,
                      onPressed: _handleOrder,
                    ),
                  ),
                ].divide(SizedBox(width: 16.0)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
