using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using UnityEditor;
using UnityEditor.Build.Reporting;
using UnityEditor.SceneManagement;
using UnityEngine;

namespace XianxiaRogue.Editor
{
    /// <summary>
    /// Shared build / lightmap entry points used both from the Unity menu and from
    /// remote build machines via:
    ///   Unity.exe -batchmode -nographics -quit -projectPath &lt;path&gt;
    ///     -executeMethod XianxiaRogue.Editor.BuildTools.BuildWindows
    ///   Unity.exe -batchmode -nographics -projectPath &lt;path&gt;
    ///     -executeMethod XianxiaRogue.Editor.BuildTools.BakeAllEnabledScenes   (no -quit)
    /// </summary>
    public static class BuildTools
    {
        private const string MenuRoot = "Tools/Xianxia Rogue/";

        private static string ProjectRoot =>
            Path.GetFullPath(Path.Combine(Application.dataPath, ".."));

        private static string DefaultOutputRoot => Path.Combine(ProjectRoot, "Builds");

        // ---------------------------------------------------------------- Windows build

        [MenuItem(MenuRoot + "Build Windows Player")]
        public static void BuildWindowsFromMenu()
        {
            ProjectEnvironmentValidator.ValidateOrThrow();
            var output = Path.Combine(DefaultOutputRoot, "Windows");
            var report = BuildWindowsPlayer(output, BuildTarget.StandaloneWindows64);
            Debug.Log($"[XianxiaRogue] Build {report.summary.result} -> {output}");
        }

        /// <summary>CLI entry. Optional argument: -outputPath C:\path\to\dir</summary>
        public static void BuildWindows()
        {
            ProjectEnvironmentValidator.ValidateOrThrow();
            var output = GetCliArgument("outputPath") ?? Path.Combine(DefaultOutputRoot, "Windows");
            var report = BuildWindowsPlayer(output, BuildTarget.StandaloneWindows64);
            Debug.Log($"[XianxiaRogue] BuildWindows result: {report.summary.result} " +
                      $"(errors={report.summary.totalErrors}) -> {output}");
            if (report.summary.result != BuildResult.Succeeded)
            {
                EditorApplication.Exit(1);
            }
        }

        private static BuildReport BuildWindowsPlayer(string outputDir, BuildTarget target)
        {
            var enabledScenes = EditorBuildSettings.scenes
                .Where(s => s.enabled && !string.IsNullOrEmpty(s.path))
                .Select(s => s.path)
                .ToArray();
            if (enabledScenes.Length == 0)
            {
                throw new InvalidOperationException(
                    "No enabled scenes in Build Settings. Add a scene first (File > Build Settings).");
            }

            if (EditorUserBuildSettings.activeBuildTarget != target)
            {
                EditorUserBuildSettings.SwitchActiveBuildTarget(BuildTargetGroup.Standalone, target);
            }

            Directory.CreateDirectory(outputDir);
            var options = new BuildPlayerOptions
            {
                scenes = enabledScenes,
                locationPathName = Path.Combine(outputDir, $"{PlayerSettings.productName}.exe"),
                target = target,
                options = BuildOptions.None
            };
            return BuildPipeline.BuildPlayer(options);
        }

        // ---------------------------------------------------------------- Lightmap baking

        private static readonly Queue<string> BakeQueue = new Queue<string>();
        private static bool _bakeRunning;
        private static bool _bakeExitWhenDone;

        [MenuItem(MenuRoot + "Bake Lighting (enabled scenes)")]
        public static void BakeEnabledScenesFromMenu()
        {
            BakeEnabledScenes(exitWhenDone: false);
        }

        /// <summary>CLI: bakes every enabled scene in Build Settings, then exits.</summary>
        public static void BakeAllEnabledScenes()
        {
            ProjectEnvironmentValidator.ValidateOrThrow();
            BakeEnabledScenes(exitWhenDone: true);
        }

        private static void BakeEnabledScenes(bool exitWhenDone)
        {
            var scenes = EditorBuildSettings.scenes
                .Where(s => s.enabled && !string.IsNullOrEmpty(s.path))
                .Select(s => s.path)
                .ToArray();
            if (scenes.Length == 0)
            {
                throw new InvalidOperationException(
                    "No enabled scenes in Build Settings. Nothing to bake.");
            }

            BakeQueue.Clear();
            foreach (var path in scenes)
            {
                BakeQueue.Enqueue(path);
            }

            _bakeExitWhenDone = exitWhenDone;
            EditorApplication.update -= BakeTick;
            EditorApplication.update += BakeTick;
            BakeNextScene();
        }

        private static void BakeNextScene()
        {
            if (BakeQueue.Count == 0)
            {
                FinishBaking();
                return;
            }

            var path = BakeQueue.Dequeue();
            var scene = EditorSceneManager.OpenScene(path, OpenSceneMode.Single);
            Debug.Log($"[XianxiaRogue] Baking scene: {scene.name} ({path})");
            _bakeRunning = true;
            Lightmapping.BakeAsync();
        }

        private static void BakeTick()
        {
            if (!_bakeRunning)
            {
                return;
            }

            if (Lightmapping.isRunning)
            {
                return;
            }

            _bakeRunning = false;
            EditorSceneManager.SaveOpenScenes();
            AssetDatabase.SaveAssets();
            Debug.Log("[XianxiaRogue] Finished baking one scene.");
            BakeNextScene();
        }

        private static void FinishBaking()
        {
            EditorApplication.update -= BakeTick;
            Debug.Log("[XianxiaRogue] All baking jobs finished.");
            if (_bakeExitWhenDone && Application.isBatchMode)
            {
                EditorApplication.Exit(0);
            }
        }

        // ---------------------------------------------------------------- helpers

        private static string GetCliArgument(string key)
        {
            var args = Environment.GetCommandLineArgs();
            for (var i = 0; i < args.Length - 1; i++)
            {
                if (string.Equals(args[i], "-" + key, StringComparison.OrdinalIgnoreCase) &&
                    !args[i + 1].StartsWith("-", StringComparison.Ordinal))
                {
                    return args[i + 1];
                }
            }
            return null;
        }
    }
}
