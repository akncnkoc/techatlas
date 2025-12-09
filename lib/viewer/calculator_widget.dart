import 'package:flutter/material.dart';

class CalculatorWidget extends StatefulWidget {
  final VoidCallback? onClose;

  const CalculatorWidget({super.key, this.onClose});

  @override
  State<CalculatorWidget> createState() => _CalculatorWidgetState();
}

class _CalculatorWidgetState extends State<CalculatorWidget> {
  String _display = '0';
  String _currentNum = '';
  String _operation = '';
  double _firstNum = 0;
  Offset _position = const Offset(50, 50);

  void _onNumberPressed(String num) {
    setState(() {
      if (_display == '0' || _display == 'Hata') {
        _display = num;
        _currentNum = num;
      } else {
        _display += num;
        _currentNum += num;
      }
    });
  }

  void _onOperationPressed(String op) {
    if (_currentNum.isEmpty) return;
    setState(() {
      _firstNum = double.tryParse(_currentNum) ?? 0;
      _operation = op;
      _display += ' $op ';
      _currentNum = '';
    });
  }

  void _onEquals() {
    if (_currentNum.isEmpty || _operation.isEmpty) return;
    setState(() {
      double secondNum = double.tryParse(_currentNum) ?? 0;
      double result = 0;

      switch (_operation) {
        case '+':
          result = _firstNum + secondNum;
          break;
        case '-':
          result = _firstNum - secondNum;
          break;
        case '×':
          result = _firstNum * secondNum;
          break;
        case '÷':
          if (secondNum == 0) {
            _display = 'Hata';
            _currentNum = '';
            return;
          }
          result = _firstNum / secondNum;
          break;
      }

      _display = result.toString();
      if (result == result.toInt()) {
        _display = result.toInt().toString();
      }
      _currentNum = _display;
      _operation = '';
    });
  }

  void _onClear() {
    setState(() {
      _display = '0';
      _currentNum = '';
      _operation = '';
      _firstNum = 0;
    });
  }

  Widget _buildButton(
    String text, {
    Color? color,
    bool isEquals = false,
    VoidCallback? onPressed,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Container(
          decoration: isEquals
              ? BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade600, Colors.green.shade700],
                  ),
                  borderRadius: BorderRadius.circular(10),
                )
              : null,
          child: ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: isEquals
                  ? Colors.transparent
                  : (color ??
                        Theme.of(context).colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.8)),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: isEquals ? 0 : 0,
              shadowColor: Colors.transparent,
            ),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: color != null || isEquals
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurface,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        Positioned(
          left: _position.dx,
          top: _position.dy,
          child: IgnorePointer(
            ignoring: false,
            child: GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  _position = Offset(
                    (_position.dx + details.delta.dx).clamp(
                      0,
                      MediaQuery.of(context).size.width - 320,
                    ),
                    (_position.dy + details.delta.dy).clamp(
                      0,
                      MediaQuery.of(context).size.height - 500,
                    ),
                  );
                });
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(12),
                  color: scheme.surface.withValues(alpha: 0.92),
                  child: Container(
                    width: 280,
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    scheme.primary.withValues(alpha: 0.15),
                                    scheme.primary.withValues(alpha: 0.08),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.calculate_rounded,
                                color: scheme.primary,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Hesap Makinesi',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 20),
                              onPressed: () {
                                if (widget.onClose != null) {
                                  widget.onClose!();
                                } else {
                                  Navigator.pop(context);
                                }
                              },
                              padding: const EdgeInsets.all(8),
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        const Divider(),

                        // Display
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                scheme.surfaceContainerHighest.withValues(
                                  alpha: 0.6,
                                ),
                                scheme.surfaceContainerHighest.withValues(
                                  alpha: 0.4,
                                ),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _display,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Buttons
                        Row(
                          children: [
                            _buildButton(
                              '7',
                              onPressed: () => _onNumberPressed('7'),
                            ),
                            _buildButton(
                              '8',
                              onPressed: () => _onNumberPressed('8'),
                            ),
                            _buildButton(
                              '9',
                              onPressed: () => _onNumberPressed('9'),
                            ),
                            _buildButton(
                              '÷',
                              color: scheme.primary,
                              onPressed: () => _onOperationPressed('÷'),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            _buildButton(
                              '4',
                              onPressed: () => _onNumberPressed('4'),
                            ),
                            _buildButton(
                              '5',
                              onPressed: () => _onNumberPressed('5'),
                            ),
                            _buildButton(
                              '6',
                              onPressed: () => _onNumberPressed('6'),
                            ),
                            _buildButton(
                              '×',
                              color: scheme.primary,
                              onPressed: () => _onOperationPressed('×'),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            _buildButton(
                              '1',
                              onPressed: () => _onNumberPressed('1'),
                            ),
                            _buildButton(
                              '2',
                              onPressed: () => _onNumberPressed('2'),
                            ),
                            _buildButton(
                              '3',
                              onPressed: () => _onNumberPressed('3'),
                            ),
                            _buildButton(
                              '-',
                              color: scheme.primary,
                              onPressed: () => _onOperationPressed('-'),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            _buildButton(
                              'C',
                              color: Colors.red.shade400,
                              onPressed: _onClear,
                            ),
                            _buildButton(
                              '0',
                              onPressed: () => _onNumberPressed('0'),
                            ),
                            _buildButton(
                              '=',
                              isEquals: true,
                              onPressed: _onEquals,
                            ),
                            _buildButton(
                              '+',
                              color: scheme.primary,
                              onPressed: () => _onOperationPressed('+'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
