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

  Widget _buildButton(String text, {Color? color, VoidCallback? onPressed}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: color ?? Theme.of(context).colorScheme.surface,
            padding: const EdgeInsets.symmetric(vertical: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: color != null ? Colors.white : Theme.of(context).colorScheme.onSurface,
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
                    (_position.dx + details.delta.dx).clamp(0, MediaQuery.of(context).size.width - 320),
                    (_position.dy + details.delta.dy).clamp(0, MediaQuery.of(context).size.height - 500),
                  );
                });
              },
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(16),
                color: scheme.surface,
                child: Container(
                width: 320,
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Row(
                      children: [
                        Icon(Icons.calculate, color: scheme.primary),
                        const SizedBox(width: 8),
                        const Text(
                          'Hesap Makinesi',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            if (widget.onClose != null) {
                              widget.onClose!();
                            } else {
                              Navigator.pop(context);
                            }
                          },
                        ),
                      ],
                    ),
                    const Divider(),

                    // Display
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _display,
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.right,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Buttons
                    Row(
                      children: [
                        _buildButton('7', onPressed: () => _onNumberPressed('7')),
                        _buildButton('8', onPressed: () => _onNumberPressed('8')),
                        _buildButton('9', onPressed: () => _onNumberPressed('9')),
                        _buildButton('÷', color: scheme.primary, onPressed: () => _onOperationPressed('÷')),
                      ],
                    ),
                    Row(
                      children: [
                        _buildButton('4', onPressed: () => _onNumberPressed('4')),
                        _buildButton('5', onPressed: () => _onNumberPressed('5')),
                        _buildButton('6', onPressed: () => _onNumberPressed('6')),
                        _buildButton('×', color: scheme.primary, onPressed: () => _onOperationPressed('×')),
                      ],
                    ),
                    Row(
                      children: [
                        _buildButton('1', onPressed: () => _onNumberPressed('1')),
                        _buildButton('2', onPressed: () => _onNumberPressed('2')),
                        _buildButton('3', onPressed: () => _onNumberPressed('3')),
                        _buildButton('-', color: scheme.primary, onPressed: () => _onOperationPressed('-')),
                      ],
                    ),
                    Row(
                      children: [
                        _buildButton('C', color: Colors.red.shade400, onPressed: _onClear),
                        _buildButton('0', onPressed: () => _onNumberPressed('0')),
                        _buildButton('=', color: Colors.green.shade600, onPressed: _onEquals),
                        _buildButton('+', color: scheme.primary, onPressed: () => _onOperationPressed('+')),
                      ],
                    ),
                  ],
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
