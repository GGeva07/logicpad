import 'package:get_it/get_it.dart';
import '../services/app_update_service.dart';
import '../../features/canvas/data/datasources/canvas_local_datasource.dart';
import '../../features/canvas/domain/services/recognition_service.dart';
import '../../features/canvas/presentation/bloc/canvas_bloc.dart';

final sl = GetIt.instance;

/// Registra todos los servicios/datasources/repositorios/blocs de la app.
/// Se llama una sola vez en main(), antes de runApp().
///
/// Convención: cada feature registra los suyos en su propia función
/// `_registerXFeature()` — así esta función no crece sin límite a medida
/// que se agregan features nuevas. Un servicio usado por una sola feature
/// se registra en la función de esa feature, no acá arriba.
Future<void> configureDependencies() async {
  // Transversales (usados por 2+ features) van acá directo.
  sl.registerLazySingleton(() => AppUpdateService());

  _registerCanvasFeature();
}

void _registerCanvasFeature() {
  sl.registerLazySingleton(() => CanvasLocalDatasource());
  sl.registerLazySingleton(() => RecognitionService());
  sl.registerFactory(() => CanvasBloc(sl(), sl()));
}
