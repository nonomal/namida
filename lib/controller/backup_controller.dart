import 'dart:io';

import 'package:flutter_archive/flutter_archive.dart';
import 'package:namida/core/utils.dart';
import 'package:intl/intl.dart';

import 'package:namida/controller/file_browser.dart';
import 'package:namida/controller/history_controller.dart';
import 'package:namida/controller/indexer_controller.dart';
import 'package:namida/controller/navigator_controller.dart';
import 'package:namida/controller/playlist_controller.dart';
import 'package:namida/controller/queue_controller.dart';
import 'package:namida/controller/settings_controller.dart';
import 'package:namida/controller/video_controller.dart';
import 'package:namida/core/constants.dart';
import 'package:namida/core/extensions.dart';
import 'package:namida/core/translations/language.dart';
import 'package:namida/main.dart';
import 'package:namida/youtube/controller/youtube_history_controller.dart';
import 'package:namida/youtube/controller/youtube_info_controller.dart';
import 'package:namida/youtube/controller/youtube_playlist_controller.dart';

class BackupController {
  static BackupController get inst => _instance;
  static final BackupController _instance = BackupController._internal();
  BackupController._internal();

  final isCreatingBackup = false.obso;
  final isRestoringBackup = false.obso;

  String get _backupDirectoryPath => settings.defaultBackupLocation.value;
  int get _defaultAutoBackupInterval => settings.autoBackupIntervalDays.value;

  Future<void> checkForAutoBackup() async {
    final interval = _defaultAutoBackupInterval;
    if (interval <= 0) return;

    if (!await requestManageStoragePermission(request: false)) return;

    final sortedBackupFiles = await _getBackupFilesSorted.thready(_backupDirectoryPath);
    final latestBackup = sortedBackupFiles.firstOrNull;
    if (latestBackup != null) {
      final lastModified = await latestBackup.stat().then((value) => value.modified);
      final diff = DateTime.now().difference(lastModified).abs().inDays;
      if (diff > interval) {
        final itemsToBackup = [
          AppPaths.TRACKS,
          AppPaths.TRACKS_STATS,
          AppPaths.TOTAL_LISTEN_TIME,
          AppPaths.VIDEOS_CACHE,
          AppPaths.VIDEOS_LOCAL,
          AppPaths.FAVOURITES_PLAYLIST,
          AppPaths.SETTINGS,
          AppPaths.SETTINGS_EQUALIZER,
          AppPaths.SETTINGS_PLAYER,
          AppPaths.LATEST_QUEUE,
          AppPaths.YT_LIKES_PLAYLIST,
          AppDirs.PLAYLISTS,
          AppDirs.HISTORY_PLAYLIST,
          AppDirs.QUEUES,
          AppDirs.YT_DOWNLOAD_TASKS,
          AppDirs.YT_STATS,
          AppDirs.YT_PLAYLISTS,
          AppDirs.YT_HISTORY_PLAYLIST,
        ];
        await createBackupFile(itemsToBackup, fileSuffix: " - auto");
        _trimExtraBackupFiles.thready(_backupDirectoryPath);
      }
    }
  }

  Future<void> createBackupFile(List<String> backupItemsPaths, {String fileSuffix = ''}) async {
    if (isCreatingBackup.value) {
      snackyy(title: lang.NOTE, message: lang.ANOTHER_PROCESS_IS_RUNNING);
      return;
    }

    if (!await requestManageStoragePermission()) return;

    isCreatingBackup.value = true;

    // formats date
    final format = DateFormat('yyyy-MM-dd hh.mm.ss');
    final date = format.format(DateTime.now().toLocal());

    final backupDirPath = _backupDirectoryPath;

    // creates directories and file
    final dir = await Directory(backupDirPath).create();
    final backupFile = await File("${dir.path}/Namida Backup - $date$fileSuffix.zip").create();
    final sourceDir = Directory(AppDirs.USER_DATA);

    // prepares files

    final List<File> localFilesOnly = [];
    final List<File> youtubeFilesOnly = [];
    final List<File> compressedDirectories = [];
    final List<Directory> dirsOnly = [];
    File? tempAllLocal;
    File? tempAllYoutube;

    for (final f in backupItemsPaths) {
      if (await FileSystemEntity.type(f) == FileSystemEntityType.file) {
        f.startsWith(AppDirs.YOUTUBE_MAIN_DIRECTORY) ? youtubeFilesOnly.add(File(f)) : localFilesOnly.add(File(f));
      }
      if (await FileSystemEntity.type(f) == FileSystemEntityType.directory) {
        dirsOnly.add(Directory(f));
      }
    }

    try {
      for (final d in dirsOnly) {
        try {
          final prefix = d.path.startsWith(AppDirs.YOUTUBE_MAIN_DIRECTORY) ? 'YOUTUBE_' : '';
          final dirZipFile = File("${AppDirs.USER_DATA}/${prefix}TEMPDIR_${d.path.getFilename}.zip");
          await ZipFile.createFromDirectory(sourceDir: d, zipFile: dirZipFile);
          compressedDirectories.add(dirZipFile);
        } catch (e) {
          continue;
        }
      }

      if (localFilesOnly.isNotEmpty) {
        tempAllLocal = await File("${AppDirs.USER_DATA}/LOCAL_FILES.zip").create();
        await ZipFile.createFromFiles(sourceDir: sourceDir, files: localFilesOnly, zipFile: tempAllLocal);
      }

      if (youtubeFilesOnly.isNotEmpty) {
        tempAllYoutube = await File("${AppDirs.USER_DATA}/YOUTUBE_FILES.zip").create();
        await ZipFile.createFromFiles(sourceDir: sourceDir, files: youtubeFilesOnly, zipFile: tempAllYoutube);
      }

      final allFiles = [
        if (tempAllLocal != null) tempAllLocal,
        if (tempAllYoutube != null) tempAllYoutube,
        ...compressedDirectories,
      ];
      await ZipFile.createFromFiles(sourceDir: sourceDir, files: allFiles, zipFile: backupFile);

      snackyy(title: lang.CREATED_BACKUP_SUCCESSFULLY, message: lang.CREATED_BACKUP_SUCCESSFULLY_SUB);
    } catch (e) {
      printy(e, isError: true);
      snackyy(title: lang.ERROR, message: e.toString());
    }

    // Cleaning up
    tempAllLocal?.tryDeleting();
    tempAllYoutube?.tryDeleting();
    for (final d in compressedDirectories) {
      d.tryDeleting();
    }

    isCreatingBackup.value = false;
  }

  static List<File> _getBackupFilesSorted(String dirPath) {
    final dir = Directory(dirPath);
    final possibleFiles = dir.listSyncSafe();

    final List<File> matchingBackups = [];
    possibleFiles.loop((pf) {
      if (pf is File) {
        if (pf.path.getFilename.startsWith('Namida Backup - ')) {
          matchingBackups.add(pf);
        }
      }
    });

    // seems like the files are already sorted but anyways
    matchingBackups.sortByReverse((e) => e.lastModifiedSync());

    return matchingBackups;
  }

  static void _trimExtraBackupFiles(String dirPath) {
    final dir = Directory(dirPath);
    final possibleFiles = dir.listSyncSafe();

    final statsLookup = <String, FileStat>{};
    possibleFiles.loop((pf) {
      if (pf is File) {
        final filename = pf.path.getFilename;
        if (filename.startsWith('Namida Backup - ') && filename.endsWith(" - auto.zip")) {
          try {
            statsLookup[pf.path] = pf.statSync();
          } catch (_) {}
        }
      }
    });

    final remainingBackups = <File>[];
    for (final s in statsLookup.entries) {
      if (s.value.size == 0) {
        try {
          File(s.key).deleteSync();
        } catch (_) {}
      } else {
        remainingBackups.add(File(s.key));
      }
    }

    const maxAutoBackups = 10;
    final extra = remainingBackups.length - maxAutoBackups;
    if (extra > 0) {
      remainingBackups.sortBy((e) => e.lastModifiedSync()); // sorting by oldest
      for (int i = 0; i < extra; i++) {
        try {
          remainingBackups[i].deleteSync();
        } catch (_) {}
      }
    }
  }

  Future<void> restoreBackupOnTap(bool auto) async {
    if (isRestoringBackup.value) {
      snackyy(title: lang.NOTE, message: lang.ANOTHER_PROCESS_IS_RUNNING);
      return;
    }

    File? backupzip;
    if (auto) {
      final sortedFiles = await _getBackupFilesSorted.thready(_backupDirectoryPath);
      backupzip = sortedFiles.firstOrNull;
    } else {
      final filePicked = await NamidaFileBrowser.pickFile(note: lang.RESTORE_BACKUP, allowedExtensions: ['zip']);
      final path = filePicked?.path;
      if (path != null) {
        backupzip = File(path);
      }
    }

    if (backupzip == null) return;

    isRestoringBackup.value = true;

    await ZipFile.extractToDirectory(zipFile: backupzip, destinationDir: Directory(AppDirs.USER_DATA));

    // after finishing, extracts zip files inside the main zip
    await for (final backupItem in Directory(AppDirs.USER_DATA).list()) {
      if (backupItem is File) {
        final filename = backupItem.path.getFilename;
        if (filename == 'LOCAL_FILES.zip') {
          await ZipFile.extractToDirectory(
            zipFile: backupItem,
            destinationDir: Directory(AppDirs.USER_DATA),
          );
          await backupItem.tryDeleting();
        } else if (filename == 'YOUTUBE_FILES.zip') {
          await ZipFile.extractToDirectory(
            zipFile: backupItem,
            destinationDir: Directory(AppDirs.USER_DATA), // since the zipped file has the directory 'AppDirs.YOUTUBE_MAIN_DIRECTORY/'
          );
          await backupItem.tryDeleting();
        } else {
          final isLocalTemp = filename.startsWith('TEMPDIR_');
          final isYoutubeTemp = filename.startsWith('YOUTUBE_TEMPDIR_');
          if (isLocalTemp || isYoutubeTemp) {
            final dir = isYoutubeTemp ? AppDirs.YOUTUBE_MAIN_DIRECTORY : AppDirs.USER_DATA;
            final prefixToReplace = isYoutubeTemp ? 'YOUTUBE_TEMPDIR_' : 'TEMPDIR_';

            await ZipFile.extractToDirectory(
              zipFile: backupItem,
              destinationDir: Directory("$dir/${filename.replaceFirst(prefixToReplace, '').replaceFirst('.zip', '')}"),
            );
            await backupItem.tryDeleting();
          }
        }
      }
    }

    Indexer.inst.calculateAllImageSizesInStorage();
    Indexer.inst.updateColorPalettesSizeInStorage();
    Indexer.inst.updateVideosSizeInStorage();
    await _readNewFiles();
    snackyy(title: lang.RESTORED_BACKUP_SUCCESSFULLY, message: lang.RESTORED_BACKUP_SUCCESSFULLY_SUB);
    isRestoringBackup.value = false;
  }

  Future<void> _readNewFiles() async {
    await settings.prepareSettingsFile();
    Indexer.inst.prepareTracksFile();

    QueueController.inst.prepareAllQueuesFile();

    VideoController.inst.initialize();

    PlaylistController.inst.prepareAllPlaylists();
    HistoryController.inst.prepareHistoryFile().then((_) => Indexer.inst.sortMediaTracksSubListsAfterHistoryPrepared());
    await PlaylistController.inst.prepareDefaultPlaylistsFile();
    // await QueueController.inst.prepareLatestQueue();

    YoutubePlaylistController.inst.prepareAllPlaylists();
    YoutubeHistoryController.inst.prepareHistoryFile();
    await YoutubePlaylistController.inst.prepareDefaultPlaylistsFile();
    YoutubeInfoController.utils.fillBackupInfoMap(); // for history videos info.
  }
}
