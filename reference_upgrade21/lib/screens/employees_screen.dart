import 'package:flutter/material.dart';
import '../core/app_scope.dart';
import '../core/theme.dart';
import '../services/analytics_engine.dart';
import '../widgets/common.dart';

class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key});
  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  double raise = 2000;
  @override
  Widget build(BuildContext context) {
    final data = AppScope.of(context).data!;
    return ListView(
      padding: const EdgeInsets.all(22),
      children: [
        const SectionTitle('People & Performance', subtitle: 'Salary, attendance, measurable contribution and human-reviewed appraisal support.'),
        ...data.employees.map((employee) => Card(
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: LayoutBuilder(builder: (context, c) {
                  final narrow = c.maxWidth < 800;
                  final identity = Row(children: [
                    const CircleAvatar(child: Icon(Icons.person)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(employee.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                      Text(employee.role, style: const TextStyle(color: AppTheme.muted)),
                    ])),
                  ]);
                  final metrics = Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 18,
                    runSpacing: 9,
                    children: [
                      _metric('Salary', money(employee.salary)),
                      _metric('Sales handled', money(employee.salesHandled)),
                      _metric('Attendance', '${employee.attendance.toStringAsFixed(0)}%'),
                      _metric('Rating', '${employee.rating.toStringAsFixed(1)}/5'),
                    ],
                  );
                  if (narrow) return Column(children: [identity, const SizedBox(height: 14), Align(alignment: Alignment.centerRight, child: metrics)]);
                  return Row(children: [Expanded(flex: 3, child: identity), const SizedBox(width: 16), Expanded(flex: 5, child: metrics)]);
                }),
              ),
            )),
        const SizedBox(height: 20),
        const SectionTitle('Appraisal simulator', subtitle: 'Decision support only — final appraisal remains with a human manager.'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Monthly salary increase: ${money(raise)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              Slider(value: raise, min: 0, max: 10000, divisions: 20, label: money(raise), onChanged: (value) => setState(() => raise = value)),
              Text('Annual payroll impact: ${money(AnalyticsEngine.appraisalProfitImpact(raise))}', style: const TextStyle(color: AppTheme.amber, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text('Use alongside role, branch traffic, customer feedback, attendance, training and manager evidence. Do not auto-penalize staff from a single score.', style: TextStyle(color: AppTheme.muted)),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _metric(String label, String value) => SizedBox(
        width: 120,
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(label, style: const TextStyle(color: AppTheme.muted, fontSize: 12)),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
      );
}
