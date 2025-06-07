import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:wassilni/pages/auth/login_page.dart';
import 'package:wassilni/pages/map.dart';
import 'package:wassilni/providers/destination_provider.dart';
import 'package:wassilni/providers/fare_provider.dart';
import 'package:wassilni/providers/ride_provider.dart';
import 'package:wassilni/providers/user_provider.dart';
import 'package:wassilni/logic/driver_logic.dart';
import 'package:wassilni/widgets/driver_widgets/closed_panel.dart';
import 'package:wassilni/widgets/driver_widgets/dropping_off_panel.dart';
import 'package:wassilni/widgets/driver_widgets/footer_widget.dart';
import 'package:wassilni/widgets/driver_widgets/found_ride_panel.dart';
import 'package:wassilni/widgets/driver_widgets/online_offline_button.dart';
import 'package:wassilni/widgets/driver_widgets/picking_up_footer.dart';
import 'package:wassilni/widgets/driver_widgets/waitingPanel.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class DriverMap extends StatefulWidget {
  const DriverMap({super.key});

  @override
  State<DriverMap> createState() => _DriverMapState();
}

class _DriverMapState extends State<DriverMap> {
  late final DriverLogic _logic;
  late final PanelController _foundRideController;
  late final PanelController _waitingController;
  late StreamSubscription<ConnectivityResult> _connectivitySubscription;
  bool _isConnected = true;
  Timer? _snackbarTimer;

  @override
  void initState() {
    super.initState();
    _foundRideController = PanelController();
    _waitingController = PanelController();
    _logic = DriverLogic(context, () {
      if (mounted) setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_logic.driverState == DriverState.foundRide &&
            _foundRideController.isAttached) {
          _foundRideController.open();
        } else if (_logic.driverState == DriverState.waiting &&
            _waitingController.isAttached) {
          _waitingController.open();
        }
      });
    }, () => mounted);
    _logic.transitionToOffline();
    _startConnectivityMonitoring();
  }

  void _startConnectivityMonitoring() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      result,
    ) {
      final isConnected = result != ConnectivityResult.none;
      if (isConnected) {
        _showConnectionRestoredSnackbar();
      } else {
        _showConnectionLostSnackbar();
      }
      if (mounted) {
        setState(() {
          _isConnected = isConnected;
        });
      }
    });
  }

  void _showTopSnackbar(String message, Color color, int seconds) {
    _snackbarTimer?.cancel();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: Duration(seconds: seconds),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(top: 40, left: 10, right: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    _snackbarTimer = Timer(Duration(seconds: seconds), () {
      if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();
    });
  }

  void _showConnectionLostSnackbar() {
    _showTopSnackbar('No internet connection', Colors.red, 5);
  }

  void _showConnectionRestoredSnackbar() {
    _showTopSnackbar('Internet connection restored', Colors.green, 3);
  }

  void _handleButtonAction(VoidCallback action) {
    if (!_isConnected) {
      _showConnectionLostSnackbar();
      return;
    }
    action();
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    _snackbarTimer?.cancel();
    _logic.dispose();
    super.dispose();
  }

  String _panelTitle() {
    return "${_logic.currentRide?.fare.toStringAsFixed(2) ?? '0.00'}\$";
  }

  String _panelSubtitle1(BuildContext context) {
    final destinationProvider = Provider.of<DestinationProvider>(
      context,
      listen: false,
    );
    final fareProvider = Provider.of<FareProvider>(context);
    final distance =
        destinationProvider.currentToPickupDistance?.toStringAsFixed(1) ?? '--';
    final duration = (fareProvider.currentToPickupDuration ?? 0).toInt();
    return "${(duration / 60).toStringAsFixed(1)} min ($distance KM) away";
  }

  String _panelSubtitle2() {
    final ride = _logic.currentRide;
    if (ride == null) return '-- min (-- KM) away';
    return "${(ride.duration / 60).toStringAsFixed(1)} min (${(ride.distance / 1000).toStringAsFixed(1)} KM) away";
  }

  String get _panelLocation1 =>
      _logic.currentRide?.pickup["address"] ?? 'Loading...';
  String get _panelLocation2 =>
      _logic.currentRide?.destination["address"] ?? 'Loading...';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: Stack(
          children: [
            // Map
            Positioned.fill(
              child: Consumer<DestinationProvider>(
                builder:
                    (context, provider, _) =>
                        Map(key: ValueKey(provider.drawRoute.hashCode)),
              ),
            ),

            // Logout Button (only when offline)
            if (_logic.driverState == DriverState.offline)
              Positioned(
                top: 40,
                left: 20,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: IconButton(
                    iconSize: 30,
                    icon: const Icon(Icons.logout, color: Colors.white),
                    onPressed: () async {
                      await Provider.of<UserProvider>(
                        context,
                        listen: false,
                      ).logout();
                      if (mounted) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginPage()),
                        );
                      }
                    },
                  ),
                ),
              ),

            // Online/Offline Toggle Button
            if (_logic.driverState.index <= DriverState.foundRide.index)
              onlineOfflineButton(
                onPressed: () => _handleButtonAction(_logic.toggleOnlineStatus),
                isOnline: _logic.driverState != DriverState.offline,
              ),

            // Found Ride Panel
            if (_logic.driverState == DriverState.foundRide)
              Consumer<DestinationProvider>(
                builder:
                    (context, _, __) => SlidingUpPanel(
                      controller: _foundRideController,
                      minHeight: 50,
                      maxHeight: 450,
                      defaultPanelState: PanelState.CLOSED,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                      color: Colors.black,
                      panel: foundRidePanel(
                        panelTitle: _panelTitle(),
                        panelSubtitle1: _panelSubtitle1(context),
                        panelSubtitle2: _panelSubtitle2(),
                        panelLocation1: _panelLocation1,
                        panelLocation2: _panelLocation2,
                        onAcceptRide:
                            () => _handleButtonAction(
                              _logic.transitionToPickingUp,
                            ),
                        onCancelRide:
                            () => _handleButtonAction(_logic.handleRideCancel),
                      ),
                      collapsed: collapsedPanel("You're Online"),
                    ),
              ),

            // Picking Up Footer
            if (_logic.driverState == DriverState.pickingUp)
              Consumer<DestinationProvider>(
                builder: (context, provider, _) {
                  final distance = provider.currentToPickupDistance ?? 0;
                  final distanceText =
                      distance <= 0.1
                          ? '${(distance * 1000).round()} m'
                          : '${distance.toStringAsFixed(1)} km';
                  return buildPickingUpFooter(
                    userName: "Rider",
                    distanceText: distanceText,
                    onTap:
                        () => _handleButtonAction(_logic.transitionToWaiting),
                  );
                },
              ),

            // Waiting Panel
            if (_logic.driverState == DriverState.waiting)
              SlidingUpPanel(
                controller: _waitingController,
                minHeight: 100,
                maxHeight: 180,
                defaultPanelState: PanelState.CLOSED,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                color: Colors.black,
                panel: waitingPanel(
                  userName: "Rider",
                  waitTime: _logic.formatWaitTime(),
                  onStartRide:
                      () => _handleButtonAction(_logic.transitionToDroppingOff),
                  onCancelRide:
                      _logic.isCancelEnabled
                          ? () => _handleButtonAction(_logic.handleRideCancel)
                          : null,
                  isCancelEnabled: _logic.isCancelEnabled,
                ),
                collapsed: collapsedPanel(
                  "Waiting For Rider - ${_logic.formatWaitTime()}",
                ),
              ),

            // Dropping Off Panel
            if (_logic.driverState == DriverState.droppingOff)
              SlidingUpPanel(
                minHeight: 100,
                maxHeight: 280,
                defaultPanelState: PanelState.CLOSED,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                color: Colors.black,
                panel: droppingOffPanel(
                  currentRide: _logic.currentRide!,
                  context: context,
                  onCompleteRide:
                      () => _handleButtonAction(() {
                        Provider.of<RideProvider>(
                          context,
                          listen: false,
                        ).updateRideStatus("completed", _logic.currentRide!);
                        _logic.transitionToOffline();
                      }),
                ),
                collapsed: collapsedPanel("Dropping Off Rider"),
              ),

            // Bottom Status Footer
            if (_logic.driverState.index <= DriverState.lookingForRide.index)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: FooterWidget(
                  text:
                      _logic.driverState == DriverState.lookingForRide
                          ? "You're Online"
                          : "You're Offline",
                ),
              ),
          ],
        ),
      ),
    );
  }
}
