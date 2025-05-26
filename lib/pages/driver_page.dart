import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:wassilni/pages/auth/login_page.dart';
import 'package:wassilni/pages/map.dart';
import 'package:wassilni/providers/destination_provider.dart';
import 'package:wassilni/providers/fare_provider.dart';
import 'package:wassilni/providers/ride_provider.dart';
import 'package:wassilni/providers/user_provider.dart';
import 'package:wassilni/widgets/driver_widget.dart';
import 'package:wassilni/logic/driver_logic.dart';

class DriverMap extends StatefulWidget {
  const DriverMap({super.key});

  @override
  State<DriverMap> createState() => _DriverMapState();
}

class _DriverMapState extends State<DriverMap> {
  late final DriverLogic _logic;
  late final PanelController _foundRideController;
  late final PanelController _waitingController;
  @override
  void initState() {
    super.initState();
    _foundRideController = PanelController(); // Initialize all panel controllers
    _waitingController = PanelController();
    _logic = DriverLogic(
      context,
      () {
        if (mounted) setState(() {});
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_logic.driverState == DriverState.foundRide && 
              _foundRideController.isAttached) {
            _foundRideController.open();
          }
          else if (_logic.driverState == DriverState.waiting &&
              _waitingController.isAttached) {
            _waitingController.open();
          }
        });
      },
      () => mounted,
    );
    Provider.of<UserProvider>(context, listen: false).updateOnlineStatus(false);
  }

  @override
  void dispose() {
    _logic.dispose();
    super.dispose();
  }

  String _panelTitle() {
    return "${_logic.currentRide?.fare.toStringAsFixed(2) ?? '0.00'}\$";
  }

  String _panelSubtitle1(BuildContext context) {
    final destinationProvider = Provider.of<DestinationProvider>(context, listen: false);
    final fareProvider = Provider.of<FareProvider>(context);
    final distance = destinationProvider.currentToPickupDistance?.toStringAsFixed(1) ?? '--';
    final duration = (fareProvider.currentToPickupDuration ?? 0).toInt();
    return "${(duration / 60).toStringAsFixed(1)} min ($distance KM) away";
  }

  String _panelSubtitle2() {
    final ride = _logic.currentRide;
    if (ride == null) return '-- min (-- KM) away';
    return "${(ride.duration / 60).toStringAsFixed(1)} min (${(ride.distance / 1000).toStringAsFixed(1)} KM) away";
  }

  String get _panelLocation1 => _logic.currentRide?.pickup["address"] ?? 'Loading...';
  String get _panelLocation2 => _logic.currentRide?.destination["address"] ?? 'Loading...';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: Stack(
          children: [
            // Map Background
            Positioned.fill(
              child: Consumer<DestinationProvider>(
                builder: (context, provider, _) => Map(
                  key: ValueKey(provider.drawRoute.hashCode),
                ),
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
                      await Provider.of<UserProvider>(context, listen: false).logout();
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
              buildOnlineOfflineButton(
                onPressed: _logic.toggleOnlineStatus,
                isOnline: _logic.driverState != DriverState.offline,
              ),

            // Found Ride Panel
            if (_logic.driverState == DriverState.foundRide)
              Consumer<DestinationProvider>(
                builder: (context, _, __) => SlidingUpPanel(
                  controller: _foundRideController,
                  minHeight: 50,
                  maxHeight: 450,
                  defaultPanelState: PanelState.CLOSED,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  color: Colors.black,
                  panel: buildPanelContent(
                    panelTitle: _panelTitle(),
                    panelSubtitle1: _panelSubtitle1(context),
                    panelSubtitle2: _panelSubtitle2(),
                    panelLocation1: _panelLocation1,
                    panelLocation2: _panelLocation2,
                    onAcceptRide: _logic.acceptRide,
                    onCancelRide: _logic.handleRideCancel,
                  ),
                  collapsed: buildCollapsedPanel("You're Online"),
                ),
              ),

            // Picking Up Footer
            if (_logic.driverState == DriverState.pickingUp)
              Consumer<DestinationProvider>(
                builder: (context, provider, _) {
                  final distance = provider.currentToPickupDistance ?? 0;
                  final distanceText = distance <= 0.1 
                      ? '${(distance * 1000).round()} m'
                      : '${distance.toStringAsFixed(1)} km';
                  return buildPickingUpFooter(
                    userName: "Rider",
                    distanceText: distanceText,
                    onTap: _logic.transitionToWaiting,
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
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                color: Colors.black,
                panel: buildWaitingPanel(
                  userName: "Rider",
                  waitTime: _logic.formatWaitTime(),
                  onStartRide: _logic.startRide,
                  onCancelRide: _logic.isCancelEnabled ? _logic.handleRideCancel : null,
                  isCancelEnabled: _logic.isCancelEnabled,
                ),
                collapsed: buildCollapsedPanel("Waiting For Rider - ${_logic.formatWaitTime()}"),
              ),

            // Dropping Off Panel
            if (_logic.driverState == DriverState.droppingOff)
              SlidingUpPanel(
                minHeight: 100,
                maxHeight: 280,
                defaultPanelState: PanelState.CLOSED,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                color: Colors.black,
                panel: buildDroppingOffPanels(
                  currentRide: _logic.currentRide!,
                  context: context,
                  onCompleteRide: () {
                    Provider.of<RideProvider>(context, listen: false)
                      .updateRideStatus("completed", _logic.currentRide!);
                    _logic.resetToDefault();
                  },
                ),
                collapsed: buildCollapsedPanel("Dropping Off Rider"),
              ),

            // Bottom Status Footer
            if (_logic.driverState.index <= DriverState.lookingForRide.index)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: FooterWidget(
                  text: _logic.driverState == DriverState.lookingForRide
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

