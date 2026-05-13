import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:family_garment/core/theme/app_theme.dart';
import 'package:family_garment/shared/widgets/main_scaffold.dart';

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

  // Security question
  String _securityQuestion = '';
  String _securityAnswer = '';
  bool _isSettingSecurity = false;
  final _questionController = TextEditingController();
  final _answerController = TextEditingController();

  // Reset flow
  bool _isResetting = false;

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
    String? question = await _storage.read(key: 'security_question');
    String? answer = await _storage.read(key: 'security_answer');

    if (mounted) {
      setState(() {
        if (pin != null && pin.length == 4) {
          _storedPin = pin;
          _isFirstTime = false;
        }
        if (question != null && answer != null) {
          _securityQuestion = question;
          _securityAnswer = answer;
        }
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
        if (mounted) {
          setState(() {
            _firstPin = entered;
            _isConfirming = true;
            _enteredPin.clear();
            _statusMessage = 'Confirm PIN';
          });
        }
      } else {
        if (entered == _firstPin) {
          await _storage.write(key: 'user_pin', value: entered);
          if (mounted) {
            setState(() {
              _isSettingSecurity = true;
            });
          }
        } else {
          _showError("PINs don't match. Try again.");
          if (mounted) {
            setState(() {
              _isConfirming = false;
              _firstPin = '';
              _statusMessage = 'Enter PIN';
            });
          }
        }
      }
    } else if (_isResetting) {
      if (!_isConfirming) {
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) {
          setState(() {
            _firstPin = entered;
            _isConfirming = true;
            _enteredPin.clear();
            _statusMessage = 'Confirm new PIN';
          });
        }
      } else {
        if (entered == _firstPin) {
          await _storage.write(key: 'user_pin', value: entered);
          _navigateToApp();
        } else {
          _showError("PINs don't match. Try again.");
          if (mounted) {
            setState(() {
              _isConfirming = false;
              _firstPin = '';
              _statusMessage = 'Enter new PIN';
            });
          }
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
    if (mounted) {
      setState(() {
        _enteredPin.clear();
        _isError = true;
        _statusMessage = message;
      });
    }
  }

  void _navigateToApp() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const MainScaffold(),
        transitionDuration: const Duration(milliseconds: 400),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  // ========== FORGOT PIN FLOW ==========
  void _forgotPin() {
    if (_securityQuestion.isEmpty || _securityAnswer.isEmpty) {
      _showResetPinDirectly();
    } else {
      _showSecurityQuestionDialog();
    }
  }

  void _showSecurityQuestionDialog() {
    final answerController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.navy.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.lock_outline, color: AppColors.navy, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Reset PIN', style: TextStyle(color: AppColors.navy)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Security Question:',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    fontSize: 13)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(_securityQuestion,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w500)),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: answerController,
              decoration: InputDecoration(
                labelText: 'Your Answer',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppColors.navy, width: 2)),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (answerController.text.trim().toLowerCase() ==
                  _securityAnswer.toLowerCase()) {
                Navigator.pop(ctx);
                _startResetFlow();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Wrong answer. Try again.'),
                    backgroundColor: AppColors.error,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.navy,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }

  void _showResetPinDirectly() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reset PIN'),
        content: const Text(
            'No security question found. You can reset your PIN now.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _startResetFlow();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.navy,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Reset PIN'),
          ),
        ],
      ),
    );
  }

  void _startResetFlow() {
    if (mounted) {
      setState(() {
        _isResetting = true;
        _isConfirming = false;
        _enteredPin.clear();
        _firstPin = '';
        _statusMessage = 'Enter new PIN';
        _isError = false;
      });
    }
  }

  // ========== SECURITY QUESTION SETUP ==========
  Future<void> _saveSecurityQuestion() async {
    if (_questionController.text.trim().isEmpty ||
        _answerController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please fill both fields'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    await _storage.write(
        key: 'security_question', value: _questionController.text.trim());
    await _storage.write(
        key: 'security_answer',
        value: _answerController.text.trim().toLowerCase());

    if (mounted) {
      setState(() {
        _securityQuestion = _questionController.text.trim();
        _securityAnswer = _answerController.text.trim().toLowerCase();
        _isSettingSecurity = false;
      });
    }

    _navigateToApp();
  }

  void _skipSecurityQuestion() {
    if (mounted) setState(() => _isSettingSecurity = false);
    _navigateToApp();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _questionController.dispose();
    _answerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isSettingSecurity) {
      return _buildSecuritySetupScreen();
    }

    return Scaffold(
      backgroundColor: AppColors.navy,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                // Logo
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: AppColors.gold.withOpacity(0.3), width: 2),
                  ),
                  child: const Icon(Icons.checkroom_rounded,
                      size: 48, color: AppColors.gold),
                ),
                const SizedBox(height: 24),
                Text('FAMILY GARMENT',
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(
                            color: AppColors.white,
                            letterSpacing: 4,
                            fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text('Know Your Numbers',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: AppColors.goldLight)),
                const SizedBox(height: 60),

                // PIN dots
                SlideTransition(
                  position: _shakeAnimation,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) {
                      bool filled = index < _enteredPin.length;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: _isError
                                  ? AppColors.error
                                  : AppColors.gold,
                              width: 2.5),
                          color: filled
                              ? (_isError ? AppColors.error : AppColors.gold)
                              : Colors.transparent,
                          boxShadow: filled
                              ? [
                                  BoxShadow(
                                    color: (_isError
                                            ? AppColors.error
                                            : AppColors.gold)
                                        .withOpacity(0.4),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  )
                                ]
                              : null,
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 20),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: _statusMessage.isNotEmpty ? 1 : 0,
                  child: Text(_statusMessage,
                      style: TextStyle(
                          color: _isError
                              ? AppColors.error
                              : AppColors.goldLight,
                          fontSize: 14,
                          fontWeight: FontWeight.w500)),
                ),
                const SizedBox(height: 50),

                // Number pad
                _buildNumberPad(),

                const SizedBox(height: 30),

                // Forgot PIN
                if (!_isFirstTime)
                  TextButton(
                    onPressed: _forgotPin,
                    child: Text(
                      'Forgot PIN?',
                      style: TextStyle(
                        color: AppColors.goldLight.withOpacity(0.7),
                        fontSize: 14,
                        decoration: TextDecoration.underline,
                        decorationColor:
                            AppColors.goldLight.withOpacity(0.4),
                      ),
                    ),
                  ),

                if (_isResetting)
                  TextButton(
                    onPressed: () {
                      if (mounted) {
                        setState(() {
                          _isResetting = false;
                          _enteredPin.clear();
                          _statusMessage = 'Enter PIN';
                          _isError = false;
                        });
                      }
                    },
                    child: Text(
                      'Cancel Reset',
                      style: TextStyle(
                        color: AppColors.goldLight.withOpacity(0.7),
                        fontSize: 14,
                      ),
                    ),
                  ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSecuritySetupScreen() {
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.security_rounded,
                      size: 40, color: AppColors.gold),
                ),
                const SizedBox(height: 24),
                Text('Security Setup',
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(color: AppColors.white)),
                const SizedBox(height: 8),
                Text(
                  'Set a security question to reset your PIN if forgotten.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: AppColors.goldLight.withOpacity(0.8),
                      fontSize: 14),
                ),
                const SizedBox(height: 36),
                TextField(
                  controller: _questionController,
                  style: const TextStyle(color: AppColors.white),
                  cursorColor: AppColors.gold,
                  decoration: InputDecoration(
                    labelText: 'Security Question',
                    labelStyle:
                        const TextStyle(color: AppColors.goldLight),
                    hintText: 'e.g. What is your mother\'s maiden name?',
                    hintStyle: TextStyle(
                        color: AppColors.goldLight.withOpacity(0.4)),
                    filled: true,
                    fillColor: AppColors.navyLight.withOpacity(0.3),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                          color: AppColors.gold.withOpacity(0.3)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                          color: AppColors.gold.withOpacity(0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                          color: AppColors.gold, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _answerController,
                  style: const TextStyle(color: AppColors.white),
                  cursorColor: AppColors.gold,
                  decoration: InputDecoration(
                    labelText: 'Answer',
                    labelStyle:
                        const TextStyle(color: AppColors.goldLight),
                    filled: true,
                    fillColor: AppColors.navyLight.withOpacity(0.3),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                          color: AppColors.gold.withOpacity(0.3)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                          color: AppColors.gold.withOpacity(0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                          color: AppColors.gold, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 36),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _saveSecurityQuestion,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.navy,
                      elevation: 4,
                      shadowColor: AppColors.gold.withOpacity(0.4),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('SAVE & CONTINUE',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _skipSecurityQuestion,
                  child: Text(
                    'Skip (not recommended)',
                    style: TextStyle(
                      color: AppColors.goldLight.withOpacity(0.5),
                      fontSize: 13,
                    ),
                  ),
                ),
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
          _numberButton('1'),
          _numberButton('2'),
          _numberButton('3')
        ]),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _numberButton('4'),
          _numberButton('5'),
          _numberButton('6')
        ]),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          _numberButton('7'),
          _numberButton('8'),
          _numberButton('9')
        ]),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          const SizedBox(width: 72),
          _numberButton('0'),
          _deleteButton(),
        ]),
      ],
    );
  }

  Widget _numberButton(String number) {
    return GestureDetector(
      onTap: () => _onNumberTap(number),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: AppColors.navyLight.withOpacity(0.25),
          borderRadius: BorderRadius.circular(36),
          border: Border.all(color: AppColors.gold.withOpacity(0.25)),
        ),
        child: Center(
          child: Text(number,
              style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w400)),
        ),
      ),
    );
  }

  Widget _deleteButton() {
    return GestureDetector(
      onTap: _onDeleteTap,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(36),
        ),
        child: const Center(
          child: Icon(Icons.backspace_outlined,
              color: AppColors.goldLight, size: 26),
        ),
      ),
    );
  }
}