import 'package:animated_reorderable_grid/animated_reorderable_grid.dart';
import 'package:flutter/material.dart';

void main() => runApp(const ReorderableApp());

class ReorderableApp extends StatefulWidget {
  const ReorderableApp({super.key});

  @override
  State<ReorderableApp> createState() => _ReorderableAppState();
}

class _ReorderableAppState extends State<ReorderableApp> {
  final _tileLabels = [
    'zero',
    'one',
    'two',
    'three',
    'four',
    'five',
    'six',
    'seven',
    'eight',
    'nine',
  ];

  final double _segmentHeight = 140;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SafeArea(
          bottom: false,
          child: AnimatedReorderableGrid(
            length: _tileLabels.length,
            crossAxisCount: 2,
            rowHeight: _segmentHeight,
            primary: true,
            overriddenRowCounts: const [(0, 1), (5, 1)],
            keyBuilder: (index) => ValueKey(index),
            itemBuilder: (_, index) => Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                _tileLabels[index] * 2,
                style: const TextStyle(fontSize: 20),
              ),
            ),
            rowBuilder: (context, index) => Container(
              height: _segmentHeight,
              color: [Colors.red, Colors.green, Colors.blue][index % 3],
            ),
            onReorder: (oldIndex, newIndex) => setState(() {
              final temp = _tileLabels[oldIndex];
              _tileLabels[oldIndex] = _tileLabels[newIndex];
              _tileLabels[newIndex] = temp;
            }),
          ),
        ),
      ),
    );
  }
}

