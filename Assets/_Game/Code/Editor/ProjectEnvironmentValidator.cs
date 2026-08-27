using System;
using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;

namespace XianxiaRogue.Editor
{
    public static class ProjectEnvironmentValidator
    {
        private const string ExpectedUnityLine = "6000.3";

        [MenuItem("Tools/Xianxia Rogue/Validate Project Environment")]
        public static void ValidateFromMenu()
        {
            ValidateOrThrow();
            Debug.Log("[XianxiaRogue] Project environment is valid.");
        }

        public static void ValidateOrThrow()
        {
            if (!Application.unityVersion.StartsWith(ExpectedUnityLine, StringComparison.Ordinal))
            {
                throw new InvalidOperationException(
                    $"Expected Unity {ExpectedUnityLine}.x, but found {Application.unityVersion}.");
            }

            if (GraphicsSettings.defaultRenderPipeline == null ||
                !GraphicsSettings.defaultRenderPipeline.GetType().Name.Contains("Universal"))
            {
                throw new InvalidOperationException("The project is not using a Universal Render Pipeline asset.");
            }

            if (!AssetDatabase.IsValidFolder("Assets/_Game"))
            {
                throw new InvalidOperationException("Assets/_Game is missing.");
            }
        }
    }
}
