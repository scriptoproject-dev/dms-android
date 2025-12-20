import 'package:flutter/material.dart';
import 'package:qr_scanner_app/constants/colors.dart';

class AntibiogramListScreen extends StatelessWidget {
  final String categoryName;
  final bool susceptibility;
  final List<Map<String, dynamic>> dataList;

  const AntibiogramListScreen({
    super.key,
    required this.categoryName,
    required this.susceptibility,
    required this.dataList,
  });

  @override
  Widget build(BuildContext context) {
    debugPrint('Data Inside: $dataList');
    debugPrint('Susceptibility: $susceptibility');

    // Sort the list to bring "Number Tested" to the top
    dataList.sort((a, b) {
      if (a['x_axis_name'] == 'Number Tested') return -1;
      if (b['x_axis_name'] == 'Number Tested') return 1;
      return 0;
    });

    // Helper function to format values:
    // For "Number Tested" rows, remove decimal parts.
    String formatValue(dynamic value, bool isNumberTested) {
      if (value == null) return "N/A";
      double? parsedValue = double.tryParse(value.toString());
      if (parsedValue == null) return value.toString();
      return isNumberTested
          ? parsedValue.toInt().toString()
          : parsedValue.toString();
    }

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.all(16),
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: dataList.map((item) {
          String xAxisName = item['x_axis_name'] ?? 'Unknown';
          var newValue = item['new_value'];
          var oldValue = item['old_value'];
          bool isNumberTested = xAxisName == 'Number Tested';

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: Text(
                        xAxisName,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                          fontSize: isNumberTested ? 14 : 12,
                        ),
                      ),
                    ),
                    if (isNumberTested) ...[
                      const SizedBox(width: 20),
                      if (susceptibility)
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Old",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  formatValue(oldValue, isNumberTested),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              "New",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                formatValue(newValue, isNumberTested),
                                style: const TextStyle(fontSize: 12),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    if (!isNumberTested) ...[
                      if (susceptibility) ...[
                        Expanded(
                          flex: 4,
                          child: Row(
                            children: [
                              Flexible(
                                child: FractionallySizedBox(
                                  widthFactor: 0.8,
                                  child: Transform(
                                    transform: Matrix4.identity()
                                      ..scale(-1.0, 1.0),
                                    alignment: Alignment.center,
                                    child: SizedBox(
                                      height: 10,
                                      child: LinearProgressIndicator(
                                        value: (double.tryParse(
                                                    oldValue?.toString() ??
                                                        '0') ??
                                                0) /
                                            100,
                                        backgroundColor: Colors.grey[200],
                                        color: (double.tryParse(
                                                        oldValue?.toString() ??
                                                            '0') ??
                                                    0) >=
                                                80
                                            ? greenGraph
                                            : (double.tryParse(oldValue
                                                                ?.toString() ??
                                                            '0') ??
                                                        0) >=
                                                    60
                                                ? yellowGraph
                                                : redGraph,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 5),
                              SizedBox(
                                width: 40,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    formatValue(oldValue, isNumberTested),
                                    style: const TextStyle(
                                        color: lightBlack, fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                      ] else ...[
                        const Expanded(flex: 4, child: SizedBox(height: 10)),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        flex: 4,
                        child: Row(
                          children: [
                            SizedBox(
                              // width: indicatorWidth,
                              width: 32,
                              // child: FractionallySizedBox(
                              //   widthFactor: 0.5,
                              child: Transform(
                                transform: Matrix4.identity()..scale(-1.0, 1.0),
                                alignment: Alignment.center,
                                child: SizedBox(
                                  height: 10,
                                  child: LinearProgressIndicator(
                                    value: (double.tryParse(
                                                newValue?.toString() ?? '0') ??
                                            0) /
                                        100,
                                    backgroundColor: Colors.grey[200],
                                    color: (double.tryParse(
                                                    newValue?.toString() ??
                                                        '0') ??
                                                0) >=
                                            80
                                        ? greenGraph
                                        : (double.tryParse(
                                                        newValue?.toString() ??
                                                            '0') ??
                                                    0) >=
                                                60
                                            ? yellowGraph
                                            : redGraph,
                                  ),
                                ),
                              ),
                              // ),
                            ),
                            const SizedBox(width: 5),
                            SizedBox(
                              width: 40,
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  formatValue(newValue, isNumberTested),
                                  style: const TextStyle(
                                      color: lightBlack, fontSize: 12),
                                  textAlign: TextAlign.right,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                if (isNumberTested)
                  const Divider(color: dividerColor, thickness: 1),
                const SizedBox(height: 10),
                if (isNumberTested) ...[
                  Row(
                    children: [
                      if (susceptibility)
                        const Expanded(
                          flex: 3,
                          child: Padding(
                            padding: EdgeInsets.only(left: 100.0),
                            child: Text(
                              '% Sensitivity',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: gray,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      const Spacer(),
                      const Padding(
                        padding: EdgeInsets.only(right: 10),
                        child: Text(
                          '% Sensitivity',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: gray,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
