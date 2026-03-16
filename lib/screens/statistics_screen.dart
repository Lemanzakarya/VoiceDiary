import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/diary_entry.dart';
import '../providers/diary_provider.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  int _selectedPeriod = 7; // days

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('İstatistikler'),
      ),
      body: Consumer<DiaryProvider>(
        builder: (context, provider, _) {
          final entries = provider.entries;

          if (entries.isEmpty) {
            return _buildEmptyState();
          }

          final analyzed = entries.where((e) => e.isAnalyzed).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary cards
                _buildSummaryCards(entries, analyzed),
                const SizedBox(height: 24),

                // Period selector
                _buildPeriodSelector(),
                const SizedBox(height: 16),

                // Mood distribution pie chart
                _buildSectionTitle('Duygu Dağılımı'),
                const SizedBox(height: 8),
                _buildMoodPieChart(analyzed),
                const SizedBox(height: 24),

                // Weekly mood trend
                _buildSectionTitle('Duygu Trendi'),
                const SizedBox(height: 8),
                _buildMoodTrendChart(analyzed),
                const SizedBox(height: 24),

                // Recording frequency
                _buildSectionTitle('Kayıt Sıklığı'),
                const SizedBox(height: 8),
                _buildRecordingFrequencyChart(entries),
                const SizedBox(height: 24),

                // Average sentiment score
                _buildSectionTitle('Ortalama Duygu Skoru'),
                const SizedBox(height: 8),
                _buildAverageScoreChart(analyzed),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart, size: 100, color: Colors.grey[400]),
          const SizedBox(height: 20),
          Text(
            'Henüz istatistik yok',
            style: TextStyle(
              fontSize: 24,
              color: Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Ses kayıtları yaptıktan sonra\nistatistiklerinizi burada görebilirsiniz',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(List<DiaryEntry> all, List<DiaryEntry> analyzed) {
    final positive = analyzed.where((e) => e.sentimentLabel == 'positive').length;
    final negative = analyzed.where((e) => e.sentimentLabel == 'negative').length;
    final neutral = analyzed.where((e) => e.sentimentLabel == 'neutral').length;

    return Row(
      children: [
        Expanded(
          child: _buildSummaryCard(
            'Toplam Kayıt',
            '${all.length}',
            Icons.mic,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildSummaryCard(
            'Olumlu',
            '$positive',
            Icons.sentiment_satisfied,
            Colors.green,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildSummaryCard(
            'Olumsuz',
            '$negative',
            Icons.sentiment_dissatisfied,
            Colors.red,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildSummaryCard(
            'Nötr',
            '$neutral',
            Icons.sentiment_neutral,
            Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Row(
      children: [
        _buildPeriodChip('7 Gün', 7),
        const SizedBox(width: 8),
        _buildPeriodChip('30 Gün', 30),
        const SizedBox(width: 8),
        _buildPeriodChip('90 Gün', 90),
        const SizedBox(width: 8),
        _buildPeriodChip('Tümü', 365),
      ],
    );
  }

  Widget _buildPeriodChip(String label, int days) {
    final isSelected = _selectedPeriod == days;
    return FilterChip(
      selected: isSelected,
      label: Text(label),
      onSelected: (_) {
        setState(() {
          _selectedPeriod = days;
        });
      },
      selectedColor: Colors.blue.withValues(alpha: 0.2),
      checkmarkColor: Colors.blue,
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.grey[700],
      ),
    );
  }

  List<DiaryEntry> _filterByPeriod(List<DiaryEntry> entries) {
    final cutoff = DateTime.now().subtract(Duration(days: _selectedPeriod));
    return entries.where((e) => e.createdAt.isAfter(cutoff)).toList();
  }

  // ── Mood Pie Chart ──────────────────────────────────────────
  Widget _buildMoodPieChart(List<DiaryEntry> analyzed) {
    final filtered = _filterByPeriod(analyzed);
    if (filtered.isEmpty) {
      return _buildNoDataCard('Bu dönemde analiz edilmiş kayıt yok');
    }

    final positive = filtered.where((e) => e.sentimentLabel == 'positive').length;
    final negative = filtered.where((e) => e.sentimentLabel == 'negative').length;
    final neutral = filtered.where((e) => e.sentimentLabel == 'neutral').length;
    final total = filtered.length;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SizedBox(
          height: 220,
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 3,
                    centerSpaceRadius: 40,
                    sections: [
                      if (positive > 0)
                        PieChartSectionData(
                          value: positive.toDouble(),
                          title: '${(positive / total * 100).round()}%',
                          color: Colors.green,
                          radius: 60,
                          titleStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      if (negative > 0)
                        PieChartSectionData(
                          value: negative.toDouble(),
                          title: '${(negative / total * 100).round()}%',
                          color: Colors.red,
                          radius: 60,
                          titleStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      if (neutral > 0)
                        PieChartSectionData(
                          value: neutral.toDouble(),
                          title: '${(neutral / total * 100).round()}%',
                          color: Colors.orange,
                          radius: 60,
                          titleStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLegendItem('Olumlu', Colors.green, positive),
                    const SizedBox(height: 12),
                    _buildLegendItem('Olumsuz', Colors.red, negative),
                    const SizedBox(height: 12),
                    _buildLegendItem('Nötr', Colors.orange, neutral),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, int count) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '$label ($count)',
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ],
    );
  }

  // ── Mood Trend Line Chart ─────────────────────────────────
  Widget _buildMoodTrendChart(List<DiaryEntry> analyzed) {
    final filtered = _filterByPeriod(analyzed);
    if (filtered.length < 2) {
      return _buildNoDataCard('Trend gösterimi için en az 2 analiz edilmiş kayıt gerekli');
    }

    // Group entries by day and compute average sentiment score
    final Map<String, List<double>> dailyScores = {};
    for (final entry in filtered) {
      final dayKey = DateFormat('yyyy-MM-dd').format(entry.createdAt);
      final score = _sentimentToScore(entry);
      dailyScores.putIfAbsent(dayKey, () => []).add(score);
    }

    final sortedDays = dailyScores.keys.toList()..sort();
    final spots = <FlSpot>[];
    for (int i = 0; i < sortedDays.length; i++) {
      final scores = dailyScores[sortedDays[i]]!;
      final avg = scores.reduce((a, b) => a + b) / scores.length;
      spots.add(FlSpot(i.toDouble(), avg));
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 20, 20, 12),
        child: SizedBox(
          height: 220,
          child: LineChart(
            LineChartData(
              minY: -1,
              maxY: 1,
              gridData: FlGridData(
                show: true,
                horizontalInterval: 0.5,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: Colors.grey.withValues(alpha: 0.15),
                  strokeWidth: 1,
                ),
                drawVerticalLine: false,
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      switch (value.toInt()) {
                        case 1:
                          return const Text('😊', style: TextStyle(fontSize: 14));
                        case 0:
                          return const Text('😐', style: TextStyle(fontSize: 14));
                        case -1:
                          return const Text('😔', style: TextStyle(fontSize: 14));
                        default:
                          return const SizedBox.shrink();
                      }
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: (sortedDays.length / 5).ceilToDouble().clamp(1, double.infinity),
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= sortedDays.length) {
                        return const SizedBox.shrink();
                      }
                      final date = DateTime.parse(sortedDays[idx]);
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          DateFormat('dd/MM').format(date),
                          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                        ),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: Colors.blue,
                  barWidth: 3,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, bar, index) {
                      Color dotColor;
                      if (spot.y > 0.3) {
                        dotColor = Colors.green;
                      } else if (spot.y < -0.3) {
                        dotColor = Colors.red;
                      } else {
                        dotColor = Colors.orange;
                      }
                      return FlDotCirclePainter(
                        radius: 5,
                        color: dotColor,
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      );
                    },
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        Colors.blue.withValues(alpha: 0.2),
                        Colors.blue.withValues(alpha: 0.0),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
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

  double _sentimentToScore(DiaryEntry entry) {
    final score = entry.sentimentScore ?? 0.5;
    switch (entry.sentimentLabel) {
      case 'positive':
        return score; // 0 to 1
      case 'negative':
        return -score; // -1 to 0
      case 'neutral':
      default:
        return 0;
    }
  }

  // ── Recording Frequency Bar Chart ─────────────────────────
  Widget _buildRecordingFrequencyChart(List<DiaryEntry> entries) {
    final filtered = _filterByPeriod(entries);
    if (filtered.isEmpty) {
      return _buildNoDataCard('Bu dönemde kayıt yok');
    }

    // Group by day of week
    final Map<int, int> weekdayCounts = {
      for (int i = 1; i <= 7; i++) i: 0,
    };
    for (final entry in filtered) {
      weekdayCounts[entry.createdAt.weekday] =
          (weekdayCounts[entry.createdAt.weekday] ?? 0) + 1;
    }

    final maxCount = weekdayCounts.values.reduce((a, b) => a > b ? a : b);
    final dayNames = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 20, 20, 12),
        child: SizedBox(
          height: 180,
          child: BarChart(
            BarChartData(
              maxY: (maxCount + 1).toDouble(),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    return BarTooltipItem(
                      '${rod.toY.toInt()} kayıt',
                      const TextStyle(color: Colors.white, fontSize: 12),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      if (value == value.roundToDouble() && value >= 0) {
                        return Text(
                          '${value.toInt()}',
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx >= 0 && idx < dayNames.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            dayNames[idx],
                            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                show: true,
                horizontalInterval: 1,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: Colors.grey.withValues(alpha: 0.1),
                  strokeWidth: 1,
                ),
                drawVerticalLine: false,
              ),
              barGroups: List.generate(7, (i) {
                final count = weekdayCounts[i + 1] ?? 0;
                return BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: count.toDouble(),
                      color: Colors.blue,
                      width: 20,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                      backDrawRodData: BackgroundBarChartRodData(
                        show: true,
                        toY: (maxCount + 1).toDouble(),
                        color: Colors.blue.withValues(alpha: 0.05),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  // ── Average Sentiment Score Over Time ──────────────────────
  Widget _buildAverageScoreChart(List<DiaryEntry> analyzed) {
    final filtered = _filterByPeriod(analyzed);
    final withScore = filtered.where((e) => e.sentimentScore != null).toList();
    if (withScore.length < 2) {
      return _buildNoDataCard('Skor trendi için en az 2 kayıt gerekli');
    }

    // Group by day, compute average score
    final Map<String, List<double>> dailyScores = {};
    for (final entry in withScore) {
      final dayKey = DateFormat('yyyy-MM-dd').format(entry.createdAt);
      dailyScores.putIfAbsent(dayKey, () => []).add(entry.sentimentScore!);
    }

    final sortedDays = dailyScores.keys.toList()..sort();
    final spots = <FlSpot>[];
    for (int i = 0; i < sortedDays.length; i++) {
      final scores = dailyScores[sortedDays[i]]!;
      final avg = scores.reduce((a, b) => a + b) / scores.length;
      spots.add(FlSpot(i.toDouble(), avg));
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 20, 20, 12),
        child: SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: 1,
              gridData: FlGridData(
                show: true,
                horizontalInterval: 0.25,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: Colors.grey.withValues(alpha: 0.15),
                  strokeWidth: 1,
                ),
                drawVerticalLine: false,
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    interval: 0.25,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        '${(value * 100).toInt()}%',
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: (sortedDays.length / 5).ceilToDouble().clamp(1, double.infinity),
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= sortedDays.length) {
                        return const SizedBox.shrink();
                      }
                      final date = DateTime.parse(sortedDays[idx]);
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          DateFormat('dd/MM').format(date),
                          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                        ),
                      );
                    },
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  gradient: const LinearGradient(
                    colors: [Colors.purple, Colors.blue],
                  ),
                  barWidth: 3,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        Colors.purple.withValues(alpha: 0.15),
                        Colors.blue.withValues(alpha: 0.0),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
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

  Widget _buildNoDataCard(String message) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
        ),
      ),
    );
  }
}
