import 'package:args/args.dart';
import 'package:lads/core/command_processor.dart';
import 'package:lads/entry/gui.dart';
import 'package:lads/entry/repl.dart';
import 'package:lads/model/orchestrator.dart';
import 'package:lads/services/ai.dart';
import 'package:lads/services/cli_service.dart';

void main(List<String> args) {
  GeminiService geminiService = GeminiService();
  Orchestrator orchestrator = Orchestrator();
  CommandProcessor commandProcessor = CommandProcessor(orchestrator, geminiService);
  CliService cliService = CliService(commandProcessor);
  final parser = ArgParser()
    ..addFlag('gui', abbr: 'g', help: 'Run the GUI')
    ..addFlag('cli', abbr: 'c', help: 'Run the REPL')
    ..addFlag('help', abbr: 'h', help: 'Show this help message');

  final argResults = parser.parse(args);

  if (argResults['help'] as bool) {
    print('Usage: lads [options]');
    print(parser.usage);
    return;
  }
  if (argResults['gui'] as bool) {
    runGui();
  } else if (argResults['cli'] as bool) {
    runCliRepl(cliService);
  } else {
    print('No option specified. Use --help for usage information.');
  }
}
