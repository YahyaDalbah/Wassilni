import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:wassilni/pages/auth/login_page.dart';
import 'package:wassilni/pages/driver_history.dart';
import 'package:wassilni/pages/map.dart';
import 'package:wassilni/pages/driver_profile_page.dart';
import 'package:wassilni/pages/rider_history.dart';
import 'package:wassilni/providers/destination_provider.dart';
import 'package:wassilni/providers/fare_provider.dart';
import 'package:wassilni/providers/ride_provider.dart';
import 'package:wassilni/providers/user_provider.dart';
import 'package:wassilni/logic/driver_logic.dart';
import 'package:wassilni/widgets/driver_widgets/collapsed_panel.dart';
import 'package:wassilni/widgets/driver_widgets/dropping_off_sliding_panel.dart';
import 'package:wassilni/widgets/driver_widgets/footer_widget.dart';
import 'package:wassilni/widgets/driver_widgets/found_ride_sliding_panel.dart';
import 'package:wassilni/widgets/driver_widgets/go_stop_button.dart';
import 'package:wassilni/widgets/driver_widgets/picking_up_footer.dart';
import 'package:wassilni/widgets/driver_widgets/menu_drawer.dart';
import 'package:wassilni/widgets/driver_widgets/waiting_sliding_panel.dart';
import 'package:wassilni/utils/snackbar_utils.dart';

class DriverMap extends StatefulWidget {
  const DriverMap({super.key});

  @override
  State<DriverMap> createState() => _DriverMapState();
}

class _DriverMapState extends State<DriverMap> {
  late final DriverLogic _logic;
  late final PanelController _foundRideController;
  late final PanelController _waitingController;
  late final ConnectivityService _connectivityService;
  bool _isConnected = true;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isDrawerOpen = false;
  final double _drawerHeightPercentage = 0.1;
  final SnackbarUtils _snackbarUtils = SnackbarUtils();

  void _initializePanelControllers(DriverLogic logic) {
    // Initialize controllers
    _foundRideController = PanelController();
    _waitingController = PanelController();

    // Set up state change handler
    logic.setStateCallback = () {
      if (mounted) setState(() {});

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (logic.driverState == DriverState.foundRide &&
            _foundRideController.isAttached) {
          _foundRideController.open();
        } else if (logic.driverState == DriverState.waiting &&
            _waitingController.isAttached) {
          _waitingController.open();
        }
      });
    };
  }

  @override
  void initState() {
    super.initState();
    Provider.of<UserProvider>(context, listen: false).updateOnlineStatus(false);
    _logic = DriverLogic(
      context,
      null, // We'll set callback later
      () => mounted,
    );

    _initializePanelControllers(_logic);

    // Initialize connectivity service
    _connectivityService = ConnectivityService(snackbarUtils: _snackbarUtils);
    _connectivityService.monitorConnection(context, (isConnected) {
      if (mounted) setState(() => _isConnected = isConnected);
    });
  }

  void _handleButtonAction(VoidCallback action) {
    _connectivityService.handleNetworkAction(context, _isConnected, action);
  }

  @override
  void dispose() {
    _connectivityService.dispose(); // ADD THIS
    _snackbarUtils.dispose(); // Add this
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

  void _openDrawer() {
    setState(() => _isDrawerOpen = true);
  }

  void _closeDrawer() {
    setState(() => _isDrawerOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return SafeArea(
      child: Scaffold(
        key: _scaffoldKey,
        body: Stack(
          children: [
            // Map (always visible)
            Positioned.fill(
              child: Consumer<DestinationProvider>(
                builder:
                    (context, provider, _) =>
                        Map(key: ValueKey(provider.drawRoute.hashCode)),
              ),
            ),

            // Semi-transparent overlay when drawer is open
            if (_isDrawerOpen)
              GestureDetector(
                onTap: _closeDrawer,
                child: Container(
                  color: Colors.black.withOpacity(0.5),
                  width: screenWidth,
                  height: double.infinity,
                ),
              ),

            // Top sliding drawer (AnimatedPositioned)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              top:
                  _isDrawerOpen
                      ? 0
                      : -MediaQuery.of(context).size.height *
                          _drawerHeightPercentage,
              left: 0,
              right: 0,
              height:
                  MediaQuery.of(context).size.height * _drawerHeightPercentage,
              child: MenuDrawerContent(
                onProfile: () {
                  _closeDrawer();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DriverProfilePage(),
                    ),
                  );
                },
                onRides: () {
                  _closeDrawer();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const DriverHistory()),
                  );
                },
                onLogout: () async {
                  _closeDrawer();
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
                onClose: _closeDrawer,
              ),
            ),

            // Hamburger menu button (always menu icon, no close icon)
            Positioned(
              top: 40,
              left: 20,
              child: Visibility(
                visible: !_isDrawerOpen, // Only visible when drawer closed
                child: IgnorePointer(
                  ignoring: _isDrawerOpen, // Block interaction when drawer open
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.menu, color: Colors.white),
                      onPressed: _openDrawer, // Only opens drawer
                    ),
                  ),
                ),
              ),
            ),

            // Online/Offline Toggle Button
            if (_logic.driverState.index <= DriverState.foundRide.index)
              goStopButton(
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
                      panel: foundRideSlidingPanel(
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
                  return pickingUpFooter(
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
                panel: waitingSlidingPanel(
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
                panel: droppingOffSlidingPanel(
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
