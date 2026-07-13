using System.IO;
using UnityEditor;
using UnityEditor.Build;
using UnityEditor.Build.Reporting;
using UnityEngine;

namespace Terraforge.EditorTools
{
    /// <summary>
    /// Gera o APK de teste do Terraforge. Pode ser chamado pelo menu
    /// (Terraforge > Build Android APK) ou por linha de comando via
    /// -executeMethod Terraforge.EditorTools.BuildAndroid.Build
    /// </summary>
    public static class BuildAndroid
    {
        private const string OutputPath = "D:/Terraforge/Builds/Terraforge.apk";
        private const string ApplicationId = "com.terraforge.game";

        [MenuItem("Terraforge/Build Android APK")]
        public static void Build()
        {
            var scenes = new[] { "Assets/_Project/Scenes/SampleScene.unity" };

            // Identidade e retrato (DD-113).
            PlayerSettings.SetApplicationIdentifier(NamedBuildTarget.Android, ApplicationId);
            PlayerSettings.productName = "Terraforge";
            PlayerSettings.defaultInterfaceOrientation = UIOrientation.Portrait;

            // Android moderno: IL2CPP + ARM64 (exigido em builds atuais).
            PlayerSettings.SetScriptingBackend(NamedBuildTarget.Android, ScriptingImplementation.IL2CPP);
            PlayerSettings.Android.targetArchitectures = AndroidArchitecture.ARM64;
            PlayerSettings.Android.minSdkVersion = AndroidSdkVersions.AndroidApiLevel25;

            // APK único (não AAB) para instalar direto no celular de teste.
            EditorUserBuildSettings.buildAppBundle = false;

            Directory.CreateDirectory(Path.GetDirectoryName(OutputPath));

            var options = new BuildPlayerOptions
            {
                scenes = scenes,
                locationPathName = OutputPath,
                target = BuildTarget.Android,
                targetGroup = BuildTargetGroup.Android,
                options = BuildOptions.Development | BuildOptions.AutoRunPlayer
            };

            // Sem auto-run em batch (nenhum celular conectado no PC de build).
            if (Application.isBatchMode)
            {
                options.options = BuildOptions.Development;
            }

            BuildReport report = BuildPipeline.BuildPlayer(options);
            BuildSummary summary = report.summary;

            if (summary.result == BuildResult.Succeeded)
            {
                Debug.Log($"[Build] APK gerado com sucesso: {OutputPath} " +
                          $"({summary.totalSize / (1024 * 1024)} MB)");
            }
            else
            {
                Debug.LogError($"[Build] Falha ao gerar o APK: {summary.result}");
            }
        }
    }
}
