import 'package:hive_ce/hive.dart';
import '../models/computer.dart';

@GenerateAdapters([AdapterSpec<Computer>()])
part 'hive_adapters.g.dart';
