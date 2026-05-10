import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/main_scaffold.dart';

class PinScreen extends StatefulWidget {
  const PinScreen({super.key});

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen>
    with SingleTickerProviderStateMixin {
  final _storage = const FlutterSecureStorage();
  final List<String> _enteredPin = [];
  String _storedPin = '';
  bool _isFirstTime = true;
  bool _isConfirming = false;
  String _firstPin = '';
  String _statusMessage = 'Enter PIN';
  bool _isError = false;

  late AnimationController _shakeController;
  late Animation<Offset> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _shakeAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0.08, 0),
    ).chain(CurveTween(curve: Curves.elasticIn)).animate(_shakeController);
    _loadPin();
  }

  Future<void> _loadPin() async {
    String? pin = await _storage.read(key: 'user_pin');
    if (pin != null && pin.length == 4) {
      setState(() {
        _storedPin = pin;
        _isFirstTime = false;
      });
    }
  }

  void _onNumberTap(String number) {
    if (_enteredPin.length < 4) {
      setState(() {
        _enteredPin.add(number);
        _isError = false;
      });
      if (_enteredPin.length == 4) _verifyPin();
    }
  }

  void _onDeleteTap() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin.removeLast();
        _isError = false;
      });
    }
  }

  Future<void> _verifyPin() async {
    final entered = _enteredPin.join();
    if (_isFirstTime) {
      if (!_isConfirming) {
        await Future.delayed(const Duration(milliseconds: 300));
        setState(() {
          _firstPin = entered;
          _isConfirming = true;
          _enteredPin.clear();
          _statusMessage = 'Confirm PIN';
        });
      } else {
        if (entered == _firstPin) {
          await _storage.write(key: 'user_pin', value: entered);
          _navigateToApp();
        } else {
          _showError("PINs don't match. Try again.");
          setState(() {
            _isConfirming = false;
            _firstPin = '';
            _statusMessage = 'Enter PIN';
          });
        }
      }
    } else {
      if (entered == _storedPin) {
        _navigateToApp();
      } else {
        _showError('Incorrect PIN');
      }
    }
  }

  void _showError(String message) {
    _shakeController.forward().then((_) => _shakeController.reverse());
    setState(() {
      _enteredPin.clear();
      _isError = true;
      _statusMessage = message;
    });
  }

  void _navigateToApp() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainScaffold()),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.checkroom_rounded,
                    size: 64, color: AppColors.gold),
                const SizedBox(height: 16),
                Text('FAMILY GARMENT',
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(color: AppColors.white, letterSpacing: 3)),
                const SizedBox(height: 8),
                Text('Know Your Numbers',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.goldLight)),
                const SizedBox(height: 60),
                SlideTransition(
                  position: _shakeAnimation,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) {
                      bool filled = index < _enteredPin.length;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: _isError
                                  ? AppColors.error
                                  : AppColors.gold,
                              width: 2),
                          color: filled
                              ? (_isError ? AppColors.error : AppColors.gold)
                              : Colors.transparent,
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 16),
                Text(_statusMessage,
                    style: TextStyle(
                        color: _isError
                            ? AppColors.error
                            : AppColors.goldLight,
                        fontSize: 14)),
                const SizedBox(height: 50),
                _buildNumberPad(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNumberPad() {
    return Column(
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _numberButton('1'), _numberButton('2'), _numberButton('3')
        ]),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _numberButton('4'), _numberButton('5'), _numberButton('6')
        ]),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _numberButton('7'), _numberButton('8'), _numberButton('9')
        ]),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          const SizedBox(width: 70),
          _numberButton('0'),
          _deleteButton(),
        ]),
      ],
    );
  }

  Widget _numberButton(String number) {
    return GestureDetector(
      onTap: () => _onNumberTap(number),
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: AppColors.navyLight.withOpacity(0.3),
          borderRadius: BorderRadius.circular(35),
          border: Border.all(color: AppColors.gold.withOpacity(0.3)),
        ),
        child: Center(
          child: Text(number,
              style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w500)),
        ),
      ),
    );
  }

  Widget _deleteButton() {
    return GestureDetector(
      onTap: _onDeleteTap,
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(35),
        ),
        child: const Center(
          child: Icon(Icons.backspace_outlined,
              color: AppColors.goldLight, size: 28),
        ),
      ),
    );
  }
}