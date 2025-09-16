using System.IO;
using System.IO.Compression;
using UnityEditor;
using UnityEngine;
using UnityEditor.Build.Reporting;
using UnityEditor.Callbacks;
using System.Xml;
using System.Linq;
#if UNITY_IOS
using UnityEditor.iOS.Xcode;
#endif
public class BuildScript
{
	public static void BuildAPK()
	{
		// Set keystore path from the root directory of the Git project
		// Get keystore information from environment variables (GitLab CI/CD variables) - REQUIRED
		string keystorePath = System.Environment.GetEnvironmentVariable("KEYSTORE_PATH");
		string keystorePass = System.Environment.GetEnvironmentVariable("KEYSTORE_PASS");
		string keyAlias = System.Environment.GetEnvironmentVariable("KEY_ALIAS");
		string keyPass = System.Environment.GetEnvironmentVariable("KEY_PASS");

		// Validate required keystore configuration
		if (string.IsNullOrEmpty(keystorePath))
		{
			Debug.LogError("[Build] KEYSTORE_PATH environment variable is not set. Please configure keystore settings in GitLab CI/CD variables.");
			EditorApplication.Exit(1);
			return;
		}
		if (string.IsNullOrEmpty(keystorePass))
		{
			Debug.LogError("[Build] KEYSTORE_PASS environment variable is not set. Please configure keystore settings in GitLab CI/CD variables.");
			EditorApplication.Exit(1);
			return;
		}
		if (string.IsNullOrEmpty(keyAlias))
		{
			Debug.LogError("[Build] KEY_ALIAS environment variable is not set. Please configure keystore settings in GitLab CI/CD variables.");
			EditorApplication.Exit(1);
			return;
		}
		if (string.IsNullOrEmpty(keyPass))
		{
			Debug.LogError("[Build] KEY_PASS environment variable is not set. Please configure keystore settings in GitLab CI/CD variables.");
			EditorApplication.Exit(1);
			return;
		}

		// Normalize path for cross-platform compatibility (Windows \ to Unix /)
		keystorePath = keystorePath.Replace("\\", "/");

		// If path starts with \ or /, treat as relative to project root
		if (keystorePath.StartsWith("/") || keystorePath.StartsWith("\\"))
		{
			keystorePath = keystorePath.TrimStart('/', '\\');
		}

		// Convert to absolute path if it's relative
		if (!Path.IsPathRooted(keystorePath))
		{
			keystorePath = Path.Combine(Directory.GetCurrentDirectory(), keystorePath);
		}
									   // Default path for the APK
		string buildPath = "Build/Android/your_game.apk";

		// Retrieve APK file name from command line argument
		string[] args = System.Environment.GetCommandLineArgs();
		foreach (string arg in args)
		{
			if (arg.StartsWith("-buildPath"))
			{
				buildPath = arg.Split('=')[1];  // Get the value from the -buildPath argument
			}
		}
		
		if (!File.Exists(keystorePath))
		{
			Debug.LogError($"[Build] Keystore file not found at path: {keystorePath}");
			EditorApplication.Exit(1);
		}
		else
		{
			Debug.LogError($"[Build] Keystore file found at path: {keystorePath}");
		}

		// Enable custom keystore usage - CRITICAL for proper signing
		PlayerSettings.Android.useCustomKeystore = true;
		PlayerSettings.Android.keystoreName = keystorePath;
		PlayerSettings.Android.keystorePass = keystorePass;
		PlayerSettings.Android.keyaliasName = keyAlias;
		PlayerSettings.Android.keyaliasPass = keyPass;

		// Log keystore configuration for debugging
		Debug.Log($"[Build] Using custom keystore: {keystorePath}");
		Debug.Log($"[Build] Key alias: {keyAlias}");

		string[] scenes = System.Array.ConvertAll(EditorBuildSettings.scenes.Where(scene => scene.enabled).ToArray(), scene => scene.path);

		BuildPlayerOptions buildPlayerOptions = new BuildPlayerOptions
		{
			scenes = scenes,
			locationPathName = buildPath,
			target = BuildTarget.Android,
			options = BuildOptions.None  // No compression for APK
		};

		BuildReport report = BuildPipeline.BuildPlayer(buildPlayerOptions);
		CheckBuildResult(report, buildPath);
	}

	public static void BuildAAB()
	{

		// Set keystore path from the root directory of the Git project
		// Get keystore information from environment variables (GitLab CI/CD variables) - REQUIRED
		string keystorePath = System.Environment.GetEnvironmentVariable("KEYSTORE_PATH");
		string keystorePass = System.Environment.GetEnvironmentVariable("KEYSTORE_PASS");
		string keyAlias = System.Environment.GetEnvironmentVariable("KEY_ALIAS");
		string keyPass = System.Environment.GetEnvironmentVariable("KEY_PASS");

		// Validate required keystore configuration
		if (string.IsNullOrEmpty(keystorePath))
		{
			Debug.LogError("[Build] KEYSTORE_PATH environment variable is not set. Please configure keystore settings in GitLab CI/CD variables.");
			EditorApplication.Exit(1);
			return;
		}
		if (string.IsNullOrEmpty(keystorePass))
		{
			Debug.LogError("[Build] KEYSTORE_PASS environment variable is not set. Please configure keystore settings in GitLab CI/CD variables.");
			EditorApplication.Exit(1);
			return;
		}
		if (string.IsNullOrEmpty(keyAlias))
		{
			Debug.LogError("[Build] KEY_ALIAS environment variable is not set. Please configure keystore settings in GitLab CI/CD variables.");
			EditorApplication.Exit(1);
			return;
		}
		if (string.IsNullOrEmpty(keyPass))
		{
			Debug.LogError("[Build] KEY_PASS environment variable is not set. Please configure keystore settings in GitLab CI/CD variables.");
			EditorApplication.Exit(1);
			return;
		}

		// Normalize path for cross-platform compatibility (Windows \ to Unix /)
		keystorePath = keystorePath.Replace("\\", "/");

		// If path starts with \ or /, treat as relative to project root
		if (keystorePath.StartsWith("/") || keystorePath.StartsWith("\\"))
		{
			keystorePath = keystorePath.TrimStart('/', '\\');
		}

		// Convert to absolute path if it's relative
		if (!Path.IsPathRooted(keystorePath))
		{
			keystorePath = Path.Combine(Directory.GetCurrentDirectory(), keystorePath);
		}
		// Default path for the AAB
		string buildPath = "Build/Android/your_game.aab";
		string symbolsPath = "Build/Android/Symbols"; // Directory containing symbol files

		// Retrieve AAB file name from command line argument
		string[] args = System.Environment.GetCommandLineArgs();
		foreach (string arg in args)
		{
			if (arg.StartsWith("-buildPath"))
			{
				buildPath = arg.Split('=')[1];  // Get the value from the -buildPath argument
			}
		}


		// Enable custom keystore usage - CRITICAL for proper signing
		PlayerSettings.Android.useCustomKeystore = true;
		PlayerSettings.Android.keystoreName = keystorePath;
		PlayerSettings.Android.keystorePass = keystorePass;
		PlayerSettings.Android.keyaliasName = keyAlias;
		PlayerSettings.Android.keyaliasPass = keyPass;
		// Ensure usage of Google Android App Bundle format
		Debug.Log($"[Build] Using custom keystore: {keystorePath}");
		Debug.Log($"[Build] Key alias: {keyAlias}");
		EditorUserBuildSettings.buildAppBundle = true;

		// Configure symbol file generation
		EditorUserBuildSettings.androidCreateSymbols = AndroidCreateSymbols.Debugging;

		string[] scenes = System.Array.ConvertAll(EditorBuildSettings.scenes.Where(scene => scene.enabled).ToArray(), scene => scene.path);

		BuildPlayerOptions buildPlayerOptions = new BuildPlayerOptions
		{
			scenes = scenes,
			locationPathName = buildPath,
			target = BuildTarget.Android,
			options = BuildOptions.CompressWithLz4HC  // Compression option for AAB
		};

		BuildReport report = BuildPipeline.BuildPlayer(buildPlayerOptions);
		CheckBuildResult(report, buildPath);

		// Create symbols.zip if symbol files are generated
		if (Directory.Exists(symbolsPath))
		{
			string zipPath = Path.Combine("Build/Android", "symbols.zip");
			ZipFile.CreateFromDirectory(symbolsPath, zipPath);
			UnityEngine.Debug.Log("Symbols.zip created at: " + zipPath);
		}

		// Disable App Bundle build mode to avoid affecting other builds
		EditorUserBuildSettings.buildAppBundle = false;
	}
	public static void BuildiOS()
	{
		// Default path for the iOS build
		string buildPath = "Build/iOS";

		// Retrieve iOS build path from command line arguments (if specified)
		string[] args = System.Environment.GetCommandLineArgs();
		foreach (string arg in args)
		{
			if (arg.StartsWith("-buildPath"))
			{
				buildPath = arg.Split('=')[1];  // Get the value from the -buildPath argument
			}
		}

		UnityEngine.Debug.Log("Building iOS at: " + buildPath);

		// Ensure the build directory exists
		if (!Directory.Exists(buildPath))
		{
			Directory.CreateDirectory(buildPath);
		}

		// Get the scenes included in the build settings
		string[] scenes = System.Array.ConvertAll(EditorBuildSettings.scenes.Where(scene => scene.enabled).ToArray(), scene => scene.path);

		// Set up build player options
		BuildPlayerOptions buildPlayerOptions = new BuildPlayerOptions
		{
			scenes = scenes,
			locationPathName = buildPath,
			target = BuildTarget.iOS,
			options = BuildOptions.None  // No special build options
		};

		// Build the player and check the result
		BuildReport report = BuildPipeline.BuildPlayer(buildPlayerOptions);
		CheckBuildResult(report, buildPath);
	}

	private static void CheckBuildResult(BuildReport report, string buildPath)
	{
		if (report.summary.result == BuildResult.Succeeded)
		{
			UnityEngine.Debug.Log("Build succeeded: " + report.summary.totalSize + " bytes");
			if (File.Exists(buildPath))
			{
				UnityEngine.Debug.Log("File created at: " + buildPath);
				UnityEngine.Debug.Log("File size: " + new FileInfo(buildPath).Length + " bytes");
			}
			else
			{
				UnityEngine.Debug.LogError("File not found at: " + buildPath);
			}
		}
		else if (report.summary.result == BuildResult.Failed)
		{
			UnityEngine.Debug.LogError("Build failed");
		}
	}

#if UNITY_IOS
	[PostProcessBuild(999)]
	public static void OnPostprocessBuild(BuildTarget target, string pathToBuiltProject)
	{
		if (target == BuildTarget.iOS)
		{

			Debug.Log("-----[POST BUILD]: Modifying Xcode project...");
			AddFrameworks(pathToBuiltProject);

			string plistPath = Path.Combine(pathToBuiltProject, "Info.plist");

			if (File.Exists(plistPath))
			{
				Debug.Log("-----[POST BUILD]: Modifying Info.plist at " + plistPath);
				AddNonExemptEncryptionKey(plistPath);
			}
		}
	}

	private static void AddNonExemptEncryptionKey(string plistPath)
	{
		XmlDocument xmlDoc = new XmlDocument();
		xmlDoc.Load(plistPath);

		XmlNode dictNode = xmlDoc.SelectSingleNode("//dict");
		if (dictNode != null)
		{
			XmlElement keyElement = xmlDoc.CreateElement("key");
			keyElement.InnerText = "ITSAppUsesNonExemptEncryption";

			XmlElement falseElement = xmlDoc.CreateElement("false");

			dictNode.AppendChild(keyElement);
			dictNode.AppendChild(falseElement);

			xmlDoc.Save(plistPath);
			Debug.Log("-----[POST BUILD]: Successfully added ITSAppUsesNonExemptEncryption = false to Info.plist");
		}
		else
		{
			Debug.LogError("-----[POST BUILD]: Failed to find <dict> node in Info.plist");
		}
	}

	private static void AddFrameworks(string pathToBuiltProject)
	{
		string projectPath = PBXProject.GetPBXProjectPath(pathToBuiltProject);
		PBXProject project = new PBXProject();
		project.ReadFromFile(projectPath);

		// Get main target (app target)
		string targetGUID = project.GetUnityMainTargetGuid();

		// Get GUID Unity Framework (need to some Unity iOS Plugin)
		string unityFrameworkGUID = project.GetUnityFrameworkTargetGuid();

		// List added frameworks
		string[] frameworks = new string[]
		{
			"AppTrackingTransparency.framework",
			"AdSupport.framework",
			"AdServices.framework"
		};

		// Add framework to project
		foreach (string framework in frameworks)
		{
			project.AddFrameworkToProject(targetGUID, framework, false);
			project.AddFrameworkToProject(unityFrameworkGUID, framework, false);
			Debug.Log($" -----[POST BUILD]: Added {framework} to Xcode project.");
		}

		// Save changes to project.pbxproj
		project.WriteToFile(projectPath);
		Debug.Log(" -----[POST BUILD]:Successfully added frameworks to Xcode project.");
	}
#endif
}