function [installPath, installMethod] = installMatBox(mode, installationFolder, options)
% installMatBox - Install MatBox from a release or from the latest commit
%
%   installMatBox() installs the latest released version of MatBox.
%
%   installMatBox("commit") installs MatBox from the latest commit on the
%   main branch.
%
%   installMatBox("release", installationFolder, "Version", "0.9.10")
%   installs a specific released version. Version only applies to release
%   mode.
%
%   This file is the single source of truth for two contexts: the
%   install-matbox CI action in this repository, and local installs by
%   consumer toolboxes, which download this file at runtime (see
%   matlab-toolbox-template's installMatBox bootstrap). Keep it a
%   self-contained single file, and keep both the batch (CI) and
%   interactive (local) install paths working.

    arguments
        mode (1,1) string {mustBeMember(mode, ["release", "commit"])} = "release"
        installationFolder (1,1) string = fullfile(userpath, "Add-Ons")
        options.Version (1,1) string = "latest"
    end

    % Normalize version (accept both "0.9.10" and "v0.9.10")
    version = erase(options.Version, textBoundary("start") + "v");

    if mode == "release"
        [installPath, installMethod] = installFromRelease(version, installationFolder); % local function
    elseif mode == "commit"
        if version ~= "latest"
            warning("MatBox:Install:VersionIgnored", ...
                "The Version option only applies to release mode and will be ignored.")
        end
        [installPath, installMethod] = installFromCommit(installationFolder); % local function
    end

    if ~nargout
        clear installPath installMethod
    elseif nargout == 1
        clear installMethod
    end
end

function [installPath, installMethod] = installFromRelease(version, installationFolder)
    addonsTable = matlab.addons.installedAddons();
    isMatchedAddon = addonsTable.Name == "MatBox";

    % Reuse an installed MatBox addon when no specific version is requested,
    % or when the installed version matches the requested one.
    if ~isempty(isMatchedAddon) && any(isMatchedAddon)
        installedVersion = addonsTable.Version(find(isMatchedAddon, 1));
        if version == "latest" || installedVersion == version
            matlab.addons.enableAddon('MatBox')
            rehash()
            installPath = getMatBoxInstallPath();
            installMethod = "mltbx";
            return
        end
    end

    if version == "latest"
        releaseApiUrl = "https://api.github.com/repos/ehennestad/MatBox/releases/latest";
    else
        releaseApiUrl = "https://api.github.com/repos/ehennestad/MatBox/releases/tags/v" + version;
    end

    try
        info = webread(releaseApiUrl, githubWebOptions());
    catch ME
        if version ~= "latest"
            error("MatBox:Install:ReleaseNotFound", ...
                "MatBox release v%s was not found. Check available releases at %s", ...
                version, "https://github.com/ehennestad/MatBox/releases")
        else
            rethrow(ME)
        end
    end

    % Choose the install mechanism by session type. Under -batch (the mode
    % matlab-actions/run-command always uses in CI), matlab.addons.install is
    % documented by MathWorks as unsupported and has been observed to fail on
    % some MATLAB releases (e.g. R2024b) while working on others (e.g.
    % R2026a); install from the tagged source archive instead, using the same
    % addpath/savepath mechanism as commit-mode installs. In interactive
    % sessions, prefer the packaged .mltbx so MatBox is registered in the
    % Add-On Manager (visible, version-tracked, uninstallable via GUI).
    if batchStartupOptionUsed
        url = "https://github.com/ehennestad/MatBox/archive/refs/tags/" + string(info.tag_name) + ".zip";
        [installPath, installMethod] = installFromArchive(url, installationFolder);
    else
        [installPath, installMethod] = installFromMltbx(info);
    end
end

function [installPath, installMethod] = installFromMltbx(releaseInfo)
% installFromMltbx - Install the packaged .mltbx asset from a GitHub release.

    assetNames = {releaseInfo.assets.name};
    isMltbx = startsWith(assetNames, 'MatBox');

    numMatchingAssets = sum(isMltbx);
    assert(numMatchingAssets == 1, ...
        "MatBox:Install:AssetNotFound", ...
        "Expected exactly one MatBox release asset but found %d.", numMatchingAssets)

    mltbx_URL = releaseInfo.assets(isMltbx).browser_download_url;

    % Download matbox
    tempFilePath = websave(tempname, mltbx_URL);
    cleanupObj = onCleanup(@(fp) delete(tempFilePath));

    % Install toolbox
    matlab.addons.install(tempFilePath);
    rehash()
    installPath = getMatBoxInstallPath();
    installMethod = "mltbx";
end

function [installPath, installMethod] = installFromCommit(installationFolder)
    url = "https://github.com/ehennestad/MatBox/archive/refs/heads/main.zip";
    [installPath, installMethod] = installFromArchive(url, installationFolder);
end

function [installPath, installMethod] = installFromArchive(url, installationFolder)
% installFromArchive - Download a GitHub source archive (branch or tag) and
% add its code folder to the path.

    % Download the zipped source archive
    tempFilePath = websave(tempname, url);
    cleanupObj = onCleanup(@(fp) delete(tempFilePath));

    % Unzip in temporary location
    unzippedFiles = unzip(tempFilePath, tempdir);
    unzippedFolder = unzippedFiles{1};
    if endsWith(unzippedFolder, filesep)
        unzippedFolder = unzippedFolder(1:end-1);
    end

    % Move to installation location
    [~, repoFolderName] = fileparts(unzippedFolder);
    targetFolder = fullfile(installationFolder, repoFolderName);
    if isfolder(targetFolder); rmdir(targetFolder, "s"); end
    movefile(unzippedFolder, targetFolder);

    % Add to MATLAB's search path. Important: Only add code folder
    addpath(genpath(fullfile(targetFolder, 'code')))
    savepath()

    % Assign outputs
    installPath = targetFolder;
    installMethod = "folder";
end

function installPath = getMatBoxInstallPath()
    installRequirementsFile = string(which("matbox.installRequirements"));
    if installRequirementsFile == ""
        installPath = string(missing);
        return
    end

    packageFolder = fileparts(installRequirementsFile);
    codeFolder = fileparts(packageFolder);
    installPath = string(fileparts(codeFolder));
end

function options = githubWebOptions()
% githubWebOptions - weboptions carrying a GitHub auth header when available
%
%   On GitHub-hosted runners the runner IP is shared, so unauthenticated
%   calls to the GitHub REST API (60 requests/hour per IP) can fail with a
%   rate-limit error. Authenticating with the workflow token raises the
%   limit to 5000 requests/hour. Falls back to unauthenticated access when
%   GITHUB_TOKEN is not set, so local use keeps working.

    options = weboptions();
    token = string(getenv("GITHUB_TOKEN"));
    if strlength(token) > 0
        options.HeaderFields = ["Authorization", "Bearer " + token];
    end
end
