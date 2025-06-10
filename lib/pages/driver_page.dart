import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:wassilni/pages/auth/login_page.dart';
import 'package:wassilni/pages/driver_history.dart';
import 'package:wassilni/pages/map.dart';
import 'package:wassilni/pages/driver_profile_page.dart';
import 'package:wassilni/providers/destination_provider.dart';
import 'package:wassilni/providers/fare_provider.dart';
import 'package:wassilni/providers/ride_provider.dart';
import 'package:wassilni/providers/user_provider.dart';
import 'package:wassilni/logic/driver_transition_logic.dart';
import 'package:wassilni/utils/format_utils.dart';
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

class _DriverMapState extends State<DriverMap> with WidgetsBindingObserver {
  late final DriverTransitioningLogic _transitionlogic;
  late final PanelController _foundRideSlidingPanelController;
  late final PanelController _waitingSlidingPanelController;
  late final ConnectivityService _connectivityService;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final double _drawerHeightPercentage = 0.1;
  final SnackbarUtils _snackbarUtils = SnackbarUtils();
  bool _isConnected = true;
  bool _isDrawerOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(
      this,
    ); //lifecycle observer, this is to close the app when it goes to background as we dont want the driver to be online when the app is not in use

    _transitionlogic = DriverTransitioningLogic(context, null, () => mounted);
    _initializePanelControllers(_transitionlogic);
    _connectivityService = ConnectivityService(snackbarUtils: _snackbarUtils);
    _connectivityService.monitorConnection(context, (isConnected) {
      if (mounted) setState(() => _isConnected = isConnected);
    });
    // Schedule provider update after frame is built, this is also to ensure that the driver is not online when the app is initialized, although it would be mostly redundant but better safe than sorry
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<UserProvider>(
          context,
          listen: false,
        ).updateOnlineStatus(false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return SafeArea(
      child: Scaffold(
        key: _scaffoldKey,
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

            // Semi-transparent overlay when drawer is open, close when tapped
            if (_isDrawerOpen)
              GestureDetector(
                onTap: _closeDrawer,
                child: Container(
                  color: Colors.black.withOpacity(0.5),
                  width: screenWidth,
                  height: double.infinity,
                ),
              ),

            //animation for the menu drawer
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
                  _transitionlogic.handleLogout();
                  _closeDrawer;
                },
                onClose: _closeDrawer,
              ),
            ),

            // Hamburger menu button
            // the ham menu button turns into a close icon when the drawer is open
            // this is not wanted, so we use Visibility to control its visibility and make it invisible when the drawer is open
            // and IgnorePointer to block interaction when the drawer is open
            // we can close it by clicking on the overlay or but pulling it up the screen
            // which is smoother and cleaner than using a close icon that might bloc other elements
            Positioned(
              top: 40,
              left: 20,
              child: Visibility(
                visible: !_isDrawerOpen, // Only visible when drawer closed
                child: IgnorePointer(
                  ignoring:
                      _isDrawerOpen, // Block interaction with "X" icon when drawer open
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.menu, color: Colors.white),
                      onPressed:
                          _openDrawer, // Only opens drawer, the previous logic was to make this button close the drawer as well, but it was not a good Ui
                    ),
                  ),
                ),
              ),
            ),

            // Online/Offline Toggle Button
            if (_transitionlogic.driverState == DriverState.offline ||
                _transitionlogic.driverState == DriverState.lookingForRide ||
                _transitionlogic.driverState == DriverState.foundRide)
              goStopButton(
                onPressed:
                    () => _handleButtonAction(
                      _transitionlogic.toggleOnlineStatus,
                    ),
                isOnline: _transitionlogic.driverState != DriverState.offline,
              ),

            // Found Ride Panel
            if (_transitionlogic.driverState == DriverState.foundRide)
              Consumer<DestinationProvider>(
                builder:
                    (context, _, __) => SlidingUpPanel(
                      controller: _foundRideSlidingPanelController,
                      minHeight: 50,
                      maxHeight: 380,
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
                              _transitionlogic.transitionToPickingUp,
                            ),
                        onCancelRide:
                            () => _handleButtonAction(
                              _transitionlogic.handleRideCancel,
                            ),
                      ),
                      collapsed: collapsedPanel("You're Online"),
                    ),
              ),

            // Picking Up Footer
            if (_transitionlogic.driverState == DriverState.pickingUp)
              Consumer<DestinationProvider>(
                builder: (context, provider, _) {
                  final distance = provider.currentToPickupDistance ?? 0;
                  final distanceText = distance.formatDistance();
                  return pickingUpFooter(
                    userName: "Rider",
                    distanceText: distanceText,
                    onTap:
                        () => _handleButtonAction(
                          _transitionlogic.transitionToWaiting,
                        ),
                  );
                },
              ),

            // Waiting Panel
            if (_transitionlogic.driverState == DriverState.waiting)
              SlidingUpPanel(
                controller: _waitingSlidingPanelController,
                minHeight: 100,
                maxHeight: 180,
                defaultPanelState: PanelState.CLOSED,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                color: Colors.black,
                panel: waitingSlidingPanel(
                  userName: "Rider",
                  waitTime: _transitionlogic.formatWaitTime(),
                  onStartRide:
                      () => _handleButtonAction(
                        _transitionlogic.transitionToDroppingOff,
                      ),
                  onCancelRide:
                      _transitionlogic.isCancelEnabled
                          ? () => _handleButtonAction(
                            _transitionlogic.handleRideCancel,
                          )
                          : null,
                  isCancelEnabled: _transitionlogic.isCancelEnabled,
                ),
                collapsed: collapsedPanel(
                  "Waiting For Rider - ${_transitionlogic.formatWaitTime()}",
                ),
              ),

            // Dropping Off Panel
            if (_transitionlogic.driverState == DriverState.droppingOff)
              SlidingUpPanel(
                minHeight: 100,
                maxHeight: 250,
                defaultPanelState: PanelState.CLOSED,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                color: Colors.black,
                panel: droppingOffSlidingPanel(
                  onCompleteRide:
                      () => _handleButtonAction(() {
                        Provider.of<RideProvider>(
                          context,
                          listen: false,
                        ).updateRideStatus(
                          "completed",
                          _transitionlogic.currentRide!,
                        );
                        _transitionlogic.transitionToOffline();
                      }),
                  distanceText: droppingOffDistanceText(),
                  timeText: droppingOffTimeText(),
                ),
                collapsed: collapsedPanel("Dropping Off Rider"),
              ),

            // Bottom Status Footer
            if (_transitionlogic.driverState == DriverState.offline ||
                _transitionlogic.driverState == DriverState.lookingForRide)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: FooterWidget(
                  text:
                      _transitionlogic.driverState == DriverState.lookingForRide
                          ? "You're Online"
                          : "You're Offline",
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _handleButtonAction(VoidCallback action) {
    _connectivityService.handleNetworkAction(context, _isConnected, action);
    // this is to ensure that the action, any action is only performed if the user is connected to the internet, to ensure consitancy between the app and the database
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // Remove observer
    _connectivityService.dispose();
    _snackbarUtils.dispose();
    _transitionlogic.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // App going to background - update status immediately and prevent any memory leaks or unwanted behavior like assigned rides to drivers who arent availbe
      _transitionlogic.transitionToOffline();
    }
  }

  String _panelTitle() {
    return "${_transitionlogic.currentRide?.fare.toStringAsFixed(2) ?? '0.00'}\$";
  }

  String _panelSubtitle1(BuildContext context) {
    final destinationProvider = Provider.of<DestinationProvider>(
      context,
      listen: false,
    );
    final fareProvider = Provider.of<FareProvider>(context);
    final double distance = destinationProvider.currentToPickupDistance ?? 0;
    final duration = (fareProvider.currentToPickupDuration ?? 0);
    return "${(duration.formatDuration())} (${distance.formatDistance()}) away";
  }

  String _panelSubtitle2() {
    final ride = _transitionlogic.currentRide;
    if (ride == null) return '-- min (-- KM) away';
    return "${(ride.duration.formatDuration())} (${(ride.distance.formatDistance())}) away";
  }

  String get _panelLocation1 =>
      _transitionlogic.currentRide?.pickup["address"] ?? 'Loading...';
  String get _panelLocation2 =>
      _transitionlogic.currentRide?.destination["address"] ?? 'Loading...';

  void _openDrawer() {
    setState(() => _isDrawerOpen = true);
  }

  void _closeDrawer() {
    setState(() => _isDrawerOpen = false);
  }

  String droppingOffDistanceText() {
    final ride = _transitionlogic.currentRide;
    return "${(ride?.distance.formatDistance())}";
  }

  String droppingOffTimeText() {
    final ride = _transitionlogic.currentRide;
    return "${(ride?.duration.formatDuration())}";
  }

  void _initializePanelControllers(DriverTransitioningLogic logic) {
    // Initialize controllers
    // this is to make the sliding animation of the "waiting panel" and "found ride panel" smoothe
    _foundRideSlidingPanelController = PanelController();
    _waitingSlidingPanelController = PanelController();

    logic.setStateCallback = () {
      if (mounted) setState(() {});

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (logic.driverState == DriverState.foundRide &&
            _foundRideSlidingPanelController.isAttached) {
          _foundRideSlidingPanelController.open();
        } else if (logic.driverState == DriverState.waiting &&
            _waitingSlidingPanelController.isAttached) {
          _waitingSlidingPanelController.open();
        }
      });
    };
  }
}
